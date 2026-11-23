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

/// Se muestra si la app se ejecutó sin `--dart-define-from-file`.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.missing});

  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: ServiRedApp.defaultLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            appBar: AppBar(title: Text(l10n.configMissingTitle)),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(l10n.configMissingBody(missing.join(', '))),
            ),
          );
        },
      ),
    );
  }
}
