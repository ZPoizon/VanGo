async (page) => {
  // Fase 5B — aviso persistente de solicitação de entrada.
  // Executa somente contra Firebase Emulator Suite (projeto demo-vango).
  const BASE = 'http://127.0.0.1:7358/';
  const KEY = 'AIzaSyB82GT3m_AqHCFMmRl8z0avk9IE6FkxjvI';
  const FIRE = 'http://127.0.0.1:8080/v1/projects/demo-vango/databases/(default)/documents';
  const AUTH = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
  const ADMIN = { Authorization: 'Bearer owner' };
  const sufixo = String(Date.now()).slice(-8);
  const NOME_DRIVER = 'Motorista 5B';
  const NOME_A = `Aluno A 5B ${sufixo}`;
  const NOME_B = `Aluno B 5B ${sufixo}`;
  const VAN_A = `Van 5B A ${sufixo}`;
  const VAN_B = `Van 5B B ${sufixo}`;
  const MOTORISTA = { email: `e2e.5b.driver.${sufixo}@vango.test`, senha: 'Senha@123' };
  const ALUNO_A = { email: `e2e.5b.alunoa.${sufixo}@vango.test`, senha: 'Senha@123' };
  const ALUNO_B = { email: `e2e.5b.alunob.${sufixo}@vango.test`, senha: 'Senha@123' };

  const results = [];
  const erros = [];
  const contexts = [];
  const passo = (n, descricao, ok, detalhe) =>
    results.push({ n, descricao, ok: Boolean(ok), detalhe });

  const ariaTexto = (p) =>
    p.locator('flt-semantics').evaluateAll((nos) =>
      nos.map((no) => no.getAttribute('aria-label') ?? '').join('\n'),
    );
  async function waitText(p, texto, timeout = 25000) {
    const limite = Date.now() + timeout;
    while (Date.now() < limite) {
      const visiveis = p.getByText(texto, { exact: false });
      if ((await visiveis.count()) > 0) {
        try {
          await visiveis.first().waitFor({ state: 'visible', timeout: 800 });
          return;
        } catch (_) {}
      }
      const semantica = (await p.locator('flt-semantics').allTextContents()).join('\n');
      if (semantica.includes(texto)) return;
      if ((await ariaTexto(p)).includes(texto)) return;
      await p.waitForTimeout(250);
    }
    throw new Error(`Texto não apareceu: ${texto}`);
  }
  const btn = (p, nome) => p.getByRole('button', { name: nome, exact: false }).first();
  const input = (p, indice) => p.locator('input').nth(indice);
  async function preencher(p, indice, valor) {
    for (let tentativa = 0; tentativa < 4; tentativa++) {
      const el = input(p, indice);
      try {
        await el.waitFor({ state: 'visible', timeout: 8000 });
        await el.fill('');
        await p.waitForTimeout(50);
        await el.pressSequentially(valor, { delay: 10 });
        await p.waitForTimeout(120);
        if ((await el.inputValue()) === valor) return;
      } catch (_) {
        // A árvore do Flutter Web pode ser recriada durante a navegação.
      }
    }
    throw new Error(`Campo ${indice} não aceitou o valor após 4 tentativas`);
  }
  async function a11y(p) {
    const placeholder = p.locator('flt-semantics-placeholder');
    const semantica = p.locator('flt-semantics');
    for (let i = 0; i < 100; i++) {
      if ((await placeholder.count()) > 0 || (await semantica.count()) > 0) break;
      await p.waitForTimeout(100);
    }
    if ((await placeholder.count()) === 0) return;
    await placeholder.evaluate((el) => {
      el.focus();
      el.click();
    });
  }
  async function novoContexto(browser, nome) {
    const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
    contexts.push(ctx);
    const p = await ctx.newPage();
    p.on('pageerror', (e) => erros.push(`${nome}: pageerror: ${e.message}`));
    p.on('console', (m) => {
      if (m.type() === 'error') erros.push(`${nome}: console: ${m.text().slice(0, 240)}`);
    });
    await p.goto(BASE, { waitUntil: 'load' });
    await a11y(p);
    await input(p, 0).waitFor({ state: 'visible', timeout: 30000 });
    return p;
  }
  async function doc(p, caminho) {
    const r = await p.request.get(`${FIRE}/${caminho}`, { headers: ADMIN });
    return r.ok() ? await r.json() : null;
  }
  async function credenciais(p, conta) {
    const r = await p.request.post(`${AUTH}/accounts:signInWithPassword?key=${KEY}`, {
      data: { email: conta.email, password: conta.senha, returnSecureToken: true },
    });
    const j = await r.json();
    return { uid: j.localId, token: j.idToken, erro: JSON.stringify(j).slice(0, 220) };
  }
  const textoDoc = (d) => (d ? JSON.stringify(d.fields ?? {}) : null);
  async function esperarDoc(p, caminho, condicao, timeout = 20000) {
    const limite = Date.now() + timeout;
    let ultimo = null;
    while (Date.now() < limite) {
      ultimo = await doc(p, caminho);
      if (condicao(ultimo)) return ultimo;
      await p.waitForTimeout(300);
    }
    return ultimo;
  }
  async function entrar(p, conta, textoEsperado) {
    await input(p, 0).waitFor({ state: 'visible', timeout: 30000 });
    await preencher(p, 0, conta.email);
    await preencher(p, 1, conta.senha);
    await btn(p, 'Entrar').click();
    await waitText(p, textoEsperado, 30000);
  }
  async function avisosEntrada(p) {
    const lista = await doc(p, 'notificacoes');
    return (lista?.documents ?? []).filter(
      (d) => d.fields?.tipo?.stringValue === 'solicitacao_entrada',
    );
  }
  const mensagemAviso = (dados) => {
    const campos = dados.fields ?? {};
    const aviso = campos.dados?.mapValue?.fields ?? {};
    return {
      id: dados.name?.split('/').pop(),
      grupoId: campos.grupoId?.stringValue,
      tipo: campos.tipo?.stringValue,
      titulo: campos.titulo?.stringValue,
      corpo: campos.corpo?.stringValue,
      alunoIds: campos.alunoIds?.arrayValue?.values?.length ?? 0,
      solicitacaoId: aviso.solicitacaoId?.stringValue,
      destinatarioId: aviso.destinatarioId?.stringValue,
      alunoNome: aviso.alunoNome?.stringValue,
      criadoEm: campos.criadoEm?.timestampValue,
    };
  };
  async function criarVan(p, nome, periodo) {
    await btn(p, 'Criar nova van').click();
    await input(p, 0).waitFor({ state: 'visible' });
    await preencher(p, 0, nome);
    await preencher(p, 1, 'Capão Bonito');
    await preencher(p, 2, 'Itapetininga');
    await p.getByText(periodo, { exact: true }).first().click();
    await btn(p, 'Criar van').click();
    await waitText(p, 'Minhas vans', 30000);
  }
  async function cadastrarAluno(p, conta, nome) {
    await p.getByText('Criar conta', { exact: true }).first().click();
    await waitText(p, 'Escolha seu perfil');
    await p.getByText('Sou aluno', { exact: false }).first().click();
    await btn(p, 'Criar conta de aluno').waitFor({ state: 'visible', timeout: 30000 });
    await p.waitForTimeout(400);
    await preencher(p, 0, nome);
    await preencher(p, 1, conta.email);
    await preencher(p, 2, '(15) 99999-0002');
    await preencher(p, 3, 'Fatec E2E');
    await preencher(p, 4, 'Rua E2E, 100');
    await preencher(p, 5, '18270-000');
    await preencher(p, 6, conta.senha);
    await btn(p, 'Criar conta de aluno').click();
    await btn(p, 'Entrar em um grupo').waitFor({ state: 'visible', timeout: 30000 });
  }
  async function solicitar(p, codigo, nomeVan) {
    await btn(p, 'Entrar em um grupo').click();
    await input(p, 0).waitFor({ state: 'visible' });
    await preencher(p, 0, codigo);
    await btn(p, 'Buscar Van').click();
    const cartao = p.getByRole('group', { name: /Van Encontrada/ }).first();
    await cartao.waitFor({ state: 'visible', timeout: 25000 });
    const rotulo = (await cartao.getAttribute('aria-label')) ?? '';
    if (!rotulo.includes(nomeVan)) throw new Error(`Van errada: ${rotulo}`);
    await btn(p, 'Solicitar entrada nesta van').click();
    await waitText(p, 'Aguardando aprovação', 25000);
  }
  async function abrirAviso(p, mensagem) {
    const alvo = p.getByText(mensagem, { exact: false }).first();
    await alvo.waitFor({ state: 'visible', timeout: 25000 });
    await alvo.click();
    await waitText(p, 'SOLICITAÇÕES PENDENTES', 25000);
    await waitText(p, 'Solicitação selecionada', 25000);
  }

  try {
    const browser = page.context().browser();
    const dp = await novoContexto(browser, 'motorista');
    const ap = await novoContexto(browser, 'aluno-A');
    const bp = await novoContexto(browser, 'aluno-B');

    // Estado limpo do emulador: nenhuma execução anterior pode influenciar
    // contadores ou a contagem de documentos de avisos.
    await dp.request.delete(
      'http://127.0.0.1:8080/emulator/v1/projects/demo-vango/databases/(default)/documents',
      { headers: ADMIN },
    );
    await dp.request.delete(
      'http://127.0.0.1:9099/emulator/v1/projects/demo-vango/accounts',
      { headers: ADMIN },
    );

    // ---------------- preparação: motorista, duas vans e dois alunos ----------------
    await dp.getByText('Criar conta', { exact: true }).first().click();
    await waitText(dp, 'Escolha seu perfil');
    await dp.getByText('Sou motorista', { exact: false }).first().click();
    await btn(dp, 'Criar conta de motorista').waitFor({ state: 'visible', timeout: 30000 });
    await dp.waitForTimeout(400);
    await preencher(dp, 0, NOME_DRIVER);
    await preencher(dp, 1, MOTORISTA.email);
    await preencher(dp, 2, '(15) 99999-0001');
    await preencher(dp, 3, MOTORISTA.senha);
    await preencher(dp, 4, MOTORISTA.senha);
    await btn(dp, 'Criar conta de motorista').click();
    await btn(dp, 'Criar minha primeira van').waitFor({ state: 'visible', timeout: 30000 });
    await btn(dp, 'Criar minha primeira van').click();
    await btn(dp, 'Criar van').waitFor({ state: 'visible', timeout: 30000 });
    await dp.waitForTimeout(400);
    await preencher(dp, 0, VAN_A);
    await preencher(dp, 1, 'Capão Bonito');
    await preencher(dp, 2, 'Itapetininga');
    await dp.getByText('Manhã', { exact: true }).first().click();
    await btn(dp, 'Criar van').click();
    await waitText(dp, VAN_A, 30000);

    const cM = await credenciais(dp, MOTORISTA);
    const driverUid = cM.uid;
    let grupos = await doc(dp, 'grupos');
    let grupoA = (grupos?.documents ?? []).find(
      (d) => d.fields?.motoristaId?.stringValue === driverUid &&
        d.fields?.nome?.stringValue === VAN_A,
    );
    const grupoAId = grupoA?.name?.split('/').pop();
    const codigoA = grupoA?.fields?.codigo?.stringValue;

    await cadastrarAluno(ap, ALUNO_A, NOME_A);
    const cA = await credenciais(ap, ALUNO_A);
    const alunoAUid = cA.uid;

    // Painel do motorista já aberto ANTES da solicitação: prova de tempo real.
    await dp.goto(`${BASE}#/driver/dashboard`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, 'Minhas vans', 30000);
    const avisosAntes = await avisosEntrada(dp);
    passo(
      1,
      'Dashboard sem avisos antes da solicitação',
      avisosAntes.length === 0 &&
        (await dp.getByText('pendente(s)', { exact: false }).count()) === 0,
      `avisos=${avisosAntes.length}`,
    );

    // ---------------- solicitação do aluno A ----------------
    await solicitar(ap, codigoA, VAN_A);
    const avisoADoc = await esperarDoc(
      dp,
      `notificacoes/solicitacao_entrada_${alunoAUid}_${grupoAId}`,
      (d) => d?.fields?.tipo?.stringValue === 'solicitacao_entrada',
    );
    const avisoA = mensagemAviso(avisoADoc);
    const mensagemA = `${NOME_A} solicitou entrada na van ${VAN_A}.`;
    passo(
      2,
      'Solicitação gera aviso determinístico no mesmo lote',
      avisoA.id === `solicitacao_entrada_${alunoAUid}_${grupoAId}` &&
        avisoA.grupoId === grupoAId &&
        avisoA.solicitacaoId === alunoAUid &&
        avisoA.destinatarioId === driverUid &&
        avisoA.alunoNome === NOME_A &&
        avisoA.alunoIds === 0 &&
        avisoA.tipo === 'solicitacao_entrada' &&
        Boolean(avisoA.criadoEm),
      JSON.stringify(avisoA).slice(0, 420),
    );

    // ---------------- tempo real e contador ----------------
    await waitText(dp, mensagemA, 25000);
    await waitText(dp, '1 pendente(s)', 25000);
    await waitText(dp, `1 solicitações pendentes`, 25000);
    passo(
      3,
      'Aviso e contador atualizam em tempo real, sem refresh',
      true,
      `mensagem="${mensagemA}"; cartão com 1 pendente(s)`,
    );

    // ---------------- persistência após refresh e novo login ----------------
    await dp.reload({ waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, mensagemA, 30000);
    await btn(dp, 'Sair da conta').click();
    await waitText(dp, 'Entrar', 20000);
    await entrar(dp, MOTORISTA, 'Olá, Motorista');
    await dp.goto(`${BASE}#/driver/dashboard`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, mensagemA, 30000);
    const avisosAposRelogin = await avisosEntrada(dp);
    passo(
      4,
      'Aviso persiste após refresh e novo login',
      avisosAposRelogin.length === 1 &&
        avisosAposRelogin[0].name?.split('/').pop() === avisoA.id,
      `avisos=${avisosAposRelogin.map((a) => a.name?.split('/').pop()).join(',')}`,
    );

    // ---------------- múltiplas vans e segunda solicitação ----------------
    await criarVan(dp, VAN_B, 'Tarde');
    grupos = await doc(dp, 'grupos');
    const grupoB = (grupos?.documents ?? []).find(
      (d) => d.fields?.motoristaId?.stringValue === driverUid &&
        d.fields?.nome?.stringValue === VAN_B,
    );
    const grupoBId = grupoB?.name?.split('/').pop();
    const codigoB = grupoB?.fields?.codigo?.stringValue;

    await cadastrarAluno(bp, ALUNO_B, NOME_B);
    const cB = await credenciais(bp, ALUNO_B);
    const alunoBUid = cB.uid;
    await solicitar(bp, codigoB, VAN_B);

    const mensagemB = `${NOME_B} solicitou entrada na van ${VAN_B}.`;
    await waitText(dp, mensagemA, 25000);
    await waitText(dp, mensagemB, 25000);
    await waitText(dp, '2 pendente(s)', 25000);
    const avisosDuasVans = (await avisosEntrada(dp)).map(mensagemAviso);
    passo(
      5,
      'Motorista com várias vans identifica a origem de cada aviso',
      avisosDuasVans.length === 2 &&
        avisosDuasVans.some((a) => a.grupoId === grupoAId && a.solicitacaoId === alunoAUid) &&
        avisosDuasVans.some((a) => a.grupoId === grupoBId && a.solicitacaoId === alunoBUid) &&
        (await dp.getByText('Van: ' + VAN_A, { exact: false }).count()) > 0 &&
        (await dp.getByText('Van: ' + VAN_B, { exact: false }).count()) > 0,
      avisosDuasVans.map((a) => `${a.grupoId}/${a.solicitacaoId}`).join(' | '),
    );

    // ---------------- clique no aviso abre a van correta ----------------
    await dp.goto(`${BASE}#/driver/dashboard`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, mensagemB, 30000);
    await abrirAviso(dp, mensagemB);
    const vanBCorretta = await dp.getByText(VAN_B, { exact: false }).count();
    const rotulosB = await ariaTexto(dp);
    const destacadoB = rotulosB.includes(NOME_B) ? 1 : 0;
    const selecionadaB = rotulosB.includes('Solicitação selecionada') ? 1 : 0;
    passo(
      6,
      'Clique no aviso abre a van e destaca a solicitação',
      vanBCorretta > 0 &&
        destacadoB > 0 &&
        selecionadaB > 0 &&
        (await btn(dp, 'Aprovar').count()) > 0 &&
        (await btn(dp, 'Recusar').count()) > 0,
      `van=${vanBCorretta}; aluno=${destacadoB}; selecionada=${selecionadaB}`,
    );

    // ---------------- recusa remove aviso e atualiza contador ----------------
    await btn(dp, 'Recusar').click();
    const solicitacaoB = await esperarDoc(
      dp,
      `solicitacoes/${alunoBUid}`,
      (d) => d?.fields?.status?.stringValue === 'recusado',
    );
    await dp.goto(`${BASE}#/driver/dashboard`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, mensagemA, 30000);
    const avisoBVisivel = await dp.getByText(mensagemB, { exact: false }).count();
    passo(
      7,
      'Recusa remove o aviso e reduce o contador para 1',
      solicitacaoB?.fields?.status?.stringValue === 'recusado' &&
        avisoBVisivel === 0 &&
        (await dp.getByText('1 pendente(s)', { exact: false }).count()) > 0,
      `statusB=${solicitacaoB?.fields?.status?.stringValue}; avisoBVisivel=${avisoBVisivel}`,
    );

    // ---------------- aprovação remove aviso e zera contador ----------------
    await dp.goto(`${BASE}#/driver/dashboard`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, mensagemA, 30000);
    await abrirAviso(dp, mensagemA);
    await btn(dp, 'Aprovar').click();
    const solicitacaoA = await esperarDoc(
      dp,
      `solicitacoes/${alunoAUid}`,
      (d) => d?.fields?.status?.stringValue === 'aprovado',
    );
    await dp.goto(`${BASE}#/driver/dashboard`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, 'Minhas vans', 30000);
    const avisoAAposAprovacao = await dp.getByText(mensagemA, { exact: false }).count();
    const pendentesAposAprovacao = await dp.getByText('1 pendente(s)', { exact: false }).count();
    passo(
      8,
      'Aprovação remove o aviso e zera o contador',
      solicitacaoA?.fields?.status?.stringValue === 'aprovado' &&
        avisoAAposAprovacao === 0 &&
        pendentesAposAprovacao === 0,
      `statusA=${solicitacaoA?.fields?.status?.stringValue}; aviso=${avisoAAposAprovacao}; contador1=${pendentesAposAprovacao}`,
    );

    // ---------------- documento do aviso permanece como histórico ----------------
    const avisoAFinal = await doc(dp, `notificacoes/solicitacao_entrada_${alunoAUid}_${grupoAId}`);
    passo(
      9,
      'Evento persistido não é apagado nem recriado',
      Boolean(avisoAFinal) &&
        avisoAFinal.fields?.dados?.mapValue?.fields?.solicitacaoId?.stringValue === alunoAUid,
      `documento=${avisoAFinal?.name ?? 'ausente'}`,
    );

    // ---------------- segurança: aluno não lista notificações ----------------
    const leituraAluno = await ap.request.get(`${FIRE}/notificacoes`, {
      headers: { Authorization: `Bearer ${cA.token}` },
    });
    passo(
      10,
      'Aluno autenticado não lista notificações',
      !leituraAluno.ok(),
      `http=${leituraAluno.status()}`,
    );

    // ---------------- regressão Fase 5A: resposta_alterada continua ----------------
    await waitText(dp, VAN_A, 25000);
    await dp.getByText('Abrir painel', { exact: true }).first().click();
    await waitText(dp, 'Abrir chamada de amanhã', 30000);
    await btn(dp, 'Abrir chamada de amanhã').click();
    await waitText(dp, 'Encerrar chamada', 30000);
    let chamadas = await doc(dp, 'chamadas');
    const chamada = (chamadas?.documents ?? []).find(
      (d) => d.fields?.grupoId?.stringValue === grupoAId && d.fields?.status?.stringValue === 'aberta',
    );
    const chamadaId = chamada?.name?.split('/').pop();

    await ap.goto(`${BASE}#/student/home`, { waitUntil: 'load' });
    await a11y(ap);
    await waitText(ap, 'Como você vai?', 30000);
    await ap.getByRole('button', { name: /confirmar ida/i }).first().click();
    await esperarDoc(
      ap,
      `respostas/${chamadaId}_${alunoAUid}`,
      (d) => d?.fields?.ida?.stringValue === 'vai',
    );
    await ap.getByRole('button', { name: /confirmar ida/i }).last().click();
    const avisoPresenca = await esperarDoc(
      ap,
      'notificacoes',
      (d) => (d?.documents ?? []).some(
        (x) => x.fields?.tipo?.stringValue === 'resposta_alterada' &&
          x.fields?.dados?.mapValue?.fields?.alunoId?.stringValue === alunoAUid,
      ),
    );
    const existeAvisoPresenca = (avisoPresenca?.documents ?? []).some(
      (x) => x.fields?.tipo?.stringValue === 'resposta_alterada' &&
        x.fields?.dados?.mapValue?.fields?.alunoId?.stringValue === alunoAUid,
    );
    await dp.goto(`${BASE}#/driver/home`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, 'Alterações de presença', 30000);
    await waitText(dp, 'Ida: Vai → Não vai', 25000);
    passo(
      11,
      'Aviso resposta_alterada da Fase 5A continua funcionando',
      Boolean(chamadaId) && existeAvisoPresenca,
      `chamada=${chamadaId}; avisoPresenca=${existeAvisoPresenca}`,
    );

    // ---------------- idempotência: aluno recusado repete a mesma van ----------------
    await bp.goto(`${BASE}#/student/home`, { waitUntil: 'load' });
    await a11y(bp);
    await btn(bp, 'Tentar novamente').click();
    await btn(bp, 'Buscar Van').waitFor({ state: 'visible', timeout: 30000 });
    await preencher(bp, 0, codigoB);
    await btn(bp, 'Buscar Van').click();
    const cartaoRepetido = bp.getByRole('group', { name: /Van Encontrada/ }).first();
    await cartaoRepetido.waitFor({ state: 'visible', timeout: 25000 });
    await btn(bp, 'Solicitar entrada nesta van').click();
    await waitText(bp, 'Aguardando aprovação', 25000);
    const avisosAposRepeticao = await avisosEntrada(dp);
    const avisosB = avisosAposRepeticao.filter(
      (a) => a.fields?.dados?.mapValue?.fields?.solicitacaoId?.stringValue === alunoBUid,
    );
    const solicitacaoBRepetida = await doc(dp, `solicitacoes/${alunoBUid}`);
    await dp.goto(`${BASE}#/driver/dashboard`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, mensagemB, 30000);
    passo(
      12,
      'Repetir solicitação não cria segundo evento',
      avisosAposRepeticao.length === 2 &&
        avisosB.length === 1 &&
        solicitacaoBRepetida?.fields?.status?.stringValue === 'pendente' &&
        (await dp.getByText('1 pendente(s)', { exact: false }).count()) > 0,
      `totalAvisos=${avisosAposRepeticao.length}; avisosB=${avisosB.length}; statusB=${solicitacaoBRepetida?.fields?.status?.stringValue}`,
    );
  } catch (erro) {
    erros.push(` execução: ${erro.message}`);
    for (const [indice, ctx] of contexts.entries()) {
      try {
        const paginas = ctx.pages();
        for (const pagina of paginas) {
          const texto = (await pagina.locator('flt-semantics').allTextContents())
            .join(' | ')
            .slice(0, 900);
          erros.push(` contexto ${indice} (${pagina.url()}): ${texto}`);
        }
      } catch (_) {}
    }
    passo(0, 'Execução concluída sem exceção', false, erro.stack?.slice(0, 600) ?? erro.message);
  } finally {
    for (const ctx of contexts) {
      try { await ctx.close(); } catch (_) {}
    }
  }

  const ok = results.every((r) => r.ok) && erros.length === 0;
  return {
    ok,
    etapas: results.length,
    aprovadas: results.filter((r) => r.ok).length,
    falhas: results.filter((r) => !r.ok),
    erros,
    detalhes: results,
  };
}
