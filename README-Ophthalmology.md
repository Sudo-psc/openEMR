# OpenEMR para Clínica de Oftalmologia - Configuração

## Instalação e Configuração

### 1. Prerequisites
- A domain name (e.g., `openemr.example.com`) pointing to your server's public IP address.
- Ports 80 and 443 open on your server.

### 2. Initial Setup Script
The `setup.sh` script can be used to bring up the containers initially.
```bash
./setup.sh
```
This will start all services defined in `docker-compose.yml`.

### 3. SSL Certificate Generation (Let's Encrypt)
This setup uses Let's Encrypt for SSL certificates. After running the setup script (or `docker-compose up -d`):

   **a. Obtain Initial Certificate:**
   Run the following command, replacing `philipe_cruz@outlook.com` with your email:
   ```bash
   docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot \
       --email philipe_cruz@outlook.com --agree-tos --no-eff-email \
       -d openemr.example.com
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
- **URL HTTPS**: `https://openemr.example.com` (Recomendado para produção; usa Let's Encrypt)
- **URL HTTP**: `http://openemr.example.com` (Produção) ou `http://localhost` (Local/desenvolvimento)
- **Usuário**: admin
- **Senha**: pass

**Nota sobre `https://localhost`**: Acessar `https://localhost` provavelmente mostrará avisos de certificado, pois o certificado Let's Encrypt é para `openemr.example.com`. Para acesso local, prefira `http://localhost`.

## Segurança SSL/HTTPS (Let's Encrypt)

### Características de Segurança:
- **Let's Encrypt Certificates**: Trusted SSL certificates for `openemr.example.com`.
- **Automated Renewal**: Certbot service automatically renews certificates.
- **Protocolos seguros** TLS 1.2 e 1.3.
- **Headers de segurança** configurados.
- **Content Security Policy (CSP)**: `upgrade-insecure-requests` para `https://openemr.example.com` para ajudar a prevenir conteúdo misto.
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

# Manually renew certificates (usually not needed)
docker-compose run --rm certbot renew
```

## Backup e Restauração de Dados



Para restaurar um backup existente (substitua `arquivo_de_backup.sql.gz` pelo nome do arquivo desejado):

```bash
gunzip < arquivo_de_backup.sql.gz \
  | docker-compose exec -T mysql \
    mysql --user="${MYSQL_USER:-openemr}" --password="${MYSQL_PASSWORD:-openemr}" "${MYSQL_DATABASE:-openemr}"
echo "Restauração concluída"
```

**Observação:** Ajuste `MYSQL_USER`, `MYSQL_PASSWORD` e `MYSQL_DATABASE` conforme definido no seu `docker-compose.yml`. Esse método evita exposições acidentais de senha no histórico de comandos.

**Observação:** O diretório `ssl/`, contendo certificados autoassinados, não é mais utilizado por padrão quando o Let's Encrypt estiver ativo. Ele pode ser mantido para fallback ou desenvolvimento local, desde que o Nginx seja ajustado.

## Próximos Passos

1. Complete os passos de geração inicial de certificados descritos acima.
2. Acesse o OpenEMR em `https://openemr.example.com` e conclua o assistente de configuração.
3. Configure os usuários específicos da clínica.
4. Importe os templates de exames oftalmológicos.
5. Configure o agendamento para diferentes tipos de consulta.
6. Configure relatórios específicos para oftalmologia.
7. Integre com equipamentos oftalmológicos (se necessário).
8. Em produção, substitua os certificados autoassinados por certificados válidos.

## Suporte

Para suporte técnico ou dúvidas sobre configuração, consulte a documentação oficial do OpenEMR ou entre em contato com o administrador do sistema.
