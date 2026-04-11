import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/models/broadcast_message.dart';
import 'package:believer/models/mosque_content.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/models/prayer_timings.dart';
import 'package:believer/screens/mosque_admin_edit_screen.dart';
import 'package:believer/services/browser_image_picker.dart';
import 'package:believer/services/mosque_service.dart';

class _AdminAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'admin-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 'admin-1',
        fullName: 'Admin User',
        email: 'admin@example.com',
        role: 'admin',
      ),
    );
  }
}

class _RecordingMosqueService extends MosqueService {
  Map<String, dynamic>? lastPayload;
  String? lastBearerToken;
  MosqueImageUploadFile? lastUploadFile;
  int uploadCalls = 0;
  int updateCalls = 0;
  String? lastPublishedTitle;
  String? lastPublishedDescription;
  final List<String> deletedBroadcastIds = <String>[];
  List<BroadcastMessage> publishedBroadcasts = <BroadcastMessage>[
    const BroadcastMessage(
      id: 'broadcast-1',
      title: 'Parking Reminder',
      description: 'Use the overflow lot this Friday.',
      date: 'Today',
    ),
  ];

  @override
  Future<MosqueContent> getMosqueContent(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const MosqueContent(
      events: [
        MosqueProgramItem(
          id: 'event-1',
          title: 'Weekend Family Night',
          schedule: 'This Sat',
          posterLabel: 'Family',
          location: 'Community Hall',
          description: 'Weekly dinner and reminder circle.',
        ),
      ],
      classes: [
        MosqueProgramItem(
          id: 'class-1',
          title: 'Quran Circle',
          schedule: 'Tue 7 PM',
          posterLabel: 'Quran',
        ),
      ],
      connect: [
        MosqueConnectLink(
          id: 'connect-1',
          type: 'instagram',
          label: 'instagram.com/testmosque',
          value: 'instagram.com/testmosque',
        ),
      ],
      about: MosqueAboutContent(
        title: 'About Test Mosque',
        body: 'A welcoming place for prayer and reflection.',
      ),
    );
  }

  @override
  Future<PrayerTimings> getPrayerTimings({
    required String mosqueId,
    required String date,
    String? bearerToken,
  }) async {
    return const PrayerTimings(
      mosqueId: 'mosque-1',
      date: '2026-03-30',
      status: 'ready',
      isConfigured: true,
      isAvailable: true,
      source: 'cache',
      unavailableReason: null,
      timezone: 'Asia/Kolkata',
      configuration: PrayerTimeConfiguration(
        enabled: true,
        latitude: 12.9716,
        longitude: 77.5946,
        calculationMethodId: 3,
        calculationMethodName: 'Muslim World League',
        school: 'hanafi',
        schoolLabel: 'Hanafi',
        adjustments: {
          'fajr': 1,
          'sunrise': 0,
          'dhuhr': 2,
          'asr': 0,
          'maghrib': -1,
          'isha': 0,
        },
      ),
      timings: {
        'fajr': '05:08 AM',
        'sunrise': '06:18 AM',
        'dhuhr': '12:31 PM',
        'asr': '04:02 PM',
        'maghrib': '06:41 PM',
        'isha': '07:55 PM',
      },
      nextPrayer: 'Asr',
      nextPrayerTime: '04:02 PM',
      cachedAt: '2026-03-30T04:00:00.000Z',
    );
  }

  @override
  Future<List<BroadcastMessage>> getMosqueBroadcastMessages(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return List<BroadcastMessage>.from(publishedBroadcasts);
  }

  @override
  Future<MosqueAdminUpdateResult> updateMosque({
    required String mosqueId,
    required Map<String, dynamic> payload,
    String? bearerToken,
  }) async {
    updateCalls += 1;
    lastPayload = payload;
    lastBearerToken = bearerToken;

    return const MosqueAdminUpdateResult(
      mosque: MosqueModel(
        id: 'mosque-1',
        name: 'Updated Test Mosque',
        addressLine: '12 Unity Street',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        latitude: 12.9716,
        longitude: 77.5946,
        imageUrl: 'https://example.org/updated.jpg',
        imageUrls: <String>[
          'https://example.org/updated.jpg',
          'https://example.org/updated-2.jpg',
        ],
        rating: 4.0,
        distanceMiles: 0,
        sect: 'Community',
        womenPrayerArea: true,
        parking: true,
        wudu: true,
        facilities: <String>['women_area', 'parking', 'wudu'],
        isVerified: false,
        isBookmarked: false,
        duhrTime: '01:15 PM',
        asarTime: '04:45 PM',
        isOpenNow: false,
        classTags: <String>[],
        eventTags: <String>[],
      ),
      content: MosqueContent(
        events: [
          MosqueProgramItem(
            id: 'event-1',
            title: 'Updated Family Night',
            schedule: 'Fri 7 PM',
            posterLabel: 'Family',
            location: 'Prayer Hall',
            description: 'Updated event details.',
          ),
        ],
        classes: [],
        connect: [],
        about: MosqueAboutContent(
          title: 'Updated About',
          body: 'Updated description.',
        ),
      ),
    );
  }

  @override
  Future<BroadcastMessage> publishMosqueBroadcast({
    required String mosqueId,
    required String title,
    required String description,
    String? bearerToken,
  }) async {
    lastBearerToken = bearerToken;
    lastPublishedTitle = title;
    lastPublishedDescription = description;
    final message = BroadcastMessage(
      id: 'broadcast-${publishedBroadcasts.length + 1}',
      title: title,
      description: description,
      date: 'Today',
    );
    publishedBroadcasts = [message, ...publishedBroadcasts];
    return message;
  }

  @override
  Future<void> deleteMosqueBroadcast({
    required String mosqueId,
    required String broadcastId,
    String? bearerToken,
  }) async {
    lastBearerToken = bearerToken;
    deletedBroadcastIds.add(broadcastId);
    publishedBroadcasts = publishedBroadcasts
        .where((item) => item.id != broadcastId)
        .toList(growable: false);
  }

  @override
  Future<MosqueUploadedImage> uploadMosqueImage({
    required MosqueImageUploadFile file,
    String? bearerToken,
  }) async {
    lastUploadFile = file;
    lastBearerToken = bearerToken;
    uploadCalls += 1;
    return MosqueUploadedImage(
      imageUrl:
          'http://localhost:4000/uploads/mosques/updated-$uploadCalls.jpg',
      imagePath: '/uploads/mosques/updated-$uploadCalls.jpg',
      fileName: 'updated-$uploadCalls.jpg',
    );
  }
}

class _FakeBrowserImagePicker implements BrowserImagePicker {
  @override
  Future<BrowserPickedImage?> pickImage() async {
    return BrowserPickedImage(
      fileName: 'replacement.png',
      bytes: Uint8List.fromList(const <int>[8, 9, 10, 11]),
      contentType: 'image/png',
    );
  }
}

void main() {
  testWidgets('admin users submit mosque detail and page content payload',
      (tester) async {
    final service = _RecordingMosqueService();
    final imagePicker = _FakeBrowserImagePicker();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_AdminAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosqueAdminEditScreen(
            args: const MosqueAdminEditRouteArgs(
              mosque: MosqueModel(
                id: 'mosque-1',
                name: 'Test Mosque',
                addressLine: '12 Unity Street',
                city: 'Bengaluru',
                state: 'Karnataka',
                country: 'India',
                latitude: 12.9716,
                longitude: 77.5946,
                imageUrl: 'https://example.org/old.jpg',
                imageUrls: <String>[
                  'https://example.org/old.jpg',
                  'https://example.org/old-2.jpg',
                ],
                rating: 4,
                distanceMiles: 0,
                sect: 'Sunni',
                womenPrayerArea: true,
                parking: true,
                wudu: true,
                facilities: <String>['women_area', 'parking', 'wudu'],
                isVerified: false,
                isBookmarked: false,
                duhrTime: '01:10 PM',
                asarTime: '04:40 PM',
                isOpenNow: false,
                classTags: <String>[],
                eventTags: <String>[],
              ),
            ),
            mosqueService: service,
            imagePicker: imagePicker,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('admin-edit-name')),
      'Updated Test Mosque',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-edit-about-title')),
      'Updated About',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-edit-about-body')),
      'Updated description.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('event-title-0')),
      'Updated Family Night',
    );
    await tester.enterText(
      find.byKey(const ValueKey('event-schedule-0')),
      'Fri 7 PM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('event-location-0')),
      'Prayer Hall',
    );
    await tester.enterText(
      find.byKey(const ValueKey('event-description-0')),
      'Updated event details.',
    );
    final browseButton = find.byKey(const ValueKey('mosque-image-browse'));
    await tester.ensureVisible(browseButton);
    tester.widget<OutlinedButton>(browseButton).onPressed!();
    await tester.pumpAndSettle();
    final uploadButton = find.byKey(const ValueKey('mosque-image-upload'));
    await tester.ensureVisible(uploadButton);
    tester.widget<FilledButton>(uploadButton).onPressed!();
    await tester.pumpAndSettle();

    final submitButton = find.byKey(const ValueKey('admin-edit-mosque-submit'));
    await tester.ensureVisible(submitButton);
    tester.widget<ElevatedButton>(submitButton).onPressed!();
    await tester.pumpAndSettle();

    expect(service.lastBearerToken, 'admin-token');
    expect(service.lastPayload, isNotNull);
    expect(service.lastPayload!['name'], 'Updated Test Mosque');
    expect(
      service.lastPayload!['prayerTimeConfig'],
      <String, dynamic>{
        'enabled': true,
        'calculationMethod': 3,
        'school': 'hanafi',
        'adjustments': <String, int>{
          'fajr': 1,
          'sunrise': 0,
          'dhuhr': 2,
          'asr': 0,
          'maghrib': -1,
          'isha': 0,
        },
      },
    );
    expect(service.lastPayload!['content']['about']['title'], 'Updated About');
    expect(
      service.lastPayload!['content']['about']['body'],
      'Updated description.',
    );
    expect(
      service.lastPayload!['content']['events'][0]['title'],
      'Updated Family Night',
    );
    expect(
      service.lastPayload!['content']['events'][0]['location'],
      'Prayer Hall',
    );
    expect(
      service.lastPayload!['content']['events'][0]['description'],
      'Updated event details.',
    );
    expect(
      service.lastPayload!['imageUrl'],
      'https://example.org/old.jpg',
    );
    expect(
      service.lastPayload!['imageUrls'],
      <String>[
        'https://example.org/old.jpg',
        'https://example.org/old-2.jpg',
        'http://localhost:4000/uploads/mosques/updated-1.jpg',
      ],
    );
  });

  testWidgets('admin users can publish and remove broadcast messages',
      (tester) async {
    final service = _RecordingMosqueService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_AdminAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosqueAdminEditScreen(
            args: const MosqueAdminEditRouteArgs(
              mosque: MosqueModel(
                id: 'mosque-1',
                name: 'Test Mosque',
                addressLine: '12 Unity Street',
                city: 'Bengaluru',
                state: 'Karnataka',
                country: 'India',
                latitude: 12.9716,
                longitude: 77.5946,
                imageUrl: 'https://example.org/old.jpg',
                rating: 4,
                distanceMiles: 0,
                sect: 'Sunni',
                womenPrayerArea: true,
                parking: true,
                wudu: true,
                facilities: <String>['women_area', 'parking', 'wudu'],
                isVerified: false,
                isBookmarked: false,
                duhrTime: '01:10 PM',
                asarTime: '04:40 PM',
                isOpenNow: false,
                classTags: <String>[],
                eventTags: <String>[],
              ),
            ),
            mosqueService: service,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('broadcast-title-input')),
      'Jummah Parking Update',
    );
    await tester.enterText(
      find.byKey(const ValueKey('broadcast-message-input')),
      'Overflow volunteers will guide arrivals from 12:15 PM.',
    );
    final publishButton = find.byKey(const ValueKey('broadcast-publish'));
    await tester.ensureVisible(publishButton);
    tester.widget<FilledButton>(publishButton).onPressed!();
    await tester.pumpAndSettle();

    expect(service.lastPublishedTitle, 'Jummah Parking Update');
    expect(
      service.lastPublishedDescription,
      'Overflow volunteers will guide arrivals from 12:15 PM.',
    );
    expect(service.publishedBroadcasts.first.title, 'Jummah Parking Update');
    expect(service.updateCalls, 0);

    final removeButton = find.byKey(const ValueKey('broadcast-remove-0'));
    await tester.ensureVisible(removeButton);
    tester.widget<IconButton>(removeButton).onPressed!();
    await tester.pumpAndSettle();

    expect(service.deletedBroadcastIds, <String>['broadcast-2']);
    expect(
      service.publishedBroadcasts.map((item) => item.title),
      isNot(contains('Jummah Parking Update')),
    );
  });
}
