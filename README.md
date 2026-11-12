# VanGo 🚐

**Aplicativo de Confirmação de Presença e Avisos de Chegada para Transporte
Universitário por Van**

Projeto acadêmico desenvolvido para o curso de **Análise e Desenvolvimento de
Sistemas (ADS)**.

---

## 📌 Sobre o Projeto

O **VanGo** é uma solução mobile desenvolvida em **Flutter/Dart** para otimizar
o transporte universitário de estudantes entre cidades (ex: Capão Bonito →
Itapetininga).

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

#### Android

- O plugin `com.google.gms.google-services` é aplicado **somente** quando
  `android/app/google-services.json` existe, então o build continua
  funcionando sem as credenciais.
- Permissões de notificação e o canal padrão `vango_chegada` já estão no
  `AndroidManifest.xml`.

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
- `storage.rules`: foto de perfil até 5 MB, somente `image/*`.
- `functions/index.js`: observa `notificacoes/{id}` e envia push aos tokens dos
  alunos avisados, removendo tokens inválidos.

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

---

## 📱 Principais Telas

- **Login / Recuperar senha** (`lib/features/auth`)
- **Cadastro por convite** com aprovação do motorista
- **Home do aluno**: status da chamada, respostas de ida/volta, padrão semanal,
  aviso "estou indo" e "estou liberado"
- **Home do motorista**: abrir/encerrar chamada, iniciar/encerrar viagem,
  contadores em tempo real
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
- Autenticação, perfis, aprovação de alunos, chamadas, respostas, viagens,
  histórico, convites e foto de perfil integrados ao Firebase.
- Push de chegada via FCM com Cloud Function, canal Android `vango_chegada` e
  tratamento de foreground/background.
- Sem credenciais, o app continua abrindo em modo demonstração (Android, iOS,
  macOS e web); Windows/Linux usam demonstração.

**Próximos passos sugeridos:** Google Sign-In, painel administrativo, relatórios
e testes automatizados de integração com o Emulator Suite.
