import 'dart:convert';
import 'dart:typed_data';

/// Generates RFC 4180 compliant CSV files from markdown tables or structured rows
class CsvArtifactGenerator {
  /// Converts markdown table text or 2D list into standard CSV bytes
  static Uint8List generateCsv({
    List<List<String>>? rows,
    String? markdownTable,
  }) {
    final parsedRows = rows ?? (markdownTable != null ? parseMarkdownTable(markdownTable) : <List<String>>[]);
    final sb = StringBuffer();

    for (final row in parsedRows) {
      final escapedCells = row.map(_escapeCsvCell).join(',');
      sb.writeln(escapedCells);
    }

    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  /// Parses markdown table lines into 2D List of strings
  static List<List<String>> parseMarkdownTable(String markdown) {
    final result = <List<String>>[];
    final lines = markdown.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) continue;
      // Skip separator row |---|---|
      if (trimmed.contains('---')) continue;

      final cells = trimmed
          .split('|')
          .map((c) => c.trim())
          .toList();

      // Drop first and last empty elements from outer pipes
      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();

      if (cells.isNotEmpty) {
        result.add(cells);
      }
    }

    return result;
  }

  static String _escapeCsvCell(String cell) {
    if (cell.contains(',') || cell.contains('"') || cell.contains('\n') || cell.contains('\r')) {
      final escaped = cell.replaceAll('"', '""');
      return '"$escaped"';
    }
    return cell;
  }
}
