#!/usr/bin/env node
/* eslint-disable no-console */
'use strict';

/**
 * Cria o motorista e o grupo inicial no Firebase (Auth + Firestore).
 *
 * Uso:
 *   1. Baixe a chave de serviço do projeto:
 *      Console do Firebase → Configurações → Contas de serviço → Gerar nova
 *      chave privada. Salve como `tool/service-account.json` (não comite!).
 *   2. Rode:
 *
 *      $env:GOOGLE_APPLICATION_CREDENTIALS = "tool/service-account.json"
 *      node tool/seed_firestore.js ^
 *        --email=motorista@vango.app ^
 *        --senha=umaSenhaForte123 ^
 *        --nome="Motorista VanGo" ^
 *        --telefone="(15) 99999-0000"
 *
 *   O grupo padrão é `grupo-capao-itape`. Para outro grupo use `--grupo=...`.
 *   O `grupoId` padrão do app está em `lib/data/firebase/firestore_mappers.dart`.
 */

const admin = require('firebase-admin');

function argumento(nome, padrao = null) {
  const prefixo = `--${nome}=`;
  const encontrado = process.argv.find((arg) => arg.startsWith(prefixo));
  return encontrado ? encontrado.slice(prefixo.length) : padrao;
}

async function main() {
  const email = argumento('email');
  const senha = argumento('senha');
  const nome = argumento('nome', 'Motorista VanGo');
  const telefone = argumento('telefone', '');
  const grupoId = argumento('grupo', 'grupo-capao-itape');
  const projectId = process.env.FIREBASE_PROJECT_ID || argumento('project');

  if (!email || !senha) {
    console.error(
      'Informe --email=... e --senha=...\n' +
        'Exemplo: node tool/seed_firestore.js --email=motorista@vango.app ' +
        '--senha=senha123 --nome="Motorista VanGo"',
    );
    process.exit(1);
  }
  if (senha.length < 6) {
    console.error('A senha precisa ter ao menos 6 caracteres.');
    process.exit(1);
  }

  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error(
      'Defina GOOGLE_APPLICATION_CREDENTIALS apontando para a chave de ' +
        'serviço baixada do Firebase.',
    );
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: projectId || undefined,
  });

  const auth = admin.auth();
  const db = admin.firestore();

  let usuario;
  try {
    usuario = await auth.getUserByEmail(email);
    console.log(`Usuário já existe: ${usuario.uid}`);
  } catch (erro) {
    if (erro.code !== 'auth/user-not-found') throw erro;
    usuario = await auth.createUser({
      email,
      password: senha,
      displayName: nome,
      emailVerified: true,
    });
    console.log(`Usuário criado: ${usuario.uid}`);
  }

  const agora = admin.firestore.FieldValue.serverTimestamp();

  await db.collection('usuarios').doc(usuario.uid).set(
    {
      nome,
      email: email.toLowerCase(),
      perfil: 'motorista',
      status: 'ativo',
      telefone,
      fotoUrl: null,
      instituicao: null,
      turno: null,
      enderecoEmbarque: null,
      grupoId,
      criadoEm: agora,
      atualizadoEm: agora,
    },
    { merge: true },
  );
  console.log(`usuarios/${usuario.uid} atualizado.`);

  await db.collection('grupos').doc(grupoId).set(
    {
      nome: 'Capão Bonito → Itapetininga',
      motoristaId: usuario.uid,
      criadoEm: agora,
      atualizadoEm: agora,
    },
    { merge: true },
  );
  console.log(`grupos/${grupoId} atualizado.`);

  console.log('\nPronto! Agora entre no app com:');
  console.log(`  e-mail: ${email}`);
  console.log(`  senha:  ${senha}`);
}

main().catch((erro) => {
  console.error('Falha ao preparar o Firestore:', erro);
  process.exit(1);
});
