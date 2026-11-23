import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
  query,
  where,
  Timestamp,
  serverTimestamp,
  runTransaction,
  writeBatch,
} from 'firebase/firestore';

const PROJECT_ID = 'vango-rules-test';
const GRUPO = 'grupo-capao-itape';
const OUTRO_GRUPO = 'outro-grupo';
const GRUPO_MOTORISTA = 'grupo_motorista-uid_789012';

const MOTORISTA = 'motorista-uid';
const ALUNO = 'aluno-uid';
const OUTRO_ALUNO = 'outro-aluno-uid';
const INATIVO = 'inativo-uid';
const CONFLITO = 'conflito-uid';
const OUTRO_GRUPO_UID = 'outro-grupo-uid';
const SEM_PERFIL = 'sem-perfil-uid';
const NOVO_MOTORISTA = 'novo-motorista-uid';
const MOTORISTA_SEM_LEGADO = 'motorista-sem-legado-uid';
const GRUPO_SEM_LEGADO = `grupo_${MOTORISTA_SEM_LEGADO}_333444`;
const CODIGO_SEM_LEGADO = '333444';
const CODIGO_RESERVA_SEM_LEGADO = '444555';
const CADASTRO_MOTORISTA_UID = 'cadastro-motorista-uid';
const NOVO_ALUNO = 'novo-aluno-uid';
const ALUNO_SEM_GRUPO = 'aluno-sem-grupo-uid';
const ALUNO_PENDENTE = 'aluno-pendente-uid';
const OUTRO_UID = 'outro-usuario-uid';
const EMAIL_NOVO_MOTORISTA = 'novo.motorista@teste.com';
const EMAIL_NOVO_ALUNO = 'novo.aluno@teste.com';
const EMAIL_OUTRO = 'outro@teste.com';
const MOTORISTA_B = 'motorista-b-uid';
const MOTORISTA_INATIVO = 'motorista-inativo-uid';
const ALUNO_B = 'aluno-b-uid';
const ALUNO_RECUSADO = 'aluno-recusado-uid';
const GRUPO_B = `grupo_${MOTORISTA_B}_222333`;
const CODIGO_B = '222333';
const GRUPO_CODIGO_PUBLICO = `grupo_${MOTORISTA}_555777`;
const CODIGO_PUBLICO = '555777';

const rules = readFileSync(
  new URL('../../firestore.rules', import.meta.url),
  'utf8',
);

const testEnv = await initializeTestEnvironment({
  projectId: PROJECT_ID,
  firestore: { rules, host: '127.0.0.1', port: 8081 },
});

let permitidos = 0;
let permitidosFalharam = 0;
let proibidos = 0;
let proibidosFalharam = 0;

function usuario(perfil, ativo, status, grupoId = GRUPO) {
  const dados = { perfil, ativo, status, nome: 'Teste' };
  if (grupoId !== null) dados.grupoId = grupoId;
  return dados;
}

async function semear() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'usuarios', MOTORISTA), usuario('MOTORISTA', true, 'ativo'));
    await setDoc(doc(db, 'usuarios', ALUNO), usuario('ALUNO', true, 'ativo'));
    await setDoc(doc(db, 'usuarios', OUTRO_ALUNO), usuario('aluno', true, 'ativo'));
    await setDoc(doc(db, 'usuarios', INATIVO), usuario('ALUNO', false, 'desativado'));
    await setDoc(doc(db, 'usuarios', CONFLITO), usuario('ALUNO', true, 'pendente'));
    await setDoc(doc(db, 'usuarios', OUTRO_GRUPO_UID), usuario('ALUNO', true, 'ativo', OUTRO_GRUPO));
    await setDoc(doc(db, 'usuarios', SEM_PERFIL), { ativo: true, status: 'ativo', grupoId: GRUPO });
    await setDoc(doc(db, 'usuarios', NOVO_MOTORISTA), usuario('MOTORISTA', true, 'ativo', null));
    await setDoc(doc(db, 'usuarios', MOTORISTA_SEM_LEGADO), usuario('MOTORISTA', true, 'ativo', null));
    await setDoc(doc(db, 'usuarios', MOTORISTA_B), usuario('MOTORISTA', true, 'ativo', null));
    await setDoc(doc(db, 'usuarios', MOTORISTA_INATIVO), usuario('MOTORISTA', false, 'desativado', null));
    await setDoc(doc(db, 'usuarios', ALUNO_B), usuario('ALUNO', true, 'ativo', GRUPO_B));
    await setDoc(doc(db, 'usuarios', ALUNO_RECUSADO), {
      perfil: 'aluno', ativo: false, status: 'recusado', grupoId: GRUPO,
      nome: 'Aluno Recusado', motivoRecusa: 'Documentação incompleta',
    });
    await setDoc(doc(db, 'usuarios', ALUNO_SEM_GRUPO), {
      perfil: 'aluno', ativo: false, status: 'pendente', nome: 'Aluno Sem Grupo',
      telefone: '(15) 99999-0000', instituicao: 'Escola Teste', turno: 'matutino',
      enderecoEmbarque: 'Rua A, 1', referenciaEndereco: 'Portão 1',
    });
    await setDoc(doc(db, 'usuarios', ALUNO_PENDENTE), {
      perfil: 'aluno', ativo: false, status: 'pendente', grupoId: GRUPO,
      nome: 'Aluno Pendente', telefone: '(15) 99999-1111',
      instituicao: 'Escola Teste', turno: 'noturno',
      enderecoEmbarque: 'Rua B, 2', referenciaEndereco: 'Portão 2',
    });

    await setDoc(doc(db, 'grupos', GRUPO), {
      nome: 'Van do Roberto',
      motoristaId: MOTORISTA,
      codigo: '123456',
    });
    await setDoc(doc(db, 'grupos', OUTRO_GRUPO), {
      nome: 'Van do Outro',
      motoristaId: OUTRO_GRUPO_UID,
      codigo: '654321',
    });
    await setDoc(doc(db, 'grupos', GRUPO_MOTORISTA), {
      nome: 'Van do Novo Motorista',
      motoristaId: NOVO_MOTORISTA,
      codigo: '789012',
    });
    await setDoc(doc(db, 'grupos', GRUPO_SEM_LEGADO), {
      nome: 'Van Nova Sem Legado',
      motoristaId: MOTORISTA_SEM_LEGADO,
      codigo: CODIGO_SEM_LEGADO,
      cidadeOrigem: 'Capão Bonito',
      cidadeDestino: 'Itapetininga',
      periodo: 'personalizado',
      periodoPersonalizado: '07:30 às 18:00',
      horarioSaida: '07:30',
      observacoes: 'Embarque na praça',
    });
    await setDoc(doc(db, 'grupos', GRUPO_B), {
      nome: 'Van B',
      motoristaId: MOTORISTA_B,
      codigo: CODIGO_B,
    });
    await setDoc(doc(db, 'grupos', GRUPO_CODIGO_PUBLICO), {
      nome: 'Van Código Público',
      motoristaId: MOTORISTA,
      codigo: CODIGO_PUBLICO,
    });

    await setDoc(doc(db, 'codigos', '123456'), { grupoId: GRUPO, motoristaId: MOTORISTA, reservadoEm: Timestamp.now(), reservadoPor: MOTORISTA });
    await setDoc(doc(db, 'codigos', '654321'), { grupoId: OUTRO_GRUPO, motoristaId: OUTRO_GRUPO_UID, reservadoEm: Timestamp.now(), reservadoPor: OUTRO_GRUPO_UID });
    await setDoc(doc(db, 'codigos', '789012'), { grupoId: GRUPO_MOTORISTA, motoristaId: NOVO_MOTORISTA, reservadoEm: Timestamp.now(), reservadoPor: NOVO_MOTORISTA });
    await setDoc(doc(db, 'codigos', '999888'), { reservadoEm: Timestamp.now(), reservadoPor: MOTORISTA });
    await setDoc(doc(db, 'codigos', CODIGO_SEM_LEGADO), {
      grupoId: GRUPO_SEM_LEGADO, motoristaId: MOTORISTA_SEM_LEGADO, reservadoEm: Timestamp.now(), reservadoPor: MOTORISTA_SEM_LEGADO,
    });
    await setDoc(doc(db, 'codigos', CODIGO_RESERVA_SEM_LEGADO), { reservadoEm: Timestamp.now(), reservadoPor: MOTORISTA_SEM_LEGADO });
    await setDoc(doc(db, 'codigos', CODIGO_B), {
      grupoId: GRUPO_B, motoristaId: MOTORISTA_B, reservadoEm: Timestamp.now(), reservadoPor: MOTORISTA_B,
    });
    await setDoc(doc(db, 'codigos', CODIGO_PUBLICO), {
      grupoId: GRUPO_CODIGO_PUBLICO, motoristaId: MOTORISTA, reservadoEm: Timestamp.now(), reservadoPor: MOTORISTA,
    });

    await setDoc(doc(db, 'chamadas', 'chamada1'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, status: 'aberta', dataServico: Timestamp.now(),
    });
    await setDoc(doc(db, 'chamadas', 'chamadaFechada'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, status: 'encerrada', dataServico: Timestamp.now(),
    });
    await setDoc(doc(db, 'chamadas', 'chamadaOutroGrupo'), {
      grupoId: OUTRO_GRUPO, motoristaId: MOTORISTA, status: 'aberta', dataServico: Timestamp.now(),
    });
  });
}

async function permitido(nome, acao) {
  await semear();
  try {
    await assertSucceeds(acao());
    permitidos++;
    console.log(`  PASS  ${nome}`);
  } catch (erro) {
    permitidosFalharam++;
    console.log(`  FAIL  ${nome}\n        ${erro.message}`);
  }
}

async function proibido(nome, acao) {
  await semear();
  try {
    await assertFails(acao());
    proibidos++;
    console.log(`  PASS  ${nome}`);
  } catch (erro) {
    proibidosFalharam++;
    console.log(`  FAIL  ${nome}\n        ${erro.message}`);
  }
}

const ctxAluno = () => testEnv.authenticatedContext(ALUNO).firestore();
const ctxMotorista = () => testEnv.authenticatedContext(MOTORISTA).firestore();
const ctxAlunoSemGrupo = () => testEnv.authenticatedContext(ALUNO_SEM_GRUPO).firestore();
const ctxAlunoPendente = () => testEnv.authenticatedContext(ALUNO_PENDENTE).firestore();
const ctxMotoristaB = () => testEnv.authenticatedContext(MOTORISTA_B).firestore();
const ctxMotoristaInativo = () => testEnv.authenticatedContext(MOTORISTA_INATIVO).firestore();
const ctxAlunoB = () => testEnv.authenticatedContext(ALUNO_B).firestore();
const ctxAlunoRecusado = () => testEnv.authenticatedContext(ALUNO_RECUSADO).firestore();

// Contexto de cadastro: o e-mail do token precisa ser o mesmo gravado no perfil.
const ctxCadastro = (uid, email) =>
  testEnv.authenticatedContext(uid, { email }).firestore();

function avisoResposta({
  alunoId = ALUNO,
  chamadaId = 'chamada1',
  grupoId = GRUPO,
  sentido = 'volta',
  respostaAnterior = 'naoVai',
  respostaAtual = 'vai',
  dadosExtra = {},
} = {}) {
  return {
    grupoId,
    titulo: 'Presença alterada',
    corpo: 'Aluno alterou uma resposta de presença.',
    alunoIds: [],
    tipo: 'resposta_alterada',
    dados: {
      alunoId,
      chamadaId,
      sentido,
      respostaAnterior,
      respostaAtual,
      ...dadosExtra,
    },
    criadoEm: serverTimestamp(),
  };
}

const idAvisoEntrada = (uid, grupoId) =>
  `solicitacao_entrada_${uid}_${grupoId}`;

function avisoEntrada({
  uid = ALUNO_SEM_GRUPO,
  grupoId = GRUPO,
  nome = 'Aluno Sem Grupo',
  destinatarioId = MOTORISTA,
  dadosExtra = {},
} = {}) {
  return {
    grupoId,
    titulo: 'Solicitação de entrada',
    corpo: 'Um aluno solicitou entrada nesta van.',
    alunoIds: [],
    tipo: 'solicitacao_entrada',
    dados: {
      solicitacaoId: uid,
      destinatarioId,
      alunoNome: nome,
      ...dadosExtra,
    },
    criadoEm: serverTimestamp(),
  };
}

async function solicitarComAviso(
  db,
  { uid = ALUNO_SEM_GRUPO, grupoId = GRUPO, aviso } = {},
) {
  const efetivo = aviso ?? avisoEntrada({ uid, grupoId });
  await runTransaction(db, async (transaction) => {
    transaction.set(doc(db, 'solicitacoes', uid), {
      grupoId,
      alunoId: uid,
      status: 'pendente',
      criadoEm: serverTimestamp(),
    });
    transaction.update(doc(db, 'usuarios', uid), {
      grupoId,
      status: 'pendente',
      ativo: false,
      atualizadoEm: serverTimestamp(),
    });
    transaction.set(
      doc(db, 'notificacoes', idAvisoEntrada(uid, grupoId)),
      efetivo,
    );
  });
}

async function semearRespostaAlteravel() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'respostas', `chamada1_${ALUNO}`), {
      chamadaId: 'chamada1',
      alunoId: ALUNO,
      grupoId: GRUPO,
      ida: 'vai',
      volta: 'naoVai',
      versao: 0,
      respondidoEm: Timestamp.now(),
    });
  });
}

async function alterarComAviso(
  db,
  aviso = avisoResposta(),
  chamadaId = 'chamada1',
) {
  await runTransaction(db, async (transaction) => {
    transaction.update(doc(db, 'respostas', `${chamadaId}_${ALUNO}`), {
      [aviso.dados.sentido]: aviso.dados.respostaAtual,
      respondidoEm: serverTimestamp(),
      versao: 1,
    });
    transaction.set(
      doc(
        db,
        'notificacoes',
        `${chamadaId}_${ALUNO}_${aviso.dados.sentido}_v1`,
      ),
      aviso,
    );
  });
}

async function semearChamadaComViagemBloqueada() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'chamadas', 'chamadaViagem'), {
      grupoId: GRUPO,
      motoristaId: MOTORISTA,
      status: 'aberta',
      viagemBloqueada: true,
      dataServico: Timestamp.now(),
    });
    await setDoc(doc(db, 'respostas', `chamadaViagem_${ALUNO}`), {
      chamadaId: 'chamadaViagem',
      alunoId: ALUNO,
      grupoId: GRUPO,
      ida: 'vai',
      volta: 'naoVai',
      versao: 0,
      respondidoEm: Timestamp.now(),
    });
  });
}

function perfilNovo({
  nome = 'Nome de Teste',
  email,
  perfil,
  status,
  ativo,
  grupoId,
  instituicao = perfil === 'aluno' ? 'Escola Teste' : null,
  turno = perfil === 'aluno' ? 'matutino' : null,
  turnoPersonalizado,
  enderecoEmbarque = perfil === 'aluno' ? 'Rua Teste, 1' : null,
  cep,
}) {
  const dados = {
    nome,
    email,
    perfil,
    status,
    ativo,
    telefone: '(15) 99999-0000',
    fotoUrl: null,
    instituicao,
    turno,
    enderecoEmbarque,
    criadoEm: Timestamp.now(),
    atualizadoEm: Timestamp.now(),
  };
  if (turnoPersonalizado !== undefined) dados.turnoPersonalizado = turnoPersonalizado;
  if (cep !== undefined) dados.cep = cep;
  if (grupoId !== undefined) dados.grupoId = grupoId;
  return dados;
}

console.log('\n=== PERMITIDOS ===');
await permitido('aluno lê o próprio perfil (regressão)', () =>
  getDoc(doc(ctxAluno(), 'usuarios', ALUNO)));

// --- CADASTRO REAL (Fase 1.1) ---
await permitido('motorista cria somente o próprio perfil, sem grupoId', () =>
  setDoc(
    doc(ctxCadastro(CADASTRO_MOTORISTA_UID, EMAIL_NOVO_MOTORISTA), 'usuarios', CADASTRO_MOTORISTA_UID),
    perfilNovo({
      email: EMAIL_NOVO_MOTORISTA,
      perfil: 'motorista',
      status: 'ativo',
      ativo: true,
    }),
  ));

await permitido('aluno cria somente o próprio perfil, sem grupoId', () =>
  setDoc(
    doc(ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO), 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  ));

await permitido('cadastro aceita instituição livre, CEP formatado e turno vespertino', () =>
  setDoc(
    doc(ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO), 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
      instituicao: 'Instituição Personalizada',
      turno: 'vespertino',
      cep: '18000-000',
    }),
  ));

await permitido('cadastro aceita turno outro com descrição personalizada', () =>
  setDoc(
    doc(ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO), 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
      instituicao: 'UNIP',
      turno: 'outro',
      turnoPersonalizado: 'Integrado',
      cep: '18000-000',
    }),
  ));

await permitido('aluno atualiza instituição, CEP e turno para vespertino', async () => {
  const ctx = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctx, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  );
  return updateDoc(doc(ctx, 'usuarios', NOVO_ALUNO), {
    instituicao: 'Outra Instituição Qualquer',
    cep: '18000-000',
    turno: 'vespertino',
    atualizadoEm: Timestamp.now(),
  });
});

await permitido('conta antiga sem CEP continua editável sem ganhar o campo', async () => {
  const ctx = testEnv.authenticatedContext(ALUNO_SEM_GRUPO).firestore();
  await updateDoc(doc(ctx, 'usuarios', ALUNO_SEM_GRUPO), {
    telefone: '(15) 98888-7777',
    atualizadoEm: Timestamp.now(),
  });
  const atualizado = await getDoc(doc(ctx, 'usuarios', ALUNO_SEM_GRUPO));
  if (atualizado.data().cep !== undefined) {
    throw new Error('CEP não deveria ser acrescentado a uma conta antiga');
  }
});

await permitido('novo aluno lê o próprio perfil após o cadastro', async () => {
  const ctx = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctx, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  );
  return getDoc(doc(ctx, 'usuarios', NOVO_ALUNO));
});

await permitido('novo aluno sem grupo cria solicitação e vincula grupo', async () => {
  const ctx = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctx, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  );
  await setDoc(doc(ctx, 'solicitacoes', NOVO_ALUNO), {
    grupoId: GRUPO,
    alunoId: NOVO_ALUNO,
    status: 'pendente',
    criadoEm: Timestamp.now(),
  });
  return updateDoc(doc(ctx, 'usuarios', NOVO_ALUNO), {
    grupoId: GRUPO,
    status: 'pendente',
    ativo: false,
    atualizadoEm: Timestamp.now(),
  });
});

await permitido('aluno atualiza dados pessoais do próprio perfil (telefone/endereço)', () =>
  updateDoc(doc(ctxAluno(), 'usuarios', ALUNO), {
    telefone: '(15) 99999-8888',
    enderecoEmbarque: 'Rua das Flores, 123',
  }));

// --- EDIÇÃO DE PERFIL (Fase 1.3) ---
await permitido('aluno sem grupo edita todos os próprios dados pessoais', () =>
  updateDoc(doc(ctxAlunoSemGrupo(), 'usuarios', ALUNO_SEM_GRUPO), {
    nome: 'Aluno Sem Grupo Atualizado',
    telefone: '(15) 98888-7777',
    instituicao: 'Outra Escola',
    turno: 'noturno',
    enderecoEmbarque: 'Rua C, 3',
    referenciaEndereco: 'Portão 3',
    atualizadoEm: Timestamp.now(),
  }));

await permitido('aluno pendente edita próprio perfil enquanto aguarda aprovação', () =>
  updateDoc(doc(ctxAlunoPendente(), 'usuarios', ALUNO_PENDENTE), {
    telefone: '(15) 97777-6666',
    enderecoEmbarque: 'Rua D, 4',
    referenciaEndereco: 'Portão 4',
    atualizadoEm: Timestamp.now(),
  }));

await permitido('motorista edita somente nome e telefone do próprio perfil', () =>
  updateDoc(doc(ctxMotorista(), 'usuarios', MOTORISTA), {
    nome: 'Roberto Silva Atualizado',
    telefone: '(15) 91111-2222',
    atualizadoEm: Timestamp.now(),
  }));

await permitido('motorista lista alunos do mesmo grupo', () =>
  getDocs(query(collection(ctxMotorista(), 'usuarios'), where('grupoId', '==', GRUPO))));

await permitido('aluno lê chamada aberta do grupo', () =>
  getDoc(doc(ctxAluno(), 'chamadas', 'chamada1')));

await permitido('aluno lista chamadas do grupo com orderBy/limit', () =>
  getDocs(query(collection(ctxAluno(), 'chamadas'), where('grupoId', '==', GRUPO))));

await permitido('aluno cria resposta própria (ida=sim, volta=semResposta)', () =>
  setDoc(doc(ctxAluno(), 'respostas', `chamada1_${ALUNO}`), {
    chamadaId: 'chamada1', alunoId: ALUNO, grupoId: GRUPO,
    ida: 'vai', volta: 'semResposta', respondidoEm: Timestamp.now(),
  }));

await permitido('aluno altera somente a volta', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'respostas', `chamada1_${ALUNO}`), {
      chamadaId: 'chamada1', alunoId: ALUNO, grupoId: GRUPO,
      ida: 'vai', volta: 'semResposta', respondidoEm: Timestamp.now(),
    });
  });
  return updateDoc(doc(ctxAluno(), 'respostas', `chamada1_${ALUNO}`), {
    volta: 'naoVai', respondidoEm: Timestamp.now(), versao: 1,
  });
});

await permitido('aluno altera a mesma resposta várias vezes enquanto aberta', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'respostas', `chamada1_${ALUNO}`), {
      chamadaId: 'chamada1', alunoId: ALUNO, grupoId: GRUPO,
      ida: 'vai', volta: 'naoVai', respondidoEm: Timestamp.now(),
    });
  });
  await updateDoc(doc(ctxAluno(), 'respostas', `chamada1_${ALUNO}`), {
    volta: 'vai', respondidoEm: Timestamp.now(), versao: 1,
  });
  return updateDoc(doc(ctxAluno(), 'respostas', `chamada1_${ALUNO}`), {
    ida: 'naoVai', respondidoEm: Timestamp.now(), versao: 2,
  });
});

await permitido('aluno lista somente a própria resposta (chamadaId + alunoId)', () =>
  getDocs(query(
    collection(ctxAluno(), 'respostas'),
    where('grupoId', '==', GRUPO),
    where('chamadaId', '==', 'chamada1'),
    where('alunoId', '==', ALUNO),
  )));

// --- FASE 4: AVISO DE ALTERAÇÃO PERSISTIDO ---------------------------------
console.log('\n=== FASE 4 - AVISO DE ALTERAÇÃO DE PRESENÇA ===');

await permitido('aluno altera resposta e registra aviso na mesma transação', async () => {
  await semearRespostaAlteravel();
  return alterarComAviso(ctxAluno());
});

await permitido('aluno cria resposta em transação com leitura prévia inexistente', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chamadas', 'chamadaTx'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, status: 'aberta',
      dataServico: Timestamp.now(), criadaEm: Timestamp.now(),
    });
  });
  const db = ctxAluno();
  const resposta = doc(db, 'respostas', `chamadaTx_${ALUNO}`);
  await runTransaction(db, async (transaction) => {
    await transaction.get(resposta);
    transaction.set(resposta, {
      chamadaId: 'chamadaTx', alunoId: ALUNO, grupoId: GRUPO,
      ida: 'vai', volta: 'semResposta', respondidoEm: serverTimestamp(), versao: 1,
    });
  });
});

await permitido('motorista lê aviso persistido da própria van', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await semearRespostaAlteravel();
    await setDoc(doc(db, 'notificacoes', `chamada1_${ALUNO}_volta_v1`), {
      ...avisoResposta(), criadoEm: Timestamp.now(),
    });
  });
  return getDoc(doc(ctxMotorista(), 'notificacoes', `chamada1_${ALUNO}_volta_v1`));
});

await permitido('motorista lista avisos persistidos da própria van', () =>
  getDocs(query(
    collection(ctxMotorista(), 'notificacoes'),
    where('grupoId', '==', GRUPO),
  )));

await proibido('aviso sem alteração correspondente da resposta é recusado', async () => {
  await semearRespostaAlteravel();
  return setDoc(
    doc(ctxAluno(), 'notificacoes', `chamada1_${ALUNO}_volta_v1`),
    avisoResposta(),
  );
});

await proibido('aluno não forja aviso com alunoId de terceiro', async () => {
  await semearRespostaAlteravel();
  return alterarComAviso(
    ctxAluno(),
    avisoResposta({ alunoId: OUTRO_ALUNO, dadosExtra: {} }),
  );
});

await proibido('aluno não forja nome do aluno no aviso', async () => {
  await semearRespostaAlteravel();
  return alterarComAviso(
    ctxAluno(),
    avisoResposta({ dadosExtra: { alunoNome: 'Nome Falso' } }),
  );
});

await proibido('aluno não registra aviso em outra van', async () => {
  await semearRespostaAlteravel();
  return alterarComAviso(ctxAluno(), avisoResposta({ grupoId: OUTRO_GRUPO }));
});

await proibido('aluno não vincula aviso a chamada de outra van', async () => {
  await semearRespostaAlteravel();
  return alterarComAviso(
    ctxAluno(),
    avisoResposta({ chamadaId: 'chamadaOutroGrupo' }),
  );
});

await proibido('aluno não informa resposta anterior divergente', async () => {
  await semearRespostaAlteravel();
  return alterarComAviso(
    ctxAluno(),
    avisoResposta({ respostaAnterior: 'vai' }),
  );
});

await proibido('aluno não informa resposta atual divergente', async () => {
  await semearRespostaAlteravel();
  return alterarComAviso(
    ctxAluno(),
    avisoResposta({ respostaAtual: 'naoVai' }),
  );
});

await proibido('resposta é recusada quando a viagem bloqueou a chamada', async () => {
  await semearChamadaComViagemBloqueada();
  return updateDoc(doc(ctxAluno(), 'respostas', `chamadaViagem_${ALUNO}`), {
    volta: 'vai',
    respondidoEm: Timestamp.now(),
    versao: 1,
  });
});

await proibido('aviso é recusado quando a viagem bloqueou a chamada', async () => {
  await semearChamadaComViagemBloqueada();
  return alterarComAviso(
    ctxAluno(),
    avisoResposta({ chamadaId: 'chamadaViagem' }),
    'chamadaViagem',
  );
});

await proibido('motorista não cria aviso de alteração de presença', async () => {
  await semearRespostaAlteravel();
  return setDoc(
    doc(ctxMotorista(), 'notificacoes', 'avisoFalsoMotorista'),
    avisoResposta(),
  );
});

await proibido('aluno não lê aviso destinado ao motorista', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', `chamada1_${ALUNO}_volta_v1`), {
      ...avisoResposta(), criadoEm: Timestamp.now(),
    });
  });
  return getDoc(doc(ctxAluno(), 'notificacoes', `chamada1_${ALUNO}_volta_v1`));
});

await proibido('motorista de outra van não lê aviso', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', `chamada1_${ALUNO}_volta_v1`), {
      ...avisoResposta(), criadoEm: Timestamp.now(),
    });
  });
  return getDoc(
    doc(testEnv.authenticatedContext(NOVO_MOTORISTA).firestore(), 'notificacoes', `chamada1_${ALUNO}_volta_v1`),
  );
});

await proibido('aviso de alteração não pode ser alterado depois', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', `chamada1_${ALUNO}_volta_v1`), {
      ...avisoResposta(), criadoEm: Timestamp.now(),
    });
  });
  return updateDoc(
    doc(ctxMotorista(), 'notificacoes', `chamada1_${ALUNO}_volta_v1`),
    { corpo: 'Alterado' },
  );
});

await permitido('aluno lê e salva o próprio padrão semanal', async () => {
  await setDoc(doc(ctxAluno(), 'padroes', ALUNO), {
    grupoId: GRUPO,
    segunda: { ida: true, volta: true },
  });
  return getDoc(doc(ctxAluno(), 'padroes', ALUNO));
});

await permitido('motorista lê padrão semanal dos alunos do grupo', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'padroes', ALUNO), { grupoId: GRUPO });
  });
  return getDocs(query(collection(ctxMotorista(), 'padroes'), where('grupoId', '==', GRUPO)));
});

await permitido('motorista lê e cria viagens do grupo', async () => {
  await setDoc(doc(ctxMotorista(), 'viagens', 'v1'), {
    grupoId: GRUPO,
    motoristaId: MOTORISTA,
    sentido: 'ida',
    status: 'em_andamento',
  });
  return getDocs(query(collection(ctxMotorista(), 'viagens'), where('grupoId', '==', GRUPO)));
});

await permitido('aluno lê viagens do próprio grupo', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'viagens', 'v1'), { grupoId: GRUPO, sentido: 'ida' });
  });
  return getDocs(query(collection(ctxAluno(), 'viagens'), where('grupoId', '==', GRUPO)));
});

await permitido('motorista lê chamada do grupo', () =>
  getDoc(doc(ctxMotorista(), 'chamadas', 'chamada1')));

await permitido('motorista abre chamada do próprio grupo', () =>
  setDoc(doc(ctxMotorista(), 'chamadas', 'chamadaNova'), {
    grupoId: GRUPO, motoristaId: MOTORISTA, status: 'aberta', dataServico: Timestamp.now(),
  }));

await permitido('motorista encerra chamada do grupo', () =>
  updateDoc(doc(ctxMotorista(), 'chamadas', 'chamada1'), { status: 'encerrada' }));

await permitido('motorista lista respostas da chamada', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'respostas', `chamada1_${ALUNO}`), {
      chamadaId: 'chamada1', alunoId: ALUNO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
    });
    await setDoc(doc(ctx.firestore(), 'respostas', `chamada1_${OUTRO_ALUNO}`), {
      chamadaId: 'chamada1', alunoId: OUTRO_ALUNO, grupoId: GRUPO, ida: 'naoVai', volta: 'vai',
    });
  });
  return getDocs(query(
    collection(ctxMotorista(), 'respostas'),
    where('grupoId', '==', GRUPO),
    where('chamadaId', '==', 'chamada1'),
  ));
});

console.log('\n=== PROIBIDOS ===');
await proibido('aluno não lê perfil de outro usuário', () =>
  getDoc(doc(ctxAluno(), 'usuarios', MOTORISTA)));

await proibido('aluno não modifica o próprio perfil para motorista', () =>
  updateDoc(doc(ctxAluno(), 'usuarios', ALUNO), { perfil: 'MOTORISTA' }));

await proibido('aluno não modifica o próprio grupoId', () =>
  updateDoc(doc(ctxAluno(), 'usuarios', ALUNO), { grupoId: OUTRO_GRUPO }));

await proibido('aluno não modifica o próprio status ou ativo', () =>
  updateDoc(doc(ctxAluno(), 'usuarios', ALUNO), { ativo: false, status: 'desativado' }));

// --- SEGURANÇA DA EDIÇÃO DE PERFIL (Fase 1.3) ---
await proibido('aluno sem grupo não altera status, ativo ou grupoId ao editar perfil', () =>
  updateDoc(doc(ctxAlunoSemGrupo(), 'usuarios', ALUNO_SEM_GRUPO), {
    telefone: '(15) 98888-7777',
    status: 'ativo',
    ativo: true,
    grupoId: GRUPO,
  }));

await proibido('aluno sem grupo não edita perfil de terceiro', () =>
  updateDoc(doc(ctxAlunoSemGrupo(), 'usuarios', ALUNO), {
    telefone: '(15) 98888-7777',
  }));

await proibido('aluno não grava campos de van no próprio perfil', () =>
  updateDoc(doc(ctxAluno(), 'usuarios', ALUNO), {
    telefone: '(15) 98888-7777',
    trajeto: 'Capão Bonito → Itapetininga',
  }));

await proibido('motorista não grava campos de aluno no próprio perfil', () =>
  updateDoc(doc(ctxMotorista(), 'usuarios', MOTORISTA), {
    telefone: '(15) 91111-2222',
    instituicao: 'Escola Teste',
    enderecoEmbarque: 'Rua A, 1',
  }));

await permitido('motorista grava URL de download válida em fotoUrl', () =>
  updateDoc(doc(ctxMotorista(), 'usuarios', MOTORISTA), {
    fotoUrl: 'https://firebasestorage.googleapis.com/v0/b/demo-vango.appspot.com/o/usuarios%2Fmotorista-uid%2Ffoto.jpg?alt=media&token=abc123',
  }));

await permitido('URL http do emulador de Storage é aceita em fotoUrl', () =>
  updateDoc(doc(ctxMotorista(), 'usuarios', MOTORISTA), {
    fotoUrl: 'http://127.0.0.1:9199/v0/b/demo-vango.appspot.com/o/usuarios%2Fmotorista-uid%2Ffoto.jpg?alt=media&token=abc123',
  }));

await proibido('perfil não aceita imagem base64 em fotoUrl', () =>
  updateDoc(doc(ctxMotorista(), 'usuarios', MOTORISTA), {
    fotoUrl: 'data:image/jpeg;base64,/9j/4AAQSkZJRg==',
  }));

await proibido('fotoUrl não aceita conteúdo não textual', () =>
  updateDoc(doc(ctxMotorista(), 'usuarios', MOTORISTA), {
    fotoUrl: { base64: '/9j/4AAQSkZJRg==' },
  }));

await proibido('motorista não edita perfil de outro motorista', () =>
  updateDoc(doc(ctxMotorista(), 'usuarios', NOVO_MOTORISTA), {
    nome: 'Motorista Alterado',
  }));

await proibido('aluno não cria resposta com ID de outro aluno', () =>
  setDoc(doc(ctxAluno(), 'respostas', `chamada1_${OUTRO_ALUNO}`), {
    chamadaId: 'chamada1', alunoId: ALUNO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
  }));

await proibido('aluno não altera resposta de outro aluno', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'respostas', `chamada1_${OUTRO_ALUNO}`), {
      chamadaId: 'chamada1', alunoId: OUTRO_ALUNO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
    });
  });
  return updateDoc(doc(ctxAluno(), 'respostas', `chamada1_${OUTRO_ALUNO}`), {
    ida: 'naoVai', versao: 1,
  });
});

await proibido('aluno não lê resposta de outro aluno', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'respostas', `chamada1_${OUTRO_ALUNO}`), {
      chamadaId: 'chamada1', alunoId: OUTRO_ALUNO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
    });
  });
  return getDoc(doc(ctxAluno(), 'respostas', `chamada1_${OUTRO_ALUNO}`));
});

await proibido('aluno não lista respostas sem filtrar alunoId', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'respostas', `chamada1_${ALUNO}`), {
      chamadaId: 'chamada1', alunoId: ALUNO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
    });
    await setDoc(doc(ctx.firestore(), 'respostas', `chamada1_${OUTRO_ALUNO}`), {
      chamadaId: 'chamada1', alunoId: OUTRO_ALUNO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
    });
  });
  return getDocs(query(
    collection(ctxAluno(), 'respostas'),
    where('chamadaId', '==', 'chamada1'),
  ));
});

await proibido('aluno não responde chamada encerrada', () =>
  setDoc(doc(ctxAluno(), 'respostas', `chamadaFechada_${ALUNO}`), {
    chamadaId: 'chamadaFechada', alunoId: ALUNO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
  }));

await proibido('aluno não altera resposta existente de chamada encerrada', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'respostas', `chamadaFechada_${ALUNO}`), {
      chamadaId: 'chamadaFechada', alunoId: ALUNO, grupoId: GRUPO,
      ida: 'vai', volta: 'naoVai', respondidoEm: Timestamp.now(),
    });
  });
  return updateDoc(doc(ctxAluno(), 'respostas', `chamadaFechada_${ALUNO}`), {
    volta: 'vai', respondidoEm: Timestamp.now(), versao: 1,
  });
});

await proibido('aluno não responde chamada inexistente', () =>
  setDoc(doc(ctxAluno(), 'respostas', `chamadaInexistente_${ALUNO}`), {
    chamadaId: 'chamadaInexistente', alunoId: ALUNO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
  }));

await proibido('aluno inativo não responde', () =>
  setDoc(doc(testEnv.authenticatedContext(INATIVO).firestore(), 'respostas', `chamada1_${INATIVO}`), {
    chamadaId: 'chamada1', alunoId: INATIVO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
  }));

await proibido('aluno com ativo/status conflitantes não responde', () =>
  setDoc(doc(testEnv.authenticatedContext(CONFLITO).firestore(), 'respostas', `chamada1_${CONFLITO}`), {
    chamadaId: 'chamada1', alunoId: CONFLITO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
  }));

await proibido('usuário sem perfil reconhecido não responde', () =>
  setDoc(doc(testEnv.authenticatedContext(SEM_PERFIL).firestore(), 'respostas', `chamada1_${SEM_PERFIL}`), {
    chamadaId: 'chamada1', alunoId: SEM_PERFIL, grupoId: GRUPO, ida: 'vai', volta: 'vai',
  }));

await proibido('aluno de outro grupo não responde chamada do grupo', () =>
  setDoc(doc(testEnv.authenticatedContext(OUTRO_GRUPO_UID).firestore(), 'respostas', `chamada1_${OUTRO_GRUPO_UID}`), {
    chamadaId: 'chamada1', alunoId: OUTRO_GRUPO_UID, grupoId: GRUPO, ida: 'vai', volta: 'vai',
  }));

await proibido('aluno não vê chamada de outro grupo', () =>
  getDoc(doc(ctxAluno(), 'chamadas', 'chamadaOutroGrupo')));

await proibido('aluno não abre chamada', () =>
  setDoc(doc(ctxAluno(), 'chamadas', 'chamadaNova'), {
    grupoId: GRUPO, motoristaId: ALUNO, status: 'aberta', dataServico: Timestamp.now(),
  }));

await proibido('motorista não cria chamada com outro motoristaId', () =>
  setDoc(doc(ctxMotorista(), 'chamadas', 'chamadaNova'), {
    grupoId: GRUPO, motoristaId: ALUNO, status: 'aberta', dataServico: Timestamp.now(),
  }));

await proibido('motorista não altera o motoristaId da chamada', () =>
  updateDoc(doc(ctxMotorista(), 'chamadas', 'chamada1'), { motoristaId: ALUNO }));

await proibido('aluno não grava sentido com valor inválido', () =>
  setDoc(doc(ctxAluno(), 'respostas', `chamada1_${ALUNO}`), {
    chamadaId: 'chamada1', alunoId: ALUNO, grupoId: GRUPO, ida: 'talvez', volta: 'vai',
  }));

await proibido('motorista não cria resposta', () =>
  setDoc(doc(ctxMotorista(), 'respostas', `chamada1_${MOTORISTA}`), {
    chamadaId: 'chamada1', alunoId: MOTORISTA, grupoId: GRUPO, ida: 'vai', volta: 'vai',
  }));

await proibido('usuário não autenticado não lê chamada', () =>
  getDoc(doc(testEnv.unauthenticatedContext().firestore(), 'chamadas', 'chamada1')));

console.log('\n=== NOVOS TESTES - FASE A ===');

const ctxNovoMotorista = () => testEnv.authenticatedContext(NOVO_MOTORISTA).firestore();
const ctxSemLegado = () => testEnv.authenticatedContext(MOTORISTA_SEM_LEGADO).firestore();

// --- GRUPOS ---
await permitido('motorista cria seu próprio grupo com código válido', () =>
  setDoc(doc(ctxNovoMotorista(), 'grupos', `grupo_${NOVO_MOTORISTA}_999888`), {
    nome: 'Nova Van',
    motoristaId: NOVO_MOTORISTA,
    codigo: '999888',
  }));

await proibido('motorista não cria grupo com ID de outro motorista', () =>
  setDoc(doc(ctxNovoMotorista(), 'grupos', `grupo_${MOTORISTA}`), {
    nome: 'Van Inválida',
    motoristaId: MOTORISTA,
    codigo: '999888',
  }));

await proibido('motorista não cria grupo sem código', () =>
  setDoc(doc(ctxNovoMotorista(), 'grupos', `grupo_${NOVO_MOTORISTA}_999888`), {
    nome: 'Van Sem Código',
    motoristaId: NOVO_MOTORISTA,
  }));

await proibido('motorista não cria grupo com código curto', () =>
  setDoc(doc(ctxNovoMotorista(), 'grupos', `grupo_${NOVO_MOTORISTA}_999888`), {
    nome: 'Van Código Curto',
    motoristaId: NOVO_MOTORISTA,
    codigo: '12345',
  }));

await permitido('qualquer autenticado lê grupo por código (busca pública)', () =>
  getDoc(doc(ctxAluno(), 'grupos', GRUPO)));

await permitido('aluno sem grupo lê a van apontada pelo código público', () =>
  getDoc(doc(ctxAlunoSemGrupo(), 'grupos', GRUPO_CODIGO_PUBLICO)));

await proibido('aluno sem grupo não lê grupo sem mapeamento de código válido', () =>
  getDoc(doc(ctxAlunoSemGrupo(), 'grupos', OUTRO_GRUPO)));

await proibido('aluno pendente vinculado não lê outra van por código', () =>
  getDoc(doc(ctxAlunoPendente(), 'grupos', GRUPO_CODIGO_PUBLICO)));

// O app resolve o código pelo documento pontual de `codigos`, não por listagem
// de grupos: a consulta abaixo continua bloqueada para alunos.
await permitido('aluno resolve código de entrada pelo mapeamento pontual', () =>
  getDoc(doc(ctxAluno(), 'codigos', '123456')));

await proibido('usuário não autenticado não resolve código de entrada', () =>
  getDoc(doc(testEnv.unauthenticatedContext().firestore(), 'codigos', '123456')));

await proibido('aluno não lista grupos filtrando por código', () =>
  getDocs(query(collection(ctxAluno(), 'grupos'), where('codigo', '==', '123456'))));

await permitido('motorista lista seus próprios grupos', () =>
  getDocs(query(collection(ctxMotorista(), 'grupos'), where('motoristaId', '==', MOTORISTA))));

await permitido('motorista atualiza nome do próprio grupo', () =>
  updateDoc(doc(ctxMotorista(), 'grupos', GRUPO), { nome: 'Novo Nome da Van' }));

await permitido('motorista atualiza código do próprio grupo', () =>
  updateDoc(doc(ctxMotorista(), 'grupos', GRUPO), { codigo: '111222' }));

await proibido('motorista não altera motoristaId do grupo', () =>
  updateDoc(doc(ctxMotorista(), 'grupos', GRUPO), { motoristaId: ALUNO }));

await proibido('motorista não atualiza grupo de outro motorista', () =>
  updateDoc(doc(ctxMotorista(), 'grupos', GRUPO_MOTORISTA), { nome: 'Hack' }));

// --- SOLICITAÇÕES ---
await permitido('aluno cria solicitação pendente para grupo', () =>
  setDoc(doc(ctxAluno(), 'solicitacoes', ALUNO), {
    grupoId: GRUPO, alunoId: ALUNO, status: 'pendente',
  }));

await proibido('aluno não cria solicitação com status aprovado', () =>
  setDoc(doc(ctxAluno(), 'solicitacoes', ALUNO), {
    grupoId: GRUPO, alunoId: ALUNO, status: 'aprovado',
  }));

await proibido('aluno não cria solicitação para outro aluno', () =>
  setDoc(doc(ctxAluno(), 'solicitacoes', ALUNO), {
    grupoId: GRUPO, alunoId: OUTRO_ALUNO, status: 'pendente',
  }));

await permitido('motorista lê solicitações do próprio grupo', () =>
  getDocs(query(collection(ctxMotorista(), 'solicitacoes'), where('grupoId', '==', GRUPO))));

await proibido('motorista não lê solicitações de outro grupo', () =>
  getDocs(query(collection(ctxMotorista(), 'solicitacoes'), where('grupoId', '==', GRUPO_MOTORISTA))));

await permitido('motorista aprova solicitação (status -> aprovado)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', 'solAprovar'), {
      grupoId: GRUPO, alunoId: ALUNO, status: 'pendente',
    });
  });
  return updateDoc(doc(ctxMotorista(), 'solicitacoes', 'solAprovar'), { status: 'aprovado' });
});

await permitido('motorista recusa solicitação (status -> recusado)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', 'solRecusar'), {
      grupoId: GRUPO, alunoId: ALUNO, status: 'pendente',
    });
  });
  return updateDoc(doc(ctxMotorista(), 'solicitacoes', 'solRecusar'), { status: 'recusado' });
});

await proibido('motorista não altera outros campos da solicitação', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', 'solOutro'), {
      grupoId: GRUPO, alunoId: ALUNO, status: 'pendente',
    });
  });
  return updateDoc(doc(ctxMotorista(), 'solicitacoes', 'solOutro'), { grupoId: OUTRO_GRUPO });
});

await proibido('motorista de outro grupo não aprova solicitação', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', 'solOutroGrupo'), {
      grupoId: GRUPO_MOTORISTA, alunoId: OUTRO_GRUPO_UID, status: 'pendente',
    });
  });
  return updateDoc(doc(ctxMotorista(), 'solicitacoes', 'solOutroGrupo'), { status: 'aprovado' });
});

// --- CÓDIGOS ---
await permitido('motorista reserva código via transação (criação)', () =>
  setDoc(doc(ctxMotorista(), 'codigos', '555666'), {
    reservadoEm: Timestamp.now(),
    expiraEm: Timestamp.fromMillis(Date.now() + 10 * 60 * 1000),
    reservadoPor: MOTORISTA,
  }));

await permitido('motorista deleta código ao gerar novo', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'codigos', '555666'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, reservadoEm: Timestamp.now(),
    });
  });
  return deleteDoc(doc(ctxMotorista(), 'codigos', '555666'));
});

await permitido('motorista conclui a reserva do próprio código', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'grupos', GRUPO_SEM_LEGADO), {
      nome: 'Van Sem Legado', motoristaId: MOTORISTA_SEM_LEGADO, codigo: CODIGO_RESERVA_SEM_LEGADO,
    });
    await setDoc(doc(ctx.firestore(), 'codigos', CODIGO_RESERVA_SEM_LEGADO), {
      reservadoEm: Timestamp.now(),
      expiraEm: Timestamp.fromMillis(Date.now() + 10 * 60 * 1000),
      reservadoPor: MOTORISTA_SEM_LEGADO,
    });
  });
  return updateDoc(doc(ctxSemLegado(), 'codigos', CODIGO_RESERVA_SEM_LEGADO), {
    grupoId: GRUPO_SEM_LEGADO, motoristaId: MOTORISTA_SEM_LEGADO,
  });
});

await proibido('motorista não vincula código a outro grupo', () =>
  updateDoc(doc(ctxMotorista(), 'codigos', '999888'), {
    grupoId: OUTRO_GRUPO, motoristaId: MOTORISTA,
  }));

await proibido('aluno não altera metadados de código', () =>
  updateDoc(doc(ctxAluno(), 'codigos', '999888'), {
    grupoId: GRUPO, motoristaId: ALUNO,
  }));

await proibido('aluno não deleta código', () =>
  deleteDoc(doc(ctxAluno(), 'codigos', '123456')));

// --- CONVITES ---
await permitido('motorista cria convite para seu grupo', () =>
  setDoc(doc(ctxMotorista(), 'convites', 'convite1'), {
    grupoId: GRUPO, motoristaId: MOTORISTA, turno: 'matutino',
  }));

await proibido('motorista não cria convite para outro grupo', () =>
  setDoc(doc(ctxMotorista(), 'convites', 'convite2'), {
    grupoId: OUTRO_GRUPO, motoristaId: MOTORISTA, turno: 'matutino',
  }));

await proibido('aluno não cria convite', () =>
  setDoc(doc(ctxAluno(), 'convites', 'convite3'), {
    grupoId: GRUPO, motoristaId: MOTORISTA, turno: 'matutino',
  }));

await permitido('qualquer autenticado lê convite por token', () =>
  getDoc(doc(ctxAluno(), 'convites', 'convite1')));

// --- NOTIFICAÇÕES ---
await permitido('motorista cria notificação para alunos do grupo', () =>
  setDoc(doc(ctxMotorista(), 'notificacoes', 'notif1'), {
    grupoId: GRUPO, titulo: 'Teste', corpo: 'Corpo', alunoIds: [ALUNO],
    tipo: 'chamada_aberta', dados: {}, criadoEm: serverTimestamp(),
  }));

await proibido('motorista não cria notificação para outro grupo', () =>
  setDoc(doc(ctxMotorista(), 'notificacoes', 'notif2'), {
    grupoId: OUTRO_GRUPO, titulo: 'Teste', corpo: 'Corpo', alunoIds: [ALUNO],
    tipo: 'chamada_aberta', dados: {}, criadoEm: Timestamp.now(),
  }));

await proibido('aluno não cria notificação', () =>
  setDoc(doc(ctxAluno(), 'notificacoes', 'notif3'), {
    grupoId: GRUPO, titulo: 'Teste', corpo: 'Corpo', alunoIds: [ALUNO],
    tipo: 'chamada_aberta', dados: {}, criadoEm: Timestamp.now(),
  }));

await permitido('aluno lê notificação destinada a ele', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', 'notifAluno'), {
      grupoId: GRUPO, titulo: 'Teste', corpo: 'Corpo', alunoIds: [ALUNO],
    tipo: 'chamada_aberta', dados: {}, criadoEm: Timestamp.now(),
    });
  });
  return getDoc(doc(ctxAluno(), 'notificacoes', 'notifAluno'));
});

await proibido('aluno não lê notificação destinada a outro aluno', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', 'notifOutro'), {
      grupoId: GRUPO, titulo: 'Teste', corpo: 'Corpo', alunoIds: [OUTRO_ALUNO], tipo: 'teste', dados: {},
    });
  });
  return getDoc(doc(ctxAluno(), 'notificacoes', 'notifOutro'));
});

// --- FASE 2: MÚLTIPLAS VANS -------------------------------------------------
console.log('\n=== FASE 2 - MÚLTIPLAS VANS ===');

const novoGrupoId = `grupo_${MOTORISTA_SEM_LEGADO}_777888`;
const grupoNovo = {
  nome: 'Nova Van Fase 2',
  motoristaId: MOTORISTA_SEM_LEGADO,
  codigo: '777888',
  cidadeOrigem: 'Sorocaba',
  cidadeDestino: 'São Paulo',
  periodo: 'personalizado',
  periodoPersonalizado: '06:00 às 20:00',
  horarioSaida: '06:00',
  observacoes: 'Ponto de embarque A',
};

await permitido('motorista sem grupo legado cria primeira van com campos completos', () =>
  setDoc(doc(ctxSemLegado(), 'grupos', novoGrupoId), grupoNovo));

await proibido('motorista desativado não cria van', () =>
  setDoc(doc(ctxMotoristaInativo(), 'grupos', `grupo_${MOTORISTA_INATIVO}_666777`), {
    nome: 'Van Inativa', motoristaId: MOTORISTA_INATIVO, codigo: '666777',
  }));

await proibido('motorista desativado não reserva código', () =>
  setDoc(doc(ctxMotoristaInativo(), 'codigos', '666777'), {
    reservadoEm: Timestamp.now(),
    expiraEm: Timestamp.fromMillis(Date.now() + 10 * 60 * 1000),
    reservadoPor: MOTORISTA_INATIVO,
  }));

await permitido('motorista sem grupo legado lista somente as próprias vans', () =>
  getDocs(query(
    collection(ctxSemLegado(), 'grupos'),
    where('motoristaId', '==', MOTORISTA_SEM_LEGADO),
  )));

await permitido('motorista sem grupo legado abre chamada da própria van', () =>
  setDoc(doc(ctxSemLegado(), 'chamadas', 'chamadaSemLegado'), {
    grupoId: GRUPO_SEM_LEGADO,
    motoristaId: MOTORISTA_SEM_LEGADO,
    status: 'aberta',
    dataServico: Timestamp.now(),
  }));

await permitido('motorista sem grupo legado conclui reserva do próprio código', () =>
  updateDoc(doc(ctxSemLegado(), 'codigos', CODIGO_RESERVA_SEM_LEGADO), {
    grupoId: GRUPO_SEM_LEGADO,
    motoristaId: MOTORISTA_SEM_LEGADO,
  }));

await permitido('motorista sem grupo legado libera código da própria van', () =>
  deleteDoc(doc(ctxSemLegado(), 'codigos', CODIGO_SEM_LEGADO)));

await permitido('motorista sem grupo legado lê solicitações da própria van', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', ALUNO), {
      grupoId: GRUPO_SEM_LEGADO, alunoId: ALUNO, status: 'pendente',
    });
  });
  return getDocs(query(
    collection(ctxSemLegado(), 'solicitacoes'),
    where('grupoId', '==', GRUPO_SEM_LEGADO),
  ));
});

await permitido('motorista sem grupo legado cria convite da própria van', () =>
  setDoc(doc(ctxSemLegado(), 'convites', 'conviteSemLegado'), {
    grupoId: GRUPO_SEM_LEGADO,
    motoristaId: MOTORISTA_SEM_LEGADO,
    turno: 'matutino',
  }));

await permitido('aluno recusado reabre solicitação em outra van', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', ALUNO), {
      grupoId: GRUPO, alunoId: ALUNO, status: 'recusado', criadoEm: Timestamp.now(),
    });
  });
  return updateDoc(doc(ctxAluno(), 'solicitacoes', ALUNO), {
    grupoId: GRUPO_SEM_LEGADO,
    status: 'pendente',
    criadoEm: Timestamp.now(),
  });
});

await proibido('ID da van não aceita sufixo após os 6 dígitos', () =>
  setDoc(doc(ctxSemLegado(), 'grupos', `${novoGrupoId}_extra`), grupoNovo));

await proibido('código da van deve conter apenas 6 dígitos', () =>
  setDoc(doc(ctxSemLegado(), 'grupos', novoGrupoId), {
    ...grupoNovo, codigo: '77A888',
  }));

await proibido('período personalizado exige descrição', () =>
  setDoc(doc(ctxSemLegado(), 'grupos', novoGrupoId), {
    nome: grupoNovo.nome,
    motoristaId: MOTORISTA_SEM_LEGADO,
    codigo: '777888',
    periodo: 'personalizado',
  }));

await proibido('reserva de código exige ID numérico de 6 dígitos', () =>
  setDoc(doc(ctxAluno(), 'codigos', 'ABC123'), { reservadoEm: Timestamp.now() }));

await proibido('aluno não cria segunda solicitação com ID diverso', () =>
  setDoc(doc(ctxAluno(), 'solicitacoes', 'segunda-tentativa'), {
    grupoId: GRUPO_SEM_LEGADO, alunoId: ALUNO, status: 'pendente',
  }));

await proibido('aluno não troca de van enquanto a solicitação está pendente', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', ALUNO), {
      grupoId: GRUPO, alunoId: ALUNO, status: 'pendente', criadoEm: Timestamp.now(),
    });
  });
  return updateDoc(doc(ctxAluno(), 'solicitacoes', ALUNO), {
    grupoId: GRUPO_SEM_LEGADO,
  });
});

await proibido('motorista de outra van não lê solicitações da van nova', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', ALUNO), {
      grupoId: GRUPO_SEM_LEGADO, alunoId: ALUNO, status: 'pendente',
    });
  });
  return getDocs(query(
    collection(ctxMotorista(), 'solicitacoes'),
    where('grupoId', '==', GRUPO_SEM_LEGADO),
  ));
});

await proibido('motorista sem grupo legado não cria convite para outra van', () =>
  setDoc(doc(ctxSemLegado(), 'convites', 'conviteInvalido'), {
    grupoId: GRUPO_MOTORISTA,
    motoristaId: MOTORISTA_SEM_LEGADO,
    turno: 'matutino',
  }));

await proibido('motorista sem grupo legado não vincula código à van de outro motorista', () =>
  updateDoc(doc(ctxSemLegado(), 'codigos', CODIGO_RESERVA_SEM_LEGADO), {
    grupoId: GRUPO_MOTORISTA,
    motoristaId: MOTORISTA_SEM_LEGADO,
  }));

await proibido('motorista sem grupo legado não altera código com letras', () =>
  updateDoc(doc(ctxSemLegado(), 'grupos', GRUPO_SEM_LEGADO), { codigo: '33A444' }));

// --- VERIFICAÇÕES DE ISOLAMENTO ---
await proibido('aluno pendente sem grupo não acessa alunosAtivos (regressão isolamento)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usuarios', 'pendente-sem-grupo'), {
      perfil: 'ALUNO', ativo: false, status: 'pendente', grupoId: ''
    });
  });
  const ctxPendente = testEnv.authenticatedContext('pendente-sem-grupo').firestore();
  return getDocs(query(collection(ctxPendente, 'usuarios'), where('grupoId', '==', GRUPO)));
});

await proibido('motorista não aprova aluno de outro grupo via update em usuarios', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usuarios', 'aluno-outro-grupo'), {
      perfil: 'ALUNO', ativo: false, status: 'pendente', grupoId: GRUPO_MOTORISTA
    });
  });
  return updateDoc(doc(ctxMotorista(), 'usuarios', 'aluno-outro-grupo'), {
    status: 'ativo', ativo: true, atualizadoEm: Timestamp.now()
  });
});

// --- BLOQUEIOS DE CADASTRO (Fase 1.1) ---
await proibido('usuário não cria perfil com UID diferente do autenticado', () =>
  setDoc(
    doc(ctxCadastro(OUTRO_UID, EMAIL_OUTRO), 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_OUTRO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  ));

await proibido('perfil não pode usar e-mail diferente do token do Auth', () =>
  setDoc(
    doc(ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO), 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_OUTRO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  ));

await proibido('cadastro não pode definir grupoId', () =>
  setDoc(
    doc(ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO), 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
      grupoId: GRUPO,
    }),
  ));

await proibido('motorista não pode se criar como pendente/inativo', () =>
  setDoc(
    doc(ctxCadastro(CADASTRO_MOTORISTA_UID, EMAIL_NOVO_MOTORISTA), 'usuarios', CADASTRO_MOTORISTA_UID),
    perfilNovo({
      email: EMAIL_NOVO_MOTORISTA,
      perfil: 'motorista',
      status: 'pendente',
      ativo: false,
    }),
  ));

await proibido('aluno não pode se criar como ativo', () =>
  setDoc(
    doc(ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO), 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'ativo',
      ativo: true,
    }),
  ));

await proibido('cadastro não aceita turno inválido', () =>
  setDoc(
    doc(ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO), 'usuarios', NOVO_ALUNO),
    {
      ...perfilNovo({
        email: EMAIL_NOVO_ALUNO,
        perfil: 'aluno',
        status: 'pendente',
        ativo: false,
      }),
      turno: 'integral',
    },
  ));

await proibido('cadastro não aceita CEP sem a máscara 00000-000', () =>
  setDoc(
    doc(ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO), 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
      cep: '18000000',
    }),
  ));

await proibido('cadastro não aceita CEP com menos de 8 dígitos', () =>
  setDoc(
    doc(ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO), 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
      cep: '1234',
    }),
  ));

await proibido('cadastro não aceita turno outro sem descrição', () =>
  setDoc(
    doc(ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO), 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
      turno: 'outro',
    }),
  ));

await proibido('aluno não salva CEP inválido na edição do perfil', async () => {
  const ctx = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctx, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
      cep: '18000-000',
    }),
  );
  return updateDoc(doc(ctx, 'usuarios', NOVO_ALUNO), {
    cep: '1234',
    atualizadoEm: Timestamp.now(),
  });
});

await proibido('aluno não muda para turno outro sem descrição', async () => {
  const ctx = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctx, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  );
  return updateDoc(doc(ctx, 'usuarios', NOVO_ALUNO), {
    turno: 'outro',
    atualizadoEm: Timestamp.now(),
  });
});

await proibido('aluno não usa CEP válido para alterar status/ativo', async () => {
  const ctx = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctx, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  );
  return updateDoc(doc(ctx, 'usuarios', NOVO_ALUNO), {
    cep: '18000-000',
    status: 'ativo',
    ativo: true,
    atualizadoEm: Timestamp.now(),
  });
});

await proibido('perfil não pode ser alterado para outro perfil após o cadastro', async () => {
  const ctx = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctx, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  );
  return updateDoc(doc(ctx, 'usuarios', NOVO_ALUNO), { perfil: 'motorista' });
});

await proibido('aluno não pode se ativar alterando status/ativo', async () => {
  const ctx = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctx, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  );
  return updateDoc(doc(ctx, 'usuarios', NOVO_ALUNO), {
    status: 'ativo',
    ativo: true,
    atualizadoEm: Timestamp.now(),
  });
});

await proibido('motorista não pode alterar próprio status/ativo após o cadastro', async () => {
  const ctx = ctxCadastro(CADASTRO_MOTORISTA_UID, EMAIL_NOVO_MOTORISTA);
  await setDoc(
    doc(ctx, 'usuarios', CADASTRO_MOTORISTA_UID),
    perfilNovo({
      email: EMAIL_NOVO_MOTORISTA,
      perfil: 'motorista',
      status: 'ativo',
      ativo: true,
    }),
  );
  return updateDoc(doc(ctx, 'usuarios', CADASTRO_MOTORISTA_UID), {
    status: 'pendente',
    ativo: false,
    atualizadoEm: Timestamp.now(),
  });
});

await proibido('motorista sem grupo não pode vincular grupo arbitrário', async () => {
  const ctx = ctxCadastro(CADASTRO_MOTORISTA_UID, EMAIL_NOVO_MOTORISTA);
  await setDoc(
    doc(ctx, 'usuarios', CADASTRO_MOTORISTA_UID),
    perfilNovo({
      email: EMAIL_NOVO_MOTORISTA,
      perfil: 'motorista',
      status: 'ativo',
      ativo: true,
    }),
  );
  return updateDoc(doc(ctx, 'usuarios', CADASTRO_MOTORISTA_UID), {
    grupoId: GRUPO,
    atualizadoEm: Timestamp.now(),
  });
});

await proibido('motorista recém-cadastrado não assume nem o próprio grupo determinístico', async () => {
  const uid = 'motorista-vinculo-uid';
  const grupoId = `grupo_${uid}`;
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'grupos', grupoId), {
      nome: 'Van do motorista novo',
      motoristaId: uid,
      codigo: '111222',
    });
  });
  const ctx = ctxCadastro(uid, EMAIL_NOVO_MOTORISTA);
  await setDoc(
    doc(ctx, 'usuarios', uid),
    perfilNovo({
      email: EMAIL_NOVO_MOTORISTA,
      perfil: 'motorista',
      status: 'ativo',
      ativo: true,
    }),
  );
  return updateDoc(doc(ctx, 'usuarios', uid), {
    grupoId,
    atualizadoEm: Timestamp.now(),
  });
});

await proibido('usuário não altera perfil de outro usuário', async () => {
  const ctxDono = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctxDono, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  );
  return updateDoc(
    doc(ctxCadastro(OUTRO_UID, EMAIL_OUTRO), 'usuarios', NOVO_ALUNO),
    { telefone: '(15) 99999-1111' },
  );
});

await proibido('motorista sem grupo não ganha privilégio de abrir chamada', async () => {
  const uid = 'motorista-sem-grupo-uid';
  const ctx = ctxCadastro(uid, EMAIL_NOVO_MOTORISTA);
  await setDoc(
    doc(ctx, 'usuarios', uid),
    perfilNovo({
      email: EMAIL_NOVO_MOTORISTA,
      perfil: 'motorista',
      status: 'ativo',
      ativo: true,
    }),
  );
  return setDoc(doc(ctx, 'chamadas', 'chamadaSemGrupo'), {
    grupoId: GRUPO,
    motoristaId: uid,
    status: 'aberta',
    dataServico: Timestamp.now(),
  });
});

await proibido('motorista sem grupo não cria convite', async () => {
  const uid = 'motorista-sem-grupo-convite-uid';
  const ctx = ctxCadastro(uid, EMAIL_NOVO_MOTORISTA);
  await setDoc(
    doc(ctx, 'usuarios', uid),
    perfilNovo({
      email: EMAIL_NOVO_MOTORISTA,
      perfil: 'motorista',
      status: 'ativo',
      ativo: true,
    }),
  );
  return setDoc(doc(ctx, 'convites', 'conviteSemGrupo'), {
    grupoId: GRUPO,
    motoristaId: uid,
    codigo: '123456',
    criadoEm: Timestamp.now(),
  });
});

await proibido('aluno sem grupo não lê chamada do grupo', async () => {
  const ctx = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctx, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  );
  return getDoc(doc(ctx, 'chamadas', 'chamada1'));
});

await proibido('aluno sem grupo não lê perfil de outro aluno', async () => {
  const ctx = ctxCadastro(NOVO_ALUNO, EMAIL_NOVO_ALUNO);
  await setDoc(
    doc(ctx, 'usuarios', NOVO_ALUNO),
    perfilNovo({
      email: EMAIL_NOVO_ALUNO,
      perfil: 'aluno',
      status: 'pendente',
      ativo: false,
    }),
  );
  return getDoc(doc(ctx, 'usuarios', ALUNO));
});

// --- COMPATIBILIDADE / MIGRAÇÃO ---
// Sem grupo implícito: usuário sem grupoId não herda van legada. Ele ainda
// lê o próprio perfil, mas não ganha acesso a dados de grupo.
await permitido('usuário sem grupoId lê o próprio perfil (sem fallback implícito)', () =>
  getDoc(doc(testEnv.authenticatedContext(SEM_PERFIL).firestore(), 'usuarios', SEM_PERFIL)));

await proibido('usuário sem grupoId não lê chamada de grupo legado', () =>
  getDoc(doc(testEnv.authenticatedContext(SEM_PERFIL).firestore(), 'chamadas', 'chamada1')));

// --- FASE 5.1: SEGURANÇA PENDENTE ---
console.log('\n=== FASE 5.1 - SEGURANÇA PENDENTE ===');

// Dois motoristas / duas vans
await permitido('motorista B lê a própria van', () =>
  getDoc(doc(ctxMotoristaB(), 'grupos', GRUPO_B)));

await proibido('motorista B não lê van de outro motorista', () =>
  getDoc(doc(ctxMotoristaB(), 'grupos', GRUPO)));

await proibido('motorista B não altera grupo de outro motorista', () =>
  updateDoc(doc(ctxMotoristaB(), 'grupos', GRUPO), { nome: 'Van Invadida' }));

await proibido('motorista B não cria chamada na van de outro motorista', () =>
  setDoc(doc(ctxMotoristaB(), 'chamadas', 'chamadaInvasao'), {
    grupoId: GRUPO, motoristaId: MOTORISTA_B, status: 'aberta', dataServico: Timestamp.now(),
  }));

await proibido('motorista B não cria notificação para alunos de outro grupo', () =>
  setDoc(doc(ctxMotoristaB(), 'notificacoes', 'notifInvasao'), {
    grupoId: GRUPO, titulo: 'Invasão', corpo: 'x', alunoIds: [ALUNO],
    tipo: 'chamada_aberta', dados: {}, criadoEm: serverTimestamp(),
  }));

await permitido('motorista B lista apenas suas próprias vans', () =>
  getDocs(query(collection(ctxMotoristaB(), 'grupos'), where('motoristaId', '==', MOTORISTA_B))));

await proibido('motorista B não lista vans de outro motorista', () =>
  getDocs(query(collection(ctxMotoristaB(), 'grupos'), where('motoristaId', '==', MOTORISTA))));

// Isolamento aluno entre vans
await proibido('aluno da van A não lê chamada da van B', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chamadas', 'chamadaB'), {
      grupoId: GRUPO_B, motoristaId: MOTORISTA_B, status: 'aberta', dataServico: Timestamp.now(),
    });
  });
  return getDoc(doc(ctxAluno(), 'chamadas', 'chamadaB'));
});

await proibido('aluno da van A não lista respostas da van B', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chamadas', 'chamadaB2'), {
      grupoId: GRUPO_B, motoristaId: MOTORISTA_B, status: 'aberta', dataServico: Timestamp.now(),
    });
    await setDoc(doc(ctx.firestore(), 'respostas', `chamadaB2_${ALUNO_B}`), {
      chamadaId: 'chamadaB2', alunoId: ALUNO_B, grupoId: GRUPO_B,
      ida: 'vai', volta: 'vai', versao: 0, respondidoEm: Timestamp.now(),
    });
  });
  return getDocs(query(
    collection(ctxAluno(), 'respostas'),
    where('grupoId', '==', GRUPO_B),
    where('chamadaId', '==', 'chamadaB2'),
    where('alunoId', '==', ALUNO_B),
  ));
});

await proibido('aluno da van A não lê notificação da van B', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', 'notifB'), {
      grupoId: GRUPO_B, titulo: 'B', corpo: 'B', alunoIds: [ALUNO_B],
      tipo: 'chamada_aberta', dados: {}, criadoEm: Timestamp.now(),
    });
  });
  return getDoc(doc(ctxAluno(), 'notificacoes', 'notifB'));
});

// Aluno sem grupo / aguardando aprovação / recusado
await proibido('aluno sem grupo não lê chamada privada do grupo', () =>
  getDoc(doc(ctxAlunoSemGrupo(), 'chamadas', 'chamada1')));

await proibido('aluno pendente não lê chamada privada do grupo', () =>
  getDoc(doc(ctxAlunoPendente(), 'chamadas', 'chamada1')));

await permitido('aluno pendente vinculado lê apenas o grupo da própria solicitação', () =>
  getDoc(doc(ctxAlunoPendente(), 'grupos', GRUPO)));

await proibido('aluno pendente vinculado não lê outro grupo', () =>
  getDoc(doc(ctxAlunoPendente(), 'grupos', GRUPO_B)));

await permitido('aluno recusado lê grupo vinculado para consultar status mínimo', () =>
  getDoc(doc(ctxAlunoRecusado(), 'grupos', GRUPO)));

await proibido('aluno recusado não lê grupo de outra van', () =>
  getDoc(doc(ctxAlunoRecusado(), 'grupos', GRUPO_B)));

await proibido('aluno recusado não lê chamada privada do grupo', () =>
  getDoc(doc(ctxAlunoRecusado(), 'chamadas', 'chamada1')));

// Tokens FCM: somente proprietário
await permitido('usuário cria próprio token FCM', () =>
  setDoc(doc(ctxAluno(), 'usuarios', ALUNO, 'tokens', 'tok1'), {
    token: 'abc123', plataforma: 'android', atualizadoEm: serverTimestamp(),
  }));

await permitido('usuário lê próprio token FCM', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usuarios', ALUNO, 'tokens', 'tokRead'), {
      token: 'abc123', plataforma: 'android', atualizadoEm: Timestamp.now(),
    });
  });
  return getDoc(doc(ctxAluno(), 'usuarios', ALUNO, 'tokens', 'tokRead'));
});

await proibido('usuário não lê token FCM de outro usuário', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usuarios', OUTRO_ALUNO, 'tokens', 'tokOutro'), {
      token: 'zzz', plataforma: 'android', atualizadoEm: Timestamp.now(),
    });
  });
  return getDoc(doc(ctxAluno(), 'usuarios', OUTRO_ALUNO, 'tokens', 'tokOutro'));
});

await proibido('usuário não cria token FCM em documento de outro usuário', () =>
  setDoc(doc(ctxAluno(), 'usuarios', OUTRO_ALUNO, 'tokens', 'tokInv'), {
    token: 'abc123', plataforma: 'android', atualizadoEm: serverTimestamp(),
  }));

await proibido('usuário não altera token FCM de outro usuário', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usuarios', OUTRO_ALUNO, 'tokens', 'tokEdit'), {
      token: 'old', plataforma: 'android', atualizadoEm: Timestamp.now(),
    });
  });
  return updateDoc(doc(ctxAluno(), 'usuarios', OUTRO_ALUNO, 'tokens', 'tokEdit'), {
    token: 'novo', plataforma: 'android', atualizadoEm: serverTimestamp(),
  });
});

// Códigos: expiraEm, unicidade, renovação, acesso controlado
await proibido('reserva de código sem expiraEm é recusada', () =>
  setDoc(doc(ctxMotorista(), 'codigos', '121212'), { reservadoEm: Timestamp.now() }));

await proibido('reserva de código com expiraEm no passado é recusada', () =>
  setDoc(doc(ctxMotorista(), 'codigos', '131313'), {
    reservadoEm: Timestamp.now(),
    expiraEm: Timestamp.fromMillis(Date.now() - 60_000),
  }));

await proibido('não pode tomar código já vinculado a um grupo (unicidade)', async () => {
  // código 123456 já está vinculado ao GRUPO/MOTORISTA na semente
  return updateDoc(doc(ctxMotoristaB(), 'codigos', '123456'), {
    grupoId: GRUPO_B, motoristaId: MOTORISTA_B,
  });
});

await permitido('motorista renova reserva órfã atualizando reservadoEm/expiraEm', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'codigos', '151515'), {
      reservadoEm: Timestamp.now(), expiraEm: Timestamp.fromMillis(Date.now() - 60_000),
      reservadoPor: MOTORISTA,
    });
  });
  return updateDoc(doc(ctxMotorista(), 'codigos', '151515'), {
    reservadoEm: serverTimestamp(),
    expiraEm: Timestamp.fromMillis(Date.now() + 600_000),
  });
});

await proibido('aluno não lista códigos (acesso controlado)', () =>
  getDocs(collection(ctxAluno(), 'codigos')));

await proibido('motorista de outra van não conclui reserva vinculando grupo alheio', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'codigos', '161616'), {
      reservadoEm: Timestamp.now(), expiraEm: Timestamp.fromMillis(Date.now() + 600_000),
      reservadoPor: MOTORISTA, // reservado pelo motorista A
    });
  });
  return updateDoc(doc(ctxMotoristaB(), 'codigos', '161616'), {
    grupoId: GRUPO, motoristaId: MOTORISTA_B,
  });
});

await proibido('motorista não conclui reserva criada por outro motorista (mesmo conhecendo código)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'codigos', '171717'), {
      reservadoEm: Timestamp.now(), expiraEm: Timestamp.fromMillis(Date.now() + 600_000),
      reservadoPor: MOTORISTA,
    });
  });
  // B tenta reivindicar reserva do A, mesmo usando ID de grupo no seu padrão.
  return updateDoc(doc(ctxMotoristaB(), 'codigos', '171717'), {
    grupoId: `grupo_${MOTORISTA_B}_171717`, motoristaId: MOTORISTA_B,
  });
});

// Aprovação/recusa atômicas
await permitido('motorista aprova aluno em batch atômico (usuario + solicitacao)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', ALUNO_SEM_GRUPO), {
      grupoId: GRUPO, alunoId: ALUNO_SEM_GRUPO, status: 'pendente', criadoEm: Timestamp.now(),
    });
    await updateDoc(doc(ctx.firestore(), 'usuarios', ALUNO_SEM_GRUPO), {
      grupoId: GRUPO, status: 'pendente', ativo: false,
    });
  });
  const db = ctxMotorista();
  const batch = db.batch ? null : null;
  // rules-unit-testing firestore supports writeBatch via modular API? use runTransaction-like batch from firebase/firestore
  // We'll use a transaction for atomicity in test.
  return runTransaction(db, async (txn) => {
    txn.update(doc(db, 'usuarios', ALUNO_SEM_GRUPO), {
      status: 'ativo', ativo: true, atualizadoEm: Timestamp.now(),
    });
    txn.update(doc(db, 'solicitacoes', ALUNO_SEM_GRUPO), { status: 'aprovado' });
  });
});

await permitido('motorista recusa aluno em batch atômico (usuario + solicitacao)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', ALUNO_PENDENTE), {
      grupoId: GRUPO, alunoId: ALUNO_PENDENTE, status: 'pendente', criadoEm: Timestamp.now(),
    });
  });
  const db = ctxMotorista();
  return runTransaction(db, async (txn) => {
    txn.update(doc(db, 'usuarios', ALUNO_PENDENTE), {
      status: 'recusado', ativo: false, motivoRecusa: 'Dados incompletos',
      atualizadoEm: Timestamp.now(),
    });
    txn.update(doc(db, 'solicitacoes', ALUNO_PENDENTE), { status: 'recusado' });
  });
});

await proibido('motorista não aprova aluno de outro grupo em transação', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', ALUNO_B), {
      grupoId: GRUPO_B, alunoId: ALUNO_B, status: 'pendente', criadoEm: Timestamp.now(),
    });
    await updateDoc(doc(ctx.firestore(), 'usuarios', ALUNO_B), {
      status: 'pendente', ativo: false,
    });
  });
  const db = ctxMotorista();
  return runTransaction(db, async (txn) => {
    txn.update(doc(db, 'usuarios', ALUNO_B), {
      status: 'ativo', ativo: true, atualizadoEm: Timestamp.now(),
    });
    txn.update(doc(db, 'solicitacoes', ALUNO_B), { status: 'aprovado' });
  });
});

// Notificações: criação/leitura por grupo
await proibido('motorista não lê notificação resposta_alterada de outro grupo', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chamadas', 'chamadaB3'), {
      grupoId: GRUPO_B, motoristaId: MOTORISTA_B, status: 'aberta', dataServico: Timestamp.now(),
    });
    await setDoc(doc(ctx.firestore(), 'respostas', `chamadaB3_${ALUNO_B}`), {
      chamadaId: 'chamadaB3', alunoId: ALUNO_B, grupoId: GRUPO_B,
      ida: 'vai', volta: 'naoVai', versao: 1, respondidoEm: Timestamp.now(),
    });
    await setDoc(doc(ctx.firestore(), 'notificacoes', 'notifAltB'), {
      grupoId: GRUPO_B, titulo: 'Presença alterada', corpo: 'x', alunoIds: [],
      tipo: 'resposta_alterada', dados: {
        alunoId: ALUNO_B, chamadaId: 'chamadaB3', sentido: 'volta',
        respostaAnterior: 'naoVai', respostaAtual: 'vai',
      }, criadoEm: Timestamp.now(),
    });
  });
  return getDoc(doc(ctxMotorista(), 'notificacoes', 'notifAltB'));
});

await proibido('motorista não cria notificação com alunoIds de outro grupo', () =>
  setDoc(doc(ctxMotorista(), 'notificacoes', 'notifCross'), {
    grupoId: GRUPO, titulo: 'Teste', corpo: 'Corpo', alunoIds: [ALUNO_B],
    tipo: 'chamada_aberta', dados: {}, criadoEm: serverTimestamp(),
  }));

await proibido('notificação resposta_alterada duplicada com mesmo ID é recusada como create', async () => {
  await semearRespostaAlteravel();
  await alterarComAviso(ctxAluno());
  // Tentar criar novamente o mesmo doc (create via setDoc em doc existente falha como update/create semantics in rules; setDoc overwrites but rules evaluate as create or update? setDoc on existing is update)
  return setDoc(doc(ctxAluno(), 'notificacoes', `chamada1_${ALUNO}_volta_v1`), avisoResposta());
});

// Bloqueio escrita em chamadas/viagens encerradas
await proibido('motorista não atualiza chamada encerrada como se aberta (campos proibidos)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chamadas', 'chamadaEnc2'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, status: 'encerrada', dataServico: Timestamp.now(),
    });
  });
  return updateDoc(doc(ctxMotorista(), 'chamadas', 'chamadaEnc2'), {
    status: 'aberta',
  });
});

await proibido('motorista não reabre viagem finalizada', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'viagens', 'viagemFim'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, chamadaId: 'chamada1',
      sentido: 'ida', status: 'finalizada', confirmacoes: [],
    });
  });
  return updateDoc(doc(ctxMotorista(), 'viagens', 'viagemFim'), {
    status: 'em_andamento',
  });
});

await proibido('aluno não escreve em viagem encerrada/finalizada', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'viagens', 'viagemFim2'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, chamadaId: 'chamada1',
      sentido: 'ida', status: 'finalizada', confirmacoes: [],
    });
  });
  return updateDoc(doc(ctxAluno(), 'viagens', 'viagemFim2'), {
    confirmacoes: [{ alunoId: ALUNO, idaConfirmada: true }],
  });
});

await proibido('aluno não altera resposta quando chamada encerrada (regressão)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'respostas', `chamadaFechada_${ALUNO}`), {
      chamadaId: 'chamadaFechada', alunoId: ALUNO, grupoId: GRUPO,
      ida: 'vai', volta: 'naoVai', versao: 0, respondidoEm: Timestamp.now(),
    });
  });
  return updateDoc(doc(ctxAluno(), 'respostas', `chamadaFechada_${ALUNO}`), {
    volta: 'vai', versao: 1,
  });
});

// Fase 4: conclusão/cancelamento operacional e trava por van
await permitido('motorista inicia viagem com status emAndamento serializado pelo app', async () => {
  const grupoCamel = 'grupo_status_camel';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'grupos', grupoCamel), {
      nome: 'Van status camel', motoristaId: MOTORISTA, codigo: '777888',
    });
  });
  const db = ctxMotorista();
  const lote = writeBatch(db);
  lote.set(doc(db, 'viagens', 'vStatusCamel'), {
    grupoId: grupoCamel, motoristaId: MOTORISTA, chamadaId: 'chamada1',
    sentido: 'ida', status: 'emAndamento', confirmacoes: [],
  });
  lote.set(doc(db, 'controles_viagem', grupoCamel), {
    grupoId: grupoCamel, motoristaId: MOTORISTA, viagemId: 'vStatusCamel',
    status: 'emAndamento', atualizadoEm: serverTimestamp(),
  });
  return lote.commit();
});

await permitido('motorista conclui viagem gravando status finalizada', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'viagens', 'vConcluir'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, chamadaId: 'chamada1',
      sentido: 'ida', status: 'em_andamento', confirmacoes: [],
    });
    await setDoc(doc(ctx.firestore(), 'controles_viagem', GRUPO), {
      grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vConcluir',
      status: 'emAndamento', atualizadoEm: Timestamp.now(),
    });
  });
  const db = ctxMotorista();
  const lote = writeBatch(db);
  lote.update(doc(db, 'viagens', 'vConcluir'), {
    status: 'finalizada', encerradaEm: Timestamp.now(),
  });
  lote.set(doc(db, 'controles_viagem', GRUPO), {
    grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vConcluir',
    status: 'finalizada', atualizadoEm: serverTimestamp(),
  });
  return lote.commit();
});

await permitido('motorista cancela viagem gravando data e motivo', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'viagens', 'vCancelar'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, chamadaId: 'chamada1',
      sentido: 'ida', status: 'em_andamento', confirmacoes: [],
    });
    await setDoc(doc(ctx.firestore(), 'controles_viagem', GRUPO), {
      grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vCancelar',
      status: 'emAndamento', atualizadoEm: Timestamp.now(),
    });
  });
  const db = ctxMotorista();
  const lote = writeBatch(db);
  lote.update(doc(db, 'viagens', 'vCancelar'), {
    status: 'cancelada', canceladaEm: Timestamp.now(), motivoCancelamento: 'Chuva',
  });
  lote.set(doc(db, 'controles_viagem', GRUPO), {
    grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vCancelar',
    status: 'cancelada', atualizadoEm: serverTimestamp(),
  });
  return lote.commit();
});

await permitido('motorista inicia volta após ida finalizada na mesma van', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'controles_viagem', GRUPO), {
      grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vIda',
      status: 'finalizada', atualizadoEm: Timestamp.now(),
    });
  });
  const db = ctxMotorista();
  const lote = writeBatch(db);
  lote.set(doc(db, 'viagens', 'vVolta'), {
    grupoId: GRUPO, motoristaId: MOTORISTA, chamadaId: 'chamada1',
    sentido: 'volta', status: 'em_andamento', confirmacoes: [],
  });
  lote.set(doc(db, 'controles_viagem', GRUPO), {
    grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vVolta',
    status: 'emAndamento', atualizadoEm: serverTimestamp(),
  });
  return lote.commit();
});

await permitido('motorista cancela chamada encerrada sem apagar resposta', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chamadas', 'chamadaCancelar'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, status: 'encerrada',
      viagemBloqueada: false, dataServico: Timestamp.now(),
    });
    await setDoc(doc(ctx.firestore(), 'respostas', `chamadaCancelar_${ALUNO}`), {
      chamadaId: 'chamadaCancelar', alunoId: ALUNO, grupoId: GRUPO,
      ida: 'vai', volta: 'vai', versao: 0, respondidoEm: Timestamp.now(),
    });
  });
  await updateDoc(doc(ctxMotorista(), 'chamadas', 'chamadaCancelar'), {
    status: 'cancelada', canceladaEm: Timestamp.now(), motivoCancelamento: 'Imprevisto',
  });
  const resposta = await getDoc(doc(ctxMotorista(), 'respostas', `chamadaCancelar_${ALUNO}`));
  if (!resposta.exists() || resposta.data().ida !== 'vai') {
    throw new Error('A resposta antiga não foi preservada');
  }
});

await proibido('motorista não cria viagem já finalizada', () =>
  setDoc(doc(ctxMotorista(), 'viagens', 'vFinal'), {
    grupoId: GRUPO, motoristaId: MOTORISTA, chamadaId: 'chamada1',
    sentido: 'ida', status: 'finalizada', confirmacoes: [],
  }));

await proibido('motorista não inicia segunda viagem da mesma van', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'controles_viagem', GRUPO), {
      grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vAtiva',
      status: 'emAndamento', atualizadoEm: Timestamp.now(),
    });
  });
  const db = ctxMotorista();
  const lote = writeBatch(db);
  lote.set(doc(db, 'viagens', 'vSegunda'), {
    grupoId: GRUPO, motoristaId: MOTORISTA, chamadaId: 'chamada1',
    sentido: 'ida', status: 'em_andamento', confirmacoes: [],
  });
  lote.set(doc(db, 'controles_viagem', GRUPO), {
    grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vSegunda',
    status: 'emAndamento', atualizadoEm: serverTimestamp(),
  });
  return lote.commit();
});

await proibido('motorista não troca a viagem do controle ao concluir', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'controles_viagem', GRUPO), {
      grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vAtiva',
      status: 'emAndamento', atualizadoEm: Timestamp.now(),
    });
  });
  return updateDoc(doc(ctxMotorista(), 'controles_viagem', GRUPO), {
    viagemId: 'vOutra', status: 'finalizada', atualizadoEm: serverTimestamp(),
  });
});

await proibido('motorista não reabre viagem cancelada', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'viagens', 'vCanceladaReaberta'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, chamadaId: 'chamada1',
      sentido: 'ida', status: 'cancelada', confirmacoes: [],
    });
  });
  return updateDoc(doc(ctxMotorista(), 'viagens', 'vCanceladaReaberta'), {
    status: 'em_andamento',
  });
});

await proibido('motorista não reabre chamada cancelada', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chamadas', 'chamadaCanceladaReaberta'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, status: 'cancelada',
      viagemBloqueada: false, dataServico: Timestamp.now(),
    });
  });
  return updateDoc(doc(ctxMotorista(), 'chamadas', 'chamadaCanceladaReaberta'), {
    status: 'aberta',
  });
});

await proibido('aluno não cancela chamada do grupo', () =>
  updateDoc(doc(ctxAluno(), 'chamadas', 'chamada1'), {
    status: 'cancelada', canceladaEm: Timestamp.now(),
  }));

await proibido('motorista de outra van não cancela chamada', () =>
  updateDoc(doc(ctxMotoristaB(), 'chamadas', 'chamada1'), {
    status: 'cancelada', canceladaEm: Timestamp.now(),
  }));

await proibido('aluno não altera resposta após chamada cancelada', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chamadas', 'chamadaCanceladaResp'), {
      grupoId: GRUPO, motoristaId: MOTORISTA, status: 'cancelada',
      viagemBloqueada: false, dataServico: Timestamp.now(),
    });
    await setDoc(doc(ctx.firestore(), 'respostas', `chamadaCanceladaResp_${ALUNO}`), {
      chamadaId: 'chamadaCanceladaResp', alunoId: ALUNO, grupoId: GRUPO,
      ida: 'vai', volta: 'vai', versao: 0, respondidoEm: Timestamp.now(),
    });
  });
  return updateDoc(doc(ctxAluno(), 'respostas', `chamadaCanceladaResp_${ALUNO}`), {
    volta: 'naoVai', versao: 1,
  });
});

await proibido('aluno não escreve controle de viagem', () =>
  setDoc(doc(ctxAluno(), 'controles_viagem', GRUPO), {
    grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vInvasao',
    status: 'emAndamento', atualizadoEm: serverTimestamp(),
  }));

await proibido('motorista de outra van não escreve controle de viagem', () =>
  setDoc(doc(ctxMotoristaB(), 'controles_viagem', GRUPO), {
    grupoId: GRUPO, motoristaId: MOTORISTA, viagemId: 'vInvasao',
    status: 'emAndamento', atualizadoEm: serverTimestamp(),
  }));

// Fase 5B: aviso persistente de solicitação de entrada
console.log('\n=== FASE 5B: notificação de solicitação de entrada ===');

await permitido('aluno cria solicitação, vínculo e aviso na mesma transação', () =>
  solicitarComAviso(ctxAlunoSemGrupo()));

await permitido('aluno lê o próprio aviso para idempotência', async () => {
  await solicitarComAviso(ctxAlunoSemGrupo());
  return getDoc(
    doc(ctxAlunoSemGrupo(), 'notificacoes', idAvisoEntrada(ALUNO_SEM_GRUPO, GRUPO)),
  );
});

await permitido('aluno lê solicitação e aviso inexistentes na transação', async () => {
  const db = ctxAlunoSemGrupo();
  await runTransaction(db, async (transaction) => {
    await transaction.get(doc(db, 'solicitacoes', ALUNO_SEM_GRUPO));
    await transaction.get(doc(db, 'notificacoes', idAvisoEntrada(ALUNO_SEM_GRUPO, GRUPO)));
  });
});

await permitido('aluno recusado reabre solicitação na mesma van com o perfil', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'solicitacoes', ALUNO_RECUSADO), {
      grupoId: GRUPO,
      alunoId: ALUNO_RECUSADO,
      status: 'recusado',
      criadoEm: Timestamp.now(),
    });
  });
  const db = ctxAlunoRecusado();
  await runTransaction(db, async (transaction) => {
    await transaction.get(doc(db, 'solicitacoes', ALUNO_RECUSADO));
    await transaction.get(doc(db, 'usuarios', ALUNO_RECUSADO));
    await transaction.get(doc(db, 'notificacoes', idAvisoEntrada(ALUNO_RECUSADO, GRUPO)));
    transaction.set(doc(db, 'solicitacoes', ALUNO_RECUSADO), {
      grupoId: GRUPO,
      alunoId: ALUNO_RECUSADO,
      status: 'pendente',
      criadoEm: serverTimestamp(),
    });
    transaction.set(
      doc(db, 'usuarios', ALUNO_RECUSADO),
      { grupoId: GRUPO, status: 'pendente', ativo: false, atualizadoEm: serverTimestamp() },
      { merge: true },
    );
  });
});

await permitido('motorista lê aviso de entrada da própria van', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', 'avisoEntradaLeitura'), avisoEntrada({
      uid: ALUNO_SEM_GRUPO, grupoId: GRUPO, nome: 'Pedro',
    }));
  });
  return getDoc(doc(ctxMotorista(), 'notificacoes', 'avisoEntradaLeitura'));
});

await permitido('motorista lista avisos filtrando grupo e tipo', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', 'avisoEntradaLista'), avisoEntrada({
      uid: ALUNO_SEM_GRUPO, grupoId: GRUPO, nome: 'Pedro',
    }));
  });
  return getDocs(
    query(
      collection(ctxMotorista(), 'notificacoes'),
      where('grupoId', '==', GRUPO),
      where('tipo', '==', 'solicitacao_entrada'),
    ),
  );
});

await permitido('aviso resposta_alterada continua funcionando (regressão 5A)', async () => {
  await semearRespostaAlteravel();
  return alterarComAviso(ctxAluno());
});

await proibido('aluno não cria aviso com destinatário de outra van', () =>
  solicitarComAviso(ctxAlunoSemGrupo(), {
    aviso: avisoEntrada({ destinatarioId: MOTORISTA_B }),
  }));

await proibido('aluno não forja o nome no aviso', () =>
  solicitarComAviso(ctxAlunoSemGrupo(), {
    aviso: avisoEntrada({ nome: 'Nome Falso' }),
  }));

await proibido('aluno não cria aviso para outro aluno', () =>
  solicitarComAviso(ctxAlunoSemGrupo(), {
    aviso: avisoEntrada({ uid: ALUNO }),
  }));

await proibido('aluno não cria notificação arbitrária de outro tipo', () =>
  setDoc(doc(ctxAlunoSemGrupo(), 'notificacoes', 'avisoFalsoAluno'), {
    grupoId: GRUPO, titulo: 'Falso', corpo: 'Falso', alunoIds: [ALUNO],
    tipo: 'chamada_aberta', dados: {}, criadoEm: serverTimestamp(),
  }));

await proibido('motorista de outra van não lê aviso de entrada', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', 'avisoEntradaCross'), avisoEntrada({
      uid: ALUNO_SEM_GRUPO, grupoId: GRUPO, nome: 'Pedro',
    }));
  });
  return getDoc(doc(ctxMotoristaB(), 'notificacoes', 'avisoEntradaCross'));
});

await proibido('aluno não lista notificações', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', 'avisoEntradaListaAluno'), avisoEntrada({
      uid: ALUNO_SEM_GRUPO, grupoId: GRUPO, nome: 'Pedro',
    }));
  });
  return getDocs(
    query(
      collection(ctxAluno(), 'notificacoes'),
      where('grupoId', '==', GRUPO),
      where('tipo', '==', 'solicitacao_entrada'),
    ),
  );
});

await proibido('ID determinístico impede segundo aviso para a mesma solicitação', async () => {
  await solicitarComAviso(ctxAlunoSemGrupo());
  return setDoc(
    doc(ctxAlunoSemGrupo(), 'notificacoes', idAvisoEntrada(ALUNO_SEM_GRUPO, GRUPO)),
    avisoEntrada(),
  );
});

await proibido('aviso de entrada não pode ser alterado', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'notificacoes', 'avisoEntradaAlterado'), avisoEntrada({
      uid: ALUNO_SEM_GRUPO, grupoId: GRUPO, nome: 'Pedro',
    }));
  });
  return updateDoc(doc(ctxMotorista(), 'notificacoes', 'avisoEntradaAlterado'), {
    corpo: 'Alterado',
  });
});

console.log('\n=== RESULTADO ===');
console.log(`Permitidos: ${permitidos} OK, ${permitidosFalharam} falharam`);
console.log(`Proibidos:  ${proibidos} OK, ${proibidosFalharam} falharam`);

await testEnv.cleanup();
if (permitidosFalharam > 0 || proibidosFalharam > 0) process.exit(1);
