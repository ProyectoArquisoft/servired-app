import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:servired_app/core/router/routes.dart';
import 'package:servired_app/core/theme/app_theme.dart';
import 'package:servired_app/l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.homeGreeting, style: textTheme.headlineSmall),
            const SizedBox(height: 20),
            _PrimaryAction(
              icon: Icons.power_off_outlined,
              label: l10n.homeReportOutage,
              onPressed: () => context.push(Routes.newOutage),
            ),
            const SizedBox(height: 16),
            _PrimaryAction(
              icon: Icons.check_circle_outline,
              label: l10n.homeReportRestoration,
              onPressed: () => context.push(Routes.restoration),
            ),
            const SizedBox(height: 28),
            _SecondaryAction(
              icon: Icons.map_outlined,
              label: l10n.homeMap,
              onPressed: () => context.push(Routes.map),
            ),
            _SecondaryAction(
              icon: Icons.fact_check_outlined,
              label: l10n.homeValidate,
              onPressed: () => context.push(Routes.validate),
            ),
            _SecondaryAction(
              icon: Icons.list_alt_outlined,
              label: l10n.homeMyReports,
              onPressed: () => context.push(Routes.myReports),
            ),
            _SecondaryAction(
              icon: Icons.bar_chart_outlined,
              label: l10n.homeIndicators,
              onPressed: () => context.push(Routes.indicators),
            ),
            const SizedBox(height: 12),
            _SecondaryAction(
              icon: Icons.report_outlined,
              label: l10n.homeFraud,
              subtitle: l10n.homeFraudHint,
              onPressed: () => context.push(Routes.fraud),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppTheme.primaryButtonHeight,
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(label),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        minTileHeight: 56,
        leading: Icon(icon),
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}
