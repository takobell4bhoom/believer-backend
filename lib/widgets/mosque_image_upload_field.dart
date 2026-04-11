import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'mosque_image_frame.dart';

class MosqueImageUploadField extends StatelessWidget {
  const MosqueImageUploadField({
    super.key,
    required this.imageUrls,
    required this.onPickImage,
    required this.onUploadImage,
    required this.isUploading,
    this.maxImages = 10,
    this.pendingImageBytes,
    this.pendingFileName,
    this.errorText,
    this.onClearSelection,
    this.onRemoveImage,
    this.onMakePrimary,
  });

  final List<String> imageUrls;
  final int maxImages;
  final Uint8List? pendingImageBytes;
  final String? pendingFileName;
  final String? errorText;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback onUploadImage;
  final VoidCallback? onClearSelection;
  final ValueChanged<int>? onRemoveImage;
  final ValueChanged<int>? onMakePrimary;

  bool get _hasPendingImage => pendingImageBytes != null;

  @override
  Widget build(BuildContext context) {
    final primaryImageUrl = imageUrls.isNotEmpty ? imageUrls.first : '';
    final hasSavedImages = imageUrls.isNotEmpty;
    final hasReachedMax = imageUrls.length >= maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mosque Images',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose an image, preview it, then upload it to save backend-owned mosque images.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.mutedText,
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Best fit: upload landscape JPG, PNG, or WebP images, ideally 1600 x 900 or larger. Up to 10 images.',
                key: ValueKey('mosque-image-guidance-note'),
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.mutedText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MosqueImageFrame(
          width: double.infinity,
          borderRadius: BorderRadius.circular(12),
          child: _hasPendingImage
              ? Image.memory(
                  pendingImageBytes!,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.1),
                  errorBuilder: (_, __, ___) => const _PreviewPlaceholder(
                    message: 'Selected image preview is unavailable',
                  ),
                )
              : hasSavedImages
                  ? Image.network(
                      primaryImageUrl,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.1),
                      errorBuilder: (_, __, ___) => const _PreviewPlaceholder(
                        message: 'Saved image could not be loaded',
                      ),
                    )
                  : const _PreviewPlaceholder(
                      message: 'Image preview will appear here',
                    ),
        ),
        const SizedBox(height: 10),
        if (_hasPendingImage && pendingFileName != null) ...[
          Text(
            pendingFileName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
        ] else if (hasSavedImages) ...[
          Text(
            '${imageUrls.length} of $maxImages images uploaded. The first image is used as the cover photo.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              key: const ValueKey('mosque-image-browse'),
              onPressed:
                  hasReachedMax && !_hasPendingImage ? null : onPickImage,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _hasPendingImage
                    ? 'Choose Another Image'
                    : hasSavedImages
                        ? 'Add Another Image'
                        : 'Browse Image',
              ),
            ),
            FilledButton(
              key: const ValueKey('mosque-image-upload'),
              onPressed:
                  _hasPendingImage && !isUploading ? onUploadImage : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentSoft,
                foregroundColor: AppColors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isUploading ? 'Uploading...' : 'Upload Image'),
            ),
            if (_hasPendingImage && onClearSelection != null)
              TextButton(
                key: const ValueKey('mosque-image-clear'),
                onPressed: isUploading ? null : onClearSelection,
                child: const Text('Clear Selection'),
              ),
          ],
        ),
        if (hasReachedMax && !_hasPendingImage) ...[
          const SizedBox(height: 8),
          const Text(
            'Maximum of 10 images reached. Remove one to upload another.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedText,
            ),
          ),
        ],
        if (imageUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final imageUrl = imageUrls[index];
                final isPrimary = index == 0;
                return _SavedImageCard(
                  imageUrl: imageUrl,
                  imageNumber: index + 1,
                  isPrimary: isPrimary,
                  onMakePrimary: isPrimary || onMakePrimary == null
                      ? null
                      : () => onMakePrimary!(index),
                  onRemove: onRemoveImage == null
                      ? null
                      : () => onRemoveImage!(index),
                );
              },
            ),
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _SavedImageCard extends StatelessWidget {
  const _SavedImageCard({
    required this.imageUrl,
    required this.imageNumber,
    required this.isPrimary,
    this.onMakePrimary,
    this.onRemove,
  });

  final String imageUrl;
  final int imageNumber;
  final bool isPrimary;
  final VoidCallback? onMakePrimary;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                MosqueImageFrame(
                  width: 180,
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.1),
                    errorBuilder: (_, __, ___) => const _PreviewPlaceholder(
                      message: 'Saved image could not be loaded',
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? const Color(0xFF2C5E4E)
                          : const Color(0x88102325),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isPrimary ? 'Cover image' : 'Image $imageNumber',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onMakePrimary != null)
                OutlinedButton(
                  key: ValueKey('mosque-image-make-primary-$imageNumber'),
                  onPressed: onMakePrimary,
                  child: const Text('Set as Cover'),
                ),
              if (onRemove != null)
                TextButton(
                  key: ValueKey('mosque-image-remove-$imageNumber'),
                  onPressed: onRemove,
                  child: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MosqueImagePlaceholder(
      message: message,
      iconSize: 30,
    );
  }
}
