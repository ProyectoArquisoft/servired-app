import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final photoServiceProvider = Provider<PhotoService>(
  (ref) => DevicePhotoService(),
);

abstract interface class PhotoService {
  /// Abre la cámara (o la galería) y devuelve la ruta de la foto ya
  /// comprimida y sin EXIF, o `null` si el usuario canceló.
  Future<String?> pick({required bool fromCamera});
}

class DevicePhotoService implements PhotoService {
  static const _maxSide = 1280;
  static const _targetBytes = 500 * 1024;

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

    var compressed = await _compress(picked.path, quality: 70);
    if (compressed != null && await compressed.length() > _targetBytes) {
      compressed = await _compress(picked.path, quality: 55);
    }
    return compressed?.path;
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
