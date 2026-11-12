/* eslint-disable */
'use strict';

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

/**
 * Envia push para os alunos quando o motorista cria um documento em
 * `notificacoes`.
 *
 * O app grava:
 *   { grupoId, titulo, corpo, alunoIds: [...], tipo, dados: {...}, criadoEm }
 */
exports.enviarNotificacao = onDocumentCreated(
  'notificacoes/{notificacaoId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const dados = snapshot.data() || {};
    const alunoIds = Array.isArray(dados.alunoIds) ? dados.alunoIds : [];
    if (alunoIds.length === 0) return;

    // Reúne os tokens dos alunos avisados.
    const tokens = new Set();
    const referencias = new Map(); // token -> DocumentReference

    await Promise.all(
      alunoIds.map(async (alunoId) => {
        try {
          const tokensSnap = await db
            .collection('usuarios')
            .doc(alunoId)
            .collection('tokens')
            .get();
          tokensSnap.forEach((doc) => {
            const token = doc.get('token');
            if (typeof token === 'string' && token.length > 0) {
              tokens.add(token);
              referencias.set(token, doc.ref);
            }
          });
        } catch (erro) {
          console.warn(`[FCM] falha ao ler tokens de ${alunoId}:`, erro);
        }
      }),
    );

    if (tokens.size === 0) {
      console.log('[FCM] nenhum token encontrado para os alunos avisados.');
      return;
    }

    const payload = {
      tokens: [...tokens],
      notification: {
        title: dados.titulo || 'VanGo',
        body: dados.corpo || '',
      },
      data: Object.fromEntries(
        Object.entries(dados.dados || {}).map(([chave, valor]) => [
          chave,
          String(valor),
        ]),
      ),
      android: {
        priority: 'high',
        notification: {
          channelId: 'vango_chegada',
          icon: 'ic_launcher',
        },
      },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
    };

    try {
      const resposta = await admin.messaging().sendEachForMulticast(payload);
      console.log(
        `[FCM] ${resposta.successCount} enviadas, ` +
          `${resposta.failureCount} falhas.`,
      );

      // Remove tokens inválidos para não acumular lixo.
      const remocoes = [];
      resposta.responses.forEach((resultado, indice) => {
        if (resultado.success) return;
        const codigo = resultado.error && resultado.error.code;
        if (
          codigo === 'messaging/registration-token-not-registered' ||
          codigo === 'messaging/invalid-registration-token' ||
          codigo === 'messaging/invalid-argument'
        ) {
          const token = payload.tokens[indice];
          const ref = referencias.get(token);
          if (ref) remocoes.push(ref.delete());
        }
      });
      await Promise.all(remocoes);
    } catch (erro) {
      console.error('[FCM] falha ao enviar notificação:', erro);
      throw erro;
    }
  },
);
