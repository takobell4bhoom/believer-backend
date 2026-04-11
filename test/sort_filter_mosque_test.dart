import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/screens/sort_filter_mosque.dart';

void main() {
  testWidgets('sort filter mosque applies the verified payload structure',
      (tester) async {
    Map<String, dynamic>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push(
                      MaterialPageRoute<Map<String, dynamic>>(
                        builder: (_) => const SortFilterMosque(
                          initialFilters: <String, dynamic>{
                            'sortBy': 'Nearest Mosque',
                            'radius': 3,
                            'sect': 'Any',
                            'asarTime': 'Any',
                            'reviewRating': 'Any',
                            'timing': 'All mosques',
                            'facilities': <String>[],
                            'classes': <String>[],
                            'events': <String>[],
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Sort & Filter'), findsOneWidget);
    expect(find.text('SORT BY'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('FACILITIES'), findsOneWidget);
    expect(find.text('MOSQUE EVENTS'), findsOneWidget);

    await tester.tap(find.text('Earlier Dhuhr'));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(10);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sunni'));
    await tester.tap(find.text('Sunni'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('5:00 PM or later'));
    await tester.tap(find.text('5:00 PM or later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4.0+'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prayer times listed'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Parking'));
    await tester.tap(find.text('Parking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Classes listed'));
    await tester.tap(find.text('Classes listed'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Events listed'));
    await tester.tap(find.text('Events listed'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!['sortBy'], 'Earlier Dhuhr');
    expect(result!['radius'], 10);
    expect(result!['sect'], 'Sunni');
    expect(result!['asarTime'], '5:00 PM or later');
    expect(result!['reviewRating'], '4.0+');
    expect(result!['timing'], 'Prayer times listed');
    expect(result!['facilities'], contains('Parking'));
    expect(result!['classes'], contains('Classes listed'));
    expect(result!['events'], contains('Events listed'));
  });
}
