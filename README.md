A simple and clean Stripe Element Card clone, rebuilt in native Flutter widgets.

# DISCLAIMER

This is not an officially maintained package by Stripe, but using the html stripe
elements they provide in flutter was inconvenient for me, so I made this package.

# Features

Got to use emojis and taglines for attention grabbing and algorithm hacking:

- ⚡ Blazingly fast ( its as fast as the rest of flutter )
- 🧹 Cleaner & Easier to Use ( fewer dependencies than the official stripe elements )
- 🛡  Safe and Supports all Flutter Targets ( its native flutter with minimal dependencies )
- ☑  Seemless UI/UX ( hard to match stripe quality, but I think I got pretty close )
- 💳 Built-in Stripe Integration ( guess that one is obvious )
- ☯  Chi Energy Boost ( alright I'm fishing... )

## Why StripeNativeCardField?

- Fewer dependencies: no more depending on Flutter Webview
- Customizable: the entire field can inherit native Flutter styling, i.e. `BoxDecoration()`
- Native Implementation: compiles and loads like the rest of your app, unlike embeded html
- Automatic validation: no `inputFormatters` or `RegExp` needed on your side

The card data can either be retrieved with the `onValidCardDetails` callback, or
you can have the element automatically create a Stripe card token when the fields
are filled out, and return the token with the `onTokenReceived` callback.

### Card Provider Detection

![Card Provider Detection](https://git.fosscat.com/n8r/stripe_native_card_field/raw/branch/main/readme_assets/card_provider_detection.gif)

[Supported Card Providers in Docs](https://pub.dev/documentation/stripe_native_card_field/latest/card_details/CardProviderID.html)

### Customizable Styles

![Customizable Style 1](https://git.fosscat.com/n8r/stripe_native_card_field/raw/branch/main/readme_assets/customizable_style.gif)

This dark mode style example provided [here](https://git.fosscat.com/n8r/stripe_native_card_field/raw/branch/main/example/lib/dark_customization.dart)

For documentation on all of the available customizable aspects of the `CardTextField`, go
to the [API docs here](https://pub.dev/documentation/stripe_native_card_field/latest/stripe_native_card_field/CardTextField-class.html).

### Smooth UX

![Smooth UX](https://git.fosscat.com/n8r/stripe_native_card_field/raw/branch/main/readme_assets/smooth_ux.gif)

Mimics the Stripe html elements behavior wherever possible. Auto focusing / transitioning text fields, backspacing focuses to last field,
automatically validating user input, etc.

# Getting started

- Install the package by running `flutter pub add stripe_native_card_field`

## Usage

Include the package in a file:


```dart
import 'package:stripe_native_card_field/stripe_native_card_field.dart';
```

### For Raw Card Data

Provide a callback for the `CardTextField` to return you the data when its complete.
```dart
CardTextField(
  width: 500,
  onValidCardDetails: (details) {
    // Save the card details to use with your call to Stripe, or whoever
    setState(() => _cardDetails = details);
  },
);
```

### For Stripe Token

Simply provide a function for the `onStripeResponse` callback!

```dart
CardTextField(
  width: 500,
  stripePublishableKey: 'pk_test_abc123', // Your stripe key here
  onStripeResponse: (Map<String, dynamic> data) {
    // Save the stripe token to send to your backend
    setState(() => _tokenData = data);
  },
);
```

If you want more fine-grained control of when the stripe call is made, you
can create a `GlobalKey` and access the `CardTextFieldState`, calling the
`getStripeResponse()` function yourself. See the provided [example](https://pub.dev/packages/stripe_native_card_field/example)
for details. If you choose this route, do not provide an `onStripeResponse` callback, or you will end up
making two calls to stripe!

# Additional information

Repository located [here](https://git.fosscat.com/n8r/stripe_native_card_field)

Please email me at n8r@fosscat.com for any issues or PRs.
