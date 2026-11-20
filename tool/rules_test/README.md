# Testes das regras de segurança (emulador local)

Testa `firestore.rules.confirmacao.proposto` no emulador do Firestore, sem
tocar no projeto `vango-4b4a5` e sem publicar regras.

## Executar

```bash
cd tool/rules_test
npm install
npm test
```

O `npm test` inicia apenas o emulador do Firestore, executa `test.mjs` e
encerra o emulador ao final.

## Cobertura

- **Permitidos (10):** leitura do próprio perfil, leitura/listagem de chamadas
  do grupo, abertura/encerramento da chamada pelo motorista, criação e
  alteração independente da própria resposta, listagem da própria resposta e
  leitura das respostas pelo motorista.
- **Proibidos (21):** perfil de outro usuário, alteração de perfil, abertura de
  chamada pelo aluno, falsificação de `motoristaId`, resposta com
  ID/outro aluno, leitura ou alteração da resposta alheia, listagem sem filtro
  de `alunoId`, chamada encerrada/inexistente/de outro grupo, aluno inativo,
  perfil ausente/conflitante, gravação de campos de outras fases, valor de
  sentido inválido, motorista criando resposta, acesso anônimo e acesso a
  `viagens` nesta fase.

Nenhum teste usa dados reais do projeto; todos os documentos são criados no
emulador com `withSecurityRulesDisabled`.
