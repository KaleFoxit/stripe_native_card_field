## 0.0.10

- One little 'Y' I missed
- Fixed out of range error with `_adjustSelection`

## 0.0.9

- Drastically improved usability and performance with flutter web and canvaskit renderer, especially on mobile
- Using streams to more accurately call `widget.onValidCardDetails` when the card details are valid and completed
- Added `cursorColor` customization
- Reworked widget life cycle so that hot reloads work as expected (resizing, focus, etc.).

## 0.0.8

- Updated dart sdk constraints again... oops (>=3.0.0)

## 0.0.7

- Changed pubspec versioning to allow lower SDK constraints (>=2.12.0)

## 0.0.6

- Improved assertion and error messaging when missing stripe implements
- Added better doc comments
- Fixed `CardTextField.delayToShowLoading`, now it uses it
- Fixed bad assertion logic when providing stripe keys
- Added ability to make Stripe call with `GlobalKey`
- Refactored method `onTokenReceived` to `onStripeResponse` to be clearer
- Refactored method `onCardDetailsComplete` to `onValidCardDetails` to be clearer

## 0.0.5

- Fix Web, invalid call to `Platform.isAndroid`
- Analysis issues fixed for pub points

## 0.0.4

- Fix for focus and soft keyboard on mobile devices
- Added README gif to show `CardTextField` in action
- Added Icon color customization to `CardProviderIcon` widget
- Fleshed out a dark mode styling example

## 0.0.3

Lots of improvements!

- `CardTextField` now has customizable styles. Stripe integration is natively handled now, returning a card token, if stripe keys are provided.
- `README` revamped with emojis, screen recordings, the whole nine yards.
- `LICENSE` changed from BSD-3.0 to MIT license for pub points, I guess it wasn't being recognized correctly...
- Added `http` depency for handling Stripe token api call.
- Added Widget tests because that should be a thing that gets checked.
- Fix for backspacing on mobile not changing focus.
- Fix for text field spacing when in small form factor
- Much improved usability on mobile, added manually scrolling to element
- Added Icon Size param for card Provider Icon


## 0.0.2

Added dartdoc comments for more pub points!

## 0.0.1

I think it works
