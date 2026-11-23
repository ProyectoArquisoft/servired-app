import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:servired_app/features/fraud/fraud_models.dart';
import 'package:servired_app/features/fraud/fraud_repository.dart';
import 'domain/fraud_history_notifier.dart';

class FraudScreen extends ConsumerStatefulWidget {
  const FraudScreen({super.key});

  @override
  ConsumerState<FraudScreen> createState() => _FraudScreenState();
}

class _FraudScreenState extends ConsumerState<FraudScreen> {
  static const Map<int, String> _serviceNames = {
    1: 'Energía',
    2: 'Gas',
    3: 'Acueducto',
    4: 'Alcantarillado',
    5: 'Aseo',
  };

  final _formKey = GlobalKey<FormState>();
  final _reportIdController = TextEditingController(text: '1');
  final _latController = TextEditingController(text: '4.7110');
  final _lngController = TextEditingController(text: '-74.0721');
  final _descriptionController = TextEditingController();

  int _selectedServiceId = 1;
  bool _submitting = false;
  FraudReportResponse? _result;
  String? _errorMessage;

  @override
  void dispose() {
    _reportIdController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final reportId = int.tryParse(_reportIdController.text.trim());
    final lat = double.tryParse(
      _latController.text.trim().replaceAll(',', '.'),
    );
    final lng = double.tryParse(
      _lngController.text.trim().replaceAll(',', '.'),
    );

    if (reportId == null || lat == null || lng == null) {
      setState(() {
        _errorMessage = 'Revisa el ID del reporte y las coordenadas.';
      });
      return;
    }

    final description = _descriptionController.text.trim();
    final serviceName = _serviceNames[_selectedServiceId] ?? 'Energía';
    final baseHistoryItem = FraudHistoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      reportId: reportId,
      service: serviceName,
      latitude: lat,
      longitude: lng,
      description: description,
      createdAt: DateTime.now(),
      status: 'Pendiente de envío',
    );

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final response = await ref
          .read(fraudRepositoryProvider)
          .submitAnonymousFraud(
            FraudReportRequest(
              idReporte: reportId,
              idServicio: _selectedServiceId,
              descripcion: description,
              lat: lat,
              lng: lng,
            ),
          );

      ref
          .read(fraudHistoryProvider.notifier)
          .addRecord(baseHistoryItem.copyWith(status: 'Enviada'));

      if (!mounted) return;
      setState(() {
        _result = response;
      });
    } catch (e) {
      ref.read(fraudHistoryProvider.notifier).addRecord(baseHistoryItem);

      if (!mounted) return;
      setState(() {
        _errorMessage =
            '${e.toString().replaceFirst('Exception: ', '')} (Guardada en historial local)';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Denuncia anónima de fraude')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Es anónimo: no se envía tu sesión ni datos personales.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reportIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ID del reporte',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || int.tryParse(value.trim()) == null) {
                    return 'Ingresa un número de reporte válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedServiceId,
                decoration: const InputDecoration(
                  labelText: 'Servicio',
                  border: OutlineInputBorder(),
                ),
                items: _serviceNames.entries
                    .map(
                      (entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedServiceId = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitud',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitud',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción de la conexión fraudulenta',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Escribe una descripción';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar denuncia anónima'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_errorMessage!),
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estado: ${_result!.estado}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_result!.motivo != null &&
                            _result!.motivo!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Motivo: ${_result!.motivo}'),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
