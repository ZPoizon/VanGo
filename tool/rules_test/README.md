# Testes das regras de segurança (emulador local)

Testa `../../firestore.rules` no emulador do Firestore, sem tocar no projeto
`vango-4b4a5` e sem publicar regras. O emulador exige JDK 21 ou superior.

## Executar

```bash
cd tool/rules_test
npm install
npm test
```

O `npm test` inicia apenas o emulador do Firestore, executa `test.mjs` e
encerra o emulador ao final.

## Cobertura

- **Permitidos (54):** cadastro seguro de motorista e aluno, leitura do próprio
  perfil, leitura/listagem de chamadas do grupo, abertura/encerramento da
  chamada pelo motorista, criação e alteração independente da própria resposta,
  padrões, viagens, grupos, solicitações, convites e notificações. Inclui a
  resolução pontual do código de entrada por aluno autenticado, a conclusão e
  liberação da reserva pelo motorista dono, e a edição de dados pessoais: aluno
  sem grupo/pendente edita nome, telefone, instituição, turno, endereço e
  referência; motorista edita nome e telefone.
- **Fase 2 (incluído nos totais):** motorista sem `grupoId` legado cria e lista
  suas vans, abre chamada, cria convite, lê solicitações e reserva/libera código
  da própria van; aluno recusado reabre solicitação em outra van. Códigos e IDs
  de novos grupos exigem 6 dígitos, período personalizado exige descrição e a
  posse é validada no documento do grupo, sem depender do perfil.
- **Fase 4 (incluído nos totais):** alteração de resposta e aviso
  `resposta_alterada` na mesma transação, incluindo a leitura prévia de uma
  resposta ainda inexistente; motorista lê/listar avisos da própria van. O aviso
  só é aceito com `alunoId`, `chamadaId`, `grupoId`, sentido e valores
  anterior/atual conferidos pela resposta antes/depois da transação. Nome do
  aluno não é aceito no documento. Tanto a resposta quanto o aviso são recusados
  se a chamada estiver encerrada ou marcada como bloqueada pela viagem.
- **Proibidos (88):** UID/e-mail/perfil/status/ativo/grupoId inválidos no
  cadastro, alterações indevidas de perfil, assunção de grupo por motorista
  recém-cadastrado, privilégios de motorista sem grupo,
  acesso a dados privados antes da aprovação, falsificação de `motoristaId`,
  resposta com ID/outro aluno, listagem sem filtro de `alunoId`, chamada
  encerrada/com viagem bloqueada/inexistente/de outro grupo, aluno inativo, perfil
  ausente/conflitante, acesso anônimo, listagem de grupos por código,
  alteração de códigos/grupos de terceiros, segunda solicitação ativa, troca de
  van com solicitação pendente, código com formato inválido, aviso falsificado
  (outro aluno/grupo/chamada, nome arbitrário, valores divergentes, sem
  alteração real ou criado pelo motorista), leitura entre grupos e tentativa de
  alterar campos sensíveis ou de terceiros durante a edição de perfil.

Nenhum teste usa dados reais do projeto; todos os documentos são criados no
emulador com `withSecurityRulesDisabled`.
