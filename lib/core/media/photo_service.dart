import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final photoServiceProvider = Provider<PhotoService>(
  (ref) => DevicePhotoService(),
);

/// La foto elegida no se pudo preparar (formato no compatible o muy pesada).
class PhotoException implements Exception {
  const PhotoException();

  @override
  String toString() => 'PhotoException';
}

abstract interface class PhotoService {
  /// Abre la cámara (o la galería) y devuelve la ruta de la foto ya
  /// comprimida y sin EXIF, o `null` si el usuario canceló.
  Future<String?> pick({required bool fromCamera});
}

class DevicePhotoService implements PhotoService {
  static const _maxSide = 1280;
  static const _targetBytes = 500 * 1024;
  static const _backendMaxBytes = 2 * 1024 * 1024;

  final _picker = ImagePicker();

  @override
  Future<String?> pick({required bool fromCamera}) async {
    // image_picker reduce el lado mayor a 1280 px; la compresión posterior
    // baja la calidad y quita el EXIF (incluida la ubicación GPS de la foto).
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: _maxSide.toDouble(),
      maxHeight: _maxSide.toDouble(),
    );
    if (picked == null) return null;

    final compressed = await _compressSafely(picked.path);
    if (compressed != null) return compressed;

    // Si la compresión falla (pasa con algunos formatos o emuladores), sirve
    // la foto original solo si ya es JPEG y cabe en el límite del backend
    // (2 MB); Reportes además le quita el EXIF al guardarla.
    final lower = picked.path.toLowerCase();
    final isJpeg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');
    if (isJpeg && await File(picked.path).length() <= _backendMaxBytes) {
      return picked.path;
    }
    throw const PhotoException();
  }

  /// Comprime a JPEG y devuelve la ruta, o `null` si no se pudo.
  Future<String?> _compressSafely(String source) async {
    try {
      var result = await _compress(source, quality: 70);
      if (result != null && await result.length() > _targetBytes) {
        result = await _compress(source, quality: 55);
      }
      return result?.path;
    } on Object {
      // El plugin puede lanzar errores (no solo excepciones) con formatos raros.
      return null;
    }
  }

  Future<XFile?> _compress(String source, {required int quality}) {
    final target = source.replaceFirst(
      RegExp(r'\.[^./\\]+$'),
      '_servired_q$quality.jpg',
    );
    return FlutterImageCompress.compressAndGetFile(
      source,
      target == source ? '$source.servired.jpg' : target,
      quality: quality,
      minWidth: _maxSide,
      minHeight: _maxSide,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
  }
}
