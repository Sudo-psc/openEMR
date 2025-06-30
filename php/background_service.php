<?php
declare(strict_types=1);

/**
 * Manage background operations that should be executed at intervals.
 *
 * This script may be executed by a suitable Ajax request, by a cron job, or both.
 *
 * When called from cron, optinal args are [site] [service] [force]
 * @param site to specify a specific site, 'default' used if omitted
 * @param service to specify a specific service, 'all' used if omitted
 * @param force '1' to ignore specified wait interval, '0' to honor wait interval
 *
 * The same parameters can be accessed via Ajax using the $_POST variables
 * 'site', 'background_service', and 'background_force', respectively.
 *
 * For both calling methods, this script guarantees that each active
 * background service function: (1) will not be called again before it has completed,
 * and (2) will not be called any more frequently than at the specified interval
 * (unless the force execution flag is used).  A service function that is already running
 * will not be called a second time even if the force execution flag is used.
 *
 * Notes for the default background behavior:
 * 1. If the Ajax method is used, services will only be checked while
 * Ajax requests are being received, which is currently only when users are
 * logged in.
 * 2. All services are checked and called sequentially in the order specified
 * by the sort_order field in the background_services table. Service calls that are "slow"
 * should be given a higher sort_order value.
 * 3. The actual interval between two calls to a given background service may be
 * as long as the time to complete that service plus the interval between
 * n+1 calls to this script where n is the number of other services preceding it
 * in the array, even if the specified minimum interval is shorter, so plan
 * accordingly. Example: with a 5 min cron interval, the 4th service on the list
 * may not be started again for up to 20 minutes after it has completed if
 * services 1, 2, and 3 take more than 15, 10, and 5 minutes to complete,
 * respectively.
 *
 * Returns a count of due messages for current user.
 *
 * @package   OpenEMR
 * @link      https://www.open-emr.org
 * @author    EMR Direct <https://www.emrdirect.com/>
 * @author    Brady Miller <brady.g.miller@gmail.com>
 * @copyright Copyright (c) 2013 EMR Direct <https://www.emrdirect.com/>
 * @copyright Copyright (c) 2018 Brady Miller <brady.g.miller@gmail.com>
 * @license   https://github.com/openemr/openemr/blob/master/LICENSE GNU General Public License 3
 */

use OpenEMR\Common\Csrf\CsrfUtils;

require_once 'vendor/autoload.php';

use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Monolog\Handler\RotatingFileHandler;
use Monolog\Formatter\LineFormatter;

/**
 * Background Service Class
 */
class BackgroundService
{
    private Logger $logger;
    private array $config;
    private bool $running = false;
    private string $pidFile;
    
    /**
     * Constructor
     */
    public function __construct(array $config = [])
    {
        $this->config = array_merge($this->getDefaultConfig(), $config);
        $this->pidFile = $this->config['pid_file'];
        $this->initializeLogger();
        
        // Set up signal handlers
        pcntl_signal(SIGTERM, [$this, 'handleSignal']);
        pcntl_signal(SIGINT, [$this, 'handleSignal']);
        pcntl_signal(SIGQUIT, [$this, 'handleSignal']);
    }
    
    /**
     * Get default configuration
     */
    private function getDefaultConfig(): array
    {
        return [
            'log_file' => '/var/log/openemr/background_service.log',
            'log_level' => Logger::INFO,
            'pid_file' => '/var/run/openemr_background.pid',
            'max_execution_time' => 3600, // 1 hour
            'sleep_interval' => 60, // 1 minute
            'database' => [
                'host' => $_ENV['DB_HOST'] ?? 'localhost',
                'port' => (int)($_ENV['DB_PORT'] ?? 3306),
                'username' => $_ENV['DB_USER'] ?? 'openemr',
                'password' => $_ENV['DB_PASS'] ?? '',
                'database' => $_ENV['DB_NAME'] ?? 'openemr'
            ]
        ];
    }
    
    /**
     * Initialize logger
     */
    private function initializeLogger(): void
    {
        $this->logger = new Logger('background_service');
        
        // Add rotating file handler
        $fileHandler = new RotatingFileHandler(
            $this->config['log_file'],
            0,
            $this->config['log_level']
        );
        
        // Add console handler for development
        $consoleHandler = new StreamHandler('php://stdout', Logger::DEBUG);
        
        // Set custom formatter
        $formatter = new LineFormatter(
            "[%datetime%] %channel%.%level_name%: %message% %context% %extra%\n",
            'Y-m-d H:i:s'
        );
        
        $fileHandler->setFormatter($formatter);
        $consoleHandler->setFormatter($formatter);
        
        $this->logger->pushHandler($fileHandler);
        $this->logger->pushHandler($consoleHandler);
    }
    
    /**
     * Start the background service
     */
    public function start(): void
    {
        try {
            $this->checkIfRunning();
            $this->writePidFile();
            $this->running = true;
            
            $this->logger->info('Background service started', ['pid' => getmypid()]);
            
            $startTime = time();
            $maxExecutionTime = $this->config['max_execution_time'];
            
            while ($this->running) {
                $this->processTasks();
                
                // Check if we've exceeded max execution time
                if (time() - $startTime > $maxExecutionTime) {
                    $this->logger->info('Max execution time reached, stopping service');
                    break;
                }
                
                // Process pending signals
                pcntl_signal_dispatch();
                
                // Sleep before next iteration
                sleep($this->config['sleep_interval']);
            }
            
        } catch (Exception $e) {
            $this->logger->error('Service error: ' . $e->getMessage(), [
                'exception' => $e,
                'trace' => $e->getTraceAsString()
            ]);
            throw $e;
        } finally {
            $this->cleanup();
        }
    }
    
    /**
     * Stop the background service
     */
    public function stop(): void
    {
        $this->running = false;
        $this->logger->info('Background service stop requested');
    }
    
    /**
     * Check if service is already running
     */
    private function checkIfRunning(): void
    {
        if (file_exists($this->pidFile)) {
            $pid = (int)file_get_contents($this->pidFile);
            
            if ($pid > 0 && posix_kill($pid, 0)) {
                throw new RuntimeException("Service already running with PID: $pid");
            } else {
                // Stale PID file
                unlink($this->pidFile);
                $this->logger->warning('Removed stale PID file', ['pid' => $pid]);
            }
        }
    }
    
    /**
     * Write PID file
     */
    private function writePidFile(): void
    {
        $pid = getmypid();
        
        if (file_put_contents($this->pidFile, $pid) === false) {
            throw new RuntimeException("Failed to write PID file: {$this->pidFile}");
        }
        
        $this->logger->debug('PID file written', ['pid' => $pid, 'file' => $this->pidFile]);
    }
    
    /**
     * Process background tasks
     */
    private function processTasks(): void
    {
        $this->logger->debug('Processing background tasks');
        
        try {
            // Task 1: Database maintenance
            $this->performDatabaseMaintenance();
            
            // Task 2: Log cleanup
            $this->performLogCleanup();
            
            // Task 3: Cache cleanup
            $this->performCacheCleanup();
            
            // Task 4: Session cleanup
            $this->performSessionCleanup();
            
            // Task 5: Backup validation
            $this->validateBackups();
            
            $this->logger->debug('Background tasks completed successfully');
            
        } catch (Exception $e) {
            $this->logger->error('Error processing tasks: ' . $e->getMessage(), [
                'exception' => $e
            ]);
        }
    }
    
    /**
     * Perform database maintenance
     */
    private function performDatabaseMaintenance(): void
    {
        try {
            $pdo = $this->getDatabaseConnection();
            
            // Optimize tables
            $tables = ['audit_master', 'log', 'api_log', 'sessions'];
            
            foreach ($tables as $table) {
                $stmt = $pdo->prepare("OPTIMIZE TABLE $table");
                $stmt->execute();
                $this->logger->debug("Optimized table: $table");
            }
            
            // Clean old audit logs (older than 6 months)
            $stmt = $pdo->prepare("DELETE FROM audit_master WHERE date < DATE_SUB(NOW(), INTERVAL 6 MONTH)");
            $deleted = $stmt->execute();
            $rowCount = $stmt->rowCount();
            
            if ($rowCount > 0) {
                $this->logger->info("Cleaned audit logs", ['deleted_rows' => $rowCount]);
            }
            
        } catch (PDOException $e) {
            $this->logger->error('Database maintenance error: ' . $e->getMessage());
            throw $e;
        }
    }
    
    /**
     * Perform log cleanup
     */
    private function performLogCleanup(): void
    {
        $logDirs = [
            '/var/log/openemr',
            '/var/log/nginx',
            '/var/log/apache2'
        ];
        
        foreach ($logDirs as $logDir) {
            if (!is_dir($logDir)) {
                continue;
            }
            
            $this->cleanOldLogs($logDir, 30); // Keep logs for 30 days
        }
    }
    
    /**
     * Clean old log files
     */
    private function cleanOldLogs(string $directory, int $daysToKeep): void
    {
        $cutoffTime = time() - ($daysToKeep * 24 * 60 * 60);
        $deletedFiles = 0;
        
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($directory),
            RecursiveIteratorIterator::LEAVES_ONLY
        );
        
        foreach ($iterator as $file) {
            if ($file->isFile() && $file->getMTime() < $cutoffTime) {
                if (preg_match('/\.(log|log\.\d+)$/', $file->getFilename())) {
                    unlink($file->getPathname());
                    $deletedFiles++;
                }
            }
        }
        
        if ($deletedFiles > 0) {
            $this->logger->info("Cleaned old logs", [
                'directory' => $directory,
                'deleted_files' => $deletedFiles,
                'days_kept' => $daysToKeep
            ]);
        }
    }
    
    /**
     * Perform cache cleanup
     */
    private function performCacheCleanup(): void
    {
        $cacheDirs = [
            '/tmp/openemr_cache',
            '/var/cache/openemr',
            sys_get_temp_dir() . '/openemr'
        ];
        
        foreach ($cacheDirs as $cacheDir) {
            if (is_dir($cacheDir)) {
                $this->cleanCacheDirectory($cacheDir);
            }
        }
    }
    
    /**
     * Clean cache directory
     */
    private function cleanCacheDirectory(string $directory): void
    {
        $cutoffTime = time() - (24 * 60 * 60); // 1 day
        $deletedFiles = 0;
        
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($directory),
            RecursiveIteratorIterator::LEAVES_ONLY
        );
        
        foreach ($iterator as $file) {
            if ($file->isFile() && $file->getMTime() < $cutoffTime) {
                unlink($file->getPathname());
                $deletedFiles++;
            }
        }
        
        if ($deletedFiles > 0) {
            $this->logger->info("Cleaned cache directory", [
                'directory' => $directory,
                'deleted_files' => $deletedFiles
            ]);
        }
    }
    
    /**
     * Perform session cleanup
     */
    private function performSessionCleanup(): void
    {
        try {
            $pdo = $this->getDatabaseConnection();
            
            // Clean expired sessions
            $stmt = $pdo->prepare("DELETE FROM sessions WHERE last_updated < DATE_SUB(NOW(), INTERVAL 24 HOUR)");
            $stmt->execute();
            $rowCount = $stmt->rowCount();
            
            if ($rowCount > 0) {
                $this->logger->info("Cleaned expired sessions", ['deleted_rows' => $rowCount]);
            }
            
        } catch (PDOException $e) {
            $this->logger->error('Session cleanup error: ' . $e->getMessage());
        }
    }
    
    /**
     * Validate backups
     */
    private function validateBackups(): void
    {
        $backupDir = '/var/backups/openemr';
        
        if (!is_dir($backupDir)) {
            $this->logger->warning('Backup directory not found', ['directory' => $backupDir]);
            return;
        }
        
        $recentBackups = glob("$backupDir/backup_*.sql");
        usort($recentBackups, function ($a, $b) {
            return filemtime($b) - filemtime($a);
        });
        
        if (empty($recentBackups)) {
            $this->logger->warning('No backup files found', ['directory' => $backupDir]);
            return;
        }
        
        $latestBackup = $recentBackups[0];
        $backupAge = time() - filemtime($latestBackup);
        
        if ($backupAge > (24 * 60 * 60)) { // Older than 1 day
            $this->logger->warning('Latest backup is old', [
                'file' => basename($latestBackup),
                'age_hours' => round($backupAge / 3600, 2)
            ]);
        } else {
            $this->logger->debug('Backup validation passed', [
                'latest_backup' => basename($latestBackup),
                'age_hours' => round($backupAge / 3600, 2)
            ]);
        }
    }
    
    /**
     * Get database connection
     */
    private function getDatabaseConnection(): PDO
    {
        static $pdo = null;
        
        if ($pdo === null) {
            $config = $this->config['database'];
            $dsn = "mysql:host={$config['host']};port={$config['port']};dbname={$config['database']};charset=utf8mb4";
            
            $options = [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::MYSQL_ATTR_INIT_COMMAND => "SET sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'"
            ];
            
            $pdo = new PDO($dsn, $config['username'], $config['password'], $options);
        }
        
        return $pdo;
    }
    
    /**
     * Handle system signals
     */
    public function handleSignal(int $signal): void
    {
        $this->logger->info('Received signal', ['signal' => $signal]);
        
        switch ($signal) {
            case SIGTERM:
            case SIGINT:
            case SIGQUIT:
                $this->stop();
                break;
        }
    }
    
    /**
     * Cleanup resources
     */
    private function cleanup(): void
    {
        if (file_exists($this->pidFile)) {
            unlink($this->pidFile);
        }
        
        $this->logger->info('Background service stopped');
    }
}

/**
 * Service runner function
 */
function runBackgroundService(array $config = []): void
{
    try {
        $service = new BackgroundService($config);
        $service->start();
    } catch (Exception $e) {
        error_log("Background service error: " . $e->getMessage());
        exit(1);
    }
}

// CLI execution
if (php_sapi_name() === 'cli') {
    $config = [];
    
    // Parse command line arguments
    $options = getopt('c:', ['config:']);
    if (isset($options['c']) || isset($options['config'])) {
        $configFile = $options['c'] ?? $options['config'];
        if (file_exists($configFile)) {
            $config = include $configFile;
        }
    }
    
    runBackgroundService($config);
}

//ajax param should be set by calling ajax scripts
$isAjaxCall = isset($_POST['ajax']);

//if false ajax and this is a called from command line, this is a cron job and set up accordingly
if (!$isAjaxCall && (php_sapi_name() === 'cli')) {
    $ignoreAuth = 1;
    //process optional arguments when called from cron
    $_GET['site'] = $argv[1] ?? 'default';
    if (isset($argv[2]) && $argv[2] != 'all') {
        $_GET['background_service'] = $argv[2];
    }

    if (isset($argv[3]) && $argv[3] == '1') {
        $_GET['background_force'] = 1;
    }

    //an additional require file can be specified for each service in the background_services table
    // Since from command line, set $sessionAllowWrite since need to set site_id session and no benefit to set to false
    $sessionAllowWrite = true;
    require_once(__DIR__ . "/../../interface/globals.php");
} else {
    //an additional require file can be specified for each service in the background_services table
    require_once(__DIR__ . "/../../interface/globals.php");

    // not calling from cron job so ensure passes csrf check
    if (!CsrfUtils::verifyCsrfToken($_POST["csrf_token_form"])) {
        CsrfUtils::csrfNotVerified();
    }
}

//Remove time limit so script doesn't time out
set_time_limit(0);

//Safety in case one of the background functions tries to output data
ignore_user_abort(1);

/**
 * Execute background services
 * This function reads a list of available services from the background_services table
 * For each service that is not already running and is due for execution, the associated
 * background function is run.
 *
 * Note: Each service must do its own logging, as appropriate, and should disable itself
 * to prevent continued service calls if an error condition occurs which requires
 * administrator intervention. Any service function return values and output are ignored.
 */

function execute_background_service_calls()
{
  /**
   * Note: The global $service_name below is set to the name of the service currently being
   * processed before the actual service function call, and is unset after normal
   * completion of the loop. If the script exits abnormally, the shutdown_function
   * uses the value of $service_name to do any required clean up.
   */
    global $service_name;

    $single_service = isset($_REQUEST['background_service']) ? $_REQUEST['background_service'] : '';
    $force = (isset($_REQUEST['background_force']) && $_REQUEST['background_force']);

    $sql = 'SELECT * FROM background_services WHERE ' . ($force ? '1' : 'execute_interval > 0');
    if ($single_service != "") {
        $services = sqlStatementNoLog($sql . ' AND name=?', array($single_service));
    } else {
        $services = sqlStatementNoLog($sql . ' ORDER BY sort_order');
    }

    while ($service = sqlFetchArray($services)) {
        $service_name = $service['name'];
        if (!$service['active'] || $service['running'] == 1) {
            continue;
        }

        $interval = (int)$service['execute_interval'];

        //leverage locking built-in to UPDATE to prevent race conditions
        //will need to assess performance in high concurrency setting at some point
        $sql = 'UPDATE background_services SET running = 1, next_run = NOW()+ INTERVAL ?'
        . ' MINUTE WHERE running < 1 ' . ($force ? '' : 'AND NOW() > next_run ') . 'AND name = ?';
        if (sqlStatementNoLog($sql, array($interval,$service_name)) === false) {
            continue;
        }

        $acquiredLock =  generic_sql_affected_rows();
        if ($acquiredLock < 1) {
            continue; //service is already running or not due yet
        }

        if ($service['require_once']) {
            require_once($GLOBALS['fileroot'] . $service['require_once']);
        }

        if (!function_exists($service['function'])) {
            continue;
        }

        //use try/catch in case service functions throw an unexpected Exception
        try {
            $service['function']();
        } catch (Exception $e) {
          //do nothing
        }

        $sql = 'UPDATE background_services SET running = 0 WHERE name = ?';
        $res = sqlStatementNoLog($sql, array($service_name));
    }
}

/**
 * Catch unexpected failures.
 *
 * if the global $service_name is still set, then a die() or exit() occurred during the execution
 * of that service's function call, and we did not complete the foreach loop properly,
 * so we need to reset the is_running flag for that service before quitting
 */

function background_shutdown()
{
    global $service_name;
    if (isset($service_name)) {
        $sql = 'UPDATE background_services SET running = 0 WHERE name = ?';
        $res = sqlStatementNoLog($sql, array($service_name));
    }
}

register_shutdown_function('background_shutdown');
execute_background_service_calls();
unset($service_name);
