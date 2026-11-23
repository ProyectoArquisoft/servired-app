import 'package:flutter/material.dart';

import 'package:servired_app/features/reports/domain/report_models.dart';
import 'package:servired_app/l10n/app_localizations.dart';

/// Ícono, color y nombre de cada servicio. El catálogo de la API no los trae,
/// así que los define la app (CLAUDE.md §10.3).
extension ServiceStyle on TipoServicio {
  IconData get icon => switch (this) {
    TipoServicio.energia => Icons.bolt,
    TipoServicio.gas => Icons.local_fire_department,
    TipoServicio.acueducto => Icons.water_drop,
    TipoServicio.alcantarillado => Icons.plumbing,
    TipoServicio.aseo => Icons.delete,
    TipoServicio.desconocido => Icons.home_repair_service,
  };

  Color get color => switch (this) {
    TipoServicio.energia => const Color(0xFFB26A00),
    TipoServicio.gas => const Color(0xFFC62828),
    TipoServicio.acueducto => const Color(0xFF1565C0),
    TipoServicio.alcantarillado => const Color(0xFF4E5B31),
    TipoServicio.aseo => const Color(0xFF2E7D32),
    TipoServicio.desconocido => const Color(0xFF546E7A),
  };

  String label(AppLocalizations l10n) => switch (this) {
    TipoServicio.energia => l10n.serviceEnergia,
    TipoServicio.gas => l10n.serviceGas,
    TipoServicio.acueducto => l10n.serviceAcueducto,
    TipoServicio.alcantarillado => l10n.serviceAlcantarillado,
    TipoServicio.aseo => l10n.serviceAseo,
    TipoServicio.desconocido => l10n.serviceOther,
  };
}

/// Círculo con el ícono del servicio.
class ServiceAvatar extends StatelessWidget {
  const ServiceAvatar(this.tipo, {super.key, this.radius = 24});

  final TipoServicio tipo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: tipo.color,
      foregroundColor: Colors.white,
      child: Icon(tipo.icon, size: radius),
    );
  }
}

/// Chip con el estado del reporte.
class EstadoChip extends StatelessWidget {
  const EstadoChip(this.estado, {super.key});

  final EstadoReporte estado;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (estado) {
      EstadoReporte.activo => (l10n.estadoActivo, scheme.errorContainer),
      EstadoReporte.enAtencion => (
        l10n.estadoEnAtencion,
        scheme.tertiaryContainer,
      ),
      EstadoReporte.restablecimientoReportado => (
        l10n.estadoRestablecimientoReportado,
        scheme.secondaryContainer,
      ),
      EstadoReporte.restablecido => (
        l10n.estadoRestablecido,
        scheme.primaryContainer,
      ),
      EstadoReporte.cerrado => (
        l10n.estadoCerrado,
        scheme.surfaceContainerHighest,
      ),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
