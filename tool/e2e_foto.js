async (page) => {
  const BASE = 'http://127.0.0.1:7358/';
  const KEY = 'AIzaSyB82GT3m_AqHCFMmRl8z0avk9IE6FkxjvI';
  const FIRE = 'http://127.0.0.1:8080/v1/projects/demo-vango/databases/(default)/documents';
  const STORAGE = 'http://127.0.0.1:9199/v0/b/demo-vango.appspot.com/o';
  const ADMIN = { Authorization: 'Bearer owner' };
  const sufixo = String(Date.now()).slice(-8);
  const DRIVER = { email: `e2e.foto.motorista.${sufixo}@vango.test`, senha: 'Senha@123' };
  const ALUNO = { email: `e2e.foto.aluno.${sufixo}@vango.test`, senha: 'Senha@123' };
  const results = [];
  const erros = [];
  const logs = [];
  const contexts = [];

  const passo = (n, descricao, ok, detalhe) =>
    results.push({ n, descricao, ok: Boolean(ok), detalhe });

  async function waitText(p, texto, timeout = 30000) {
    const limite = Date.now() + timeout;
    while (Date.now() < limite) {
      const visiveis = p.getByText(texto, { exact: false });
      if ((await visiveis.count()) > 0) {
        try {
          await visiveis.first().waitFor({ state: 'visible', timeout: 700 });
          return;
        } catch (_) {}
      }
      const semantica = (await p.locator('flt-semantics').allTextContents()).join('\n');
      if (semantica.includes(texto)) return;
      await p.waitForTimeout(250);
    }
    throw new Error(`Texto não apareceu: ${texto}`);
  }
  const btn = (p, nome) => p.getByRole('button', { name: nome, exact: false }).first();
  const input = (p, indice) => p.locator('input').nth(indice);
  async function preencher(p, indice, valor) {
    const el = input(p, indice);
    for (let tentativa = 0; tentativa < 3; tentativa++) {
      await el.fill('');
      await p.waitForTimeout(50);
      await el.pressSequentially(valor, { delay: 12 });
      await p.waitForTimeout(120);
      if ((await el.inputValue()) === valor) return;
    }
    throw new Error(`Campo ${indice} não aceitou o valor esperado`);
  }
  async function a11y(p) {
    const placeholder = p.locator('flt-semantics-placeholder');
    const semantica = p.locator('flt-semantics');
    for (let i = 0; i < 100; i++) {
      if ((await placeholder.count()) > 0 || (await semantica.count()) > 0) break;
      await p.waitForTimeout(100);
    }
    if ((await placeholder.count()) === 0) return;
    await placeholder.evaluate((el) => { el.focus(); el.click(); });
  }
  async function novoContexto(browser, nome) {
    const ctx = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
    contexts.push(ctx);
    const p = await ctx.newPage();
    p.on('pageerror', (e) => erros.push(`${nome}: pageerror: ${e.message}`));
    p.on('console', (m) => {
      const texto = m.text();
      if (texto.includes('[Storage]') || texto.includes('[Firestore]')) {
        logs.push(`${nome}: ${texto.slice(0, 240)}`);
      }
      if (m.type() === 'error') erros.push(`${nome}: console: ${texto.slice(0, 240)}`);
    });
    await p.goto(BASE, { waitUntil: 'load' });
    await a11y(p);
    await input(p, 0).waitFor({ state: 'visible', timeout: 30000 });
    return p;
  }
  async function entrar(p, conta) {
    await input(p, 0).waitFor({ state: 'visible', timeout: 30000 });
    await preencher(p, 0, conta.email);
    await preencher(p, 1, conta.senha);
    await btn(p, 'Entrar').click();
    await waitText(p, 'VanGo · conectado ao Firebase', 30000);
  }
  async function uidAuth(p, conta) {
    const r = await p.request.post(
      `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${KEY}`,
      { data: { email: conta.email, password: conta.senha, returnSecureToken: true } },
    );
    const j = await r.json();
    if (!j.localId) throw new Error(`Auth: ${JSON.stringify(j).slice(0, 240)}`);
    return { uid: j.localId, token: j.idToken };
  }
  const doc = async (p, caminho) => {
    const r = await p.request.get(`${FIRE}/${caminho}`, { headers: ADMIN });
    return r.ok() ? await r.json() : null;
  };
  async function esperarFoto(p, uid, condicao, timeout = 20000) {
    const limite = Date.now() + timeout;
    let ultimo = null;
    while (Date.now() < limite) {
      ultimo = await doc(p, `usuarios/${uid}`);
      if (condicao(ultimo?.fields?.fotoUrl?.stringValue ?? null)) return ultimo;
      await p.waitForTimeout(250);
    }
    return ultimo;
  }
  async function esperarStorageApagado(p, url, timeout = 10000) {
    const limite = Date.now() + timeout;
    let resposta = null;
    while (Date.now() < limite) {
      resposta = await p.request.get(url);
      if (resposta.status() >= 400) return resposta;
      await p.waitForTimeout(250);
    }
    return resposta;
  }
  async function abrirPerfil(p, rota) {
    await p.goto(`${BASE}#/${rota}/profile`, { waitUntil: 'load' });
    await a11y(p);
    await waitText(p, 'Alterar foto', 30000);
  }
  async function escolherArquivo(p, buffer, nome = 'foto.png') {
    const escolha = p.waitForEvent('filechooser', { timeout: 15000 });
    await btn(p, 'Escolher da galeria').click();
    const fc = await escolha;
    await fc.setFiles({ name: nome, mimeType: 'image/png', buffer });
  }

  // PNGs 1x1 válidos, embutidos para não depender de arquivos externos.
  const VERMELHO = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4AWO5I6fBgA2wYBUdtBIA79gBQyUaZ+kAAAAASUVORK5CYII=',
    'base64',
  );
  const AZUL = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4AWORC7jDgA2wYBUdtBIADWUBa/xEKsoAAAAASUVORK5CYII=',
    'base64',
  );

  try {
    const browser = page.context().browser();
    const dp = await novoContexto(browser, 'motorista');
    const ap = await novoContexto(browser, 'aluno');

    // Cadastro das contas sintéticas.
    await dp.getByText('Criar conta', { exact: true }).first().click();
    await waitText(dp, 'Escolha seu perfil');
    await dp.getByText('Sou motorista', { exact: false }).first().click();
    await input(dp, 0).waitFor({ state: 'visible' });
    await preencher(dp, 0, 'Motorista Foto');
    await preencher(dp, 1, DRIVER.email);
    await preencher(dp, 2, '(15) 99999-1001');
    await preencher(dp, 3, DRIVER.senha);
    await preencher(dp, 4, DRIVER.senha);
    await btn(dp, 'Criar conta de motorista').click();
    await waitText(dp, 'VanGo · conectado ao Firebase', 30000);
    const motorista = await uidAuth(dp, DRIVER);

    await ap.getByText('Criar conta', { exact: true }).first().click();
    await waitText(ap, 'Escolha seu perfil');
    await ap.getByText('Sou aluno', { exact: false }).first().click();
    await input(ap, 0).waitFor({ state: 'visible' });
    await preencher(ap, 0, 'Aluno Foto');
    await preencher(ap, 1, ALUNO.email);
    await preencher(ap, 2, '(15) 99999-1002');
    await preencher(ap, 3, 'Fatec Foto');
    await preencher(ap, 4, 'Rua Foto, 10');
    await preencher(ap, 5, '18270-000');
    await preencher(ap, 6, ALUNO.senha);
    await btn(ap, 'Criar conta de aluno').click();
    await waitText(ap, 'VanGo · conectado ao Firebase', 30000);
    const aluno = await uidAuth(ap, ALUNO);
    passo(1, 'Contas sintéticas de motorista e aluno', true,
      `${DRIVER.email} / ${ALUNO.email}`);

    // Motorista: selecionar → prévia → salvar.
    await abrirPerfil(dp, 'driver');
    await btn(dp, 'Alterar foto').click();
    await waitText(dp, 'Escolher da galeria');
    await escolherArquivo(dp, VERMELHO);
    await waitText(dp, 'Prévia da nova foto');
    await waitText(dp, 'Salvar foto');
    await btn(dp, 'Salvar foto').click();
    let perfil = await esperarFoto(dp, motorista.uid, (url) => Boolean(url));
    const url1 = perfil?.fields?.fotoUrl?.stringValue ?? '';
    let respostaStorage = url1 ? await dp.request.get(url1) : null;
    passo(2, 'Motorista seleciona, visualiza e salva a foto', Boolean(url1) && respostaStorage?.ok(),
      `fotoUrl=${url1 ? 'presente' : 'ausente'}; storage=${respostaStorage?.status()}`);

    // Persistência após refresh e novo login.
    await dp.reload({ waitUntil: 'load' });
    await a11y(dp);
    await waitText(dp, 'VanGo · conectado ao Firebase', 30000);
    await abrirPerfil(dp, 'driver');
    perfil = await doc(dp, `usuarios/${motorista.uid}`);
    passo(3, 'Foto persiste após refresh', perfil?.fields?.fotoUrl?.stringValue === url1,
      `fotoUrl igual=${perfil?.fields?.fotoUrl?.stringValue === url1}`);

    await btn(dp, 'Sair da conta').click();
    await input(dp, 0).waitFor({ state: 'visible', timeout: 30000 });
    await entrar(dp, DRIVER);
    await abrirPerfil(dp, 'driver');
    perfil = await doc(dp, `usuarios/${motorista.uid}`);
    passo(4, 'Foto persiste após novo login', perfil?.fields?.fotoUrl?.stringValue === url1,
      `fotoUrl igual=${perfil?.fields?.fotoUrl?.stringValue === url1}`);

    // Substituição.
    await btn(dp, 'Alterar foto').click();
    await waitText(dp, 'Escolher da galeria');
    await escolherArquivo(dp, AZUL, 'nova.png');
    await waitText(dp, 'Prévia da nova foto');
    await btn(dp, 'Salvar foto').click();
    perfil = await esperarFoto(dp, motorista.uid, (url) => Boolean(url && url !== url1));
    const url2 = perfil?.fields?.fotoUrl?.stringValue ?? '';
    passo(5, 'Motorista substitui a foto', Boolean(url2 && url2 !== url1),
      `trocou=${Boolean(url2 && url2 !== url1)}`);

    // Remoção com confirmação.
    await btn(dp, 'Alterar foto').click();
    await waitText(dp, 'Remover foto');
    await btn(dp, 'Remover foto').click();
    await waitText(dp, 'Remover foto?');
    await btn(dp, 'Remover').last().click();
    perfil = await esperarFoto(dp, motorista.uid, (url) => url === null);
    const apagado = await esperarStorageApagado(dp, url2);
    passo(6, 'Motorista remove a foto e limpa o arquivo',
      (perfil?.fields?.fotoUrl === undefined || perfil?.fields?.fotoUrl?.nullValue !== undefined) &&
        apagado.status() >= 400,
      `fotoUrl=${JSON.stringify(perfil?.fields?.fotoUrl ?? null)}; storage apos remocao=${apagado.status()}`);

    // Aluno: salva foto própria em caminho vinculado ao UID.
    await abrirPerfil(ap, 'student');
    await btn(ap, 'Alterar foto').click();
    await waitText(ap, 'Escolher da galeria');
    await escolherArquivo(ap, VERMELHO);
    await waitText(ap, 'Prévia da nova foto');
    await btn(ap, 'Salvar foto').click();
    let perfilAluno = await esperarFoto(ap, aluno.uid, (url) => Boolean(url));
    const urlAluno = perfilAluno?.fields?.fotoUrl?.stringValue ?? '';
    const caminhoAluno = decodeURIComponent(new URL(urlAluno).pathname.split('/o/')[1] ?? '');
    passo(7, 'Aluno salva foto no próprio caminho',
      Boolean(urlAluno) && caminhoAluno === `usuarios/${aluno.uid}/foto.jpg`,
      `caminho=${caminhoAluno}`);

    try {
      const r = await ap.request.post(
        `${STORAGE}?name=${encodeURIComponent(`usuarios/${aluno.uid}/foto.jpg`)}`,
        {
          headers: {
            Authorization: `Firebase ${motorista.token}`,
            'Content-Type': 'image/jpeg',
          },
          data: VERMELHO,
        },
      );
      passo(8, 'Outro usuário não pode gravar no caminho do aluno', r.status() === 403,
        `status=${r.status()}`);
    } catch (e) {
      passo(8, 'Outro usuário não pode gravar no caminho do aluno', false, String(e).slice(0, 220));
    }

    try {
      const r = await ap.request.patch(
        `${FIRE}/usuarios/${aluno.uid}?updateMask.fieldPaths=fotoUrl`,
        {
          headers: { Authorization: `Bearer ${motorista.token}`, 'Content-Type': 'application/json' },
          data: { fields: { fotoUrl: { stringValue: 'https://invalido' } } },
        },
      );
      passo(9, 'Outro usuário não pode alterar fotoUrl no Firestore', r.status() === 403,
        `status=${r.status()}`);
    } catch (e) {
      passo(9, 'Outro usuário não pode alterar fotoUrl no Firestore', false, String(e).slice(0, 220));
    }

    // Storage Rules: tipo e tamanho também são bloqueados no servidor.
    const uploadDireto = async (nome, corpo) =>
      ap.request.post(
        `${STORAGE}?name=${encodeURIComponent(`usuarios/${aluno.uid}/${nome}`)}`,
        {
          headers: {
            Authorization: `Firebase ${aluno.token}`,
            'Content-Type': 'image/jpeg',
          },
          data: corpo,
        },
      );
    try {
      let r = await uploadDireto('foto.gif', VERMELHO);
      passo(10, 'Storage Rules bloqueia extensão inválida', r.status() === 403,
        `status=${r.status()}`);
      r = await uploadDireto('foto.jpg', Buffer.alloc(6 * 1024 * 1024, 1));
      passo(11, 'Storage Rules bloqueia arquivo acima de 5 MB', r.status() === 403,
        `status=${r.status()}`);
      r = await uploadDireto('outro.jpg', VERMELHO);
      passo(12, 'Storage Rules bloqueia outro nome de arquivo', r.status() === 403,
        `status=${r.status()}`);
    } catch (e) {
      passo(10, 'Storage Rules bloqueia extensão/tamanho/nome inválidos', false,
        String(e).slice(0, 220));
    }

    // Validação de tamanho no cliente antes do upload.
    await btn(ap, 'Alterar foto').click();
    await waitText(ap, 'Escolher da galeria');
    await escolherArquivo(ap, Buffer.alloc(16 * 1024 * 1024, 7), 'grande.png');
    await waitText(ap, 'Imagem muito grande');
    await btn(ap, 'Cancelar').click();
    passo(13, 'Arquivo grande é rejeitado antes do upload', true, 'erro exibido na prévia');

    await ap.reload({ waitUntil: 'load' });
    await a11y(ap);
    await waitText(ap, 'VanGo · conectado ao Firebase', 30000);
    await abrirPerfil(ap, 'student');
    perfilAluno = await doc(ap, `usuarios/${aluno.uid}`);
    passo(14, 'Foto do aluno persiste após refresh',
      perfilAluno?.fields?.fotoUrl?.stringValue === urlAluno, 'fotoUrl conferido');

    return {
      ok: results.every((r) => r.ok) && erros.length === 0,
      sufixo,
      total: results.length,
      resumo: results.map((r) => `${r.n}:${r.ok ? 'OK' : 'FALHA'}`).join(' '),
      detalhes: results,
      logs,
      erros,
    };
  } catch (falha) {
    const estados = [];
    for (const ctx of contexts) {
      for (const p of ctx.pages()) estados.push({ url: p.url(), texto: (await p.locator('flt-semantics').allTextContents()).slice(-4) });
    }
    return {
      ok: false,
      sufixo,
      total: results.length,
      resumo: results.map((r) => `${r.n}:${r.ok ? 'OK' : 'FALHA'}`).join(' '),
      detalhes: results,
      falhou: String(falha?.stack ?? falha).slice(0, 1400),
      estados,
      logs,
      erros,
    };
  } finally {
    for (const ctx of contexts) await ctx.close().catch(() => {});
  }
}
