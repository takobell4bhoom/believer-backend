import 'package:flutter/material.dart';

import '../models/mosque_content.dart';
import '../theme/app_colors.dart';

class MosqueAdminEventDraft {
  MosqueAdminEventDraft({
    required this.id,
    String title = '',
    String schedule = '',
    String posterLabel = '',
    String location = '',
    String description = '',
  })  : titleController = TextEditingController(text: title),
        scheduleController = TextEditingController(text: schedule),
        posterLabelController = TextEditingController(text: posterLabel),
        locationController = TextEditingController(text: location),
        descriptionController = TextEditingController(text: description);

  factory MosqueAdminEventDraft.empty() {
    return MosqueAdminEventDraft(id: '');
  }

  factory MosqueAdminEventDraft.fromProgramItem(MosqueProgramItem item) {
    return MosqueAdminEventDraft(
      id: item.id,
      title: item.title,
      schedule: item.schedule,
      posterLabel: item.posterLabel,
      location: item.location,
      description: item.description,
    );
  }

  final String id;
  final TextEditingController titleController;
  final TextEditingController scheduleController;
  final TextEditingController posterLabelController;
  final TextEditingController locationController;
  final TextEditingController descriptionController;

  Map<String, dynamic>? toPayload() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      return null;
    }

    final schedule = scheduleController.text.trim();
    final posterLabel = posterLabelController.text.trim();
    final location = locationController.text.trim();
    final description = descriptionController.text.trim();

    return <String, dynamic>{
      if (id.trim().isNotEmpty) 'id': id.trim(),
      'title': title,
      'schedule': schedule,
      'posterLabel': posterLabel,
      if (location.isNotEmpty) 'location': location,
      if (description.isNotEmpty) 'description': description,
    };
  }

  void dispose() {
    titleController.dispose();
    scheduleController.dispose();
    posterLabelController.dispose();
    locationController.dispose();
    descriptionController.dispose();
  }
}

class MosqueAdminEventEditor extends StatelessWidget {
  const MosqueAdminEventEditor({
    super.key,
    required this.drafts,
    required this.onAddEvent,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    this.maxEvents = 12,
  });

  final List<MosqueAdminEventDraft> drafts;
  final VoidCallback onAddEvent;
  final ValueChanged<int> onMoveUp;
  final ValueChanged<int> onMoveDown;
  final ValueChanged<int> onRemove;
  final int maxEvents;

  @override
  Widget build(BuildContext context) {
    final canAddMore = drafts.length < maxEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saved events publish directly to the current Mosque Page event rail and the existing Home featured-event reuse path. Public surfaces currently emphasize title, timing, and badge text first.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 12),
        if (drafts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text(
              'No published mosque events yet. Add one when this mosque has a live community event ready to show.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.mutedText,
              ),
            ),
          ),
        for (var i = 0; i < drafts.length; i += 1) ...[
          if (i > 0) const SizedBox(height: 12),
          _EventDraftCard(
            index: i,
            draft: drafts[i],
            onMoveUp: i == 0 ? null : () => onMoveUp(i),
            onMoveDown: i == drafts.length - 1 ? null : () => onMoveDown(i),
            onRemove: () => onRemove(i),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('event-add'),
          onPressed: canAddMore ? onAddEvent : null,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            canAddMore ? 'Add Event' : 'Maximum $maxEvents events',
          ),
        ),
      ],
    );
  }
}

class _EventDraftCard extends StatelessWidget {
  const _EventDraftCard({
    required this.index,
    required this.draft,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });

  final int index;
  final MosqueAdminEventDraft draft;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

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
            children: [
              Expanded(
                child: Text(
                  'Published Event ${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('event-move-up-$index'),
                tooltip: 'Move up',
                onPressed: onMoveUp,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                key: ValueKey('event-move-down-$index'),
                tooltip: 'Move down',
                onPressed: onMoveDown,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                key: ValueKey('event-remove-$index'),
                tooltip: 'Remove event',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AdminEventField(
            fieldKey: ValueKey('event-title-$index'),
            label: 'Event Title',
            controller: draft.titleController,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AdminEventField(
                  fieldKey: ValueKey('event-schedule-$index'),
                  label: 'Date and time label',
                  hintText: 'Fri, Apr 12 • 7:30 PM',
                  controller: draft.scheduleController,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdminEventField(
                  fieldKey: ValueKey('event-poster-$index'),
                  label: 'Badge text',
                  hintText: 'Youth',
                  controller: draft.posterLabelController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AdminEventField(
            fieldKey: ValueKey('event-location-$index'),
            label: 'Location',
            hintText: 'Main Prayer Hall',
            controller: draft.locationController,
          ),
          const SizedBox(height: 10),
          _AdminEventField(
            fieldKey: ValueKey('event-description-$index'),
            label: 'Short details',
            hintText: 'Optional notes for future event surfaces.',
            controller: draft.descriptionController,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _AdminEventField extends StatelessWidget {
  const _AdminEventField({
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryText,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}
