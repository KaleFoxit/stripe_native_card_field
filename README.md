For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

A simple and clean Stripe Element Card clone, rebuilt in native Flutter widgets.

This is not an officially maintained package by Stripe, but using the html stripe
elements they provide with flutter is less than ideal.

## Features

- Card number validation
- No more depending on Flutter Webview

## Getting started

- Install the package by running `flutter pub add stripe_native_card_field`

## Usage

Include the package in a file:

```dart
import 'package:stripe_native_card_field/stripe_native_card_field.dart';
```

```dart
CardTextField(
  width: 500,
  onCardDetailsComplete: (details) {
    // Save the card details to use with your call to Stripe, or whoever
    setState(() => _cardDetails = details);
  },
);
```

## Additional information

Repository located [here](https://git.fosscat.com/n8r/stripe_native_card_field)
