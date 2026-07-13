import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/aira_button.dart';
import 'package:aira_app/core/widgets/aira_text_field.dart';
import 'package:aira_app/features/creative/presentation/providers/creative_provider.dart';

class CreativeScreen extends ConsumerStatefulWidget {
  const CreativeScreen({super.key});

  @override
  ConsumerState<CreativeScreen> createState() => _CreativeScreenState();
}

class _CreativeScreenState extends ConsumerState<CreativeScreen> {
  final _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creativeProvider);

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.palette_outlined, color: AiraColors.electricCyan, size: 24),
            const SizedBox(width: 8),
            Text('Creative Studio', style: AiraTypography.h4),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AiraTextField(
                    controller: _promptController,
                    hintText: 'A futuristic cybernetic city, electric cyan light...',
                  ),
                ),
                const SizedBox(width: 8),
                AiraButton(
                  label: 'Generate',
                  onPressed: () {
                    final prompt = _promptController.text.trim();
                    if (prompt.isEmpty) return;
                    ref.read(creativeProvider.notifier).generateImage(prompt);
                    _promptController.clear();
                  },
                  isLoading: state.isLoading,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: state.isLoading && state.galleryUrls.isEmpty
                  ? _buildLoadingState()
                  : state.galleryUrls.isEmpty
                      ? _buildEmptyState()
                      : _buildGalleryGrid(state),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AiraColors.electricCyan),
          const SizedBox(height: 16),
          Text(
            'Creating your art...\nThis takes a few seconds',
            style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_search_rounded,
            size: 56,
            color: AiraColors.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Create AI Art',
            style: AiraTypography.h5.copyWith(color: AiraColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a descriptive prompt above to generate\nhigh-resolution futuristic illustrations.',
            style: AiraTypography.bodySmall.copyWith(
              color: AiraColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(CreativeState state) {
    return GridView.builder(
      itemCount: state.isLoading ? state.galleryUrls.length + 1 : state.galleryUrls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        if (state.isLoading && index == 0) {
          return Shimmer.fromColors(
            baseColor: AiraColors.surfaceDark,
            highlightColor: AiraColors.surfaceLight,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }
        
        final urlIndex = state.isLoading ? index - 1 : index;
        final url = state.galleryUrls[urlIndex];

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            onTap: () => _viewFullImage(url),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AiraColors.surfaceDark,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AiraColors.electricCyan),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AiraColors.surfaceDark,
                child: const Icon(Icons.broken_image_outlined, color: AiraColors.error),
              ),
            ),
          ),
        );
      },
    );
  }

  void _viewFullImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('Close', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
