import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aira_app/core/theme/aira_colors.dart';

class ArtifactCanvasScreen extends StatefulWidget {
  final String title;
  final String content;
  final String language;

  const ArtifactCanvasScreen({
    super.key,
    required this.title,
    required this.content,
    this.language = 'code',
  });

  @override
  State<ArtifactCanvasScreen> createState() => _ArtifactCanvasScreenState();
}

class _ArtifactCanvasScreenState extends State<ArtifactCanvasScreen> {
  bool _showPreview = false;
  final bool _showLineNumbers = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMarkdown = widget.language.toLowerCase() == 'markdown' || widget.language.toLowerCase() == 'md';

    final lines = widget.content.split('\n');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141311) : const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1B18) : const Color(0xFFF3F1EC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.sourceSerif4(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              widget.language.toUpperCase(),
              style: GoogleFonts.sourceSerif4(
                color: AiraColors.claudeTerracotta,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          if (isMarkdown)
            IconButton(
              icon: Icon(
                _showPreview ? Icons.code_rounded : Icons.preview_rounded,
                color: theme.colorScheme.onSurface,
                size: 20,
              ),
              tooltip: _showPreview ? 'View Source' : 'View Preview',
              onPressed: () => setState(() => _showPreview = !_showPreview),
            ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AiraColors.claudeTerracotta, size: 20),
            tooltip: 'Copy code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.content));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied ${widget.title} to clipboard'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _showPreview && isMarkdown
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: MarkdownBody(
                data: widget.content,
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.sourceSerif4(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                    height: 1.6,
                  ),
                  h1: GoogleFonts.playfairDisplay(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                  h2: GoogleFonts.playfairDisplay(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
                selectable: true,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1D1A) : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AiraColors.borderDark : AiraColors.borderLight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showLineNumbers)
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(lines.length, (index) {
                            return Text(
                              '${index + 1}',
                              style: GoogleFonts.firaCode(
                                fontSize: 13,
                                color: isDark ? Colors.white24 : Colors.black26,
                                height: 1.5,
                              ),
                            );
                          }),
                        ),
                      ),
                    Expanded(
                      child: SelectableText(
                        widget.content,
                        style: GoogleFonts.firaCode(
                          fontSize: 13.5,
                          color: isDark ? const Color(0xFFECEBE6) : const Color(0xFF1E1E1C),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
