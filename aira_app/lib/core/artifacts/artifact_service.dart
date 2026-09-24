import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:aira_app/core/artifacts/artifact_model.dart';
import 'package:aira_app/core/artifacts/generators/pdf_generator.dart';
import 'package:aira_app/core/artifacts/generators/docx_generator.dart';
import 'package:aira_app/core/artifacts/generators/pptx_generator.dart';
import 'package:aira_app/core/artifacts/generators/csv_generator.dart';
import 'package:aira_app/core/services/google_workspace_service.dart';

/// Master service for compiling, exporting, and managing Claude-style GenAI Artifacts in AIRA-OS
class ArtifactService {
  static final ArtifactService _instance = ArtifactService._internal();
  factory ArtifactService() => _instance;
  ArtifactService._internal();

  final GoogleWorkspaceService _workspace = GoogleWorkspaceService();

  /// Compiles an artifact into its binary format (PDF bytes, DOCX zip bytes, PPTX zip bytes, CSV, etc.)
  Future<Uint8List> compileArtifactBytes(AiraArtifact artifact) async {
    if (artifact.compiledBytes != null) {
      return artifact.compiledBytes!;
    }

    switch (artifact.type) {
      case ArtifactType.pdf:
        return await PdfArtifactGenerator.generatePdf(
          title: artifact.title,
          content: artifact.content,
        );

      case ArtifactType.docx:
        return DocxArtifactGenerator.generateDocx(
          title: artifact.title,
          content: artifact.content,
        );

      case ArtifactType.pptx:
        return PptxArtifactGenerator.generatePptx(
          title: artifact.title,
          rawMarkdown: artifact.content,
        );

      case ArtifactType.csv:
      case ArtifactType.sheet:
        return CsvArtifactGenerator.generateCsv(
          markdownTable: artifact.content,
        );

      case ArtifactType.html:
      case ArtifactType.svg:
      case ArtifactType.markdown:
      case ArtifactType.code:
        return Uint8List.fromList(utf8.encode(artifact.content));
    }
  }

  /// Saves the compiled artifact file to the local storage or Downloads folder
  Future<String> saveArtifactLocally(AiraArtifact artifact) async {
    final bytes = await compileArtifactBytes(artifact);
    final cleanTitle = artifact.title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_').trim();
    final fileName = cleanTitle.endsWith(artifact.type.fileExtension)
        ? cleanTitle
        : '$cleanTitle${artifact.type.fileExtension}';

    Directory targetDir;
    if (Platform.isAndroid) {
      targetDir = Directory('/storage/emulated/0/Download');
      if (!targetDir.existsSync()) {
        targetDir = Directory.systemTemp;
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\';
      targetDir = Directory('$userProfile\\Downloads');
      if (!targetDir.existsSync()) {
        targetDir = Directory.systemTemp;
      }
    } else {
      targetDir = Directory.systemTemp;
    }

    final file = File('${targetDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Exports artifact directly to Google Drive as an uploaded file
  Future<Map<String, dynamic>> exportToGoogleDrive(AiraArtifact artifact) async {
    final cleanTitle = artifact.title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_').trim();
    final fileName = cleanTitle.endsWith(artifact.type.fileExtension)
        ? cleanTitle
        : '$cleanTitle${artifact.type.fileExtension}';

    return await _workspace.uploadTextFileToDrive(
      filename: fileName,
      content: artifact.content,
    );
  }

  /// Exports artifact directly as a formatted Google Doc
  Future<Map<String, dynamic>> exportToGoogleDoc(AiraArtifact artifact) async {
    return await _workspace.createDoc(
      title: artifact.title,
    );
  }

  /// Exports artifact directly as a Google Sheet
  Future<Map<String, dynamic>> exportToGoogleSheet(AiraArtifact artifact) async {
    final sheetRes = await _workspace.createSheet(title: artifact.title);
    final rows = CsvArtifactGenerator.parseMarkdownTable(artifact.content);
    for (final row in rows) {
      await _workspace.appendSheetRow(
        sheetTarget: artifact.title,
        values: row,
      );
    }

    return sheetRes;
  }
}
