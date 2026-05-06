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
  static double? lastLatitude;
  static double? lastLongitude;
  static double? lastRadiusMiles;
  static double? lastRadiusKm;
  static int loadNearbyCallCount = 0;

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
    int limit = 20,
  }) async {
    loadNearbyCallCount += 1;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastRadiusMiles = radiusMiles;
    lastRadiusKm = radiusKm;
    state = AsyncData(mosques);
    return mosques;
  }
}

class _FakeLocationPreferencesService extends LocationPreferencesService {
  _FakeLocationPreferencesService(this.savedLocation);

  final SavedUserLocation? savedLocation;

  @override
  Future<SavedUserLocation?> loadSavedLocation() async => savedLocation;
}

void main() {
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
    _TrackingMosqueNotifier.mosques = const <MosqueModel>[mosque];
    _TrackingMosqueNotifier.lastLatitude = null;
    _TrackingMosqueNotifier.lastLongitude = null;
    _TrackingMosqueNotifier.lastRadiusMiles = null;
    _TrackingMosqueNotifier.lastRadiusKm = null;
    _TrackingMosqueNotifier.loadNearbyCallCount = 0;

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
    _TrackingMosqueNotifier.mosques = const <MosqueModel>[];
    _TrackingMosqueNotifier.lastLatitude = null;
    _TrackingMosqueNotifier.lastLongitude = null;
    _TrackingMosqueNotifier.lastRadiusMiles = null;
    _TrackingMosqueNotifier.lastRadiusKm = null;
    _TrackingMosqueNotifier.loadNearbyCallCount = 0;

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
      'default 50 mile filter is frontend-only after loading the max nearby radius',
      (tester) async {
    const nearbyMosque = MosqueModel(
      id: 'listing-mosque-near',
      name: 'Neighborhood Masjid',
      addressLine: '15 Mercy Road',
      city: 'Jacksonville',
      state: 'FL',
      country: 'US',
      imageUrl: '',
      rating: 4.6,
      reviewCount: 4,
      distanceMiles: 0.8,
      sect: 'Community',
      womenPrayerArea: true,
      parking: true,
      wudu: false,
      facilities: ['women_area', 'parking'],
      isVerified: true,
      isBookmarked: false,
      duhrTime: '01:15 PM',
      asarTime: '--',
      isOpenNow: false,
      classTags: <String>[],
      eventTags: <String>[],
    );
    const midRangeMosque = MosqueModel(
      id: 'listing-mosque-mid',
      name: 'County Islamic Center',
      addressLine: '20 Crescent Avenue',
      city: 'Jacksonville',
      state: 'FL',
      country: 'US',
      imageUrl: '',
      rating: 4.5,
      reviewCount: 3,
      distanceMiles: 30,
      sect: 'Community',
      womenPrayerArea: true,
      parking: true,
      wudu: true,
      facilities: ['women_area', 'parking', 'wudu'],
      isVerified: true,
      isBookmarked: false,
      duhrTime: '01:20 PM',
      asarTime: '--',
      isOpenNow: false,
      classTags: <String>[],
      eventTags: <String>[],
    );
    const edgeMosque = MosqueModel(
      id: 'listing-mosque-edge',
      name: 'Fifty Mile Masjid',
      addressLine: '50 Unity Drive',
      city: 'Jacksonville',
      state: 'FL',
      country: 'US',
      imageUrl: '',
      rating: 4.1,
      reviewCount: 5,
      distanceMiles: 50,
      sect: 'Community',
      womenPrayerArea: true,
      parking: true,
      wudu: true,
      facilities: ['women_area', 'parking', 'wudu'],
      isVerified: true,
      isBookmarked: false,
      duhrTime: '01:22 PM',
      asarTime: '--',
      isOpenNow: false,
      classTags: <String>[],
      eventTags: <String>[],
    );
    const fartherMosque = MosqueModel(
      id: 'listing-mosque-far',
      name: 'Regional Islamic Center',
      addressLine: '25 Faith Avenue',
      city: 'Jacksonville',
      state: 'FL',
      country: 'US',
      imageUrl: '',
      rating: 4.2,
      reviewCount: 2,
      distanceMiles: 120,
      sect: 'Community',
      womenPrayerArea: true,
      parking: true,
      wudu: true,
      facilities: ['women_area', 'parking', 'wudu'],
      isVerified: true,
      isBookmarked: false,
      duhrTime: '01:25 PM',
      asarTime: '--',
      isOpenNow: false,
      classTags: <String>[],
      eventTags: <String>[],
    );

    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Test User',
      'auth.user.email': 'test@example.com',
      'auth.user.role': 'community',
    });
    _TrackingMosqueNotifier.mosques = const <MosqueModel>[
      nearbyMosque,
      midRangeMosque,
      edgeMosque,
      fartherMosque,
    ];
    _TrackingMosqueNotifier.lastLatitude = null;
    _TrackingMosqueNotifier.lastLongitude = null;
    _TrackingMosqueNotifier.lastRadiusMiles = null;
    _TrackingMosqueNotifier.lastRadiusKm = null;
    _TrackingMosqueNotifier.loadNearbyCallCount = 0;

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

    expect(find.text('Neighborhood Masjid'), findsOneWidget);
    expect(find.text('3 Mosques'), findsOneWidget);
    expect(find.text('Within 50 miles'), findsOneWidget);
    expect(
      _TrackingMosqueNotifier.lastRadiusMiles,
      defaultNearbyRadiusMiles,
    );
    expect(_TrackingMosqueNotifier.lastRadiusKm, isNull);
    expect(_TrackingMosqueNotifier.loadNearbyCallCount, 1);

    Future<void> applyRadius(int radiusMiles) async {
      await tester.tap(find.byTooltip('Open filters'));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged?.call(radiusMiles.toDouble());
      await tester.pumpAndSettle();
      expect(find.text('$radiusMiles miles'), findsOneWidget);

      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
    }

    await applyRadius(30);
    expect(_TrackingMosqueNotifier.lastRadiusMiles, 30);
    expect(_TrackingMosqueNotifier.loadNearbyCallCount, 2);
    expect(find.text('Within 30 miles'), findsOneWidget);
    expect(find.text('2 Mosques'), findsOneWidget);
    expect(find.text('Neighborhood Masjid'), findsOneWidget);

    await applyRadius(50);
    expect(_TrackingMosqueNotifier.lastRadiusMiles, 50);
    expect(_TrackingMosqueNotifier.loadNearbyCallCount, 3);
    expect(find.text('Within 50 miles'), findsOneWidget);
    expect(find.text('3 Mosques'), findsOneWidget);
    expect(find.text('Neighborhood Masjid'), findsOneWidget);

    await applyRadius(100);
    expect(_TrackingMosqueNotifier.lastRadiusMiles, 100);
    expect(_TrackingMosqueNotifier.loadNearbyCallCount, 4);
    expect(find.text('Within 100 miles'), findsOneWidget);
    expect(find.text('3 Mosques'), findsOneWidget);
    expect(find.text('Neighborhood Masjid'), findsOneWidget);

    await applyRadius(150);
    expect(_TrackingMosqueNotifier.lastRadiusMiles, 150);
    expect(_TrackingMosqueNotifier.loadNearbyCallCount, 5);
    expect(find.text('Within 150 miles'), findsOneWidget);
    expect(find.text('4 Mosques'), findsOneWidget);
    expect(find.text('Neighborhood Masjid'), findsOneWidget);
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
