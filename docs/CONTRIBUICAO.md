# Como Contribuir

Obrigado por seu interesse em contribuir com o projeto OpenEMR Docker Setup! Segue abaixo um guia simples de como colaborar.

## 1. Fork e Clone

1. Acesse o repositório principal no GitHub e crie um **fork** em sua conta.
2. Clone o fork para sua máquina:

```bash
git clone https://github.com/<seu_usuario>/openEMR.git
```

## 2. Crie um Branch

Navegue até o diretório clonado e crie um branch para sua modificação:

```bash
cd openEMR
git checkout -b minha-contribuicao
```

## 3. Realize as Mudanças

Edite os arquivos necessários e faça *commits* com mensagens claras, de preferência em português ou inglês.

## 4. Rode os Testes

Execute o script abaixo para garantir que as alterações não quebram nada:

```bash
./run-tests.sh
```

## 5. Envie o Pull Request

1. Faça o push do seu branch:

```bash
git push origin minha-contribuicao
```

2. Acesse seu fork no GitHub e abra um **Pull Request** para o branch `master` deste repositório.
3. Descreva resumidamente suas mudanças e aguarde a revisão da equipe.

Ficamos felizes em receber contribuições que melhorem os scripts, documentação ou tragam novas funcionalidades.
