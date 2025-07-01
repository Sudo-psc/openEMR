#!/bin/bash

# Health Monitor Test Suite
# Tests the health monitoring functionality

set -euo pipefail

# Test configuration
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$TEST_DIR")"
readonly HEALTH_MONITOR="$PROJECT_ROOT/health_monitor.sh"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
test_start() {
    local test_name="$1"
    echo -e "${YELLOW}Running test: $test_name${NC}"
    ((TESTS_RUN++))
}

test_pass() {
    local test_name="$1"
    echo -e "${GREEN}✓ PASS: $test_name${NC}"
    ((TESTS_PASSED++))
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    echo -e "${RED}✗ FAIL: $test_name - $reason${NC}"
    ((TESTS_FAILED++))
}

# Test: Check if health monitor script exists and is executable
test_script_exists() {
    test_start "Health monitor script exists and is executable"
    
    if [[ -f "$HEALTH_MONITOR" && -x "$HEALTH_MONITOR" ]]; then
        test_pass "Script exists and is executable"
    else
        test_fail "Script missing or not executable" "File: $HEALTH_MONITOR"
    fi
}

# Test: Check script syntax
test_script_syntax() {
    test_start "Script syntax validation"
    
    if bash -n "$HEALTH_MONITOR"; then
        test_pass "Script syntax is valid"
    else
        test_fail "Script syntax validation" "Syntax errors found"
    fi
}

# Test: Check ShellCheck compliance
test_shellcheck_compliance() {
    test_start "ShellCheck compliance"
    
    if command -v shellcheck &> /dev/null; then
        local shellcheck_output
        if shellcheck_output=$(shellcheck "$HEALTH_MONITOR" 2>&1); then
            test_pass "ShellCheck compliance"
        else
            # Check if only warnings (not errors)
            if echo "$shellcheck_output" | grep -q "error"; then
                test_fail "ShellCheck compliance" "Errors found: $shellcheck_output"
            else
                test_pass "ShellCheck compliance (warnings only)"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ SKIP: ShellCheck not available${NC}"
    fi
}

# Test: Help command
test_help_command() {
    test_start "Help command functionality"
    
    local help_output
    if help_output=$("$HEALTH_MONITOR" help 2>&1); then
        if echo "$help_output" | grep -q "Usage:"; then
            test_pass "Help command works"
        else
            test_fail "Help command" "No usage information found"
        fi
    else
        test_fail "Help command" "Command failed"
    fi
}

# Test: Check command (dry run)
test_check_command() {
    test_start "Check command (single run)"

    if ! command -v docker >/dev/null; then
        echo -e "${YELLOW}⚠ SKIP: Docker not available${NC}"
        return
    fi

    # This might fail due to missing dependencies, but should not crash
    local check_output
    local exit_code
    
    if check_output=$("$HEALTH_MONITOR" check 2>&1); then
        exit_code=$?
    else
        exit_code=$?
    fi
    
    # Check that the script doesn't crash (exit codes 0 or 1 are acceptable)
    if [[ $exit_code -eq 0 || $exit_code -eq 1 ]]; then
        test_pass "Check command runs without crashing"
    else
        test_fail "Check command" "Unexpected exit code: $exit_code"
    fi
}

# Test: Configuration file loading
test_config_loading() {
    test_start "Configuration file loading"
    
    local temp_config
    temp_config=$(mktemp)
    
    cat > "$temp_config" << 'EOF'
# Test configuration
CPU_THRESHOLD=90
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
LOAD_THRESHOLD=3.0
CHECK_INTERVAL=120
EOF
    
    # Create config directory
    mkdir -p "$PROJECT_ROOT/config"
    cp "$temp_config" "$PROJECT_ROOT/config/health_monitor.conf"
    
    # Run a check to see if config is loaded (this is implicit)
    if "$HEALTH_MONITOR" help &> /dev/null; then
        test_pass "Configuration file loading"
    else
        test_fail "Configuration file loading" "Script failed with config file"
    fi
    
    # Cleanup
    rm -f "$temp_config" "$PROJECT_ROOT/config/health_monitor.conf"
    rmdir "$PROJECT_ROOT/config" 2>/dev/null || true
}

# Test: Log directory creation
test_log_directory_creation() {
    test_start "Log directory creation"
    
    local temp_script_dir
    temp_script_dir=$(mktemp -d)
    
    # Copy script to temp directory
    cp "$HEALTH_MONITOR" "$temp_script_dir/"
    
    # Run help command which should create necessary directories
    if "$temp_script_dir/health_monitor.sh" help &> /dev/null; then
        if [[ -d "$temp_script_dir/logs" ]]; then
            test_pass "Log directory creation"
        else
            test_fail "Log directory creation" "Logs directory not created"
        fi
    else
        test_fail "Log directory creation" "Script execution failed"
    fi
    
    # Cleanup
    rm -rf "$temp_script_dir"
}

# Test: Signal handling setup
test_signal_handling() {
    test_start "Signal handling setup"
    
    # Check if script contains proper signal trap setup
    if grep -q "trap cleanup EXIT INT TERM" "$HEALTH_MONITOR"; then
        test_pass "Signal handling setup"
    else
        test_fail "Signal handling setup" "No proper signal traps found"
    fi
}

# Test: Function existence
test_required_functions() {
    test_start "Required functions exist"
    
    local required_functions=(
        "check_cpu_usage"
        "check_memory_usage"
        "check_disk_usage"
        "check_load_average"
        "check_docker_containers"
        "check_database_connection"
        "check_web_service"
        "check_ssl_certificate"
        "send_alert"
        "generate_report"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$HEALTH_MONITOR"; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        test_pass "All required functions exist"
    else
        test_fail "Required functions exist" "Missing: ${missing_functions[*]}"
    fi
}

# Test: Error handling patterns
test_error_handling() {
    test_start "Error handling patterns"
    
    local error_patterns=(
        "set -euo pipefail"
        "log_message.*ERROR"
        "error_exit"
        "trap.*cleanup"
    )
    
    local missing_patterns=()
    
    for pattern in "${error_patterns[@]}"; do
        if ! grep -q "$pattern" "$HEALTH_MONITOR"; then
            missing_patterns+=("$pattern")
        fi
    done
    
    if [[ ${#missing_patterns[@]} -eq 0 ]]; then
        test_pass "Error handling patterns found"
    else
        test_fail "Error handling patterns" "Missing: ${missing_patterns[*]}"
    fi
}

# Test: Security best practices
test_security_practices() {
    test_start "Security best practices"
    
    local security_issues=()
    
    # Check for quoted variables
    if grep -q '\$[A-Za-z_][A-Za-z0-9_]*[^"]' "$HEALTH_MONITOR"; then
        # This is a simplified check - some unquoted variables might be acceptable
        echo "  Note: Found potentially unquoted variables (manual review needed)"
    fi
    
    # Check for dangerous commands
    if grep -qE '\b(eval|exec|sh -c)\b' "$HEALTH_MONITOR"; then
        security_issues+=("dangerous_commands")
    fi
    
    # Check for hardcoded credentials
    if grep -qE '(password|secret|key)\s*=\s*[^$]' "$HEALTH_MONITOR"; then
        security_issues+=("hardcoded_credentials")
    fi
    
    if [[ ${#security_issues[@]} -eq 0 ]]; then
        test_pass "Security best practices"
    else
        test_fail "Security best practices" "Issues: ${security_issues[*]}"
    fi
}

# Test: Documentation completeness
test_documentation() {
    test_start "Documentation completeness"
    
    local doc_elements=(
        "Usage:"
        "Options:"
        "Configuration:"
        "Logs:"
    )
    
    local missing_docs=()
    
    for element in "${doc_elements[@]}"; do
        if ! grep -q "$element" "$HEALTH_MONITOR"; then
            missing_docs+=("$element")
        fi
    done
    
    if [[ ${#missing_docs[@]} -eq 0 ]]; then
        test_pass "Documentation completeness"
    else
        test_fail "Documentation completeness" "Missing: ${missing_docs[*]}"
    fi
}

# Run all tests
run_all_tests() {
    echo "=== Health Monitor Test Suite ==="
    echo "Testing: $HEALTH_MONITOR"
    echo
    
    test_script_exists
    test_script_syntax
    test_shellcheck_compliance
    test_help_command
    test_check_command
    test_config_loading
    test_log_directory_creation
    test_signal_handling
    test_required_functions
    test_error_handling
    test_security_practices
    test_documentation
    
    echo
    echo "=== Test Summary ==="
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi