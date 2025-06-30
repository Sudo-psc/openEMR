# Pipeline CI/CD

Este repositório utiliza o **GitHub Actions** para automatizar lint, testes e verificações de segurança.

### Principais etapas

1. **pre-commit** - Executa os hooks definidos em `.pre-commit-config.yaml` para garantir qualidade de código.
2. **Lint** - Valida o `docker-compose.yml` e roda `shellcheck` nos scripts Bash.
3. **Smoke Tests** - Sobe os contêineres de forma básica e executa verificacoes rápidas.
4. **Testes Unitários** - Executa `run-tests.sh` com os testes presentes na pasta `tests/`.

O workflow está definido em `.github/workflows/main.yml` e é executado a cada `push` ou `pull_request` para o branch `main`.
