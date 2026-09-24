import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates professional PDF documents from structured content or markdown
class PdfArtifactGenerator {
  /// Generates a PDF document as raw bytes
  static Future<Uint8List> generatePdf({
    required String title,
    String? subtitle,
    required String content,
    String? author,
    DateTime? date,
    Map<String, dynamic>? metadata,
  }) async {
    final pdf = pw.Document(
      title: title,
      author: author ?? 'AIRA-OS Autonomous Intelligence',
    );

    final docDate = date ?? DateTime.now();
    final formattedDate =
        '${docDate.year}-${docDate.month.toString().padLeft(2, '0')}-${docDate.day.toString().padLeft(2, '0')}';

    // Parse content lines into sections
    final lines = content.split('\n');
    final widgets = <pw.Widget>[];

    // Document Header
    widgets.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 20),
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.brown, width: 1.5),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'AIRA-OS INTELLIGENCE REPORT',
                  style: pw.TextStyle(
                    color: PdfColors.brown800,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.Text(
                  formattedDate,
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                subtitle,
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey800,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Parse Body
    List<List<String>> tableBuffer = [];
    bool inTable = false;

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i].trim();

      // Table row detection
      if (rawLine.startsWith('|') && rawLine.endsWith('|')) {
        inTable = true;
        // Skip separator row |---|---|
        if (rawLine.contains('---')) continue;

        final cells = rawLine
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cells.isNotEmpty) tableBuffer.add(cells);
        continue;
      } else if (inTable) {
        // Table finished, render buffered table
        if (tableBuffer.isNotEmpty) {
          widgets.add(_buildPdfTable(tableBuffer));
          tableBuffer = [];
        }
        inTable = false;
      }

      if (rawLine.isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
        continue;
      }

      // Headings
      if (rawLine.startsWith('### ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
            child: pw.Text(
              rawLine.replaceFirst('### ', ''),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ),
        );
      } else if (rawLine.startsWith('## ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
            child: pw.Text(
              rawLine.replaceFirst('## ', ''),
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
          ),
        );
      } else if (rawLine.startsWith('# ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
            child: pw.Text(
              rawLine.replaceFirst('# ', ''),
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.brown900,
              ),
            ),
          ),
        );
      } else if (rawLine.startsWith('- ') || rawLine.startsWith('* ')) {
        // Bullet points
        final text = rawLine.substring(2).trim();
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 4,
                  height: 4,
                  margin: const pw.EdgeInsets.only(top: 5, right: 6),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.brown,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    text,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      lineSpacing: 1.3,
                      color: PdfColors.grey900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (rawLine.startsWith('> ')) {
        // Blockquote / Callout Box
        final quoteText = rawLine.substring(2).trim();
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.amber50,
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.brown, width: 3),
              ),
            ),
            child: pw.Text(
              quoteText,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.brown900,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        );
      } else {
        // Standard Paragraph
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Text(
              rawLine,
              style: const pw.TextStyle(
                fontSize: 10,
                lineSpacing: 1.4,
                color: PdfColors.grey900,
              ),
            ),
          ),
        );
      }
    }

    if (tableBuffer.isNotEmpty) {
      widgets.add(_buildPdfTable(tableBuffer));
    }

    // Add multi-page document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (pw.Context context) {
          if (context.pageNumber == 1) return pw.SizedBox();
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by AIRA-OS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => widgets,
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfTable(List<List<String>> tableData) {
    if (tableData.isEmpty) return pw.SizedBox();

    final header = tableData.first;
    final rows = tableData.skip(1).toList();

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.TableHelper.fromTextArray(
        headers: header,
        data: rows,
        headerStyle: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.brown800),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        rowDecoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
        ),
      ),
    );
  }
}
