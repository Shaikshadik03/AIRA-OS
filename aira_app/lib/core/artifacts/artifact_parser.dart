import 'package:aira_app/core/artifacts/artifact_model.dart';
import 'package:uuid/uuid.dart';

/// Parses and extracts Claude-style and AIRA-style artifacts from LLM text responses
class ArtifactParser {
  static const _uuid = Uuid();

  /// Extracts all artifacts found within an assistant's response text
  static List<AiraArtifact> extractArtifacts(String text) {
    final artifacts = <AiraArtifact>[];
    final seenContents = <String>{};

    // 1. Check for XML tags: <aira_artifact ...> or <antArtifact ...>
    final xmlRegex = RegExp(
      r'<(?:aira_artifact|antArtifact)\s+([^>]*?)>([\s\S]*?)<\/(?:aira_artifact|antArtifact)>',
      caseSensitive: false,
    );

    for (final match in xmlRegex.allMatches(text)) {
      final attrString = match.group(1) ?? '';
      final content = match.group(2)?.trim() ?? '';
      if (content.isEmpty || seenContents.contains(content)) continue;

      final attrs = _parseAttributes(attrString);
      final rawType = (attrs['type'] ?? 'code').toLowerCase();
      final title = attrs['title'] ?? attrs['identifier'] ?? 'AIRA Artifact';
      final lang = attrs['language'] ?? attrs['lang'] ?? rawType;

      final artifactType = _resolveType(rawType, lang);

      artifacts.add(AiraArtifact(
        id: 'art_${_uuid.v4().substring(0, 8)}',
        title: title,
        type: artifactType,
        content: content,
        language: lang,
        createdAt: DateTime.now(),
        metadata: attrs,
      ));
      seenContents.add(content);
    }

    // 2. Check for fenced code blocks with explicit types or titles
    // e.g. ```pdf:Q4_Report or ```pptx:Investor_Deck or ```html or ```dart
    final fenceRegex = RegExp(r'```([a-zA-Z0-9_\-\.\:\s]+)\n([\s\S]*?)```');

    for (final match in fenceRegex.allMatches(text)) {
      final header = match.group(1)?.trim() ?? '';
      final content = match.group(2)?.trim() ?? '';
      if (content.length < 35 || seenContents.contains(content)) continue;

      String typeStr = 'code';
      String title = '';

      if (header.contains(':')) {
        final parts = header.split(':');
        typeStr = parts[0].trim().toLowerCase();
        title = parts.sublist(1).join(':').trim().replaceAll('_', ' ');
      } else {
        typeStr = header.toLowerCase();
      }

      final resolvedType = _resolveType(typeStr, header);
      if (title.isEmpty) {
        title = '${resolvedType.displayName} (${content.split('\n').length} lines)';
      }

      artifacts.add(AiraArtifact(
        id: 'art_${_uuid.v4().substring(0, 8)}',
        title: title,
        type: resolvedType,
        content: content,
        language: typeStr,
        createdAt: DateTime.now(),
      ));
      seenContents.add(content);
    }

    return artifacts;
  }

  /// Strips artifact XML tags from the visible markdown display so chat stays clean
  static String sanitizeTextForDisplay(String text) {
    return text.replaceAllMapped(
      RegExp(
        r'<(?:aira_artifact|antArtifact)\s+([^>]*?)>[\s\S]*?<\/(?:aira_artifact|antArtifact)>',
        caseSensitive: false,
      ),
      (match) {
        final attrs = _parseAttributes(match.group(1) ?? '');
        final title = attrs['title'] ?? 'Artifact';
        final type = (attrs['type'] ?? 'document').toUpperCase();
        return '\n> 📦 **Generated $type:** *$title* (View in Canvas below)\n';
      },
    );
  }

  static ArtifactType _resolveType(String typeStr, String lang) {
    final lower = '$typeStr $lang'.toLowerCase();
    if (lower.contains('pdf')) return ArtifactType.pdf;
    if (lower.contains('docx') || lower.contains('doc') || lower.contains('word')) return ArtifactType.docx;
    if (lower.contains('pptx') || lower.contains('ppt') || lower.contains('slide') || lower.contains('presentation')) return ArtifactType.pptx;
    if (lower.contains('csv') || lower.contains('sheet') || lower.contains('excel') || lower.contains('xlsx')) return ArtifactType.csv;
    if (lower.contains('svg')) return ArtifactType.svg;
    if (lower.contains('html') || lower.contains('web') || lower.contains('react') || lower.contains('vue')) return ArtifactType.html;
    if (lower.contains('markdown') || lower.contains('md')) return ArtifactType.markdown;
    return ArtifactType.code;
  }

  static Map<String, String> _parseAttributes(String attrString) {
    final map = <String, String>{};
    final regex = RegExp(r'([a-zA-Z0-9_\-]+)=(?:"([^"]*)"|([^\s>]+))');
    for (final match in regex.allMatches(attrString)) {
      final key = match.group(1)!.toLowerCase();
      final val = match.group(2) ?? match.group(3) ?? '';
      map[key] = val;
    }
    return map;
  }
}
