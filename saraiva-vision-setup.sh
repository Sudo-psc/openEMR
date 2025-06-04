#!/bin/bash

set -Eeuo pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [setup] $*" >&2
}

abort() {
    log "ERRO: $*"
    exit 1
}

command -v docker-compose >/dev/null 2>&1 || abort "docker-compose nao encontrado"

log "=== Configuracao OpenEMR para Clinica Saraiva Vision ==="
log "Iniciando containers..."

# Iniciar os containers
docker-compose up -d

log "Aguardando inicializacao dos containers..."
sleep 30

log "Containers iniciados! Acesse:"
log "- OpenEMR HTTP (Local): http://localhost"
log "- OpenEMR HTTP (Produção): http://emr.saraivavision.com.br"
log "- OpenEMR HTTPS (Local): https://localhost (certificado autoassinado - avisos do navegador)"
log "- OpenEMR HTTPS (Produção): https://emr.saraivavision.com.br (certificado autoassinado - avisos do navegador)"
log "- Usuário: admin"
log "- Senha: pass"
log ""
log "NOTA SOBRE HTTPS:"
log "O sistema está configurado com certificados autoassinados para acesso HTTPS imediato."
log "Os navegadores mostrarão avisos de segurança, mas o acesso funcionará normalmente."
log ""
log "Para produção sem avisos do navegador, você pode configurar Let's Encrypt"
log "seguindo as instruções no knowledge.md ou README.md."
log ""
log "=== Configuracoes especificas para Oftalmologia ==="
log "1. Após o login, vá em Administration > Modules"
log "2. Ative os módulos relacionados a oftalmologia:"
log "   - Eye Exam Module"
log "   - Visual Acuity Tests"
log "   - Ophthalmology Forms"
log ""
log "3. Configure os formulários específicos em:"
log "   - Administration > Forms"
log "   - Adicione formulários para:"
log "     * Exame de Acuidade Visual"
log "     * Tonometria"
log "     * Fundoscopia"
log "     * Campo Visual"
log "     * Biomicroscopia"
log ""
log "4. Configure especialidades médicas:"
log "   - Administration > Lists > Medical Services"
log "   - Adicione: Oftalmologia, Retina, Glaucoma, etc."
log ""
log "=== Próximos passos ==="
log "1. Complete a configuração inicial no navegador"
log "2. Configure os usuários da clínica"
log "3. Importe templates de exames oftalmológicos"
log "4. Configure agendamento para consultas de oftalmologia"

log ""
log "Para parar os containers: docker-compose down"
log "Para ver logs: docker-compose logs -f"
log "Para ver logs do nginx: docker-compose logs -f nginx"
