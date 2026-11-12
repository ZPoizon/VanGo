import 'package:go_router/go_router.dart';

import 'package:vango/core/store.dart';
import 'package:vango/features/auth/invited_signup_screen.dart';
import 'package:vango/features/auth/login_screen.dart';
import 'package:vango/features/auth/signup_success_screen.dart';
import 'package:vango/features/driver/daily_list/daily_list_screen.dart';
import 'package:vango/features/driver/history/history_detail_screen.dart';
import 'package:vango/features/driver/history/history_screen.dart';
import 'package:vango/features/driver/home/driver_home_screen.dart';
import 'package:vango/features/driver/profile/driver_profile_screen.dart';
import 'package:vango/features/driver/students/invite_screen.dart';
import 'package:vango/features/driver/students/student_detail_screen.dart';
import 'package:vango/features/driver/students/students_screen.dart';
import 'package:vango/features/driver/trips/notify_students_screen.dart';
import 'package:vango/features/student/arrival/arrival_alert_screen.dart';
import 'package:vango/features/student/home/student_home_screen.dart';
import 'package:vango/features/student/profile/student_profile_screen.dart';
import 'package:vango/features/student/schedule/weekly_schedule_screen.dart';
import 'package:vango/features/student/today/today_students_screen.dart';

GoRouter criarRouter(VanGoStore store) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: store,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggedIn = store.autenticado;
      final isPublic = loc == '/login' || loc.startsWith('/signup/');

      if (!loggedIn) {
        return isPublic ? null : '/login';
      }

      final isDriver = store.ehMotorista;
      final home = isDriver ? '/driver/home' : '/student/home';

      if (loc == '/login' || loc == '/signup/success') return home;

      if (isDriver && loc.startsWith('/student')) return home;
      if (!isDriver && loc.startsWith('/driver')) return home;

      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup/success',
        builder: (context, state) => const SignupSuccessScreen(),
      ),
      GoRoute(
        path: '/signup/:token',
        builder: (context, state) => InvitedSignupScreen(
          token: state.pathParameters['token'] ?? 'convite-demo',
        ),
      ),
      GoRoute(
        path: '/driver/home',
        builder: (context, state) => const DriverHomeScreen(),
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
