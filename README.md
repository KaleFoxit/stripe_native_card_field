A simple and clean Stripe Element Card clone, rebuilt in native Flutter widgets.

# DISCLAIMER

This is not an officially maintained package by Stripe, but using the html stripe
elements they provide in flutter was inconvenient for me, so I made this package.

# Features

Got to use emojis and taglines for attention grabbing and algorithm hacking:

- 󱐋  Blazingly fast ( its as fast as the rest of flutter )
- 󰃢  Cleaner ( fewer dependencies than the official stripe elements )
- 🛡  Safe and Supports all Flutter Targets ( its native flutter with minimal dependencies )
- ☑  Seemless UI/UX ( hard to match stripe quality, but I think I got close )
-   Built-in Stripe Integration ( guess that one is obvious )
- ☯  Chi Energy Boost ( alright I'm fishing... )

## Why StripeNativeCardField?

- Fewer dependencies: no more depending on Flutter Webview
- Customizable: the entire field can inherit native Flutter styling, i.e. `BoxDecoration()`
- Native Implementation: compiles and loads like the rest of your app, unlike embeded html
- Automatic validation: no `inputFormatters` or `RegExp` needed on your side

The card data can either be retrieved with the `onCardDetailsComplete` callback, or
you can have the element automatically create a Stripe card token when the fields
are filled out, and return the token with the `onTokenReceived` callback.

### Card Provider Detection

![Card Provider Detection](https://git.fosscat.com/n8r/stripe_native_card_field/raw/branch/main/readme_assets/card_provider_detection.gif)

[Documentation to supported card providers](https://pub.dev/documentation/stripe_native_card_field/latest/card_details/CardProviderID.html)

Currently support American Express, Diners Club, Discover Card, Mastercard, Jcb, Visa

### Customizable Styles

![Customizable Style 1]()

![Customizable Style 2]()

### Cross Platform

![desktop showcase](./example/loading.gif)

# Getting started

- Install the package by running `flutter pub add stripe_native_card_field`

## Usage

Include the package in a file:


```dart
import 'package:stripe_native_card_field/stripe_native_card_field.dart';
```

### For just Card Data

```dart
CardTextField(
  width: 500,
  onCardDetailsComplete: (details) {
    // Save the card details to use with your call to Stripe, or whoever
    setState(() => _cardDetails = details);
  },
);
```

### For Stripe Token

```dart
CardTextField(
  width: 500,
  stripePublishableKey: 'pk_test_abc123', // Your stripe key here
  onTokenReceived: (token) {
    // Save the stripe token to send to your backend
    setState(() => _token = token);
  },
);
```

### Cumstomization

For documentation on all of the available customizable aspects of the `CardTextField`, go
to the [API docs here](https://pub.dev/documentation/stripe_native_card_field/latest/stripe_native_card_field/CardTextField-class.html).

# Additional information

Repository located [here](https://git.fosscat.com/n8r/stripe_native_card_field)
