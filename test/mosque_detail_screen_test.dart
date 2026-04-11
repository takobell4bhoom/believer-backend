import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/data/mosque_provider.dart';
import 'package:believer/models/broadcast_message.dart';
import 'package:believer/models/mosque_content.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/models/prayer_timings.dart';
import 'package:believer/models/review.dart';
import 'package:believer/navigation/mosque_detail_route_args.dart';
import 'package:believer/screens/mosque_detail_screen.dart';
import 'package:believer/services/bookmark_service.dart';
import 'package:believer/services/mosque_service.dart';

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(
        id: 'user-1',
        fullName: 'Test User',
        email: 'test@example.com',
        role: 'community',
      ),
    );
  }
}

class _EmptyMosqueNotifier extends MosqueNotifier {
  @override
  Future<List<MosqueModel>> build() async {
    return const <MosqueModel>[];
  }
}

class _FakeBookmarkService extends BookmarkService {
  int addCalls = 0;

  @override
  Future<void> addBookmark(String mosqueId, {String? bearerToken}) async {
    addCalls += 1;
  }
}

class _LegacyCompatMosqueService extends MosqueService {
  @override
  Future<ReviewFeed> getMosqueReviews(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const ReviewFeed(
      items: [],
      averageRating: 0,
      totalReviews: 0,
    );
  }

  @override
  Future<List<BroadcastMessage>> getMosqueBroadcastMessages(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const <BroadcastMessage>[];
  }

  @override
  Future<MosqueContent> getMosqueContent(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const MosqueContent(
      events: [],
      classes: [],
      connect: [],
    );
  }

  @override
  Future<PrayerTimings> getPrayerTimings({
    required String mosqueId,
    required String date,
    String? bearerToken,
  }) async {
    return const PrayerTimings(
      mosqueId: 'legacy-detail-mosque',
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
        school: 'standard',
        schoolLabel: 'Standard',
        adjustments: {
          'fajr': 0,
          'sunrise': 0,
          'dhuhr': 0,
          'asr': 0,
          'maghrib': 0,
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
}

MosqueModel _sampleMosque({bool isBookmarked = false}) {
  return MosqueModel(
    id: 'legacy-detail-mosque',
    name: 'Test Mosque',
    addressLine: '123 Main Street',
    city: 'Jacksonville',
    state: 'FL',
    country: 'US',
    imageUrl: '',
    rating: 4.2,
    distanceMiles: 0.8,
    sect: 'Sunni',
    womenPrayerArea: true,
    parking: true,
    wudu: true,
    facilities: const ['women_area', 'parking', 'wudu'],
    isVerified: true,
    isBookmarked: isBookmarked,
    duhrTime: '01:15 PM',
    asarTime: '04:45 PM',
    isOpenNow: true,
    classTags: const <String>[],
    eventTags: const <String>[],
  );
}

void main() {
  testWidgets(
      'legacy mosque detail screen delegates to the routed mosque page behavior',
      (tester) async {
    final mosque = _sampleMosque();
    final bookmarkService = _FakeBookmarkService();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        mosqueProvider.overrideWith(_EmptyMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(mosqueProvider.notifier).addMosque(mosque);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosqueDetailScreen(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: _LegacyCompatMosqueService(),
            bookmarkService: bookmarkService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('IQAMAH'), findsOneWidget);
    expect(find.text('Prayer timings TODAY'), findsOneWidget);
    expect(find.text('12:31 PM'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();

    expect(bookmarkService.addCalls, 1);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}
