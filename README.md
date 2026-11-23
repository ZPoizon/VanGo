# VanGo 🚐

**Aplicativo de Confirmação de Presença e Avisos de Chegada para Transporte
Universitário por Van**

Projeto acadêmico desenvolvido para o curso de **Análise e Desenvolvimento de
Sistemas (ADS)**.

---

## 📌 Sobre o Projeto

O **VanGo** é uma solução mobile desenvolvida em **Flutter/Dart** para otimizar
o transporte universitário de estudantes entre cidades (qualquer rota de van).

O sistema organiza a rotina de viagens com dois perfis de acesso:

- **Aluno**: confirma presença para os trajetos de ida e volta do dia, ajusta o
  padrão semanal, avisa que está indo/liberado e recebe notificações de
  aproximação da van.
- **Motorista**: consulta a lista de presença em tempo real, abre e fecha
  chamadas, inicia e encerra viagens, envia avisos de chegada e gerencia o
  cadastro dos estudantes.

---

## 🛠️ Tecnologias Utilizadas

- **Flutter SDK** / **Dart**
- **Material Design 3** com identidade visual customizada
- **Firebase Authentication** (e-mail e senha)
- **Cloud Firestore** (dados em tempo real)
- **Firebase Storage** (foto de perfil)
- **Firebase Cloud Messaging + Cloud Functions** (push de chegada)
- **flutter_local_notifications** (exibição em primeiro plano no Android)

---

## 🚀 Como Executar

### Modo demonstração (sem Firebase)

O app inicia automaticamente em **modo demonstração** quando não há credenciais
do Firebase configuradas. Nesse modo os dados ficam em memória e são perdidos
ao fechar o app — ideal para avaliar a interface sem criar um projeto Firebase.

```bash
flutter pub get
flutter run
```

> No modo demonstração a tela de login exibe os atalhos **Sou aluno** e
> **Sou motorista**. No modo Firebase esses atalhos desaparecem.

### Com Firebase

Pré-requisitos: um projeto no [Console do Firebase](https://console.firebase.google.com)
com **Authentication (E-mail/senha)**, **Firestore**, **Storage** e
**Cloud Messaging** habilitados.

#### Opção A — FlutterFire CLI (recomendado)

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<seu-project-id>
```

O comando gera `lib/firebase_options.dart` e os arquivos nativos
(`google-services.json` / `GoogleService-Info.plist`) com os valores reais.

> `lib/firebase_options.dart` já existe neste repositório e lê as credenciais de
> `--dart-define`. Se você rodar `flutterfire configure`, ele será sobrescrito
> pelos valores reais e tudo continuará funcionando.

#### Opção B — sem CLI, via `--dart-define-from-file`

1. Copie `firebase.local.example.json` para `firebase.local.json`.
2. Preencha os valores do app web/Android/iOS (Console do Firebase →
   Configurações do projeto → Seus apps).
3. Rode:

```bash
flutter run --dart-define-from-file=firebase.local.json
```

Chaves aceitas: `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`,
`FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_AUTH_DOMAIN`,
`FIREBASE_STORAGE_BUCKET`, `FIREBASE_APP_ID_ANDROID`, `FIREBASE_APP_ID_IOS`,
`FIREBASE_APP_ID_MACOS`, `FIREBASE_APP_ID_WEB`, `FIREBASE_IOS_BUNDLE_ID`,
`FIREBASE_MACOS_BUNDLE_ID`.

> `firebase.local.json` está no `.gitignore` — não comite credenciais.

### Validação local com Firebase Emulator Suite (`demo-vango`)

Para validação automatizada, use **somente** os emuladores. O bootstrap do app
impõe `demo-vango`, sonda Auth/Firestore/Storage e chama `useAuthEmulator` /
`useFirestoreEmulator` / `useStorageEmulator`; não existe fallback para produção
nesse modo.

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
firebase emulators:start --only auth,firestore,storage,ui --project demo-vango
```

Em outro terminal, gere o build **debug** e sirva o web:

```powershell
flutter build web --debug `
  --dart-define=USE_FIREBASE_EMULATORS=true `
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 `
  --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9099 `
  --dart-define=FIREBASE_FIRESTORE_EMULATOR_PORT=8080 `
  --dart-define=FIREBASE_STORAGE_EMULATOR_PORT=9199 `
  --dart-define=FIREBASE_EMULATOR_PROJECT_ID=demo-vango `
  --output=build/web_e2e

node tool/e2e_static_server.mjs build/web_e2e 7358
```

> O build precisa ser `--debug`: o `firebase_auth_web` reaplica a origem do
> emulador a partir de `sessionStorage` somente em `kDebugMode`. Em release, um
> reload pode contatar Auth de produção antes de `useAuthEmulator`.

Endereços locais: app `http://127.0.0.1:7358/`, UI dos emuladores
`http://127.0.0.1:4000/`, Auth `127.0.0.1:9099`, Firestore `127.0.0.1:8080`,
Storage `127.0.0.1:9199`.

Para rodar somente as regras:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npm --prefix tool/rules_test test
```

#### Android

- O plugin `com.google.gms.google-services` é aplicado **somente** quando
  `android/app/google-services.json` existe, então o build continua
  funcionando sem as credenciais.
- Permissões de notificação e o canal padrão `vango_chegada` já estão no
  `AndroidManifest.xml`.
- Fase 5A: `flutter build apk --debug` validado com `image_picker`,
  `firebase_storage` e permissões de câmera/galeria. A captura com câmera em
  dispositivo físico ainda não foi executada neste ambiente.

#### iOS / macOS

- Adicione `GoogleService-Info.plist` em `ios/Runner/` (e `macos/Runner/` para
  macOS) ou use as credenciais via `--dart-define-from-file`.
- `Info.plist` já declara `remote-notification` em `UIBackgroundModes` e os
  textos de permissão de câmera/fotos.
- No Console do Firebase → Cloud Messaging, envie sua **chave APNs** para
  habilitar push no iOS.

#### Regras, índices e Cloud Functions

```bash
npm --prefix functions install
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

- `firestore.rules`: leitura autenticada por grupo; escrita restrita ao
  motorista do grupo ou ao próprio aluno.
- `firestore.indexes.json`: índices compostos usados pelo app.
- `storage.rules`: foto de perfil em `usuarios/{uid}/foto.*`, no máximo 5 MB,
  tipos `image/jpeg|png|webp`, somente o dono do UID pode escrever/excluir e
  a leitura exige login.
- `functions/index.js`: observa `notificacoes/{id}` e envia push aos tokens dos
  alunos avisados, removendo tokens inválidos.

> **Fase 5A — bloqueio de produção:** o upload real depende de um bucket do
> Cloud Storage habilitado no projeto. `firebase projects:list` confirma que
> `vango-4b4a5` está ativo, mas a disponibilidade do bucket padrão
> (`vango-4b4a5.firebasestorage.app`) e o faturamento não puderam ser
> confirmados com as ferramentas disponíveis neste ambiente (sem `gcloud`/
> `gsutil`). Nenhum serviço ou plano foi ativado. Antes de publicar, verifique
> no Console do Firebase se o Storage está habilitado, se o projeto possui o
> plano de faturamento exigido e publique `storage.rules` e `firestore.rules`.
> Até lá, foto de perfil funciona somente com emuladores (ou em modo demo, sem
> persistência).

#### Criar o motorista (primeiro acesso)

O cadastro de alunos é feito por link de convite gerado pelo motorista, mas o
primeiro motorista precisa existir. Use o script de seed:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "tool/service-account.json"
node tool/seed_firestore.js `
  --email=motorista@vango.app `
  --senha=umaSenhaForte123 `
  --nome="Motorista VanGo" `
  --telefone="(15) 99999-0000"
```

Baixe a chave de serviço em Console do Firebase → Configurações → Contas de
serviço. O arquivo é ignorado pelo Git.

Depois entre no app com o e-mail/senha informados e compartilhe o link de
convite em **Alunos → Convidar aluno**.

---

## 🗂️ Modelo de Dados (Firestore)

| Caminho | Conteúdo |
| --- | --- |
| `usuarios/{uid}` | `nome`, `email`, `perfil` (`aluno`/`motorista`), `status`, `telefone`, `fotoUrl`, `instituicao`, `turno`, `enderecoEmbarque`, `grupoId` |
| `usuarios/{uid}/tokens/{token}` | token FCM do dispositivo |
| `chamadas/{id}` | `grupoId`, `motoristaId`, `dataServico`, `status`, `criadaEm`, `abertaEm`, `encerradaEm` |
| `respostas/{chamadaId}_{alunoId}` | `chamadaId`, `alunoId`, `grupoId`, `ida`, `volta`, `respondidoEm`, `estouIndo`, `liberadoEm`, `avisadoEm` |
| `viagens/{id}` | `chamadaId`, `grupoId`, `dataViagem`, `sentido`, `status`, `iniciadaEm`, `encerradaEm`, `confirmacoes[]` |
| `padroes/{uid}` | grade semanal (`dias.{1..7}`) |
| `convites/{token}` | `grupoId`, `motoristaId`, `turno`, `criadoEm` |
| `notificacoes/{id}` | fila de push: `grupoId`, `titulo`, `corpo`, `alunoIds`, `tipo`, `dados` |
| `grupos/{id}` | metadados do grupo |

O grupo padrão é `grupo-capao-itape`
(`lib/data/firebase/firestore_mappers.dart`).

### Estrutura adotada para presença

A especificação inicial citava `viagens`, `confirmacoes` e `padraoSemanal`
como se fossem coleções. O código funcional usa uma estrutura equivalente, sem
duplicidade:

- `chamadas/{id}` — chamada do dia, com `status` `aberta`/`encerrada`;
- `respostas/{chamadaId}_{alunoId}` — **fonte da verdade** de ida e volta. O ID
  determinístico impede respostas duplicadas; cada sentido é gravado
  separadamente com `set(..., merge: true)`, preservando o outro;
- `viagens/{id}` — documento da viagem por sentido, com o campo array
  `confirmacoes[]` como snapshot para a viagem/histórico. **Não existe**
  coleção `confirmacoes`;
- `padroes/{uid}` — grade semanal. `padraoSemanal` é apenas o getter/modelo Dart
  (`PadraoSemanalDia`), não uma coleção.

Nenhuma migração ou exclusão de dados foi feita. O bloqueio de alteração após o
início da viagem é feito no servidor pela regra que exige `chamada.status ==
'aberta'`; o motorista encerra a chamada antes de iniciar a viagem.

As regras foram validadas no emulador: **82 permitidos e 149 proibidos, sem
falhas** (última execução, incluindo as Fases 5A e 5B). A leitura somente leitura
do projeto `vango-4b4a5` identificou como ruleset ativo
`84033eba-209f-46aa-9183-ebe54e0aa139`
(SHA `48a7e2ab5c990d8b37dfa71bfbc0db89534c3e5898da6c2c8d0ca7724f225594`).
A referência antiga `02a1712e-e1e3-496f-910a-10f56a264a22` **não é o ruleset
ativo**.

O `firestore.rules` deste repositório **pode divergir das regras publicadas**.
A correção de leitura pontual da van por código público ainda não foi publicada
e exige deploy autorizado; nada foi publicado nesta consolidação. Resultados
obtidos no emulador não comprovam funcionamento em produção.

A listagem de `chamadas` filtra apenas por `grupoId` e ordena `dataServico`
localmente no cliente, evitando o índice composto que ainda não foi publicado.

### Validação E2E no Emulator Suite

`tool/e2e_part1.js` executa o fluxo crítico com sessões isoladas de motorista e
aluno e confere os documentos diretamente no Firestore Emulator. Cobertura:

- cadastro/login do motorista com o UID do Auth espelhado em `usuarios/{uid}`;
- criação da van e emissão de código de 6 dígitos;
- aluno sem grupo resolve o código, vê a van correta e envia solicitação;
- solicitação permanece **pendente** após refresh;
- motorista visualiza e aprova a solicitação de forma atômica;
- aluno vê o vínculo ativo após refresh, **sem logout**;
- motorista abre a chamada; aluno responde ida e volta; motorista encerra;
- conferência final de `usuarios`, `solicitacoes`, `grupos`, `codigos`,
  `chamadas` e `respostas`.

Última execução: **14/14 etapas aprovadas**, zero erros de console/HTTP.
O isolamento entre grupos é verificado pelos casos proibidos da suíte de regras
(leitura/escrita entre grupos) e pelo uso de contextos de navegador separados.

`tool/e2e_foto.js` cobre a Fase 5A: seleção, prévia, salvamento, substituição,
remoção com limpeza do arquivo antigo, persistência após refresh e novo login,
bloqueio de escrita no caminho de outro UID e rejeição de extensão/tamanho
inválidos nas Storage Rules. Última execução no Emulator Suite (Auth +
Firestore + Storage, build web debug): **14/14 etapas aprovadas**, zero erros
de console/HTTP. A suíte de regras do Firestore terminou com **82 permitidos e
149 proibidos aprovados**, incluindo a rejeição de base64 em `fotoUrl` e os
casos da Fase 5B.

`tool/e2e_fase5b.js` cobre os avisos persistentes de solicitação de entrada com
sessões isoladas de motorista e dois alunos: criação atômica do aviso, atualização
em tempo real, persistência após refresh e novo login, identificação da van,
navegação para aprovação/recusa, idempotência, ausência de duplicidade,
isolamento e regressão de `resposta_alterada`. Última execução: **12/12 etapas
aprovadas**, zero erros.

Ainda pendente de validação em ambiente real: deploy das regras locais,
índices (incluindo `notificacoes(grupoId, tipo)`), Storage, Functions/Hosting e
FCM. Nenhum desses itens foi publicado ou validado em produção nesta
consolidação.

---

## 📱 Principais Telas

- **Login / Recuperar senha** (`lib/features/auth`)
- **Cadastro por convite** com aprovação do motorista
- **Dashboard do motorista** (`/driver/dashboard`): resumo das próprias vans,
  alunos e solicitações, acesso rápido e seleção da van operacional
- **Home do aluno**: status da chamada, respostas de ida/volta, padrão semanal,
  aviso "estou indo" e "estou liberado"
- **Home do motorista** (`/driver/home`): painel operacional da van selecionada;
  abrir/encerrar chamada, iniciar/encerrar viagem, contadores em tempo real
- **Lista do dia**, **Alunos** (ativos/pendentes), **Convite**, **Histórico**,
  **Avisos de chegada**, **Perfis** e **Padrão semanal**

---

## 📁 Estrutura

```text
vango/
├── android/ ios/ web/ windows/
├── functions/                  # Cloud Function de envio FCM
├── lib/
│   ├── core/                   # contrato de store, escopo, notificações, widgets
│   ├── data/
│   │   ├── firebase/           # FirebaseStore + mappers do Firestore
│   │   └── demo/               # dados de demonstração
│   ├── demo/                   # DemoStore em memória
│   ├── features/               # telas organizadas por perfil/funcionalidade
│   ├── models/                 # Chamada, Viagem, Usuario, Presença...
│   ├── app/                    # MaterialApp, router e tema
│   ├── firebase_options.dart   # credenciais via --dart-define
│   └── main.dart               # escolhe FirebaseStore ou DemoStore
├── tool/seed_firestore.js      # cria o motorista inicial
├── firebase.json
├── firestore.rules / firestore.indexes.json
├── storage.rules
└── firebase.local.example.json
```

> `lib/telas/`, `lib/theme/`, `lib/app.dart` e `lib/data/dados_mock.dart` são da
> primeira versão do protótipo e estão excluídos da análise; a implementação
> ativa está em `lib/features` e `lib/app`.

---

## ✅ Estado Atual

- Interface completa e navegável nos modos **demonstração** e **Firebase**.
- Fluxo crítico (cadastro, van por código, aprovação, chamada e respostas)
  validado de ponta a ponta no **Firebase Emulator Suite**, não em produção.
- Regras locais validadas no emulador; regras publicadas podem ser diferentes.
- Push de chegada via FCM, Cloud Function, canal Android `vango_chegada` e
  tratamento de foreground/background permanecem **sem validação em produção**.
- Sem credenciais, o app continua abrindo em modo demonstração (Android, iOS,
  macOS e web); Windows/Linux usam demonstração. O `DemoStore` nunca foi usado
  como evidência de funcionamento do Firebase.

**Pendências de validação:** deploy autorizado das regras locais e demais
recursos do Firebase; validação de FCM/push em projeto real; Google Sign-In,
painel administrativo e relatórios (fora do escopo desta consolidação).
