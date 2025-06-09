# Configuração do OpenEMR via Docker

Este repositório disponibiliza uma configuração simples do Docker Compose para o [OpenEMR](https://www.open-emr.org/). O Nginx atua como proxy reverso e possui suporte ao Let's Encrypt.

Os scripts de instalação fazem o download automático dos modelos de oftalmologia, incluindo o formulário **Eye Exam**.

## Primeiros Passos

Em sistemas Ubuntu, execute o script `ubuntu-setup.sh` para instalar as dependências do Docker e iniciar os contêineres. O script solicitará o nome de domínio e as variáveis de ambiente principais antes de gerar o arquivo `.env` e, opcionalmente, configurar o firewall:

```bash
  sudo ./ubuntu-setup.sh
```

### OpenEMR Env Installer

Para um ambiente de desenvolvimento ou testes que inclua Docker e outras ferramentas básicas, utilize o **OpenEMR Env Installer**. Baixe o script e execute conforme abaixo:

```bash
curl -L https://raw.githubusercontent.com/openemr/openemr-devops/master/utilities/openemr-env-installer/openemr-env-installer > openemr-env-installer
chmod +x openemr-env-installer
./openemr-env-installer
```

O script instala git, Docker, docker-compose, `openemr-cmd`, minikube e `kubectl`.

```bash
bash openemr-env-installer <diretorio_do_codigo> <usuario_github>
```

Exemplo:

```bash
bash openemr-env-installer /home/test/code usuario
```

**NOTA1:** Certifique-se de criar forks do OpenEMR e do `openemr-devops` antes de rodar o instalador.

**NOTA2:** Caso pretenda usar o minikube, o sistema precisa ter:

- 2 CPUs ou mais
- 2GB de memória livre
- 20GB de espaço em disco
- Conexão à internet
- Algum gerenciador de contêiner ou máquina virtual como Docker, Hyperkit, Hyper-V, KVM, Parallels, Podman, VirtualBox ou VMWare.

Consulte [openemr-env-installer.md](openemr-env-installer.md) para a documentação completa.

Se preferir configurar manualmente:

1. Copie `.env.example` para `.env` e defina senhas fortes para o banco de dados e para o usuário inicial do OpenEMR. O serviço MySQL usa o arquivo de configuração `./mysql/my.cnf`, que desabilita `io_uring` e AIO nativo, prevenindo avisos como `io_uring_queue_init() failed with EPERM` em hosts que restringem essas funcionalidades.
2. Inicie os serviços:
   ```bash
   docker-compose up -d
   ```
3. Gere o certificado Let's Encrypt (substitua o endereço de e-mail se necessário):
   ```bash
docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot \
    --email you@example.com --agree-tos --no-eff-email \
    -d openemr.example.com
docker-compose restart nginx
   ```
4. Acesse `https://openemr.example.com` e complete o assistente de instalação.
5. Para manter a instalação atualizada, execute:
   ```bash
   ./update.sh
   ```
   Isso baixa as imagens mais recentes, cria um backup e reinicia os serviços.
6. O arquivo compose inclui um serviço `php-fpm`. Coloque seus arquivos PHP no diretório `./php` para que sejam servidos por esse contêiner.
7. Um serviço `couchdb` é fornecido para módulos que o utilizam. Defina `COUCHDB_USER` e `COUCHDB_PASSWORD` no seu `.env` para habilitá-lo. O banco de dados é exposto na porta `5984`.

## Backup

Use o script `backup.sh` para criar dumps do banco de dados no diretório `./backups`.

```bash
./backup.sh
```

Defina a variável `RCLONE_REMOTE` para enviar o arquivo automaticamente usando o [rclone](https://rclone.org). O valor deve ser um caminho remoto configurado, como `s3:meubucket/backups`.

Agende esse script no `cron` para execução diária.

## Notas de Segurança

- As senhas ficam armazenadas no arquivo `.env`, que é ignorado pelo Git.
- A configuração do Nginx inclui cabeçalhos de segurança e força o uso de HTTPS.
- Mantenha contêineres e imagens atualizados.

## Configuração do Firewall

Execute `./firewall-setup.sh` como root para liberar as portas 80 e 443 para os contêineres Docker.

## Comandos Úteis

- Iniciar/atualizar serviços: `docker-compose up -d`
- Parar serviços: `docker-compose down`
- Visualizar logs: `docker-compose logs -f`

### Utilitário openemr-cmd

Este repositório acompanha o script auxiliar `openemr-cmd` do projeto [openemr-devops](https://github.com/openemr/openemr-devops). Durante a configuração, ele é instalado em `~/.local/bin`, ficando disponível no seu shell. Rode `openemr-cmd -h` para ver os subcomandos que facilitam o gerenciamento do ambiente Docker.

### Removendo o aviso ServerName do Apache

Se aparecer a mensagem:

```
AH00558: httpd: Could not reliably determine the server's fully qualified domain name
```

O Apache precisa da diretiva `ServerName`. O compose monta `apache/servername.conf` dentro do contêiner OpenEMR definindo `localhost`. Edite esse arquivo se desejar usar outro domínio.

## Solução de Problemas - 502 Bad Gateway

Uma resposta 502 do Nginx geralmente significa que ele não consegue acessar o contêiner OpenEMR ou que a aplicação falhou ao iniciar. Verifique o seguinte:

1. Confirme se todos os contêineres estão em execução:
   ```bash
   docker-compose ps
   ```
   Os serviços `openemr`, `mysql` e `nginx` devem aparecer como `Up`.
2. Certifique-se de que o arquivo `.env` possui credenciais válidas do banco de dados. Valores incorretos podem fazer o contêiner OpenEMR encerrar.
3. Verifique os logs dos contêineres:
   ```bash
   docker-compose logs openemr
docker-compose logs nginx
   ```
4. Após corrigir qualquer problema, reinicie os serviços:
   ```bash
   docker-compose restart openemr nginx
   ```

## Monitoramento de Logs com OpenAI

Use `log-monitor-openai.sh` para resumir logs dos contêineres com a API da OpenAI. O script utiliza o modelo `gpt-4o` para resumos mais precisos. Defina `OPENAI_API_KEY` e execute:

```bash
OPENAI_API_KEY=sua_chave ./log-monitor-openai.sh
```

## Executando os Testes

Rode a suíte de testes em shell para validar os scripts auxiliares:

```bash
./run-tests.sh
```

## CI/CD

Um workflow do GitHub Actions localizado em `.github/workflows/main.yml` verifica a configuração do Docker Compose, executa lints nos scripts shell e faz um simples smoke test. Esse teste sobe os serviços com o arquivo de ambiente de exemplo, roda o `backup.sh` e depois derruba tudo. Use esse workflow como ponto de partida para implantações automáticas.

Para instruções detalhadas, consulte `README-Ophthalmology.md`.

## Monitoramento de Saúde

### Visão Geral
O script `health_monitor.sh` executa verificações regulares nos componentes vitais do ambiente Docker do OpenEMR, incluindo a própria aplicação, o banco MySQL, o proxy Nginx e o status de renovação do certificado do Certbot. Ele registra o resultado das verificações e pode enviar alertas por e-mail se algo falhar.

### Pré-requisitos
São necessários no sistema onde `health_monitor.sh` será executado:

* **`bash`**
* **`curl`**
* **`docker`** (o usuário deve ter permissão para utilizá-lo)
* **`openssl`**
* **`mailutils`** (opcional, para envio de e-mails)
* Contêineres do OpenEMR, MySQL, Nginx e Certbot rodando conforme definidos em `docker-compose.yml`

### Configuração
O script é configurado principalmente via variáveis de ambiente. Itens críticos como senhas e e-mails de destino devem ser definidos.

Principais variáveis:

* `OPENEMR_URL`: URL de login do OpenEMR (padrão: `https://emr.saraivavision.com.br`)
* `MYSQL_CONTAINER_NAME`: nome do contêiner MySQL (padrão: `mysql`)
* `DB_USER`: usuário para teste de conectividade (padrão: `openemr` ou valor de `MYSQL_USER`)
* `DB_PASS`: senha do `DB_USER` **obrigatória**
* `MYSQL_ROOT_PASSWORD`: senha de root do MySQL (usada como fallback)
* `NGINX_CONTAINER_NAME`: nome do contêiner Nginx (padrão: `nginx`)
* `NGINX_HEALTH_URL_INTERNAL`: URL interna de verificação do Nginx (padrão: `http://localhost/health.html`)
* `SSL_DOMAIN_TO_CHECK`: domínio para verificar validade do certificado SSL (padrão: `emr.saraivavision.com.br`)
* `SSL_CERT_WARN_DAYS`: dias antes do vencimento para gerar alerta (padrão: `30`)
* `CERTBOT_CONTAINER_NAME`: contêiner do Certbot (padrão: `certbot`)
* `CERTBOT_LOG_LINES_TO_CHECK`: linhas recentes do log a verificar (padrão: `50`)
* `ALERT_EMAIL_RECIPIENT`: e-mail que receberá notificações (obrigatório para alertas)
* `ALERT_EMAIL_SUBJECT_PREFIX`: prefixo do assunto dos e-mails (padrão: `[HealthMonitor Alert]`)

Exemplo de execução com variáveis:

```bash
export DB_PASS="senha_openemr"
export MYSQL_ROOT_PASSWORD="senha_root"
export ALERT_EMAIL_RECIPIENT="sysadmin@example.com"
./health_monitor.sh
```

### Execução Manual
1. Torne o script executável:
   ```bash
   chmod +x health_monitor.sh
   ```
2. Rode o script (garanta que as variáveis estejam configuradas):
   ```bash
   ./health_monitor.sh
   ```

### Agendamento com Cron
Para agendar o monitor em intervalos regulares, crie um wrapper script (para lidar com variáveis de ambiente) e adicione uma entrada no `crontab`, por exemplo:

```cron
*/15 * * * * /caminho/projeto/run_health_monitor_cron.sh
```

### Interpretando a Saída
O script registra suas ações e resultados no stdout. Se executado via cron, redirecione a saída para um arquivo de log. O status final indica se todas as verificações passaram (`0`) ou se houve falhas (`1`).

## OpenEMR Monitor

O script **openemr-monitor-setup.sh** instala o stack de monitoramento (Grafana, Prometheus, cAdvisor e AlertManager) do projeto [openemr-devops](https://github.com/openemr/openemr-devops).

Execute com os parâmetros necessários:

```bash
./openemr-monitor-setup.sh <diretorio_instalacao> <ip_host> \
  <smtp:porta> <email_remetente> <senha_remetente> <email_destino>
```

Após a instalação, os serviços ficam disponíveis nas seguintes portas:
- **Grafana:** `http://<ip_host>:3000` (login `admin`/`admin`)
- **Prometheus:** `http://<ip_host>:3001`
- **cAdvisor:** `http://<ip_host>:3002/metrics`
- **AlertManager:** `http://<ip_host>:3003`

## Como Contribuir

Consulte o [guia de contribuição](docs/CONTRIBUICAO.md) para saber como enviar melhorias ao projeto.

