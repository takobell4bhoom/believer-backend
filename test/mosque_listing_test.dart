import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/core/nearby_radius.dart';
import 'package:believer/data/auth_provider.dart';
import 'package:believer/data/mosque_provider.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/navigation/mosque_detail_route_args.dart';
import 'package:believer/screens/mosque_listing.dart';
import 'package:believer/screens/sort_filter_mosque.dart';
import 'package:believer/services/location_preferences_service.dart';

class _TrackingMosqueNotifier extends MosqueNotifier {
  static List<MosqueModel> mosques = const <MosqueModel>[];
  static Map<int, List<MosqueModel>> mosquesByRadiusMiles =
      const <int, List<MosqueModel>>{};
  static double? lastLatitude;
  static double? lastLongitude;
  static double? lastRadiusMiles;
  static double? lastRadiusKm;
  static int lastPage = 0;
  static int lastLimit = 0;
  static int loadNearbyCallCount = 0;
  static List<int> requestedPages = <int>[];
  static Set<int> failingPages = <int>{};

  static void reset() {
    mosques = const <MosqueModel>[];
    mosquesByRadiusMiles = const <int, List<MosqueModel>>{};
    lastLatitude = null;
    lastLongitude = null;
    lastRadiusMiles = null;
    lastRadiusKm = null;
    lastPage = 0;
    lastLimit = 0;
    loadNearbyCallCount = 0;
    requestedPages = <int>[];
    failingPages = <int>{};
  }

  @override
  Future<List<MosqueModel>> build() async {
    return mosques;
  }

  @override
  Future<List<MosqueModel>> loadNearby({
    required double latitude,
    required double longitude,
    double? radiusMiles,
    double? radiusKm,
    int page = 1,
    int limit = nearbyMosquesPageSize,
    bool append = false,
  }) async {
    loadNearbyCallCount += 1;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastRadiusMiles = radiusMiles;
    lastRadiusKm = radiusKm;
    lastPage = page;
    lastLimit = limit;
    requestedPages = [...requestedPages, page];

    if (failingPages.contains(page)) {
      throw StateError('failed to load page $page');
    }

    final radiusKey = (radiusMiles ?? defaultNearbyRadiusMiles).round();
    final availableMosques = mosquesByRadiusMiles[radiusKey] ?? mosques;
    final pageStart = (page - 1) * limit;
    final pageItems =
        availableMosques.skip(pageStart).take(limit).toList(growable: false);
    final visibleItems = append
        ? [...(state.valueOrNull ?? const <MosqueModel>[]), ...pageItems]
        : pageItems;

    updateNearbyPagination(
      page: page,
      limit: limit,
      hasMore: pageStart + pageItems.length < availableMosques.length,
      total: availableMosques.length,
    );
    state = AsyncData(visibleItems);
    return visibleItems;
  }
}

class _FakeLocationPreferencesService extends LocationPreferencesService {
  _FakeLocationPreferencesService(this.savedLocation);

  final SavedUserLocation? savedLocation;

  @override
  Future<SavedUserLocation?> loadSavedLocation() async => savedLocation;
}

class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return null;
  }
}

MosqueModel _buildNearbyMosque({
  required int index,
  required double distanceMiles,
  String? name,
  List<String> classTags = const <String>[],
  List<String> eventTags = const <String>[],
}) {
  return MosqueModel(
    id: 'listing-mosque-$index',
    name: name ?? 'Listing Mosque $index',
    addressLine: '$index Mercy Road',
    city: 'Jacksonville',
    state: 'FL',
    country: 'US',
    imageUrl: '',
    rating: 4.0 + ((index % 5) * 0.1),
    reviewCount: 4,
    distanceMiles: distanceMiles,
    sect: 'Community',
    womenPrayerArea: true,
    parking: true,
    wudu: true,
    facilities: const ['women_area', 'parking', 'wudu'],
    isVerified: true,
    isBookmarked: false,
    duhrTime: '01:15 PM',
    asarTime: index.isEven ? '04:45 PM' : '--',
    isOpenNow: false,
    classTags: classTags,
    eventTags: eventTags,
  );
}

Widget _buildListingHarness({
  required ProviderContainer container,
  SavedUserLocation? savedLocation,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.sortFilterMosque) {
          return MaterialPageRoute<void>(
            builder: (_) => SortFilterMosque(
              initialFilters: settings.arguments as Map<String, dynamic>?,
            ),
            settings: settings,
          );
        }
        return null;
      },
      home: MosqueListing(
        locationPreferencesService: _FakeLocationPreferencesService(
          savedLocation ??
              const SavedUserLocation(
                label: 'Tampa, Florida',
                latitude: 27.9506,
                longitude: -82.4572,
              ),
        ),
      ),
    ),
  );
}

Future<void> _scrollToLoadMore(WidgetTester tester) async {
  final listView = find.byType(ListView).last;
  for (var index = 0;
      index < 12 && find.textContaining('Load more mosques').evaluate().isEmpty;
      index++) {
    await tester.drag(listView, const Offset(0, -700));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
      'signed-out guests can browse mosque listing and open mosque pages',
      (tester) async {
    const mosque = MosqueModel(
      id: 'listing-mosque-guest',
      name: 'Guest Friendly Masjid',
      addressLine: '42 Crescent Road',
      city: 'Tampa',
      state: 'FL',
      country: 'US',
      imageUrl: '',
      rating: 4.5,
      reviewCount: 8,
      distanceMiles: 1.8,
      sect: 'Community',
      womenPrayerArea: true,
      parking: true,
      wudu: true,
      facilities: ['women_area', 'parking', 'wudu'],
      isVerified: true,
      isBookmarked: false,
      duhrTime: '01:10 PM',
      asarTime: '04:40 PM',
      isOpenNow: true,
      classTags: ['Tafsir Circle'],
      eventTags: ['Family Night'],
    );

    _TrackingMosqueNotifier.reset();
    _TrackingMosqueNotifier.mosques = const <MosqueModel>[mosque];

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_SignedOutAuthNotifier.new),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.mosqueDetail: (_) =>
                const Scaffold(body: Text('Mosque page stub')),
          },
          home: MosqueListing(
            locationPreferencesService: _FakeLocationPreferencesService(
              const SavedUserLocation(
                label: 'Tampa, Florida',
                latitude: 27.9506,
                longitude: -82.4572,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Guest Friendly Masjid'), findsOneWidget);
    expect(find.text('Redirecting...'), findsNothing);

    await tester.tap(find.text('Guest Friendly Masjid'));
    await tester.pumpAndSettle();

    expect(find.text('Mosque page stub'), findsOneWidget);
  });

  testWidgets('mosque listing surfaces honest summary content', (tester) async {
    const mosque = MosqueModel(
      id: 'listing-mosque-1',
      name: 'Northside Community Mosque',
      addressLine: '15 Mercy Road',
      city: 'Jacksonville',
      state: 'FL',
      country: 'US',
      imageUrl: '',
      imageUrls: <String>['https://example.org/listing-cover.jpg'],
      rating: 4.6,
      reviewCount: 4,
      distanceMiles: 1.2,
      sect: 'Community',
      womenPrayerArea: true,
      parking: true,
      wudu: false,
      facilities: ['women_area', 'parking', 'wheelchair_access'],
      isVerified: true,
      isBookmarked: true,
      duhrTime: '01:15 PM',
      asarTime: '--',
      isOpenNow: false,
      classTags: ['Quran Circle', 'Weekend Halaqa'],
      eventTags: ['Family Night'],
    );

    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Test User',
      'auth.user.email': 'test@example.com',
      'auth.user.role': 'community',
    });
    _TrackingMosqueNotifier.reset();
    _TrackingMosqueNotifier.mosques = const <MosqueModel>[mosque];

    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(
          _FakeAuthTokenStore(
            tokens: const AuthTokens(
              accessToken: 'token',
              refreshToken: 'refresh',
            ),
          ),
        ),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosqueListing(
            locationPreferencesService: _FakeLocationPreferencesService(
              const SavedUserLocation(
                label: 'Tampa, Florida',
                latitude: 27.9506,
                longitude: -82.4572,
              ),
            ),
          ),
        ),
      ),
    );

    for (var index = 0; index < 12; index++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.text('Northside Community Mosque').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Northside Community Mosque'), findsOneWidget);
    expect(_TrackingMosqueNotifier.lastLatitude, 27.9506);
    expect(_TrackingMosqueNotifier.lastLongitude, -82.4572);
    expect(
      _TrackingMosqueNotifier.lastRadiusMiles,
      defaultNearbyRadiusMiles,
    );
    expect(_TrackingMosqueNotifier.lastRadiusKm, isNull);
    expect(_TrackingMosqueNotifier.loadNearbyCallCount, 1);
    expect(find.text('Within 50 miles'), findsOneWidget);
    expect(find.text('Prayer times listed'), findsNothing);
    expect(find.text('Listed: Dhuhr 01:15 PM'), findsOneWidget);
    expect(find.text('Verified listing'), findsOneWidget);
    expect(find.text('2 classes • 1 event'), findsOneWidget);
    expect(find.text('Newly added'), findsNothing);
    expect(find.text('This weekend'), findsNothing);
    expect(find.text('Starts in 8 mins'), findsNothing);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('mosque-listing-card-image')),
    );
    final provider = image.image as NetworkImage;
    expect(provider.url, 'https://example.org/listing-cover.jpg');
  });

  testWidgets('mosque listing stays honest when no precise location is stored',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Test User',
      'auth.user.email': 'test@example.com',
      'auth.user.role': 'community',
    });
    _TrackingMosqueNotifier.reset();
    _TrackingMosqueNotifier.mosques = const <MosqueModel>[];

    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(
          _FakeAuthTokenStore(
            tokens: const AuthTokens(
              accessToken: 'token',
              refreshToken: 'refresh',
            ),
          ),
        ),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosqueListing(
            locationPreferencesService: _FakeLocationPreferencesService(null),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Set your location first.'), findsOneWidget);
    expect(find.text('Save a location to load nearby mosques honestly.'),
        findsOneWidget);
    expect(_TrackingMosqueNotifier.lastLatitude, isNull);
    expect(_TrackingMosqueNotifier.lastLongitude, isNull);
    expect(_TrackingMosqueNotifier.lastRadiusMiles, isNull);
    expect(_TrackingMosqueNotifier.lastRadiusKm, isNull);
  });

  testWidgets(
      'first nearby load shows only the initial batch and load more appends the next batch',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Test User',
      'auth.user.email': 'test@example.com',
      'auth.user.role': 'community',
    });
    _TrackingMosqueNotifier.reset();
    _TrackingMosqueNotifier.mosques = List<MosqueModel>.generate(
      25,
      (index) => _buildNearbyMosque(
        index: index + 1,
        distanceMiles: index + 1,
      ),
      growable: false,
    );

    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(
          _FakeAuthTokenStore(
            tokens: const AuthTokens(
              accessToken: 'token',
              refreshToken: 'refresh',
            ),
          ),
        ),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildListingHarness(container: container));
    await tester.pumpAndSettle();

    expect(find.text('Listing Mosque 1'), findsOneWidget);
    expect(find.text('Listing Mosque 21'), findsNothing);
    expect(find.text('20 Mosques'), findsOneWidget);
    await _scrollToLoadMore(tester);
    expect(find.text('Load more mosques'), findsOneWidget);
    expect(_TrackingMosqueNotifier.lastPage, 1);
    expect(_TrackingMosqueNotifier.lastLimit, nearbyMosquesPageSize);
    expect(_TrackingMosqueNotifier.requestedPages, [1]);
    expect(_TrackingMosqueNotifier.lastRadiusMiles, defaultNearbyRadiusMiles);

    await tester.ensureVisible(find.text('Load more mosques'));
    await tester.tap(find.text('Load more mosques'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_TrackingMosqueNotifier.requestedPages, [1, 2]);
    expect(find.text('25 Mosques'), findsOneWidget);
    expect(find.text('Load more mosques'), findsNothing);
  });

  testWidgets('changing radius resets nearby paging back to page 1',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Test User',
      'auth.user.email': 'test@example.com',
      'auth.user.role': 'community',
    });
    _TrackingMosqueNotifier.reset();
    _TrackingMosqueNotifier.mosquesByRadiusMiles = <int, List<MosqueModel>>{
      30: List<MosqueModel>.generate(
        12,
        (index) => _buildNearbyMosque(
          index: index + 1,
          distanceMiles: index + 1,
          name: '30 Mile Mosque ${index + 1}',
        ),
        growable: false,
      ),
      50: List<MosqueModel>.generate(
        25,
        (index) => _buildNearbyMosque(
          index: index + 1,
          distanceMiles: index + 1,
          name: '50 Mile Mosque ${index + 1}',
        ),
        growable: false,
      ),
    };
    _TrackingMosqueNotifier.mosques =
        _TrackingMosqueNotifier.mosquesByRadiusMiles[50]!;

    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(
          _FakeAuthTokenStore(
            tokens: const AuthTokens(
              accessToken: 'token',
              refreshToken: 'refresh',
            ),
          ),
        ),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildListingHarness(container: container));
    await tester.pumpAndSettle();

    await _scrollToLoadMore(tester);
    await tester.ensureVisible(find.text('Load more mosques'));
    await tester.tap(find.text('Load more mosques'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('25 Mosques'), findsOneWidget);

    await tester.tap(find.byTooltip('Open filters'));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(30.0);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_TrackingMosqueNotifier.lastRadiusMiles, 30);
    expect(_TrackingMosqueNotifier.lastPage, 1);
    expect(find.text('30 Mile Mosque 12'), findsOneWidget);
    expect(find.text('25 Mosques'), findsNothing);
    expect(find.text('12 Mosques'), findsOneWidget);
  });

  testWidgets('changing filters resets nearby paging back to page 1',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Test User',
      'auth.user.email': 'test@example.com',
      'auth.user.role': 'community',
    });
    _TrackingMosqueNotifier.reset();
    _TrackingMosqueNotifier.mosques = List<MosqueModel>.generate(
      25,
      (index) => _buildNearbyMosque(
        index: index + 1,
        distanceMiles: index + 1,
        classTags:
            index >= 20 ? const <String>['Quran Study'] : const <String>[],
      ),
      growable: false,
    );

    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(
          _FakeAuthTokenStore(
            tokens: const AuthTokens(
              accessToken: 'token',
              refreshToken: 'refresh',
            ),
          ),
        ),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildListingHarness(container: container));
    await tester.pumpAndSettle();

    await _scrollToLoadMore(tester);
    await tester.ensureVisible(find.text('Load more mosques'));
    await tester.tap(find.text('Load more mosques'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('25 Mosques'), findsOneWidget);

    await tester.tap(find.byTooltip('Open filters'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Classes listed'));
    await tester.tap(find.text('Classes listed'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_TrackingMosqueNotifier.lastPage, 1);
    expect(_TrackingMosqueNotifier.requestedPages, [1, 2, 1]);
    expect(find.text('Listing Mosque 21'), findsNothing);
    expect(find.text('0 Mosques'), findsOneWidget);
    expect(find.text('Load more mosques'), findsOneWidget);
  });

  testWidgets(
      'loading more errors keep already loaded mosques visible and allow retry',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Test User',
      'auth.user.email': 'test@example.com',
      'auth.user.role': 'community',
    });
    _TrackingMosqueNotifier.reset();
    _TrackingMosqueNotifier.mosques = List<MosqueModel>.generate(
      25,
      (index) => _buildNearbyMosque(
        index: index + 1,
        distanceMiles: index + 1,
      ),
      growable: false,
    );
    _TrackingMosqueNotifier.failingPages = <int>{2};

    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(
          _FakeAuthTokenStore(
            tokens: const AuthTokens(
              accessToken: 'token',
              refreshToken: 'refresh',
            ),
          ),
        ),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildListingHarness(container: container));
    await tester.pumpAndSettle();

    await _scrollToLoadMore(tester);
    await tester.ensureVisible(find.text('Load more mosques'));
    await tester.tap(find.text('Load more mosques'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Listing Mosque 20'), findsOneWidget);
    expect(find.text('Listing Mosque 21'), findsNothing);
    expect(
      find.textContaining('could not load the next nearby batch'),
      findsOneWidget,
    );
    expect(find.text('Retry loading more mosques'), findsOneWidget);

    _TrackingMosqueNotifier.failingPages = <int>{};
    final retryButton =
        find.widgetWithText(OutlinedButton, 'Retry loading more mosques');
    await tester.ensureVisible(retryButton);
    tester.widget<OutlinedButton>(retryButton).onPressed!();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_TrackingMosqueNotifier.requestedPages, [1, 2, 2]);
    expect(find.text('25 Mosques'), findsOneWidget);
    expect(find.text('Retry loading more mosques'), findsNothing);
  });

  testWidgets(
      'google listed mosque keeps the same card layout and opens the mosque page',
      (tester) async {
    const googleMosque = MosqueModel(
      id: 'google:place-123',
      name: 'Masjid Al Noor',
      addressLine: '15 Mercy Road',
      city: 'Jacksonville',
      state: 'FL',
      country: 'US',
      imageUrl: '',
      rating: 0,
      reviewCount: 0,
      distanceMiles: 0.8,
      sect: 'Community',
      womenPrayerArea: false,
      parking: false,
      wudu: false,
      facilities: <String>[],
      isVerified: false,
      isBookmarked: false,
      duhrTime: '',
      asarTime: '',
      isOpenNow: false,
      classTags: <String>[],
      eventTags: <String>[],
      sourceType: MosqueSourceType.googleListed,
    );

    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Test User',
      'auth.user.email': 'test@example.com',
      'auth.user.role': 'community',
    });
    _TrackingMosqueNotifier.reset();
    _TrackingMosqueNotifier.mosques = const <MosqueModel>[googleMosque];
    MosqueDetailRouteArgs? pushedArgs;

    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(
          _FakeAuthTokenStore(
            tokens: const AuthTokens(
              accessToken: 'token',
              refreshToken: 'refresh',
            ),
          ),
        ),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.mosqueDetail) {
              pushedArgs = settings.arguments as MosqueDetailRouteArgs?;
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: Text('detail route opened'),
                ),
                settings: settings,
              );
            }

            return null;
          },
          home: MosqueListing(
            locationPreferencesService: _FakeLocationPreferencesService(
              const SavedUserLocation(
                label: 'Tampa, Florida',
                latitude: 27.9506,
                longitude: -82.4572,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Masjid Al Noor'), findsOneWidget);
    expect(find.text('Google listed mosque'), findsOneWidget);
    expect(find.text('Prayer times not published yet'), findsOneWidget);

    await tester.tap(find.text('Masjid Al Noor'));
    await tester.pumpAndSettle();

    expect(find.text('detail route opened'), findsOneWidget);
    expect(pushedArgs, isNotNull);
    expect(pushedArgs!.mosqueId, googleMosque.id);
    expect(pushedArgs!.initialMosque, googleMosque);
  });
}

class _FakeAuthTokenStore implements AuthTokenStore {
  _FakeAuthTokenStore({
    AuthTokens? tokens,
  }) : _tokens = tokens;

  AuthTokens? _tokens;

  @override
  Future<void> clearTokens() async {
    _tokens = null;
  }

  @override
  Future<AuthTokens?> readTokens() async => _tokens;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _tokens = AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}
