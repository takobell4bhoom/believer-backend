import 'package:flutter/material.dart';

import '../models/broadcast_message.dart';
import '../theme/app_colors.dart';

class MosqueAdminBroadcastEditor extends StatelessWidget {
  const MosqueAdminBroadcastEditor({
    super.key,
    required this.titleController,
    required this.messageController,
    required this.publishedMessages,
    required this.isPublishing,
    required this.removingBroadcastIds,
    required this.onPublish,
    required this.onRemove,
  });

  final TextEditingController titleController;
  final TextEditingController messageController;
  final List<BroadcastMessage> publishedMessages;
  final bool isPublishing;
  final Set<String> removingBroadcastIds;
  final VoidCallback onPublish;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Publish short mosque-page updates here. New messages appear on the Mosque Page preview and the full Mosque Broadcast screen using the existing persisted read path.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 12),
        if (publishedMessages.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text(
              'No broadcast messages have been published for this mosque yet.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.mutedText,
              ),
            ),
          ),
        for (var i = 0; i < publishedMessages.length; i += 1) ...[
          if (i > 0) const SizedBox(height: 12),
          _PublishedBroadcastCard(
            index: i,
            message: publishedMessages[i],
            isRemoving:
                removingBroadcastIds.contains(publishedMessages[i].id ?? ''),
            onRemove: publishedMessages[i].id == null
                ? null
                : () => onRemove(publishedMessages[i].id!),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compose New Broadcast',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 10),
              _BroadcastField(
                fieldKey: const ValueKey('broadcast-title-input'),
                label: 'Title',
                hintText: 'Jummah Parking Update',
                controller: titleController,
              ),
              const SizedBox(height: 10),
              _BroadcastField(
                fieldKey: const ValueKey('broadcast-message-input'),
                label: 'Message',
                hintText: 'Share the practical update mosque visitors need.',
                controller: messageController,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('broadcast-publish'),
                  onPressed: isPublishing ? null : onPublish,
                  icon: isPublishing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: Text(
                    isPublishing ? 'Publishing...' : 'Publish Broadcast',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PublishedBroadcastCard extends StatelessWidget {
  const _PublishedBroadcastCard({
    required this.index,
    required this.message,
    required this.isRemoving,
    this.onRemove,
  });

  final int index;
  final BroadcastMessage message;
  final bool isRemoving;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    if (message.displayDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message.displayDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('broadcast-remove-$index'),
                tooltip: 'Remove message',
                onPressed: isRemoving ? null : onRemove,
                icon: isRemoving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastField extends StatelessWidget {
  const _BroadcastField({
    required this.label,
    required this.controller,
    this.fieldKey,
    this.hintText,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final String? hintText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
    );
  }
}
