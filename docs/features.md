# Sugestão de Features e Melhorias

## Versão Review

- Integração opcional com serviços de nuvem para armazenar backups (ex: AWS S3 ou Google Cloud Storage).
- Criação de script `restore.sh` para restaurar backups gerados pelo `backup.sh`.
- Melhoria no processo de atualização para reduzir downtime (ex: blue/green deploy).
- Adição de arquivos de configuração separados para ambientes de desenvolvimento e produção.
- Documentação mais detalhada sobre integrações com equipamentos oftalmológicos.
- Inclusão de testes automatizados para os scripts de monitoramento.
- Utilização de imagens Docker menores para otimizar o consumo de recursos.

## Versão Final

- **Backup em nuvem**: adicionar suporte nativo a serviços como S3 via `rclone` para envio automático dos backups.
- **Script de restauração**: implementar `restore.sh` permitindo que um backup seja facilmente restaurado.
- **Atualizações sem interrupção**: estudar estratégias de blue/green deployment ou uso de containers paralelos para evitar downtime durante atualizações.
- **Ambientes distintos**: separar configurações de desenvolvimento e produção em arquivos `.env` específicos.
- **Integração oftalmológica**: elaborar documentação passo a passo para conectar equipamentos de diagnóstico ao OpenEMR.
- **Testes dos monitores**: criar testes para `health_monitor.sh` e scripts correlatos, garantindo maior estabilidade.
- **Imagens otimizadas**: avaliar a criação de imagens Docker customizadas com tamanho reduzido, diminuindo o tempo de download e de inicialização.
