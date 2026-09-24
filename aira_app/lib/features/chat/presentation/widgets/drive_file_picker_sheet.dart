import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/services/google_workspace_service.dart';

class DriveFilePickerSheet extends StatefulWidget {
  final Function(Map<String, dynamic> file) onFileSelected;

  const DriveFilePickerSheet({
    super.key,
    required this.onFileSelected,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Function(Map<String, dynamic> file) onFileSelected,
  }) {
    final theme = Theme.of(context);

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.75,
        child: DriveFilePickerSheet(
          onFileSelected: (file) {
            Navigator.pop(ctx, file);
            onFileSelected(file);
          },
        ),
      ),
    );
  }

  @override
  State<DriveFilePickerSheet> createState() => _DriveFilePickerSheetState();
}

class _DriveFilePickerSheetState extends State<DriveFilePickerSheet> {
  final GoogleWorkspaceService _workspace = GoogleWorkspaceService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles([String? query]) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final results = (query != null && query.trim().isNotEmpty)
          ? await _workspace.searchDriveFiles(query.trim())
          : await _workspace.listRecentDriveFiles();

      if (mounted) {
        setState(() {
          _files = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load Google Drive files: $e';
          _isLoading = false;
        });
      }
    }
  }

  IconData _getFileIcon(String mimeType, String name) {
    if (mimeType.contains('folder')) return Icons.folder_rounded;
    if (mimeType.contains('document') || name.endsWith('.gdoc') || name.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    if (mimeType.contains('spreadsheet') || name.endsWith('.gsheet') || name.endsWith('.xlsx')) {
      return Icons.table_chart_rounded;
    }
    if (mimeType.contains('pdf') || name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    }
    if (mimeType.contains('presentation') || name.endsWith('.pptx')) {
      return Icons.slideshow_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String mimeType, String name) {
    if (mimeType.contains('folder')) return Colors.amber.shade700;
    if (mimeType.contains('document') || name.endsWith('.gdoc')) return Colors.blue.shade600;
    if (mimeType.contains('spreadsheet') || name.endsWith('.gsheet')) return Colors.green.shade600;
    if (mimeType.contains('pdf') || name.endsWith('.pdf')) return Colors.red.shade600;
    return AiraColors.claudeTerracotta;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).padding.bottom + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.shade800.withValues(alpha: isDark ? 0.2 : 0.12),
                ),
                child: Icon(Icons.add_to_drive_rounded, color: Colors.amber.shade800, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Drive Files',
                      style: GoogleFonts.playfairDisplay(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _workspace.isConnected
                          ? 'Select a document or file to reference in chat'
                          : 'Workspace Sandbox Active (Preview Mode)',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 12,
                        color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => _loadFiles(_searchController.text),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _searchController,
              onSubmitted: (q) => _loadFiles(q),
              style: GoogleFonts.sourceSerif4(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search Drive files & folders...',
                hintStyle: GoogleFonts.sourceSerif4(
                  fontSize: 13.5,
                  color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AiraColors.claudeTerracotta),
                    ),
                  )
                : _error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _error,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.sourceSerif4(
                              color: AiraColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : _files.isEmpty
                        ? Center(
                            child: Text(
                              'No files found.',
                              style: GoogleFonts.sourceSerif4(
                                fontSize: 14,
                                color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _files.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final f = _files[index];
                              final name = f['name'] as String? ?? 'Untitled';
                              final mime = f['mimeType'] as String? ?? '';
                              final size = f['size'] as String? ?? '';

                              final iconData = _getFileIcon(mime, name);
                              final iconColor = _getFileColor(mime, name);

                              return InkWell(
                                onTap: () => widget.onFileSelected(f),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                        ),
                                        child: Icon(iconData, color: iconColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.sourceSerif4(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              size.isNotEmpty ? '$size • Google Drive' : 'Google Drive File',
                                              style: GoogleFonts.sourceSerif4(
                                                fontSize: 11.5,
                                                color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 18,
                                        color: AiraColors.claudeTerracotta,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
