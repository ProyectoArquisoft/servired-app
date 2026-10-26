import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:servired_app/core/router/routes.dart';
import 'package:servired_app/features/home/presentation/home_screen.dart';
import 'package:servired_app/l10n/app_localizations.dart';
import 'package:servired_app/shared/widgets/placeholder_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      // Secciones que se implementan en M2–M7.
      _placeholder(Routes.newOutage, (l10n) => l10n.homeReportOutage),
      _placeholder(Routes.restoration, (l10n) => l10n.homeReportRestoration),
      _placeholder(Routes.myReports, (l10n) => l10n.homeMyReports),
      _placeholder(Routes.validate, (l10n) => l10n.homeValidate),
      _placeholder(Routes.map, (l10n) => l10n.homeMap),
      _placeholder(Routes.indicators, (l10n) => l10n.homeIndicators),
      _placeholder(Routes.fraud, (l10n) => l10n.homeFraud),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
  ref.onDispose(router.dispose);
  return router;
});

GoRoute _placeholder(String path, String Function(AppLocalizations) title) {
  return GoRoute(
    path: path,
    builder: (context, state) =>
        PlaceholderScreen(title: title(AppLocalizations.of(context))),
  );
}

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
