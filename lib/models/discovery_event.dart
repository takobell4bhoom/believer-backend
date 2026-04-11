import 'package:flutter/material.dart';

import 'mosque_content.dart';
import 'mosque_model.dart';

class DiscoveryEvent {
  const DiscoveryEvent({
    required this.id,
    required this.sourceMosqueId,
    required this.title,
    required this.type,
    required this.category,
    required this.dateLabel,
    required this.locationLine,
    required this.distanceLabel,
    required this.tags,
    required this.description,
    required this.speakers,
    required this.organizer,
    required this.priceLabel,
    required this.posterHeadline,
    required this.posterHeadlineFont,
    required this.posterLabel,
    required this.posterColors,
    required this.posterStyle,
    required this.shareText,
  });

  final String id;
  final String sourceMosqueId;
  final String title;
  final String type;
  final String category;
  final String dateLabel;
  final String locationLine;
  final String distanceLabel;
  final List<String> tags;
  final String description;
  final List<DiscoveryEventSpeaker> speakers;
  final DiscoveryEventOrganizer organizer;
  final String priceLabel;
  final String posterHeadline;
  final String posterHeadlineFont;
  final String posterLabel;
  final List<Color> posterColors;
  final DiscoveryEventPosterStyle posterStyle;
  final String shareText;

  factory DiscoveryEvent.fromMosque(MosqueModel mosque) {
    final publicPrograms = <String>[
      ...mosque.eventTags,
      ...mosque.classTags,
    ].where((item) => item.trim().isNotEmpty).toList(growable: false);
    final lowerHaystack = [
      mosque.name,
      ...publicPrograms,
    ].join(' ').toLowerCase();
    final type = _deriveType(lowerHaystack, mosque.classTags.isNotEmpty);
    final category = _primaryCategory(mosque);
    final city =
        mosque.city.trim().isEmpty ? 'Nearby community' : mosque.city.trim();
    final state = mosque.state.trim();
    final locationParts = <String>[
      if (mosque.addressLine.trim().isNotEmpty) mosque.addressLine.trim(),
      city,
      if (state.isNotEmpty) state,
    ];
    final locationLine = locationParts.join(', ');

    final posterPalette = _posterPaletteFor(type);
    final posterStyle = switch (type) {
      'Islamic Knowledge' => DiscoveryEventPosterStyle.seerah,
      'Charity' => DiscoveryEventPosterStyle.community,
      _ => DiscoveryEventPosterStyle.generic,
    };

    final title = mosque.name.trim().isEmpty
        ? 'Community event listing'
        : mosque.name.trim();
    final organizerName = mosque.name.trim().isEmpty
        ? 'Mosque organizer'
        : mosque.name.trim();

    return DiscoveryEvent(
      id: mosque.id,
      sourceMosqueId: mosque.id,
      title: title,
      type: type,
      category: category,
      dateLabel: 'Schedule not published',
      locationLine: locationLine,
      distanceLabel: '${mosque.distanceMiles.toStringAsFixed(1)} mi away',
      tags: _buildListingTags(
        type: type,
        category: category,
        hasWomenPrayerArea: mosque.womenPrayerArea,
        hasEventTags: mosque.eventTags.isNotEmpty,
        hasClassTags: mosque.classTags.isNotEmpty,
      ),
      description: _buildListingDescription(
        organizerName: organizerName,
        publicPrograms: publicPrograms,
      ),
      speakers: const <DiscoveryEventSpeaker>[],
      organizer: DiscoveryEventOrganizer(
        name: organizerName,
        description: _buildOrganizerDescription(organizerName: organizerName),
      ),
      priceLabel: '',
      posterHeadline: _posterHeadlineForTitle(title),
      posterHeadlineFont: 'Figtree',
      posterLabel: _posterLabelFor(type),
      posterColors: posterPalette,
      posterStyle: posterStyle,
      shareText: '$title\nSchedule not published\n$locationLine',
    );
  }

  factory DiscoveryEvent.fromMosqueProgram(
    MosqueModel mosque,
    MosqueProgramItem item,
  ) {
    final base = DiscoveryEvent.fromMosque(mosque);
    final type = _deriveTypeForProgram(
      mosque: mosque,
      item: item,
    );
    final title = item.title.trim().isNotEmpty ? item.title.trim() : base.title;
    final category = item.posterLabel.trim().isNotEmpty
        ? item.posterLabel.trim()
        : base.category;
    final locationLine = item.location.trim().isNotEmpty
        ? item.location.trim()
        : base.locationLine;
    final dateLabel =
        item.schedule.trim().isNotEmpty ? item.schedule.trim() : base.dateLabel;
    final description = item.description.trim().isNotEmpty
        ? item.description.trim()
        : base.description;
    final shareParts = <String>[
      title,
      dateLabel,
      locationLine,
    ].where((part) => part.trim().isNotEmpty).toList(growable: false);

    return DiscoveryEvent(
      id: item.id.trim().isNotEmpty ? item.id.trim() : base.id,
      sourceMosqueId: mosque.id,
      title: title,
      type: type,
      category: category,
      dateLabel:
          dateLabel.trim().isEmpty ? 'Schedule not published' : dateLabel,
      locationLine: locationLine,
      distanceLabel: base.distanceLabel,
      tags: _buildProgramTags(
        type: type,
        category: category,
        hasWomenPrayerArea: mosque.womenPrayerArea,
      ),
      description: description.trim().isEmpty
          ? 'Additional event details have not been published yet.'
          : description,
      speakers: const <DiscoveryEventSpeaker>[],
      organizer: DiscoveryEventOrganizer(
        name: base.organizer.name,
        description:
            _buildOrganizerDescription(organizerName: base.organizer.name),
      ),
      priceLabel: '',
      posterHeadline: _posterHeadlineForTitle(title),
      posterHeadlineFont: 'Figtree',
      posterLabel: item.posterLabel.trim().isNotEmpty
          ? item.posterLabel.trim()
          : base.posterLabel,
      posterColors: _posterPaletteFor(type),
      posterStyle: switch (type) {
        'Islamic Knowledge' => DiscoveryEventPosterStyle.seerah,
        'Charity' => DiscoveryEventPosterStyle.community,
        _ => DiscoveryEventPosterStyle.generic,
      },
      shareText: shareParts.join('\n'),
    );
  }

  static String _deriveTypeForProgram({
    required MosqueModel mosque,
    required MosqueProgramItem item,
  }) {
    final haystack = [
      item.title,
      item.posterLabel,
      item.schedule,
      item.location,
      item.description,
      mosque.name,
      mosque.city,
      mosque.state,
    ].join(' ').toLowerCase();
    final isClassProgram = mosque.classes.any(
      (candidate) =>
          identical(candidate, item) ||
          (candidate.id.trim().isNotEmpty &&
              candidate.id.trim() == item.id.trim()),
    );
    return _deriveType(haystack, isClassProgram);
  }

  static String _deriveType(String haystack, bool hasClassTags) {
    if (_containsAny(
      haystack,
      const ['zakat', 'sadaqah', 'food', 'donation', 'fund', 'volunteer'],
    )) {
      return 'Charity';
    }

    if (_containsAny(
          haystack,
          const ['quran', 'lecture', 'tafsir', 'halaqa', 'seerah', 'history'],
        ) ||
        hasClassTags) {
      return 'Islamic Knowledge';
    }

    return 'Celebration';
  }

  static bool _containsAny(String haystack, Iterable<String> needles) {
    return needles.any(haystack.contains);
  }

  static String _primaryCategory(MosqueModel mosque) {
    final source = <String>[
      ...mosque.eventTags,
      ...mosque.classTags,
    ];
    return source.firstWhere(
      (item) => item.trim().isNotEmpty,
      orElse: () => 'Community Gathering',
    );
  }

  static List<String> _buildListingTags({
    required String type,
    required String category,
    required bool hasWomenPrayerArea,
    required bool hasEventTags,
    required bool hasClassTags,
  }) {
    final tags = <String>[
      type,
      if (category.trim().isNotEmpty && category.trim() != type) category,
      if (hasWomenPrayerArea) 'Men & Women',
      if (hasEventTags) 'Event listing',
      if (hasClassTags) 'Class listing',
    ];

    return tags.take(3).toList(growable: false);
  }

  static List<String> _buildProgramTags({
    required String type,
    required String category,
    required bool hasWomenPrayerArea,
  }) {
    final tags = <String>[
      if (category.trim().isNotEmpty) category,
      type,
      if (hasWomenPrayerArea) 'Men & Women',
    ];

    return tags.take(3).toList(growable: false);
  }

  static String _buildListingDescription({
    required String organizerName,
    required List<String> publicPrograms,
  }) {
    if (publicPrograms.isEmpty) {
      return 'This public listing is tied to $organizerName, but full event details have not been published yet. Open the organizer page for the latest schedule and contact information.';
    }

    final preview = publicPrograms.take(2).join(' and ');
    return 'This mosque is currently showing public program listings for $preview. Open the organizer page for timing, location updates, and any newer details.';
  }

  static String _buildOrganizerDescription({
    required String organizerName,
  }) {
    return 'Public event information for this listing is published by $organizerName.';
  }

  static List<Color> _posterPaletteFor(String type) {
    return switch (type) {
      'Charity' => const [Color(0xFF789680), Color(0xFF4F6856)],
      'Islamic Knowledge' => const [Color(0xFFF0D7A7), Color(0xFFDAB477)],
      _ => const [Color(0xFF6588A7), Color(0xFF94B6A7)],
    };
  }

  static String _posterHeadlineForTitle(String title) {
    final words = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.toUpperCase())
        .toList(growable: false);

    if (words.isEmpty) {
      return 'EVENT';
    }

    if (words.length == 1) {
      return words.first;
    }

    return '${words.first}\n${words.last}';
  }

  static String _posterLabelFor(String type) {
    return switch (type) {
      'Charity' => 'Charity',
      'Islamic Knowledge' => 'Knowledge',
      _ => 'Celebration',
    };
  }
}

class DiscoveryEventSpeaker {
  const DiscoveryEventSpeaker({
    required this.name,
    required this.bio,
    required this.initials,
    required this.avatarColors,
  });

  final String name;
  final String bio;
  final String initials;
  final List<Color> avatarColors;
}

class DiscoveryEventOrganizer {
  const DiscoveryEventOrganizer({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;
}

enum DiscoveryEventPosterStyle { seerah, community, generic }
