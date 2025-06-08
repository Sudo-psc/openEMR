# Lista de To Do

## Versão Review

- Criar script `restore.sh` baseado no `backup.sh`.
- Implementar workflow de CI (GitHub Actions) para rodar `run-tests.sh` em todos os commits.
- Refatorar o `setup.sh` para aceitar parâmetros via linha de comando além do modo interativo.
- Revisar configurações do Nginx para permitir fácil alternância entre certificados autoassinados e Let's Encrypt.
- Organizar uma pasta `docs/` para centralizar a documentação.
- Verificar a necessidade de monitoramento adicional (ex: banco de dados, uso de disco).
- Avaliar uso de volumes externos para facilitar migração.

## Versão Final

- **restore.sh**: script completo para restauração de backups com opção de definir o arquivo de origem e confirmação antes da execução.
- **CI automatizado**: configurar GitHub Actions para executar `./run-tests.sh` a cada push e pull request.
- **Parametros no setup**: permitir que `setup.sh` receba todos os valores via flags, mantendo compatibilidade com o modo interativo.
- **Configuração flexível do Nginx**: disponibilizar exemplos de arquivos de configuração para cada cenário (autoassinado ou Let's Encrypt).
- **Centralização de documentação**: mover guias existentes e novos para a pasta `docs/` garantindo leitura simplificada.
- **Monitoramento ampliado**: incluir métricas de banco de dados e alerta de espaço em disco no `health_monitor.sh`.
- **Volumes externos opcionais**: documentar como utilizar volumes do host ou de serviços como EBS para persistência.
