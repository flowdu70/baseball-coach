import 'package:file_picker/file_picker.dart';

class VideoImporterService {
  /// Ouvre un sélecteur de fichier vidéo
  /// Retourne le chemin du fichier ou null si annulé
  static Future<String?> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }
}
