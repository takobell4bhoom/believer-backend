import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/screens/business_registration_basic/business_registration_basic_models.dart';
import 'package:believer/screens/business_registration_basic/business_registration_basic_screen.dart';
import 'package:believer/screens/business_registration_basic/business_registration_basic_widgets.dart'
    as basic_widgets;
import 'package:believer/screens/business_registration_contact/business_registration_contact_model.dart';
import 'package:believer/screens/business_registration_contact/business_registration_contact_screen.dart';
import 'package:believer/screens/business_registration_contact/business_registration_contact_widgets.dart'
    as contact_widgets;

void main() {
  testWidgets('basic step can proceed without a logo', (tester) async {
    int nextTapCount = 0;

    await _pumpMobileScenario(
      tester,
      child: BusinessRegistrationBasicScreen(
        initialDraft: _completeBasicDraft().copyWith(clearLogo: true),
        onNext: (_) async => nextTapCount++,
        onSaveDraftAndClose: (_) async {},
      ),
      keyboardInset: 0,
    );

    expect(_findSectionLabelText('Logo'), findsOneWidget);
    expect(_findSectionLabelText('Logo*'), findsNothing);

    final ElevatedButton nextButton = tester.widget(
      find.widgetWithText(ElevatedButton, 'Next'),
    );
    expect(nextButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    expect(nextTapCount, 1);
  });

  testWidgets('basic step footer collapses when keyboard is open',
      (tester) async {
    int nextTapCount = 0;
    final Widget screen = BusinessRegistrationBasicScreen(
      initialDraft: _completeBasicDraft(),
      onNext: (_) async => nextTapCount++,
      onSaveDraftAndClose: (_) async {},
    );

    await _pumpMobileScenario(
      tester,
      child: screen,
      keyboardInset: 0,
    );

    final Finder footerContainer = find.byKey(
      const ValueKey('business-registration-basic-footer-container'),
    );
    final double expandedHeight = tester.getSize(footerContainer).height;

    expect(find.text('Please fill all the input fields to proceed'),
        findsOneWidget);
    expect(find.text('Save as draft & close'), findsOneWidget);

    await _pumpMobileScenario(
      tester,
      child: screen,
      keyboardInset: 280,
    );

    final double collapsedHeight = tester.getSize(footerContainer).height;

    expect(collapsedHeight, lessThan(expandedHeight));
    expect(
        find.text('Please fill all the input fields to proceed'), findsNothing);
    expect(find.text('Save as draft & close'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Next'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    expect(nextTapCount, 1);
  });

  testWidgets('contact step footer collapses when keyboard is open',
      (tester) async {
    int submitTapCount = 0;
    final Widget screen = BusinessRegistrationContactScreen(
      initialValue: _submitReadyContactDraft(),
      onSubmit: (_) async => submitTapCount++,
      onSaveDraft: (_) async {},
      onBackPressed: () {},
    );

    await _pumpMobileScenario(
      tester,
      child: screen,
      keyboardInset: 0,
    );

    final Finder footerContainer = find.byKey(
      const ValueKey('business-registration-contact-footer-container'),
    );
    final double expandedHeight = tester.getSize(footerContainer).height;

    expect(find.widgetWithText(OutlinedButton, 'Back'), findsOneWidget);
    expect(
        find.widgetWithText(ElevatedButton, 'Submit Listing'), findsOneWidget);
    expect(find.text('Save as draft & close'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpMobileScenario(
      tester,
      child: screen,
      keyboardInset: 280,
    );

    final double collapsedHeight = tester.getSize(footerContainer).height;

    expect(collapsedHeight, lessThan(expandedHeight));
    expect(find.text('Save as draft & close'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Back'), findsOneWidget);
    expect(
        find.widgetWithText(ElevatedButton, 'Submit Listing'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Listing'));
    await tester.pumpAndSettle();

    expect(submitTapCount, 1);
  });

  testWidgets(
      'basic details screen stays scrollable and stable with keyboard open',
      (tester) async {
    await _pumpMobileScenario(
      tester,
      child: BusinessRegistrationBasicScreen(
        initialDraft: const BusinessRegistrationBasicDraft(
          businessName: 'Noor Foods',
          tagline: 'Halal catering for every gathering',
          description: 'A long business description for keyboard testing.',
        ),
        onNext: (_) async {},
        onSaveDraftAndClose: (_) async {},
      ),
      keyboardInset: 280,
    );

    final Finder descriptionField = find.byType(TextField).last;
    await tester.ensureVisible(descriptionField);
    await tester.pumpAndSettle();
    await tester.showKeyboard(descriptionField);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Register Your Business'), findsOneWidget);
    expect(
      find.byType(basic_widgets.BusinessRegistrationSectionLabel),
      findsWidgets,
    );
    expect(find.byType(TextField), findsWidgets);
    expect(
      tester.getRect(find.widgetWithText(ElevatedButton, 'Next')).bottom,
      lessThanOrEqualTo(640),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact screen stays scrollable and stable with keyboard open',
      (tester) async {
    await _pumpMobileScenario(
      tester,
      child: BusinessRegistrationContactScreen(
        initialValue: const BusinessRegistrationContactDraft(
          businessEmail: 'owner@example.com',
          phone: '+91 9988776655',
          whatsapp: '+91 9988776655',
          openingTime: TimeOfDay(hour: 9, minute: 0),
          closingTime: TimeOfDay(hour: 18, minute: 0),
          address: '45 Crescent Road',
          zipCode: '560001',
          city: 'Bengaluru',
        ),
        onSubmit: (_) async {},
        onSaveDraft: (_) async {},
        onBackPressed: () {},
      ),
      keyboardInset: 280,
    );

    final Finder cityField = find.byType(TextFormField).last;
    await tester.ensureVisible(cityField);
    await tester.pumpAndSettle();
    await tester.showKeyboard(cityField);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit Listing'));
    await tester.pumpAndSettle();

    expect(
      find.byType(contact_widgets.BusinessRegistrationFieldLabel),
      findsWidgets,
    );
    expect(find.byType(TextFormField), findsWidgets);
    expect(
      tester
          .getRect(find.widgetWithText(ElevatedButton, 'Submit Listing'))
          .bottom,
      lessThanOrEqualTo(640),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('basic multiline fields do not overflow in compact viewport',
      (tester) async {
    await _pumpMobileScenario(
      tester,
      child: BusinessRegistrationBasicScreen(
        onNext: (_) async {},
        onSaveDraftAndClose: (_) async {},
      ),
      keyboardInset: 280,
    );

    final Finder descriptionField = find.byType(TextField).last;
    await tester.ensureVisible(descriptionField);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    expect(descriptionField, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact multiline address field does not overflow with keyboard',
      (tester) async {
    await _pumpMobileScenario(
      tester,
      child: BusinessRegistrationContactScreen(
        onSubmit: (_) async {},
        onSaveDraft: (_) async {},
        onBackPressed: () {},
      ),
      keyboardInset: 280,
    );

    final Finder addressField = find.byType(TextFormField).at(6);
    await tester.ensureVisible(addressField);
    await tester.pumpAndSettle();
    await tester.showKeyboard(addressField);
    await tester.pumpAndSettle();

    expect(addressField, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lower form fields remain reachable while editing on both steps',
      (tester) async {
    await _pumpMobileScenario(
      tester,
      child: BusinessRegistrationBasicScreen(
        initialDraft: _completeBasicDraft(),
        onNext: (_) async {},
        onSaveDraftAndClose: (_) async {},
      ),
      keyboardInset: 280,
    );

    final Finder basicDescriptionField = find.byType(TextField).last;
    await tester.ensureVisible(basicDescriptionField);
    await tester.showKeyboard(basicDescriptionField);
    await tester.pumpAndSettle();

    final Rect basicFieldRect = tester.getRect(basicDescriptionField);
    final double basicButtonTop =
        tester.getRect(find.widgetWithText(ElevatedButton, 'Next')).top;

    expect(basicFieldRect.top, greaterThanOrEqualTo(0));
    expect(basicFieldRect.top, lessThan(basicButtonTop));

    await _pumpMobileScenario(
      tester,
      child: BusinessRegistrationContactScreen(
        initialValue: _submitReadyContactDraft(),
        onSubmit: (_) async {},
        onSaveDraft: (_) async {},
        onBackPressed: () {},
      ),
      keyboardInset: 280,
    );

    final Finder cityField = find.byType(TextFormField).last;
    await tester.ensureVisible(cityField);
    await tester.showKeyboard(cityField);
    await tester.pumpAndSettle();

    final Rect cityFieldRect = tester.getRect(cityField);
    final double submitButtonTop = tester
        .getRect(find.widgetWithText(ElevatedButton, 'Submit Listing'))
        .top;

    expect(cityFieldRect.top, greaterThanOrEqualTo(0));
    expect(cityFieldRect.top, lessThan(submitButtonTop));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpMobileScenario(
  WidgetTester tester, {
  required Widget child,
  required double keyboardInset,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(320, 640),
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
        ),
        child: child,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

BusinessRegistrationBasicDraft _completeBasicDraft() {
  return BusinessRegistrationBasicDraft(
    businessName: 'Noor Foods',
    logo: const BusinessRegistrationLogoAsset(
      fileName: 'logo.png',
      contentType: 'image/png',
    ),
    selectedType: const BusinessRegistrationSelectedType(
      groupId: 'food',
      groupLabel: 'Food',
      itemId: 'catering',
      itemLabel: 'Catering',
    ),
    tagline: 'Halal catering for every gathering',
    description: 'A long business description for keyboard testing.',
  );
}

BusinessRegistrationContactDraft _submitReadyContactDraft() {
  return const BusinessRegistrationContactDraft(
    businessEmail: 'owner@example.com',
    phone: '+91 9988776655',
    whatsapp: '+91 9988776655',
    openingTime: TimeOfDay(hour: 9, minute: 0),
    closingTime: TimeOfDay(hour: 18, minute: 0),
    address: '45 Crescent Road',
    zipCode: '560001',
    city: 'Bengaluru',
  );
}

Finder _findSectionLabelText(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is RichText &&
        widget.text.toPlainText(includeSemanticsLabels: false) == text,
    description: 'section label "$text"',
  );
}
