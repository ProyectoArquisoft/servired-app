import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:servired_app/core/router/app_router.dart';
import 'package:servired_app/core/theme/app_theme.dart';
import 'package:servired_app/l10n/app_localizations.dart';

class ServiRedApp extends ConsumerWidget {
  const ServiRedApp({super.key});

  static const defaultLocale = Locale('es', 'CO');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: defaultLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
