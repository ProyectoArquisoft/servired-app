import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:servired_app/core/router/routes.dart';
import 'package:servired_app/features/auth/data/auth_repository.dart';
import 'package:servired_app/features/auth/presentation/login_screen.dart';
import 'package:servired_app/features/fraud/fraud_screen.dart';
import 'package:servired_app/features/home/presentation/home_screen.dart';
import 'package:servired_app/features/indicators/indicators_screen.dart';
import 'package:servired_app/features/map/map_screen.dart';
import 'package:servired_app/features/reports/my_reports_screen.dart';
import 'package:servired_app/features/reports/presentation/new_outage_screen.dart';
import 'package:servired_app/features/reports/presentation/restoration_screen.dart';
import 'package:servired_app/features/reports/presentation/validation_screen.dart';
import 'package:servired_app/l10n/app_localizations.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  // Avisa al router cuando la sesión termina, para sacar al usuario de las
  // pantallas que exigen sesión.
  final signedIn = ValueNotifier<bool>(auth.isSignedIn);
  ref.listen(signedInProvider, (_, next) {
    if (next case AsyncData(:final value)) signedIn.value = value;
  });

  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: signedIn,
    redirect: (context, state) {
      if (!signedIn.value && Routes.requiresLogin.contains(state.uri.path)) {
        return Uri(
          path: Routes.login,
          queryParameters: {'desde': state.uri.toString()},
        ).toString();
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) =>
            LoginScreen(redirectTo: state.uri.queryParameters['desde']),
      ),
      GoRoute(
        path: Routes.newOutage,
        builder: (context, state) => const NewOutageScreen(),
      ),
      GoRoute(
        path: Routes.restoration,
        builder: (context, state) => const RestorationScreen(),
      ),
      GoRoute(
        path: Routes.fraud,
        builder: (context, state) => const FraudScreen(),
      ),
      GoRoute(
        path: Routes.myReports,
        builder: (context, state) => const MyReportsScreen(),
      ),
      GoRoute(
        path: Routes.indicators,
        builder: (context, state) => const IndicatorsScreen(),
      ),
      GoRoute(
        path: Routes.validate,
        builder: (context, state) => const ValidationScreen(),
      ),
      GoRoute(
        path: Routes.map,
        builder: (context, state) => const MapScreen(),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
  ref.onDispose(() {
    router.dispose();
    signedIn.dispose();
  });
  return router;
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notFoundTitle)),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go(Routes.home),
          child: Text(l10n.goHome),
        ),
      ),
    );
  }
}
