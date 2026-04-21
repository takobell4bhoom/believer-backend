import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/mosque_admin_add_screen.dart';
import 'package:believer/services/browser_image_picker.dart';
import 'package:believer/services/location_preferences_service.dart';
import 'package:believer/services/mosque_service.dart';
import 'package:believer/models/mosque_model.dart';

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

class _CommunityAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'community-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 'community-1',
        fullName: 'Community User',
        email: 'community@example.com',
        role: 'community',
      ),
    );
  }
}

class _RecordingMosqueService extends MosqueService {
  Map<String, dynamic>? lastPayload;
  String? lastBearerToken;
  MosqueImageUploadFile? lastUploadFile;
  int uploadCalls = 0;

  @override
  Future<MosqueModel> createMosque({
    required Map<String, dynamic> payload,
    String? bearerToken,
  }) async {
    lastPayload = payload;
    lastBearerToken = bearerToken;

    return const MosqueModel(
      id: '11111111-1111-1111-1111-111111111111',
      name: 'Admin Created Mosque',
      addressLine: '15 Unity Street',
      city: 'Bengaluru',
      state: 'Karnataka',
      country: 'India',
      imageUrl: '',
      rating: 4.0,
      distanceMiles: 0,
      sect: 'Sunni',
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
    );
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
          'http://localhost:4000/uploads/mosques/admin-created-$uploadCalls.jpg',
      imagePath: '/uploads/mosques/admin-created-$uploadCalls.jpg',
      fileName: 'admin-created-$uploadCalls.jpg',
    );
  }
}

class _FakeBrowserImagePicker implements BrowserImagePicker {
  int _callCount = 0;

  @override
  Future<BrowserPickedImage?> pickImage() async {
    _callCount += 1;
    return BrowserPickedImage(
      fileName: _callCount == 1 ? 'mosque.png' : 'mosque-2.webp',
      bytes: Uint8List.fromList(
        _callCount == 1 ? const <int>[1, 2, 3, 4] : const <int>[4, 3, 2, 1],
      ),
      contentType: _callCount == 1 ? 'image/png' : 'image/webp',
    );
  }
}

class _FakeLocationPreferencesService extends LocationPreferencesService {
  String? lastQuery;

  @override
  Future<List<LocationSuggestion>> searchLocations(
    String query, {
    int limit = 5,
  }) async {
    lastQuery = query;
    return const <LocationSuggestion>[
      LocationSuggestion(
        label: '101 Mosque Ave, Tampa, FL, USA',
        latitude: 27.9506,
        longitude: -82.4572,
        primaryText: 'Downtown Community Mosque',
        secondaryText: 'Tampa, FL, USA',
      ),
    ];
  }
}

void main() {
  testWidgets('non-admin users see guarded access state', (tester) async {
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_CommunityAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.home: (_) => const Scaffold(body: Text('home stub')),
          },
          home: const MosqueAdminAddScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Admin Add Mosque'), findsOneWidget);
    expect(
      find.text(
          'This MVP write flow is restricted to persisted admin accounts.'),
      findsOneWidget,
    );
    expect(find.text('Create Mosque'), findsNothing);
  });

  testWidgets('admin users submit the live mosque payload', (tester) async {
    final service = _RecordingMosqueService();
    final imagePicker = _FakeBrowserImagePicker();
    final locationPreferencesService = _FakeLocationPreferencesService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_AdminAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.mosquesAndEvents: (_) =>
                const Scaffold(body: Text('mosques stub')),
            AppRoutes.mosqueDetail: (_) =>
                const Scaffold(body: Text('mosque detail stub')),
          },
          home: MosqueAdminAddScreen(
            mosqueService: service,
            imagePicker: imagePicker,
            locationPreferencesService: locationPreferencesService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mosque-image-guidance-note')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Best fit: upload landscape JPG, PNG, or WebP images, ideally 1600 x 900 or larger. Up to 10 images.',
      ),
      findsOneWidget,
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Admin Created Mosque');
    await tester.enterText(fields.at(1), 'Fatima Noor');
    await tester.enterText(fields.at(2), '+91-9999999999');
    await tester.enterText(fields.at(3), 'fatima@example.com');
    await tester.enterText(fields.at(4), 'https://example.org');
    final browseButton = find.byKey(const ValueKey('mosque-image-browse'));
    await tester.ensureVisible(browseButton);
    tester.widget<OutlinedButton>(browseButton).onPressed!();
    await tester.pumpAndSettle();
    final uploadButton = find.byKey(const ValueKey('mosque-image-upload'));
    await tester.ensureVisible(uploadButton);
    tester.widget<FilledButton>(uploadButton).onPressed!();
    await tester.pumpAndSettle();
    tester.widget<OutlinedButton>(browseButton).onPressed!();
    await tester.pumpAndSettle();
    tester.widget<FilledButton>(uploadButton).onPressed!();
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(5), '15 Unity Street');

    await tester.enterText(
      find.byKey(const ValueKey('admin-add-location-search')),
      'Downtown Community Mosque',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(locationPreferencesService.lastQuery, 'Downtown Community Mosque');
    expect(find.text('Downtown Community Mosque'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('admin-add-location-option-0')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(fields.at(10)).controller!.text,
      '27.950600',
    );
    expect(
      tester.widget<TextFormField>(fields.at(11)).controller!.text,
      '-82.457200',
    );

    await tester.enterText(fields.at(10), '27.9511');
    await tester.enterText(fields.at(11), '-82.4588');
    await tester.pumpAndSettle();

    expect(find.text('Published Events'), findsNothing);
    expect(find.byKey(const ValueKey('event-add')), findsNothing);

    final submitButton = find.byKey(const ValueKey('admin-add-mosque-submit'));
    await tester.ensureVisible(submitButton);
    tester.widget<ElevatedButton>(submitButton).onPressed!();
    await tester.pumpAndSettle();

    expect(service.lastBearerToken, 'admin-token');
    expect(service.lastPayload, isNotNull);
    expect(service.lastPayload!['name'], 'Admin Created Mosque');
    expect(service.lastPayload!['addressLine'], '15 Unity Street');
    expect(service.lastPayload!['contactName'], 'Fatima Noor');
    expect(service.lastPayload!['contactPhone'], '+91-9999999999');
    expect(service.lastPayload!['contactEmail'], 'fatima@example.com');
    expect(service.lastPayload!['websiteUrl'], 'https://example.org');
    expect(
      service.lastPayload!['imageUrl'],
      'http://localhost:4000/uploads/mosques/admin-created-1.jpg',
    );
    expect(
      service.lastPayload!['imageUrls'],
      <String>[
        'http://localhost:4000/uploads/mosques/admin-created-1.jpg',
        'http://localhost:4000/uploads/mosques/admin-created-2.jpg',
      ],
    );
    expect(service.lastPayload!['city'], 'Bengaluru');
    expect(service.lastPayload!['state'], 'Karnataka');
    expect(service.lastPayload!['country'], 'India');
    expect(service.lastPayload!['latitude'], 27.9511);
    expect(service.lastPayload!['longitude'], -82.4588);
    expect(
      service.lastPayload!['prayerTimeConfig'],
      <String, dynamic>{
        'enabled': true,
        'calculationMethod': 3,
        'school': 'standard',
        'adjustments': <String, int>{
          'fajr': 0,
          'sunrise': 0,
          'dhuhr': 0,
          'asr': 0,
          'maghrib': 0,
          'isha': 0,
        },
      },
    );
    expect(
      service.lastPayload!['facilities'],
      <String>['women_area', 'parking', 'wudu'],
    );
    expect(service.lastPayload!.containsKey('content'), isFalse);
    expect(find.text('Created Successfully'), findsOneWidget);
    expect(find.text('Admin Created Mosque'), findsWidgets);
    expect(find.text('Manage Mosque'), findsOneWidget);
    expect(
      find.text(
        'Coordinates were auto-filled from Google Maps and then edited manually. Your visible values will be saved.',
      ),
      findsOneWidget,
    );
  });
}
