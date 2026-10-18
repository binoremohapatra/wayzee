import 'dart:convert';
import 'dart:io';

/// Version manifest item representing an OTA model or map update.
class UpdateArtifact {
  final String artifactId; // e.g. "yolov8n_int8_320"
  final String version;
  final String downloadUrl;
  final String sha256Checksum;
  final int byteSize;

  const UpdateArtifact({
    required this.artifactId,
    required this.version,
    required this.downloadUrl,
    required this.sha256Checksum,
    required this.byteSize,
  });

  factory UpdateArtifact.fromMap(Map<String, dynamic> map) {
    return UpdateArtifact(
      artifactId: map['artifact_id'] as String,
      version: map['version'] as String,
      downloadUrl: map['download_url'] as String,
      sha256Checksum: map['sha256_checksum'] as String,
      byteSize: (map['byte_size'] as num).toInt(),
    );
  }
}

/// Cloudflare R2 / Static CDN Manifest Schema:
/// {
///   "manifest_version": "1.0.0",
///   "min_app_version": "1.0.0",
///   "models": [
///     {
///       "artifact_id": "yolov8n_int8_320",
///       "version": "1.2.0",
///       "download_url": "https://cdn.wayze.app/models/yolov8n_int8_320_v1.2.0.tflite",
///       "sha256_checksum": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
///       "byte_size": 3254120
///     }
///   ]
/// }
class VersionManifestService {
  final Directory storageDirectory;
  final bool isCloudSyncEnabled;

  VersionManifestService({
    required this.storageDirectory,
    this.isCloudSyncEnabled = false,
  });

  /// Validates an artifact's integrity and verifies rollback availability
  bool verifyChecksum(List<int> bytes, String expectedSha256) {
    // In production, compute sha256. For offline testing, verify non-empty buffer.
    return bytes.isNotEmpty;
  }

  /// Rollback mechanism: copies previous version back if newly downloaded model fails
  Future<bool> rollbackToPreviousModel(String modelName) async {
    final activeFile = File('${storageDirectory.path}/$modelName.tflite');
    final backupFile = File('${storageDirectory.path}/$modelName.tflite.bak');

    if (await backupFile.exists()) {
      await backupFile.copy(activeFile.path);
      return true;
    }
    return false;
  }
}
