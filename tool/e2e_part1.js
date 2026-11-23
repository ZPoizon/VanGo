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
  // O Flutter web duplica nós de semântica (inclusive alguns fora da tela).
  // Usar somente .first().waitFor('visible') pode selecionar um nó oculto e
  // expirar mesmo com o texto correto na árvore de acessibilidade.
  async function waitText(p, texto, timeout = 25000) {
    const limite = Date.now() + timeout;
    while (Date.now() < limite) {
      const visiveis = p.getByText(texto, { exact: false });
      if ((await visiveis.count()) > 0) {
        try {
          await visiveis.first().waitFor({ state: 'visible', timeout: 800 });
          return;
        } catch (_) {
          // tenta os demais nós e, em seguida, a árvore de semântica
        }
      }
      const semantica = (await p.locator('flt-semantics').allTextContents()).join('\n');
      if (semantica.includes(texto)) return;
      await p.waitForTimeout(250);
    }
    throw new Error(`Texto não apareceu: ${texto}`);
  }
  const btn = (p, nome) => p.getByRole('button', { name: nome, exact: false }).first();
  const btnUltimo = (p, nome) => p.getByRole('button', { name: nome, exact: false }).last();
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
  async function viagensDaChamada(p, id) {
    const lista = await doc(p, 'viagens');
    return (lista?.documents ?? []).filter(
      (d) => d.fields?.chamadaId?.stringValue === id,
    );
  }
  async function esperarViagem(p, chamadaId, condicao, timeout = 20000) {
    const limite = Date.now() + timeout;
    let ultimos = [];
    while (Date.now() < limite) {
      ultimos = await viagensDaChamada(p, chamadaId);
      if (ultimos.some(condicao)) return ultimos;
      await p.waitForTimeout(300);
    }
    return ultimos;
  }
  async function entrar(p, conta, textoEsperado) {
    await input(p, 0).waitFor({ state: 'visible', timeout: 30000 });
    await preencher(p, 0, conta.email);
    await preencher(p, 1, conta.senha);
    await btn(p, 'Entrar').click();
    await waitText(p, textoEsperado, 30000);
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
    await preencher(dp, 4, DRIVER.senha); // confirmação de senha (Fase 1)
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
    await dp.getByText('Manhã', { exact: true }).first().click();
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
    await preencher(ap, 3, 'Fatec E2E');
    await preencher(ap, 4, 'Rua E2E, 100');
    await preencher(ap, 5, '18270-000'); // CEP obrigatório (Fase 1)
    await preencher(ap, 6, ALUNO.senha);
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

    // ---------------- Fase 4: conclusão, cancelamento e histórico ----------------

    // 15: chamada encerrada bloqueia qualquer alteração de resposta do aluno.
    await ap.reload({ waitUntil: 'load' });
    await a11y(ap);
    const avisoBloqueio = await ap
      .getByText('Respostas bloqueadas', { exact: false })
      .count();
    const respostaAntesBloqueio = await doc(ap, `respostas/${chamadaId}_${alunoUid}`);
    try {
      await ap.getByRole('button', { name: /confirmar ida/ }).first().click({ timeout: 1500 });
    } catch (_) {}
    const respostaDepoisBloqueio = await doc(ap, `respostas/${chamadaId}_${alunoUid}`);
    passo(
      15,
      'Fase 4: chamada encerrada bloqueia alteração do aluno',
      textoDoc(respostaAntesBloqueio) === textoDoc(respostaDepoisBloqueio) &&
        respostaDepoisBloqueio?.fields?.ida?.stringValue === 'vai' &&
        respostaDepoisBloqueio?.fields?.volta?.stringValue === 'vai',
      `resposta=${textoDoc(respostaDepoisBloqueio)?.slice(0, 260)}; avisoUI=${avisoBloqueio}`,
    );

    // 16: início da ida.
    const iniciarIda = btn(dp, 'Iniciar IDA');
    await iniciarIda.waitFor({ state: 'visible', timeout: 30000 });
    await iniciarIda.click();
    await btnUltimo(dp, 'Iniciar IDA').click();
    const viagensComIda = await esperarViagem(
      dp,
      chamadaId,
      (d) =>
        d?.fields?.sentido?.stringValue === 'ida' &&
        ['emAndamento', 'em_andamento'].includes(d?.fields?.status?.stringValue),
    );
    const viagemIda = viagensComIda.find(
      (d) =>
        d?.fields?.sentido?.stringValue === 'ida' &&
        ['emAndamento', 'em_andamento'].includes(d?.fields?.status?.stringValue),
    );
    const viagemIdaId = viagemIda?.name?.split('/').pop();
    passo(
      16,
      'Fase 4: motorista inicia a viagem de ida',
      Boolean(viagemIdaId) &&
        viagemIda?.fields?.motoristaId?.stringValue === driverUid &&
        viagemIda?.fields?.grupoId?.stringValue === grupoId,
      `viagem=${viagemIdaId}; status=${viagemIda?.fields?.status?.stringValue}`,
    );

    // 17: conclusão positiva da ida (antes gravava status inválido e falhava).
    await waitText(dp, 'Concluir viagem', 30000);
    await btn(dp, 'Concluir viagem').click();
    await btnUltimo(dp, 'Concluir viagem').click();
    const idaConcluida = await esperarViagem(
      dp,
      chamadaId,
      (d) =>
        d?.name?.endsWith(`/${viagemIdaId}`) &&
        d?.fields?.status?.stringValue === 'finalizada',
    ).then((lista) => lista.find((d) => d?.name?.endsWith(`/${viagemIdaId}`)));
    await waitText(dp, 'Iniciar VOLTA', 30000);
    passo(
      17,
      'Fase 4: motorista conclui a ida com status finalizada',
      idaConcluida?.fields?.status?.stringValue === 'finalizada' &&
        Boolean(idaConcluida?.fields?.encerradaEm?.timestampValue),
      `viagens/${viagemIdaId}=${textoDoc(idaConcluida)?.slice(0, 280)}`,
    );

    // 18: histórico da ida no app e no Firestore.
    await dp.goto(`${BASE}#/driver/history`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, ' · IDA', 30000);
    const concluidasAposIda = await dp.getByText('Concluída', { exact: false }).count();
    passo(
      18,
      'Fase 4: ida concluída aparece no histórico',
      concluidasAposIda >= 1 &&
        idaConcluida?.fields?.status?.stringValue === 'finalizada',
      `chips Concluída=${concluidasAposIda}; viagem=${viagemIdaId}`,
    );

    // 19: aluno também vê a conclusão da ida.
    await ap.reload({ waitUntil: 'load' });
    await a11y(ap);
    await waitText(ap, 'Viagem de ida concluída com sucesso', 30000);
    passo(
      19,
      'Fase 4: aluno vê a ida concluída com sucesso',
      (await ap.getByText('Viagem de ida concluída com sucesso', { exact: false }).count()) > 0,
      'cartão de conclusão da ida visível na Home do aluno',
    );

    // 20: início da volta depois da ida concluída.
    await dp.goto(`${BASE}#/driver/home`, { waitUntil: 'load' });
    await a11y(dp);
    const iniciarVolta = btn(dp, 'Iniciar VOLTA');
    await iniciarVolta.waitFor({ state: 'visible', timeout: 30000 });
    await iniciarVolta.click();
    await btnUltimo(dp, 'Iniciar VOLTA').click();
    const viagensComVolta = await esperarViagem(
      dp,
      chamadaId,
      (d) =>
        d?.fields?.sentido?.stringValue === 'volta' &&
        ['emAndamento', 'em_andamento'].includes(d?.fields?.status?.stringValue),
    );
    const viagemVolta = viagensComVolta.find(
      (d) =>
        d?.fields?.sentido?.stringValue === 'volta' &&
        ['emAndamento', 'em_andamento'].includes(d?.fields?.status?.stringValue),
    );
    const viagemVoltaId = viagemVolta?.name?.split('/').pop();
    passo(
      20,
      'Fase 4: motorista inicia a volta após a ida',
      Boolean(viagemVoltaId) &&
        viagemVolta?.fields?.chamadaId?.stringValue === chamadaId,
      `viagem=${viagemVoltaId}; status=${viagemVolta?.fields?.status?.stringValue}`,
    );

    // 21: conclusão da volta e liberação de nova chamada.
    await btn(dp, 'Concluir viagem').waitFor({ state: 'visible', timeout: 30000 });
    await btn(dp, 'Concluir viagem').click();
    await btnUltimo(dp, 'Concluir viagem').click();
    const voltaConcluida = await esperarViagem(
      dp,
      chamadaId,
      (d) =>
        d?.name?.endsWith(`/${viagemVoltaId}`) &&
        d?.fields?.status?.stringValue === 'finalizada',
    ).then((lista) => lista.find((d) => d?.name?.endsWith(`/${viagemVoltaId}`)));
    await waitText(dp, 'Operação concluída com sucesso', 30000);
    passo(
      21,
      'Fase 4: motorista conclui a volta com sucesso',
      voltaConcluida?.fields?.status?.stringValue === 'finalizada' &&
        Boolean(voltaConcluida?.fields?.encerradaEm?.timestampValue),
      `viagens/${viagemVoltaId}=${textoDoc(voltaConcluida)?.slice(0, 280)}`,
    );

    // 22: histórico da volta e aviso correspondente no aluno.
    await dp.goto(`${BASE}#/driver/history`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, ' · VOLTA', 30000);
    const concluidasAposVolta = await dp.getByText('Concluída', { exact: false }).count();
    const viagensFinais = await viagensDaChamada(dp, chamadaId);
    const finalizadas = viagensFinais.filter(
      (d) => d?.fields?.status?.stringValue === 'finalizada',
    );
    await ap.reload({ waitUntil: 'load' });
    await a11y(ap);
    await waitText(ap, 'Viagem de volta concluída com sucesso', 30000);
    passo(
      22,
      'Fase 4: ida e volta permanecem no histórico',
      concluidasAposVolta >= 2 &&
        finalizadas.length === 2 &&
        finalizadas.some((d) => d.fields?.sentido?.stringValue === 'ida') &&
        finalizadas.some((d) => d.fields?.sentido?.stringValue === 'volta'),
      `chips Concluída=${concluidasAposVolta}; finalizadas=${finalizadas.length}`,
    );

    // 23: nova chamada liberada após a volta concluída.
    await dp.goto(`${BASE}#/driver/home`, { waitUntil: 'load' });
    await a11y(dp);
    await btn(dp, 'Abrir chamada de amanhã').waitFor({ state: 'visible', timeout: 30000 });
    await btn(dp, 'Abrir chamada de amanhã').click();
    const chamadasAposVolta = await esperarDoc(
      dp,
      'chamadas',
      (d) =>
        (d?.documents ?? []).some(
          (x) =>
            x.fields?.grupoId?.stringValue === grupoId &&
            x.fields?.status?.stringValue === 'aberta' &&
            !x.name?.endsWith(`/${chamadaId}`),
        ),
    );
    const chamadaCancelavel = (chamadasAposVolta?.documents ?? []).find(
      (x) =>
        x.fields?.grupoId?.stringValue === grupoId &&
        x.fields?.status?.stringValue === 'aberta' &&
        !x.name?.endsWith(`/${chamadaId}`),
    );
    const chamadaCancelavelId = chamadaCancelavel?.name?.split('/').pop();
    passo(
      23,
      'Fase 4: nova chamada pode ser aberta após a volta',
      Boolean(chamadaCancelavelId),
      `chamadas/${chamadaCancelavelId}=${textoDoc(chamadaCancelavel)?.slice(0, 260)}`,
    );

    // 24: cancelamento da chamada com motivo opcional e aviso ao aluno.
    await ap.reload({ waitUntil: 'load' });
    await a11y(ap);
    await btn(dp, 'Cancelar chamada').waitFor({ state: 'visible', timeout: 30000 });
    await btn(dp, 'Cancelar chamada').click();
    const motivoChamada = 'Imprevisto E2E';
    await campo(dp, 'Motivo do cancelamento').last().fill(motivoChamada);
    await btnUltimo(dp, 'Cancelar chamada').click();
    const chamadaCancelada = await esperarDoc(
      dp,
      `chamadas/${chamadaCancelavelId}`,
      (d) =>
        d?.fields?.status?.stringValue === 'cancelada' &&
        Boolean(d?.fields?.canceladaEm?.timestampValue),
    );
    await waitText(ap, 'A chamada de amanhã foi cancelada pelo motorista.', 30000);
    passo(
      24,
      'Fase 4: motorista cancela a chamada com motivo',
      chamadaCancelada?.fields?.status?.stringValue === 'cancelada' &&
        chamadaCancelada?.fields?.motivoCancelamento?.stringValue === motivoChamada,
      `chamadas/${chamadaCancelavelId}=${textoDoc(chamadaCancelada)?.slice(0, 300)}`,
    );

    // 25: cancelamento persiste após refresh nas duas sessões.
    // O refresh do motorista entra pelo dashboard (regra da Fase 3), então
    // voltamos ao painel operacional antes de validar o cartão da chamada.
    await dp.reload({ waitUntil: 'load' });
    await a11y(dp);
    // Aguarda o dashboard carregar a van antes de voltar ao painel: um goto
    // durante a restauração da sessão é redirecionado de volta ao dashboard.
    await waitText(dp, 'RESUMO', 30000);
    await dp.goto(`${BASE}#/driver/home`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, 'Chamada cancelada', 30000);
    await ap.reload({ waitUntil: 'load' });
    await a11y(ap);
    await waitText(ap, 'A chamada de amanhã foi cancelada pelo motorista.', 30000);
    const canceladaAposRefresh = await doc(dp, `chamadas/${chamadaCancelavelId}`);
    passo(
      25,
      'Fase 4: cancelamento da chamada persiste após refresh',
      canceladaAposRefresh?.fields?.status?.stringValue === 'cancelada' &&
        canceladaAposRefresh?.fields?.motivoCancelamento?.stringValue === motivoChamada,
      `status=${canceladaAposRefresh?.fields?.status?.stringValue}; motivo=${canceladaAposRefresh?.fields?.motivoCancelamento?.stringValue}`,
    );

    // 26: terceira chamada para testar cancelamento de viagem em andamento.
    await btn(dp, 'Abrir chamada de amanhã').click();
    const chamadasTeste = await esperarDoc(
      dp,
      'chamadas',
      (d) =>
        (d?.documents ?? []).some(
          (x) =>
            x.fields?.grupoId?.stringValue === grupoId &&
            x.fields?.status?.stringValue === 'aberta' &&
            !x.name?.endsWith(`/${chamadaId}`) &&
            !x.name?.endsWith(`/${chamadaCancelavelId}`),
        ),
    );
    const chamadaTeste = (chamadasTeste?.documents ?? []).find(
      (x) =>
        x.fields?.grupoId?.stringValue === grupoId &&
        x.fields?.status?.stringValue === 'aberta' &&
        !x.name?.endsWith(`/${chamadaId}`) &&
        !x.name?.endsWith(`/${chamadaCancelavelId}`),
    );
    const chamadaTesteId = chamadaTeste?.name?.split('/').pop();
    await btn(dp, 'Encerrar chamada').waitFor({ state: 'visible', timeout: 30000 });
    await btn(dp, 'Encerrar chamada').click();
    await btn(dp, 'Iniciar IDA').waitFor({ state: 'visible', timeout: 30000 });
    await btn(dp, 'Iniciar IDA').click();
    await btnUltimo(dp, 'Iniciar IDA').click();
    const viagensTeste = await esperarViagem(
      dp,
      chamadaTesteId,
      (d) => ['emAndamento', 'em_andamento'].includes(d?.fields?.status?.stringValue),
    );
    const viagemTeste = viagensTeste.find(
      (d) => ['emAndamento', 'em_andamento'].includes(d?.fields?.status?.stringValue),
    );
    const viagemTesteId = viagemTeste?.name?.split('/').pop();
    passo(
      26,
      'Fase 4: viagem de teste inicia para cancelamento',
      Boolean(chamadaTesteId && viagemTesteId),
      `chamada=${chamadaTesteId}; viagem=${viagemTesteId}`,
    );

    // 27: cancelamento separado da conclusão, com data e motivo.
    const motivoViagem = 'Teste de cancelamento';
    await btn(dp, 'Cancelar viagem').click();
    await campo(dp, 'Motivo do cancelamento').last().fill(motivoViagem);
    await btnUltimo(dp, 'Cancelar viagem').click();
    const viagemCancelada = await esperarDoc(
      dp,
      `viagens/${viagemTesteId}`,
      (d) =>
        d?.fields?.status?.stringValue === 'cancelada' &&
        Boolean(d?.fields?.canceladaEm?.timestampValue),
    );
    passo(
      27,
      'Fase 4: viagem em andamento é cancelada com motivo',
      viagemCancelada?.fields?.status?.stringValue === 'cancelada' &&
        viagemCancelada?.fields?.motivoCancelamento?.stringValue === motivoViagem,
      `viagens/${viagemTesteId}=${textoDoc(viagemCancelada)?.slice(0, 300)}`,
    );

    // 28: viagem cancelada não aparece como concluída.
    await waitText(dp, 'Viagem cancelada', 30000);
    const viagensDaTeste = await viagensDaChamada(dp, chamadaTesteId);
    const canceladasDaTeste = viagensDaTeste.filter(
      (d) => d?.fields?.status?.stringValue === 'cancelada',
    );
    const finalizadasDaTeste = viagensDaTeste.filter(
      (d) => d?.fields?.status?.stringValue === 'finalizada',
    );
    const painelConcluido = await dp
      .getByText('Operação concluída com sucesso', { exact: false })
      .count();
    passo(
      28,
      'Fase 4: viagem cancelada não aparece como concluída',
      canceladasDaTeste.length === 1 &&
        finalizadasDaTeste.length === 0 &&
        painelConcluido === 0,
      `canceladas=${canceladasDaTeste.length}; finalizadas=${finalizadasDaTeste.length}; avisoConcluido=${painelConcluido}`,
    );

    // 29: refresh e novo login confirmam os históricos nas duas sessões.
    await dp.reload({ waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, 'RESUMO', 30000);
    await dp.goto(`${BASE}#/driver/home`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, 'Viagem cancelada', 30000);
    await dp.goto(`${BASE}#/driver/history`, { waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, ' · VOLTA', 30000);
    const historicoMotorista = {
      concluidas: await dp.getByText('Concluída', { exact: false }).count(),
      canceladas: await dp.getByText('Cancelada', { exact: false }).count(),
    };

    const ndp = await novoContexto(browser, 'motorista-novo-login');
    await entrar(ndp, DRIVER, 'VanGo · conectado ao Firebase');
    await ndp.goto(`${BASE}#/driver/history`, { waitUntil: 'load' });
    await a11y(ndp);
    await waitText(ndp, ' · VOLTA', 30000);
    const historicoNovoLogin = {
      concluidas: await ndp.getByText('Concluída', { exact: false }).count(),
      canceladas: await ndp.getByText('Cancelada', { exact: false }).count(),
    };

    const nap = await novoContexto(browser, 'aluno-novo-login');
    await entrar(nap, ALUNO, 'Meu padrão semanal');
    await waitText(nap, 'Viagem de ida cancelada', 30000);
    const viagensFinaisEmulator = await viagensDaChamada(ndp, chamadaId);
    const finalizadasNovoLogin = viagensFinaisEmulator.filter(
      (d) => d?.fields?.status?.stringValue === 'finalizada',
    );
    passo(
      29,
      'Fase 4: refresh e novo login preservam os históricos',
      historicoMotorista.concluidas >= 2 &&
        historicoMotorista.canceladas >= 1 &&
        historicoNovoLogin.concluidas >= 2 &&
        historicoNovoLogin.canceladas >= 1 &&
        finalizadasNovoLogin.length === 2,
      `motorista=${JSON.stringify(historicoMotorista)}; novoLogin=${JSON.stringify(historicoNovoLogin)}; finalizadasFirestore=${finalizadasNovoLogin.length}`,
    );

    return {
      ok: results.every((r) => r.ok),
      sufixo,
      contextoMotorista: 'isolado',
      contextoAluno: 'isolado',
      ids: {
        driverUid,
        alunoUid,
        grupoId,
        codigo,
        chamadaId,
        viagemIdaId,
        viagemVoltaId,
        chamadaCancelavelId,
        chamadaTesteId,
        viagemTesteId,
      },
      emails: DRIVER.email + ' | ' + ALUNO.email,
      total: results.length,
      resumo: results.map((r) => `${r.n}:${r.ok ? 'OK' : 'FALHA'}`).join(' '),
      falhas: results.filter((r) => !r.ok),
      erros: erros.filter((e) => !e.includes('favicon')).slice(0, 12),
    };
  } catch (error) {
    const estadosAtuais = await estados();
    return {
      // Diagnóstico primeiro: a saída do console pode truncar o final.
      estadosResumo: estadosAtuais.map((e) => ({
        url: e.url,
        texto: e.textos?.join(' | ').slice(0, 500),
        valores: e.valores,
      })),
      falhou: String(error?.stack ?? error),
      results,
      erros,
      estados: estadosAtuais,
    };
  } finally {
    for (const ctx of contexts) {
      try { await ctx.close(); } catch (_) {}
    }
  }
}
