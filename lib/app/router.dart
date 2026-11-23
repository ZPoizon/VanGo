import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:vango/core/store.dart';
import 'package:vango/features/auth/driver_signup_screen.dart';
import 'package:vango/features/auth/enter_group_code_screen.dart';
import 'package:vango/features/auth/invited_signup_screen.dart';
import 'package:vango/features/auth/login_screen.dart';
import 'package:vango/features/auth/signup_choice_screen.dart';
import 'package:vango/features/auth/signup_success_screen.dart';
import 'package:vango/features/driver/daily_list/daily_list_screen.dart';
import 'package:vango/features/driver/dashboard/driver_dashboard_screen.dart';
import 'package:vango/features/driver/history/history_detail_screen.dart';
import 'package:vango/features/driver/history/history_screen.dart';
import 'package:vango/features/driver/home/driver_home_screen.dart';
import 'package:vango/features/driver/profile/driver_profile_screen.dart';
import 'package:vango/features/driver/requests/driver_requests_screen.dart';
import 'package:vango/features/driver/students/invite_screen.dart';
import 'package:vango/features/driver/students/student_detail_screen.dart';
import 'package:vango/features/driver/students/students_screen.dart';
import 'package:vango/features/driver/trips/notify_students_screen.dart';
import 'package:vango/features/driver/vans/create_van_screen.dart';
import 'package:vango/features/driver/vans/my_vans_screen.dart';
import 'package:vango/features/driver/vans/van_detail_screen.dart';
import 'package:vango/features/student/arrival/arrival_alert_screen.dart';
import 'package:vango/features/student/home/student_home_screen.dart';
import 'package:vango/features/student/profile/student_profile_screen.dart';
import 'package:vango/features/student/schedule/weekly_schedule_screen.dart';
import 'package:vango/features/student/today/today_students_screen.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(VanGoStore store) : _store = store {
    _store.addListener(_onStoreChanged);
  }

  final VanGoStore _store;
  bool _autenticado = false;
  bool _ehMotorista = false;
  String? _usuarioId;
  String? _perfilGrupoId;

  void _onStoreChanged() {
    final autenticado = _store.autenticado;
    final ehMotorista = _store.ehMotorista;
    final usuarioId = _store.usuarioAtual?.id;
    final perfilGrupoId = _store.usuarioAtual?.grupoId;
    if (autenticado == _autenticado &&
        ehMotorista == _ehMotorista &&
        usuarioId == _usuarioId &&
        perfilGrupoId == _perfilGrupoId) {
      return;
    }
    _autenticado = autenticado;
    _ehMotorista = ehMotorista;
    _usuarioId = usuarioId;
    _perfilGrupoId = perfilGrupoId;
    notifyListeners();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}

GoRouter criarRouter(VanGoStore store) {
  final authRefresh = _AuthRefreshNotifier(store);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggedIn = store.autenticado;
      // A tela de código é uma etapa da Home: exige sessão, mas não exige
      // participação aprovada em um grupo.
      final isPublic =
          loc == '/login' ||
          (loc.startsWith('/signup/') && loc != '/signup/enter-group');

      if (!loggedIn) {
        return isPublic ? null : '/login';
      }

      final isDriver = store.ehMotorista;
      final usuario = store.usuarioAtual;
      final grupo = usuario?.grupoId?.trim();
      // O vínculo legado do perfil não é mais a única fonte: uma van recém
      // criada pode ser a ativa mesmo com grupoId vazio no perfil.
      final semVan =
          (grupo == null || grupo.isEmpty) &&
          store.grupoSelecionado == null &&
          store.meusGrupos.isEmpty;

      // Conta autenticada e participação aprovada são coisas distintas.
      // O aluno só acessa dados privados do grupo quando status/ativo indicam
      // aprovação, independentemente de já ter ou não um grupoId.
      final alunoAprovado = !isDriver && usuario?.podeAcessar == true;

      // O motorista entra pelo dashboard geral, mesmo sem vans. O painel
      // operacional continua sendo /driver/home, sempre da van selecionada.
      if (isDriver &&
          (loc == '/login' ||
              loc == '/' ||
              loc.startsWith('/student') ||
              loc.startsWith('/signup/'))) {
        return '/driver/dashboard';
      }

      final home = isDriver ? '/driver/dashboard' : '/student/home';

      // Sem van não existe painel operacional: volta ao dashboard, que oferece
      // a criação da primeira van sem redirecionar automaticamente.
      if (isDriver && semVan && loc == '/driver/home') {
        return '/driver/dashboard';
      }

      if (isDriver) {
        if (loc == '/login' ||
            loc.startsWith('/signup/') ||
            loc.startsWith('/student')) {
          return home;
        }
        return null;
      }

      // Aluno autenticado, mesmo sem grupo/pendente/recusado, entra na Home.
      if (loc == '/login' || loc == '/signup/success') return home;

      // A tela de código é uma etapa opcional da Home: Voltar não faz logout.
      if (loc == '/signup/enter-group') return null;

      // Perfil e Home são acessíveis a qualquer aluno autenticado.
      if (loc == '/student/home' || loc == '/student/profile') return null;

      // Sem aprovação, qualquer rota privada volta para a Home restrita.
      if (!alunoAprovado) return home;

      if (loc.startsWith('/driver') || loc.startsWith('/signup/')) return home;

      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup/choice',
        builder: (context, state) => const SignupChoiceScreen(),
      ),
      GoRoute(
        path: '/signup/driver',
        builder: (context, state) => const DriverSignupScreen(),
      ),
      GoRoute(
        path: '/signup/student',
        builder: (context, state) =>
            const InvitedSignupScreen(token: 'solicitacao-direta'),
      ),
      GoRoute(
        path: '/signup/enter-group',
        builder: (context, state) => const EnterGroupCodeScreen(),
      ),
      GoRoute(
        path: '/signup/success',
        builder: (context, state) => const SignupSuccessScreen(),
      ),
      GoRoute(
        path: '/signup/:token',
        builder: (context, state) => InvitedSignupScreen(
          token: state.pathParameters['token'] ?? 'solicitacao-direta',
        ),
      ),
      GoRoute(
        path: '/driver/dashboard',
        builder: (context, state) => const DriverDashboardScreen(),
      ),
      GoRoute(
        path: '/driver/home',
        builder: (context, state) => const DriverHomeScreen(),
      ),
      GoRoute(
        path: '/driver/requests',
        builder: (context, state) => const DriverRequestsScreen(),
      ),
      GoRoute(
        path: '/driver/vans',
        builder: (context, state) => const MyVansScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'new',
            builder: (context, state) => CreateVanScreen(
              rotaRetorno: state.uri.queryParameters['retorno'],
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => VanDetailScreen(
              grupoId: state.pathParameters['id'] ?? '',
              solicitacaoId: state.uri.queryParameters['solicitacaoId'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/driver/profile',
        builder: (context, state) => const DriverProfileScreen(),
      ),
      GoRoute(
        path: '/driver/daily-list',
        builder: (context, state) => const DailyListScreen(),
      ),
      GoRoute(
        path: '/driver/students',
        builder: (context, state) => const StudentsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'invite',
            builder: (context, state) => const InviteScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                StudentDetailScreen(studentId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/driver/history',
        builder: (context, state) => const HistoryScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: ':tripId',
            builder: (context, state) =>
                HistoryDetailScreen(tripId: state.pathParameters['tripId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/driver/trips/:id/notify',
        builder: (context, state) =>
            NotifyStudentsScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/home',
        builder: (context, state) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: '/student/profile',
        builder: (context, state) => const StudentProfileScreen(),
      ),
      GoRoute(
        path: '/student/today',
        builder: (context, state) => const TodayStudentsScreen(),
      ),
      GoRoute(
        path: '/student/schedule',
        builder: (context, state) => const WeeklyScheduleScreen(),
      ),
      GoRoute(
        path: '/student/arrival/:tripId',
        builder: (context, state) => ArrivalAlertScreen(
          tripId: state.pathParameters['tripId'] ?? 'demo',
        ),
      ),
    ],
  );
}
