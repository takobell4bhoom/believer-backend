import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/widgets/mosque_image_frame.dart';

void main() {
  testWidgets('mosque image frame defaults to a 16:9 landscape ratio',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MosqueImageFrame(
            child: ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );

    final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspectRatio.aspectRatio, closeTo(16 / 9, 0.0001));
  });
}
