import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stripe_native_card_field/card_details.dart';

import 'package:stripe_native_card_field/stripe_native_card_field.dart';

void main() {
  const cardFieldKey = 'card_field';
  const String expirationFieldKey = 'expiration_field';
  const String securityFieldKey = 'security_field';
  // const String postalFieldKey = 'postal_field';

  testWidgets(
    'CardTextField: GIVEN the user enters valid input WHEN each text field is filled THEN the focus automagically changes to each field',
    (tester) async {
      const width = 500.0;
      CardDetails? details;
      final cardField = CardTextField(
        width: width,
        onCardDetailsComplete: (cd) => details = cd,
      );
      await tester.pumpWidget(baseCardFieldWidget(cardField));

      final input = TestTextInput();

      final cardState = tester.state(find.byType(CardTextField)) as CardTextFieldState;

      assertEmptyTextFields(tester, cardState.isWideFormat);

      await tester.tap(find.byType(CardTextField));
      expect(cardState.cardNumberFocusNode.hasFocus, true);

      // await enterTextByKey(tester, key: cardFieldKey, text: '4242424242424242');
      input.enterText("4242424242424242");
      await tester.pump();

      expect(cardState.cardNumberFocusNode.hasFocus, false);
      expect(cardState.expirationFocusNode.hasFocus, true);
      // Postal code should move into view
      expect(find.text("Postal Code"), findsOneWidget);

      // Deleting should change focus back to card field and remove one character
      // Backspace should move focus back to card number

      await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(getTextFormField(expirationFieldKey).controller?.text, '');
      expect(getTextFormField(cardFieldKey).controller?.text, '4242 4242 4242 424');
      expect(cardState.cardNumberFocusNode.hasFocus, true);
      expect(cardState.expirationFocusNode.hasFocus, false);
      // Postal code should now be gone
      // FIXME this doesnt work
      // expect(find.text("Postal Code"), findsNothing);

      // When using TestTextInput, any enterText() clears what is currently in focused field
      input.enterText("4242424242424242");
      await tester.pump();

      expect(getTextFormField(cardFieldKey).controller?.text, '4242 4242 4242 4242');
      expect(cardState.cardNumberFocusNode.hasFocus, false);
      expect(cardState.expirationFocusNode.hasFocus, true);
      // Postal code should move back into view
      expect(find.text("Postal Code"), findsOneWidget);

      input.enterText("1028");
      await tester.pump();

      expect(getTextFormField(expirationFieldKey).controller?.text, '10/28');
      expect(cardState.expirationFocusNode.hasFocus, false);
      expect(cardState.securityCodeFocusNode.hasFocus, true);

      // FIXME this isn't transitioning focus correctly in test
      input.enterText("333");
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(getTextFormField(securityFieldKey).controller?.text, '333');
      expect(cardState.securityCodeFocusNode.hasFocus, false);
      expect(cardState.postalCodeFocusNode.hasFocus, true);

      input.enterText("91555");
      await tester.pump();

      expect(cardState.securityCodeFocusNode.hasFocus, false);
      expect(cardState.postalCodeFocusNode.hasFocus, true);

      await input.receiveAction(TextInputAction.done);
      await tester.pump();

      final expectedCardDetails = CardDetails(
          cardNumber: '4242 4242 4242 4242', securityCode: '333', expirationString: '10/28', postalCode: '91555');
      // print('${expectedCardDetails.toString()}\n${details?.toString()}');
      expect(details?.hash, expectedCardDetails.hash);
    },
  );

  testWidgets(
      'CardTextField: GIVEN the user enters invalid input WHEN each text field is filled THEN the correct error messages are displayed',
      (tester) async {
    const width = 500.0;
    CardDetails? details;

    final cardField = CardTextField(
      width: width,
      onCardDetailsComplete: (cd) => details = cd,
    );
    await tester.pumpWidget(baseCardFieldWidget(cardField));

    final input = TestTextInput();

    final cardState = tester.state(find.byType(CardTextField)) as CardTextFieldState;

    assertEmptyTextFields(tester, cardState.isWideFormat);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    expect(cardState.cardNumberFocusNode.hasFocus, true);

    input.enterText('4242424242424222');
    await tester.pump();

    expect(find.text('Your card number is invalid.'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(cardState.cardNumberFocusNode.hasFocus, true);

    input.enterText('4242424242424242');
    await tester.pump();

    expect(cardState.expirationFocusNode.hasFocus, true);

    input.enterText('0055');
    await tester.pump();

    expect(find.text("Your card's expiration month is invalid."), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(cardState.expirationFocusNode.hasFocus, true);

    input.enterText('1099');
    await tester.pump();

    expect(find.text("Your card's expiration year is invalid."), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(cardState.expirationFocusNode.hasFocus, true);

    input.enterText('0228');
    await tester.pump();

    expect(cardState.securityCodeFocusNode.hasFocus, true);

    // FIXME this isnt transitioning focus correctly in test
    input.enterText('123');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(cardState.postalCodeFocusNode.hasFocus, true);

    input.enterText('1234');
    // Pressing enter doesnt work here...
    await input.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text("The postal code you entered is not correct."), findsOneWidget);

    await tester.tap(find.byType(CardTextField));

    // Tab from security field to get zipcode focus
    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    expect(cardState.postalCodeFocusNode.hasFocus, true);

    input.enterText('12345');
    await input.receiveAction(TextInputAction.done);
    await tester.pump();

    final expectedCardDetails = CardDetails(
        cardNumber: '4242 4242 4242 4242', expirationString: '02/28', securityCode: '123', postalCode: '12345');

    expect(details?.hash, expectedCardDetails.hash);
  });
}

Widget baseCardFieldWidget(CardTextField cardField) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            children: [
              cardField,
            ],
          ),
        ),
      ),
    );

void assertEmptyTextFields(WidgetTester tester, bool isWideFormat) {
  if (isWideFormat) {
    expect(find.text("Card number"), findsOneWidget);
    expect(find.text("MM/YY"), findsOneWidget);
    expect(find.text("CVC"), findsOneWidget);
  }
  // expect(find.text("Postal Code"), findsNothing);
}

Future<void> enterTextByKey(WidgetTester tester, {required String key, required String text}) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
}

TextFormField getTextFormField(String key) {
  return find.byKey(ValueKey(key)).evaluate().single.widget as TextFormField;
}
