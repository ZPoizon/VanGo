# VanGo 🚐

**Aplicativo de Confirmação de Presença e Avisos de Chegada para Transporte Universitário por Van**

Projeto acadêmico desenvolvido para o curso de **Análise e Desenvolvimento de Sistemas (ADS)**.

---

## 📌 Sobre o Projeto

O **VanGo** é uma solução mobile desenvolvida em **Flutter/Dart** para otimizar o transporte universitário de estudantes entre cidades (ex: Capão Bonito → Itapetininga). 

O sistema organiza a rotina de viagens com dois perfis de acesso:
* **Aluno**: confirma presença para os trajetos de ida e volta do dia, ajusta o padrão semanal e recebe notificações de aproximação da van.
* **Motorista**: consulta a lista de presença em tempo real, abre e fecha chamadas de viagens, envia avisos de chegada e gerencia cadastros dos estudantes.

---

## 🛠️ Tecnologias Utilizadas nesta Entrega

* **Flutter SDK**: Framework UI multiplataforma
* **Dart**: Linguagem de programação
* **Material Design 3**: Componentes visuais com identidade customizada baseada no protótipo Figma.

---

## 🚀 Como Executar o Projeto no Android Studio

1. **Pré-requisitos**:
   * Flutter SDK instalado e configurado nas variáveis de ambiente.
   * Android Studio com o plugin Flutter instalado.
   * Um emulador Android (AVD) ou dispositivo físico conectado.

2. **Passo a passo**:
   ```bash
   # Clonar ou abrir a pasta do projeto no Android Studio
   cd vango

   # Instalar as dependências do Flutter
   flutter pub get

   # Executar o aplicativo no dispositivo/emulador selecionado
   flutter run
   ```

---

## 📱 Telas Desenvolvidas nesta Primeira Entrega

1. **Tela de Login (`login_screen.dart`)**:
   - Identidade visual com o logotipo VanGo e rota principal.
   - Campos de E-mail e Senha.
   - Acesso rápido demonstrativo para os perfis **Aluno** e **Motorista**.
2. **Página Inicial do Aluno (`aluno_home_screen.dart`)**:
   - Resumo da presença de hoje (Ida e Volta).
   - Atalho para aviso de chegada da van.
   - Acesso às configurações de presença e padrão semanal.
3. **Confirmação de Presença (`confirmacao_screen.dart`)**:
   - Seleção interativa "Vou" e "Não vou" para as seções de Ida e Volta utilizando `setState`.
4. **Padrão Semanal (`padrao_semanal_screen.dart`)**:
   - Configuração demonstrativa dos dias da semana (Segunda a Sexta).
5. **Página Inicial do Motorista (`motorista_home_screen.dart`)**:
   - Painel principal com status da chamada do dia.
   - Botão interativo para abrir/fechar chamada de amanhã.
   - Menu de navegação para a Lista do dia, Alunos, Histórico e Avisos.
6. **Lista do Dia (`lista_viagem_screen.dart`)**:
   - Resumo numérico de alunos que responderam à chamada.
   - Badges coloridas de status (`Ida e volta`, `Só ida`, `Só volta`, `Não vai`, `Sem resposta`).
   - Confirmações de embarque (`✓ Estou indo - 06:42`).
7. **Cadastro de Alunos (`alunos_screen.dart`)**:
   - Campo de busca por nome ou instituição.
   - Abas segmentadas por turno (`Matutino`, `Noturno`, `Pendentes`).
   - Botão modal para convidar novo aluno.
8. **Histórico de Viagens (`historico_screen.dart`)**:
   - Filtro por período (mês/ano).
   - Cards detalhados com data, tipo de viagem (IDA/VOLTA), horário e total de confirmados.
9. **Simulação de Aviso de Chegada (`aviso_chegada_screen.dart`)**:
   - Interface simulada da notificação de aproximação da van.
   - Botão interativo "Estou indo!" para o aluno responder ao motorista.

---

## 📁 Estrutura de Arquivos

```text
vango/
├── android/
├── assets/
│   └── images/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── models/
│   │   └── usuario.dart
│   ├── data/
│   │   └── dados_mock.dart
│   ├── telas/
│   │   ├── login_screen.dart
│   │   ├── aluno_home_screen.dart
│   │   ├── motorista_home_screen.dart
│   │   ├── confirmacao_screen.dart
│   │   ├── padrao_semanal_screen.dart
│   │   ├── lista_viagem_screen.dart
│   │   ├── alunos_screen.dart
│   │   ├── historico_screen.dart
│   │   └── aviso_chegada_screen.dart
│   ├── widgets/
│   │   └── botao_primario.dart
│   └── theme/
│       └── app_theme.dart
├── pubspec.yaml
└── README.md
```

---

## ⏳ Estado Atual e Próximos Passos

> **Status:** Protótipo inicial navegável e funcional para validação de interface e requisitos acadêmicos.

**Etapas futuras de desenvolvimento:**
* Integração com **Firebase Authentication** (login real com e-mail e senha).
* Conexão com **Firebase Cloud Firestore** (persistência real das confirmações, alunos e viagens).
* Configuração do **Firebase Cloud Messaging (FCM)** para envio de notificações push reais aos dispositivos dos alunos.
