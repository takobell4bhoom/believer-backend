import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/data/mock_provider.dart';
import 'package:believer/data/mosque_content_refresh_provider.dart';
import 'package:believer/data/mosque_provider.dart';
import 'package:believer/models/broadcast_message.dart';
import 'package:believer/models/mosque_content.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/models/prayer_timings.dart';
import 'package:believer/models/review.dart';
import 'package:believer/navigation/mosque_detail_route_args.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/mosque_page.dart';
import 'package:believer/services/bookmark_service.dart';
import 'package:believer/services/mosque_service.dart';
import 'package:believer/services/outbound_action_service.dart';

MosqueModel _sampleMosque() {
  return const MosqueModel(
    id: 'page-mosque-1',
    name: 'Islamic Centre of South Florida',
    addressLine: '12345 Peace Avenue',
    city: 'Jacksonville',
    state: 'FL',
    country: 'US',
    imageUrl: '',
    rating: 4.1,
    distanceMiles: 0.6,
    sect: 'Sunni',
    contactPhone: '+1 (407) 555-0100',
    websiteUrl: 'iscsf.org',
    womenPrayerArea: true,
    parking: true,
    wudu: true,
    facilities: ['women_prayer_area', 'wheelchair_access', 'parking', 'wudu'],
    isVerified: true,
    isBookmarked: false,
    duhrTime: '12:55 PM',
    asarTime: '04:45 PM',
    isOpenNow: true,
    classTags: ['Every Sat & Sun Hadith Study Circle'],
    eventTags: ['Fiqh of Family, Marriage, Rights & Responsibilities'],
  );
}

MosqueModel _sparseMosque() {
  return const MosqueModel(
    id: 'page-mosque-2',
    name: 'Community Masjid',
    addressLine: '',
    city: 'Jacksonville',
    state: 'FL',
    country: 'US',
    imageUrl: '',
    rating: 0,
    distanceMiles: 1.2,
    sect: '',
    contactPhone: '',
    websiteUrl: '',
    womenPrayerArea: false,
    parking: false,
    wudu: false,
    facilities: [],
    isVerified: false,
    isBookmarked: false,
    duhrTime: '--',
    asarTime: '--',
    isOpenNow: false,
    classTags: [],
    eventTags: [],
  );
}

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

class _AdminAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'admin-token',
      refreshToken: 'refresh',
      user: AuthUser(
        id: 'admin-1',
        fullName: 'Admin User',
        email: 'admin@example.com',
        role: 'admin',
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

class _FakeMosqueService extends MosqueService {
  final List<String> prayerTimeRequests = [];

  @override
  Future<ReviewFeed> getMosqueReviews(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const ReviewFeed(
      items: [
        Review(
          rating: 5,
          userName: 'Backend Review User',
          comment: 'Loved the khutbah and volunteers.',
          timeAgo: '2 days ago',
        ),
      ],
      averageRating: 5,
      totalReviews: 1,
    );
  }

  @override
  Future<List<BroadcastMessage>> getMosqueBroadcastMessages(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const [
      BroadcastMessage(
        title: 'Backend Broadcast Title',
        description: 'Backend-backed broadcast preview text.',
        date: 'Today',
      ),
      BroadcastMessage(
        title: 'Second Message',
        description: 'Another broadcast',
        date: 'Yesterday',
      ),
    ];
  }

  @override
  Future<MosqueContent> getMosqueContent(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const MosqueContent(
      events: [
        MosqueProgramItem(
          id: 'event-1',
          title: 'Backend Family Night',
          schedule: 'This Sat',
          posterLabel: 'Family',
        ),
      ],
      classes: [
        MosqueProgramItem(
          id: 'class-1',
          title: 'Backend Quran Circle',
          schedule: 'Tue 7 PM',
          posterLabel: 'Quran',
        ),
      ],
      connect: [
        MosqueConnectLink(
          id: 'connect-1',
          type: 'instagram',
          label: 'instagram.com/backendmosque',
          value: 'instagram.com/backendmosque',
        ),
      ],
      about: MosqueAboutContent(
        title: 'About Backend Mosque',
        body: 'Backend-backed editorial copy for the mosque page.',
      ),
    );
  }

  @override
  Future<PrayerTimings> getPrayerTimings({
    required String mosqueId,
    required String date,
    String? bearerToken,
  }) async {
    prayerTimeRequests.add(date);

    return PrayerTimings(
      mosqueId: mosqueId,
      date: date,
      status: 'ready',
      isConfigured: true,
      isAvailable: true,
      source: 'cache',
      unavailableReason: null,
      timezone: 'Asia/Kolkata',
      configuration: const PrayerTimeConfiguration(
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
          'dhuhr': 2,
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

class _RefreshingMosqueService extends _FakeMosqueService {
  int broadcastReadCount = 0;

  @override
  Future<List<BroadcastMessage>> getMosqueBroadcastMessages(
    String mosqueId, {
    String? bearerToken,
  }) async {
    broadcastReadCount += 1;
    if (broadcastReadCount == 1) {
      return const [
        BroadcastMessage(
          id: 'broadcast-1',
          title: 'Initial Broadcast Title',
          description: 'Initial preview text.',
          publishedAt: null,
        ),
      ];
    }

    return const [
      BroadcastMessage(
        id: 'broadcast-2',
        title: 'Updated Broadcast Title',
        description: 'Freshly published broadcast text.',
        publishedAt: null,
      ),
    ];
  }
}

class _FakeOutboundActionService extends OutboundActionService {
  @override
  Future<OutboundActionResult> shareText(
    String text, {
    String? subject,
    String successMessage = 'Share options opened.',
    String fallbackMessage =
        'Could not open share options. Details copied to clipboard.',
    String unavailableMessage = 'Nothing to share yet.',
  }) async {
    return const OutboundActionResult(
      message: 'Share options opened for this mosque.',
      didLaunch: true,
    );
  }

  @override
  Future<OutboundActionResult> launchPhone(
    String? phoneNumber, {
    String successMessage = 'Opening phone app...',
    String fallbackMessage =
        'Could not open the phone app. Number copied to clipboard.',
    String unavailableMessage = 'Phone number not available yet.',
  }) async {
    return const OutboundActionResult(
      message: 'Opening mosque phone number...',
      didLaunch: true,
    );
  }

  @override
  Future<OutboundActionResult> launchExternalLink(
    String? rawValue, {
    String? type,
    String successMessage = 'Opening link...',
    String fallbackMessage =
        'Could not open the link. Details copied to clipboard.',
    String unavailableMessage = 'Link not available yet.',
  }) async {
    return const OutboundActionResult(
      message: 'Opening Instagram...',
      didLaunch: true,
    );
  }
}

class _FakeBookmarkService extends BookmarkService {
  int addCalls = 0;
  int removeCalls = 0;

  @override
  Future<void> addBookmark(String mosqueId, {String? bearerToken}) async {
    addCalls += 1;
  }

  @override
  Future<void> removeBookmark(String mosqueId, {String? bearerToken}) async {
    removeCalls += 1;
  }
}

class _SparseMosquePageService extends MosqueService {
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
    return const [];
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
    throw Exception('No live prayer timings');
  }
}

void main() {
  testWidgets('mosque page renders verified shell and notification route',
      (tester) async {
    final mosque = _sampleMosque();
    final service = _FakeMosqueService();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        mosqueProvider.overrideWith(_EmptyMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    container.read(mosqueProvider.notifier).addMosque(mosque);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.mosqueBroadcast: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Mosque broadcast stub'),
                ),
            AppRoutes.mosqueNotificationSettings: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Mosque notifications stub'),
                ),
          },
          home: MosquePage(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: service,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Islamic Centre of South Florida'), findsWidgets);
    expect(find.text('IQAMAH'), findsOneWidget);
    expect(find.text('FACILITIES'), findsOneWidget);
    expect(find.text('Prayer timings TODAY'), findsOneWidget);
    expect(find.text('Enable Notifications'), findsOneWidget);
    expect(find.text('Backend Review User'), findsOneWidget);
    expect(find.text('5.0 | 1 review'), findsOneWidget);
    expect(find.text('Backend Broadcast Title'), findsOneWidget);
    expect(find.text('Backend Family Night'), findsOneWidget);
    expect(find.text('Backend Quran Circle'), findsOneWidget);
    expect(find.text('instagram.com/backendmosque'), findsOneWidget);
    expect(find.text('About Backend Mosque'), findsOneWidget);
    expect(find.text('12:31 PM'), findsOneWidget);
    expect(find.text('04:02 PM'), findsWidgets);
    expect(find.textContaining('Muslim World League'), findsOneWidget);
    expect(
      find.text('Backend-backed editorial copy for the mosque page.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Enable Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Mosque notifications stub'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final allMessagesButton = find.text('See all 2 messages in last 60 days');
    await tester.ensureVisible(allMessagesButton);
    await tester.tap(allMessagesButton);
    await tester.pumpAndSettle();

    expect(find.text('Mosque broadcast stub'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final weeklyIqamahButton = find.text('View this week\'s iqamah timings');
    await tester.ensureVisible(weeklyIqamahButton);
    await tester.tap(weeklyIqamahButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('This week\'s iqamah timings'), findsOneWidget);
    expect(find.text('Daily backend-owned mosque timings for the next 7 days.'),
        findsOneWidget);
    expect(service.prayerTimeRequests.length, greaterThanOrEqualTo(7));
  });

  testWidgets('mosque page renders in compact viewport without overflow',
      (tester) async {
    final mosque = _sampleMosque();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        mosqueProvider.overrideWith(_EmptyMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    container.read(mosqueProvider.notifier).addMosque(mosque);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosquePage(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: _FakeMosqueService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Islamic Centre of South Florida'), findsWidgets);
    await tester.ensureVisible(find.text('Enable Notifications'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mosque page refreshes broadcasts when content refresh tick changes',
      (tester) async {
    final mosque = _sampleMosque();
    final service = _RefreshingMosqueService();
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
          home: MosquePage(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: service,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Initial Broadcast Title'), findsOneWidget);
    expect(find.text('Updated Broadcast Title'), findsNothing);

    container.read(mosqueContentRefreshTickProvider.notifier).state += 1;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Initial Broadcast Title'), findsNothing);
    expect(find.text('Updated Broadcast Title'), findsOneWidget);
  });

  testWidgets('mosque page uses a single landscape hero for one uploaded image',
      (tester) async {
    final mosque = _sampleMosque().copyWith(
      imageUrl: 'https://example.org/mosque.jpg',
    );
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
          home: MosquePage(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: _FakeMosqueService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mosque-gallery-single')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mosque-gallery-collage')),
      findsNothing,
    );
    expect(find.text('Courtyard'), findsNothing);
    expect(find.text('Entrance'), findsNothing);
  });

  testWidgets('mosque page shows slider controls when multiple images exist',
      (tester) async {
    final mosque = _sampleMosque().copyWith(
      imageUrl: 'https://example.org/mosque-1.jpg',
      imageUrls: const <String>[
        'https://example.org/mosque-1.jpg',
        'https://example.org/mosque-2.jpg',
        'https://example.org/mosque-3.jpg',
      ],
    );
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
          home: MosquePage(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: _FakeMosqueService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mosque-gallery-slider')), findsOneWidget);
    expect(find.byKey(const ValueKey('mosque-gallery-next')), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mosque-gallery-next')));
    await tester.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('admin users can open the mosque editor from mosque page',
      (tester) async {
    final mosque = _sampleMosque().copyWith(canEdit: true);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_AdminAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(mosqueProvider.notifier).addMosque(mosque);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.adminEditMosque: (_) =>
                const Scaffold(body: Text('Admin edit stub')),
          },
          home: MosquePage(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: _FakeMosqueService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Admin edit stub'), findsOneWidget);
  });

  testWidgets('non-owner admins do not see the mosque editor action',
      (tester) async {
    final mosque = _sampleMosque().copyWith(canEdit: false);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_AdminAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(mosqueProvider.notifier).addMosque(mosque);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosquePage(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: _FakeMosqueService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('mosque page outbound actions use the injected launcher service',
      (tester) async {
    final mosque = _sampleMosque();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(mosqueProvider.notifier).addMosque(mosque);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosquePage(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: _FakeMosqueService(),
            outboundActionService: _FakeOutboundActionService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.share_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Share options opened for this mosque.'), findsOneWidget);
  });

  testWidgets('mosque page bookmark toggle stays in sync with provider state',
      (tester) async {
    final mosque = _sampleMosque();
    final bookmarkService = _FakeBookmarkService();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(mosqueProvider.notifier).addMosque(mosque);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosquePage(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: _FakeMosqueService(),
            bookmarkService: bookmarkService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();

    expect(bookmarkService.addCalls, 1);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets(
      'mosque page uses conservative placeholders instead of fake detail content',
      (tester) async {
    final mosque = _sparseMosque();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(mosqueProvider.notifier).addMosque(mosque);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosquePage(
            args: MosqueDetailRouteArgs.fromMosque(mosque),
            mosqueService: _SparseMosquePageService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Community Masjid'), findsWidgets);
    expect(find.text('No reviews yet'), findsWidgets);
    expect(
      find.text(
        'No community reviews have been published for this mosque yet.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No recent broadcast messages have been published for this mosque yet.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No event details have been published for this mosque yet. Listing summaries only show event titles when available.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No class or halaqa details have been published for this mosque yet. Listing summaries only show class titles when available.',
      ),
      findsOneWidget,
    );
    expect(find.text('Contact details not published yet'), findsWidgets);
    expect(find.text('Prayer timings not published'), findsOneWidget);
    expect(find.text('Amina K.'), findsNothing);
    expect(find.text('Prayer schedule reminder'), findsNothing);
  });
}
