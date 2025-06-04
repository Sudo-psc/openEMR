# OpenEMR para Clínica Saraiva Vision - Configuração Oftalmológica

## Instalação e Configuração

### 1. Prerequisites
- A domain name (e.g., `emr.saraivavision.com.br`) pointing to your server's public IP address.
- Ports 80, 443, 5984 and 6379 open on your server.
- CouchDB stores documents on port 5984 and Redis provides caching on 6379.
- CrowdSec monitors Nginx logs for threats.

### 2. Initial Setup Script
The `saraiva-vision-setup.sh` script can be used to bring up the containers initially.
```bash
./saraiva-vision-setup.sh
```
This will start all services defined in `docker-compose.yml`.

### 3. SSL Certificate Generation (Let's Encrypt)
This setup uses Let's Encrypt for SSL certificates. After running the setup script (or `docker-compose up -d`):

   **a. Obtain Initial Certificate:**
   Run the following command, replacing `philipe_cruz@outlook.com` with your email:
   ```bash
   docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot \
       --email philipe_cruz@outlook.com --agree-tos --no-eff-email \
       -d emr.saraivavision.com.br
   ```

   **b. Restart Nginx:**
   After successful certificate issuance:
   ```bash
   docker-compose restart nginx
   ```

   **c. Ensure Certbot is Running for Renewals:**
   The `certbot` service handles automatic renewals. Make sure it's running:
   ```bash
   docker-compose up -d certbot 
   # Or ensure all services are up:
   # docker-compose up -d
   ```

### 4. Acesso ao Sistema
- **URL HTTPS**: `https://emr.saraivavision.com.br` (Secure, uses Let's Encrypt)
- **Usuário**: admin
- **Senha**: pass

**Nota sobre `localhost`**: Accessing via `https://localhost` will show certificate warnings because the Let's Encrypt certificate is for `emr.saraivavision.com.br`, not `localhost`.

## Segurança SSL/HTTPS (Let's Encrypt)

### Características de Segurança:
- **Let's Encrypt Certificates**: Trusted SSL certificates for `emr.saraivavision.com.br`.
- **Automated Renewal**: Certbot service automatically renews certificates.
- **Redirecionamento automático** HTTP → HTTPS.
- **Protocolos seguros** TLS 1.2 e 1.3.
- **Headers de segurança** configurados.
- **Content Security Policy (CSP)**: `upgrade-insecure-requests` to upgrade insecure HTTP requests and prevent mixed content.
- **Proxy reverso nginx** for managing SSL and serving OpenEMR.

### For Production:
This setup is designed for production use with Let's Encrypt. Ensure your domain's DNS is correctly configured.

## Módulos de Oftalmologia

### Módulos Essenciais para Ativar:
1. **Eye Exam Module** - Exames oftalmológicos completos
2. **Visual Acuity Tests** - Testes de acuidade visual
3. **Ophthalmology Forms** - Formulários específicos

### Formulários Específicos para Configurar:

#### Exames Básicos:
- **Acuidade Visual** (Snellen, LogMAR)
- **Refração** (Subjetiva e Objetiva)
- **Tonometria** (Pressão Intraocular)
- **Biomicroscopia** (Segmento Anterior)

#### Exames Especializados:
- **Fundoscopia** (Exame de Fundo de Olho)
- **Campo Visual** (Perimetria)
- **OCT** (Tomografia de Coerência Óptica)
- **Angiografia** (Fluoresceínica e Verde Indocianina)

## Configurações Específicas da Clínica

### Especialidades Médicas:
- Oftalmologia Geral
- Retina e Vítreo
- Glaucoma
- Córnea e Doenças Externas
- Oculoplástica
- Pediatria Oftalmológica

### Templates de Consulta:
- Consulta Inicial Oftalmológica
- Retorno Oftalmológico
- Pré-operatório
- Pós-operatório
- Urgência Oftalmológica

## Comandos Úteis

```bash
# Iniciar containers
docker-compose up -d

# Parar containers
docker-compose down

# Ver logs
docker-compose logs -f

# Ver logs específicos do nginx
docker-compose logs -f nginx

# Ver logs do certbot
docker-compose logs -f certbot
# Ver logs do CouchDB
docker-compose logs -f couchdb
# Ver logs do Redis
docker-compose logs -f redis
# Ver decisões do CrowdSec
docker-compose exec crowdsec cscli decisions list

# Manually renew certificates (usually not needed)
docker-compose run --rm certbot renew

# Backup dos dados
Utilize o script `backup.sh` para gerar dumps do banco de dados em `./backups`.
Ele salva MySQL, CouchDB e Redis em um único comando:

```bash
./backup.sh
```
O script também gera um arquivo compactado com os dados do CouchDB.

# Restaurar backup manualmente
docker-compose exec -i mysql mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" openemr < caminho/para/arquivo.sql
```
**Note:** The `docker/ssl/` directory with self-signed certificates is no longer used by default if Let's Encrypt is active. It can be kept for fallback or local-only development if Nginx config is adjusted.

## Próximos Passos

1. Complete the initial certificate generation steps above.
2. Access OpenEMR via `https://emr.saraivavision.com.br` and complete the setup wizard.
3. Configure usuários específicos da clínica.
4. Importe templates de exames oftalmológicos
5. Configure agendamento para diferentes tipos de consulta
6. Configure relatórios específicos para oftalmologia
7. Integre com equipamentos oftalmológicos (se necessário)
8. Para produção: substitua certificados auto-assinados por certificados válidos

## Suporte

Para suporte técnico ou dúvidas sobre configuração, consulte a documentação oficial do OpenEMR ou entre em contato com o administrador do sistema.
