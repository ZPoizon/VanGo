async (page) => {
  const BASE = 'http://127.0.0.1:7358/';
  const KEY = 'AIzaSyB82GT3m_AqHCFMmRl8z0avk9IE6FkxjvI';
  const FIRE = 'http://127.0.0.1:8080/v1/projects/demo-vango/databases/(default)/documents';
  const ADMIN = { Authorization: 'Bearer owner' };
  const sufixo = String(Date.now()).slice(-8);
  const DRIVER = { email: `e2e.motorista.${sufixo}@vango.test`, senha: 'Senha@123' };
  const ALUNO = { email: `e2e.aluno.${sufixo}@vango.test`, senha: 'Senha@123' };
  const results = [];
  const erros = [];
  const contexts = [];

  const passo = (n, descricao, ok, detalhe) =>
    results.push({ n, descricao, ok: Boolean(ok), detalhe });
  const waitText = (p, texto, timeout = 25000) =>
    p.getByText(texto, { exact: false }).first().waitFor({ state: 'visible', timeout });
  const btn = (p, nome) => p.getByRole('button', { name: nome, exact: false }).first();
  const campo = (p, nome) => p.getByRole('textbox', { name: nome, exact: false }).first();
  const input = (p, indice) => p.locator('input').nth(indice);
  async function preencher(p, indice, valor) {
    const el = input(p, indice);
    for (let tentativa = 0; tentativa < 3; tentativa++) {
      await el.fill('');
      await p.waitForTimeout(50);
      await el.pressSequentially(valor, { delay: 15 });
      await p.waitForTimeout(150);
      if ((await el.inputValue()) === valor) return;
    }
    throw new Error(`Campo ${indice} não aceitou o valor esperado: ${await el.inputValue()}`);
  }

  async function a11y(p) {
    const placeholder = p.locator('flt-semantics-placeholder');
    const semantica = p.locator('flt-semantics');
    for (let tentativa = 0; tentativa < 100; tentativa++) {
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
      if (m.type() === 'error') erros.push(`${nome}: console: ${m.text().slice(0, 300)}`);
    });
    p.on('response', (r) => {
      if (r.status() >= 400) erros.push(`${nome}: http ${r.status()} ${r.url().slice(0, 200)}`);
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
  async function uidAuth(p, conta) {
    const r = await p.request.post(
      `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${KEY}`,
      { data: { email: conta.email, password: conta.senha, returnSecureToken: true } },
    );
    const j = await r.json();
    return j.localId ?? `ERRO: ${JSON.stringify(j).slice(0, 220)}`;
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
  async function estados() {
    const out = [];
    for (const ctx of contexts) {
      for (const p of ctx.pages()) {
        const textos = (await p.locator('flt-semantics').allTextContents())
          .filter((t) => t.trim().length > 0)
          .slice(-3);
        const valores = [];
        for (const el of await p.locator('input').all()) valores.push(await el.inputValue());
        out.push({ url: p.url(), textos, valores });
      }
    }
    return out;
  }

  try {
    const browser = page.context().browser();
    const dp = await novoContexto(browser, 'motorista');
    const ap = await novoContexto(browser, 'aluno');

    // Etapa 1: cadastro e login do motorista com UID espelhado em usuarios/{uid}.
    await dp.getByText('Criar conta', { exact: true }).first().click();
    await waitText(dp, 'Escolha seu perfil');
    await dp.getByText('Sou motorista', { exact: false }).first().click();
    await input(dp, 0).waitFor({ state: 'visible' });
    await preencher(dp, 0, 'Motorista E2E');
    await preencher(dp, 1, DRIVER.email);
    await preencher(dp, 2, '(15) 99999-0001');
    await preencher(dp, 3, DRIVER.senha);
    await btn(dp, 'Criar conta de motorista').click();
    await btn(dp, 'Criar minha primeira van').waitFor({ state: 'visible', timeout: 30000 });

    const driverUid = await uidAuth(dp, DRIVER);
    const perfilMotorista = await doc(dp, `usuarios/${driverUid}`);
    passo(
      1,
      'Motorista cria conta e faz login',
      !driverUid.startsWith('ERRO') &&
        perfilMotorista?.fields?.perfil?.stringValue === 'motorista',
      `uid=${driverUid}; usuarios/{uid}=${textoDoc(perfilMotorista)?.slice(0, 220)}`,
    );

    // Etapa 2: criação da van e código de seis dígitos no Firestore.
    await btn(dp, 'Criar minha primeira van').click();
    await input(dp, 0).waitFor({ state: 'visible' });
    await preencher(dp, 0, 'Van E2E Integração');
    await preencher(dp, 1, 'Capão Bonito');
    await preencher(dp, 2, 'Itapetininga');
    await dp.getByRole('checkbox', { name: 'Manhã' }).first().click();
    await btn(dp, 'Criar van').click();
    await waitText(dp, 'Van E2E Integração', 30000);

    const grupos = await doc(dp, 'grupos');
    const grupoDoc = (grupos?.documents ?? []).find(
      (d) => d.fields?.motoristaId?.stringValue === driverUid,
    );
    const grupoId = grupoDoc?.name?.split('/').pop();
    const codigo = grupoDoc?.fields?.codigo?.stringValue;
    passo(
      2,
      'Motorista cria van e obtém código de 6 dígitos',
      Boolean(grupoId && /^\d{6}$/.test(codigo ?? '')),
      `grupo=${grupoId}; codigo=${codigo}; codigos/{codigo}=${textoDoc(await doc(dp, `codigos/${codigo}`))?.slice(0, 220)}`,
    );

    // Etapa 3: cadastro do aluno e acesso à Home sem grupo.
    await ap.getByText('Criar conta', { exact: true }).first().click();
    await waitText(ap, 'Escolha seu perfil');
    await ap.getByText('Sou aluno', { exact: false }).first().click();
    await input(ap, 0).waitFor({ state: 'visible' });
    await preencher(ap, 0, 'Aluno E2E');
    await preencher(ap, 1, ALUNO.email);
    await preencher(ap, 2, '(15) 99999-0002');
    await preencher(ap, 3, 'Rua E2E, 100');
    await preencher(ap, 4, ALUNO.senha);
    await btn(ap, 'Criar conta de aluno').click();
    await btn(ap, 'Entrar em um grupo').waitFor({ state: 'visible', timeout: 30000 });
    const alunoUid = await uidAuth(ap, ALUNO);
    const perfilAluno = await doc(ap, `usuarios/${alunoUid}`);
    const grupoDoAluno = perfilAluno?.fields?.grupoId?.stringValue ?? '';
    passo(
      3,
      'Aluno cria conta e acessa Home sem grupo',
      !alunoUid.startsWith('ERRO') &&
        grupoDoAluno === '' &&
        perfilAluno?.fields?.status?.stringValue === 'pendente',
      `uid=${alunoUid}; grupoId='${grupoDoAluno}'; perfil=${textoDoc(perfilAluno)?.slice(0, 260)}`,
    );

    // Etapas 4 e 5: código informado pelo aluno e van correta apresentada.
    await btn(ap, 'Entrar em um grupo').click();
    await input(ap, 0).waitFor({ state: 'visible' });
    await preencher(ap, 0, codigo);
    await btn(ap, 'Buscar Van').click();
    const cartaoVan = ap.getByRole('group', { name: /Van Encontrada/ }).first();
    await cartaoVan.waitFor({ state: 'visible', timeout: 25000 });
    const rotuloVan = await cartaoVan.getAttribute('aria-label');
    passo(4, 'Aluno insere o código', true, `codigo=${codigo}`);
    passo(
      5,
      'Aplicativo apresenta a van correta',
      (rotuloVan ?? '').includes('Van E2E Integração'),
      `aria-label do cartão=${(rotuloVan ?? '').slice(0, 240)}`,
    );

    // Etapa 6: solicitação de entrada persistida como pendente.
    await btn(ap, 'Solicitar entrada nesta van').click();
    await waitText(ap, 'Aguardando aprovação', 25000);
    const solicitacao = await doc(ap, `solicitacoes/${alunoUid}`);
    passo(
      6,
      'Aluno solicita entrada',
      solicitacao?.fields?.grupoId?.stringValue === grupoId &&
        solicitacao?.fields?.status?.stringValue === 'pendente',
      `solicitacoes/${alunoUid}=${textoDoc(solicitacao)?.slice(0, 260)}`,
    );

    // Etapa 7: refresh mantém a solicitação pendente.
    await ap.reload({ waitUntil: 'load' });
    await a11y(ap);
    await waitText(ap, 'Aguardando aprovação', 30000);
    const solicitacaoRefresh = await doc(ap, `solicitacoes/${alunoUid}`);
    passo(
      7,
      'Solicitação permanece pendente após refresh',
      solicitacaoRefresh?.fields?.status?.stringValue === 'pendente',
      `status após refresh=${solicitacaoRefresh?.fields?.status?.stringValue}`,
    );

    // Etapa 8: motorista visualiza a solicitação pendente.
    await dp.goto(`${BASE}#/driver/students`, { waitUntil: 'load' });
    await a11y(dp);
    const abaPendentes = dp.getByRole('tab', { name: /Pendentes \(1\)/ }).first();
    await abaPendentes.waitFor({ state: 'visible', timeout: 30000 });
    await abaPendentes.click();
    const botoesAprovar = dp.getByRole('button', { name: /Aprovar/ });
    const botaoAprovar = botoesAprovar.first();
    await botaoAprovar.waitFor({ state: 'visible', timeout: 20000 });
    const quantidadeAprovar = await botoesAprovar.count();
    passo(
      8,
      'Motorista visualiza a solicitação',
      (await botaoAprovar.isVisible()) &&
        quantidadeAprovar === 1 &&
        solicitacaoRefresh?.fields?.status?.stringValue === 'pendente',
      `botoesAprovar=${quantidadeAprovar}; solicitacao/${alunoUid}.status=${solicitacaoRefresh?.fields?.status?.stringValue}`,
    );

    // Etapa 9: aprovação atômica da solicitação e do vínculo do aluno.
    await botaoAprovar.click();
    const solicitacaoAprovada = await esperarDoc(
      dp,
      `solicitacoes/${alunoUid}`,
      (d) => d?.fields?.status?.stringValue === 'aprovado',
    );
    const perfilAprovado = await esperarDoc(
      dp,
      `usuarios/${alunoUid}`,
      (d) =>
        d?.fields?.status?.stringValue === 'ativo' &&
        d?.fields?.ativo?.booleanValue === true &&
        d?.fields?.grupoId?.stringValue === grupoId,
    );
    passo(
      9,
      'Motorista aprova a solicitação',
      solicitacaoAprovada?.fields?.status?.stringValue === 'aprovado' &&
        perfilAprovado?.fields?.status?.stringValue === 'ativo' &&
        perfilAprovado?.fields?.ativo?.booleanValue === true &&
        perfilAprovado?.fields?.grupoId?.stringValue === grupoId,
      `solicitacao=${solicitacaoAprovada?.fields?.status?.stringValue}; usuario=${textoDoc(perfilAprovado)?.slice(0, 300)}`,
    );

    // Etapa 10: refresh do aluno passa a mostrar o vínculo ativo.
    await ap.reload({ waitUntil: 'load' });
    await a11y(ap);
    await waitText(ap, 'Chamada de amanhã', 30000);
    const aindaAguardando = await ap.getByText('Aguardando aprovação', { exact: false }).count();
    const perfilAposAprovacao = await doc(ap, `usuarios/${alunoUid}`);
    passo(
      10,
      'Aluno atualiza e vê o vínculo ativo',
      aindaAguardando === 0 &&
        perfilAposAprovacao?.fields?.status?.stringValue === 'ativo' &&
        perfilAposAprovacao?.fields?.grupoId?.stringValue === grupoId,
      `aguardando=${aindaAguardando}; usuario=${textoDoc(perfilAposAprovacao)?.slice(0, 300)}`,
    );

    // Etapa 11: motorista abre a chamada da próxima viagem.
    await dp.goto(`${BASE}#/driver/home`, { waitUntil: 'load' });
    const abrirChamada = dp.getByRole('button', { name: /Abrir chamada de amanhã/ }).first();
    await abrirChamada.waitFor({ state: 'visible', timeout: 30000 });
    await abrirChamada.click();
    let listaChamadas = await esperarDoc(
      dp,
      'chamadas',
      (d) =>
        (d?.documents ?? []).some(
          (x) =>
            x.fields?.grupoId?.stringValue === grupoId &&
            x.fields?.status?.stringValue === 'aberta',
        ),
    );
    const chamadaDoc = (listaChamadas?.documents ?? []).find(
      (x) =>
        x.fields?.grupoId?.stringValue === grupoId &&
        x.fields?.status?.stringValue === 'aberta',
    );
    const chamadaId = chamadaDoc?.name?.split('/').pop();
    passo(
      11,
      'Motorista abre a chamada',
      Boolean(chamadaId) && chamadaDoc?.fields?.motoristaId?.stringValue === driverUid,
      `chamadas/${chamadaId}=${textoDoc(chamadaDoc)?.slice(0, 300)}`,
    );

    // Etapa 12: aluno responde ida e volta na chamada aberta.
    await ap.reload({ waitUntil: 'load' });
    await a11y(ap);
    const confirmarIda = ap.getByRole('button', { name: /confirmar ida/ }).first();
    await confirmarIda.waitFor({ state: 'visible', timeout: 30000 });
    await confirmarIda.click();
    const respostaIda = await esperarDoc(
      ap,
      `respostas/${chamadaId}_${alunoUid}`,
      (d) => d?.fields?.ida?.stringValue === 'vai',
    );
    const confirmarVolta = ap.getByRole('button', { name: /confirmar volta/ }).first();
    await confirmarVolta.waitFor({ state: 'visible', timeout: 20000 });
    await confirmarVolta.click();
    const respostaFinal = await esperarDoc(
      ap,
      `respostas/${chamadaId}_${alunoUid}`,
      (d) => d?.fields?.ida?.stringValue === 'vai' && d?.fields?.volta?.stringValue === 'vai',
    );
    passo(
      12,
      'Aluno responde ida e volta',
      respostaIda?.fields?.ida?.stringValue === 'vai' &&
        respostaFinal?.fields?.volta?.stringValue === 'vai' &&
        respostaFinal?.fields?.alunoId?.stringValue === alunoUid &&
        respostaFinal?.fields?.chamadaId?.stringValue === chamadaId,
      `respostas/${chamadaId}_${alunoUid}=${textoDoc(respostaFinal)?.slice(0, 320)}`,
    );

    // Etapa 13: motorista encerra a chamada.
    const encerrarChamada = dp.getByRole('button', { name: /Encerrar chamada/ }).first();
    await encerrarChamada.waitFor({ state: 'visible', timeout: 30000 });
    await encerrarChamada.click();
    const chamadaEncerrada = await esperarDoc(
      dp,
      `chamadas/${chamadaId}`,
      (d) => d?.fields?.status?.stringValue === 'encerrada',
    );
    passo(
      13,
      'Motorista encerra a chamada',
      chamadaEncerrada?.fields?.status?.stringValue === 'encerrada' &&
        Boolean(chamadaEncerrada?.fields?.encerradaEm?.timestampValue),
      `chamadas/${chamadaId}.status=${chamadaEncerrada?.fields?.status?.stringValue}`,
    );

    // Etapa 14: conferência final dos documentos no Firestore Emulator.
    const [perfilFinal, solicitacaoFinal, grupoFinal, codigoFinal, chamadaVerificada, respostaVerificada] =
      await Promise.all([
        doc(dp, `usuarios/${alunoUid}`),
        doc(dp, `solicitacoes/${alunoUid}`),
        doc(dp, `grupos/${grupoId}`),
        doc(dp, `codigos/${codigo}`),
        doc(dp, `chamadas/${chamadaId}`),
        doc(dp, `respostas/${chamadaId}_${alunoUid}`),
      ]);
    const verificado =
      perfilFinal?.fields?.perfil?.stringValue === 'aluno' &&
      perfilFinal?.fields?.status?.stringValue === 'ativo' &&
      perfilFinal?.fields?.ativo?.booleanValue === true &&
      perfilFinal?.fields?.grupoId?.stringValue === grupoId &&
      solicitacaoFinal?.fields?.status?.stringValue === 'aprovado' &&
      solicitacaoFinal?.fields?.grupoId?.stringValue === grupoId &&
      grupoFinal?.fields?.motoristaId?.stringValue === driverUid &&
      grupoFinal?.fields?.codigo?.stringValue === codigo &&
      codigoFinal?.fields?.grupoId?.stringValue === grupoId &&
      chamadaVerificada?.fields?.status?.stringValue === 'encerrada' &&
      respostaVerificada?.fields?.ida?.stringValue === 'vai' &&
      respostaVerificada?.fields?.volta?.stringValue === 'vai' &&
      respostaVerificada?.fields?.grupoId?.stringValue === grupoId;
    passo(
      14,
      'Documentos finais conferidos no Firestore',
      verificado,
      `usuario=${perfilFinal?.fields?.status?.stringValue}/${perfilFinal?.fields?.grupoId?.stringValue}; solicitacao=${solicitacaoFinal?.fields?.status?.stringValue}; grupo=${grupoFinal?.fields?.codigo?.stringValue}; chamada=${chamadaVerificada?.fields?.status?.stringValue}; resposta=${respostaVerificada?.fields?.ida?.stringValue}/${respostaVerificada?.fields?.volta?.stringValue}`,
    );

    return {
      ok: results.every((r) => r.ok),
      sufixo,
      contextoMotorista: 'isolado',
      contextoAluno: 'isolado',
      ids: { driverUid, alunoUid, grupoId, codigo, chamadaId },
      emails: DRIVER.email + ' | ' + ALUNO.email,
      results,
      erros: erros.filter((e) => !e.includes('favicon')),
    };
  } catch (error) {
    return { falhou: String(error?.stack ?? error), results, erros, estados: await estados() };
  } finally {
    for (const ctx of contexts) {
      try { await ctx.close(); } catch (_) {}
    }
  }
}
