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
  collection,
  getDocs,
  query,
  where,
  Timestamp,
} from 'firebase/firestore';

const PROJECT_ID = 'vango-rules-test';
const GRUPO = 'grupo-capao-itape';
const OUTRO_GRUPO = 'outro-grupo';

const MOTORISTA = 'motorista-uid';
const ALUNO = 'aluno-uid';
const OUTRO_ALUNO = 'outro-aluno-uid';
const INATIVO = 'inativo-uid';
const CONFLITO = 'conflito-uid';
const OUTRO_GRUPO_UID = 'outro-grupo-uid';
const SEM_PERFIL = 'sem-perfil-uid';

const rules = readFileSync(
  new URL('../../firestore.rules.confirmacao.proposto', import.meta.url),
  'utf8',
);

const testEnv = await initializeTestEnvironment({
  projectId: PROJECT_ID,
  firestore: { rules, host: '127.0.0.1', port: 8080 },
});

let permitidos = 0;
let permitidosFalharam = 0;
let proibidos = 0;
let proibidosFalharam = 0;

function usuario(perfil, ativo, status, grupoId = GRUPO) {
  return { perfil, ativo, status, grupoId, nome: 'Teste' };
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

console.log('\n=== PERMITIDOS ===');
await permitido('aluno lê o próprio perfil (regressão)', () =>
  getDoc(doc(ctxAluno(), 'usuarios', ALUNO)));

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
    volta: 'naoVai', respondidoEm: Timestamp.now(),
  });
});

await permitido('aluno lista somente a própria resposta (chamadaId + alunoId)', () =>
  getDocs(query(
    collection(ctxAluno(), 'respostas'),
    where('chamadaId', '==', 'chamada1'),
    where('alunoId', '==', ALUNO),
  )));

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
    where('chamadaId', '==', 'chamada1'),
  ));
});

console.log('\n=== PROIBIDOS ===');
await proibido('aluno não lê perfil de outro usuário', () =>
  getDoc(doc(ctxAluno(), 'usuarios', MOTORISTA)));

await proibido('aluno não modifica o próprio perfil para motorista', () =>
  updateDoc(doc(ctxAluno(), 'usuarios', ALUNO), { perfil: 'MOTORISTA' }));

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
  return updateDoc(doc(ctxAluno(), 'respostas', `chamada1_${OUTRO_ALUNO}`), { ida: 'naoVai' });
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

await proibido('aluno não grava campo estouIndo na resposta', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'respostas', `chamada1_${ALUNO}`), {
      chamadaId: 'chamada1', alunoId: ALUNO, grupoId: GRUPO, ida: 'vai', volta: 'vai',
    });
  });
  return updateDoc(doc(ctxAluno(), 'respostas', `chamada1_${ALUNO}`), { estouIndo: true });
});

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

await proibido('aluno não lê nem grava viagens nesta fase', () =>
  getDocs(collection(ctxAluno(), 'viagens')));

console.log('\n=== RESULTADO ===');
console.log(`Permitidos: ${permitidos} OK, ${permitidosFalharam} falharam`);
console.log(`Proibidos:  ${proibidos} OK, ${proibidosFalharam} falharam`);

await testEnv.cleanup();
if (permitidosFalharam > 0 || proibidosFalharam > 0) process.exit(1);
