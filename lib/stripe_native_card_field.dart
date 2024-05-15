library stripe_native_card_field;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:stripe_native_card_field/card_text_field_error.dart';

import 'card_details.dart';
import 'card_provider_icon.dart';

/// Enum to track each step of the card detail
/// entry process.
enum CardEntryStep { number, exp, cvc, postal }

enum LoadingLocation { above, below }

/// A uniform text field for entering card details, based
/// on the behavior of Stripe's various html elements.
///
/// Required `width`.
///
/// To get the card data or stripe token, provide callbacks
/// for either `onValidCardDetails`, which will return a
/// `CardDetails` object, or `onStripeResponse`, which will
/// return a Map<String, dynamic> response from the Stripe Api.
///
/// If stripe integration is desired, you must provide both
/// `stripePublishableKey` and `onStripeResponse`, otherwise
/// `CardTextField` will `assert(false)` in debug mode or
/// throw a `CardTextFieldError` in profile or release mode
///
/// If the provided `width < 450.0`, the `CardTextField`
/// will scroll its content horizontally with the cursor
/// to compensate.
class CardTextField extends StatefulWidget {
  CardTextField({
    Key? key,
    required this.width,
    this.onStripeResponse,
    this.onCallToStripe,
    this.onValidCardDetails,
    this.onSubmitted,
    this.stripePublishableKey,
    this.height,
    this.textStyle,
    this.hintTextStyle,
    this.errorTextStyle,
    this.cursorColor,
    this.boxDecoration,
    this.errorBoxDecoration,
    this.loadingWidget,
    this.loadingWidgetLocation = LoadingLocation.below,
    this.autoFetchStripektoken = true,
    this.showInternalLoadingWidget = true,
    this.delayToShowLoading = const Duration(milliseconds: 0),
    this.overrideValidState,
    this.errorText,
    this.cardFieldWidth,
    this.expFieldWidth,
    this.securityFieldWidth,
    this.postalFieldWidth,
    this.iconSize,
    this.cardIconColor,
    this.cardIconErrorColor,
    this.enablePostalCode = false,
  }) : super(key: key) {
    // Setup logic for the CardTextField
    // Will assert in debug mode, otherwise will throw `CardTextFieldError` in profile or release
    if (stripePublishableKey != null) {
      if (!stripePublishableKey!.startsWith('pk_')) {
        const msg = 'Invalid stripe key, doesn\'t start with "pk_"';
        if (kDebugMode) assert(false, msg);
        if (kReleaseMode || kProfileMode) {
          throw CardTextFieldError(CardTextFieldErrorType.stripeImplementation,
              details: msg);
        }
      }
    }
  }

  /// Whether or not to show the postalcode field in the form.
  ///
  /// Defaults is `false`. If your configuration in Stripe requires a postalcode
  /// check as defined in https://stripe.com/docs/radar/rules#traditional-bank-checks
  /// make sure this one is set to `true`.
  final bool enablePostalCode;

  /// Width of the entire CardTextField
  final double width;

  /// Height of the entire CardTextField, defaults to 60.0
  final double? height;

  /// Width of card number field, only override if changing the default `textStyle.fontSize`, defaults to 180.0
  final double? cardFieldWidth;

  /// Width of expiration date field, only override if changing the default `textStyle.fontSize`, defaults to 70.0
  final double? expFieldWidth;

  /// Width of security number field, only override if changing the default `textStyle.fontSize`, defaults to 40.0
  final double? securityFieldWidth;

  /// Width of postal code field, only override if changing the default `textStyle.fontSize`, defaults to 95.0
  final double? postalFieldWidth;

  /// Overrides the default box decoration of the text field
  final BoxDecoration? boxDecoration;

  /// Overrides the default box decoration of the text field when there is a validation error
  final BoxDecoration? errorBoxDecoration;

  /// Shown and overrides `LinearProgressIndicator` if the request to stripe takes longer than `delayToShowLoading`
  /// Recommended to only override with a `LinearProgressIndicator` or similar widget, or spacing will be messed up
  final Widget? loadingWidget;

  /// Overrides default icon size of the card provider, defaults to `Size(30.0, 20.0)`
  final Size? iconSize;

  /// CSS string name of color or hex code for the card SVG icon to render
  final String? cardIconColor;

  /// CSS string name of color or hex code for the error card SVG icon to render
  final String? cardIconErrorColor;

  /// Determines where the loading indicator appears when contacting stripe
  final LoadingLocation loadingWidgetLocation;

  /// Default TextStyle
  final TextStyle? textStyle;

  /// Default TextStyle for the hint text in each TextFormField.
  /// If null, inherits from the `textStyle`.
  final TextStyle? hintTextStyle;

  /// TextStyle used when any TextFormField's have a validation error
  /// If null, inherits from the `textStyle`.
  final TextStyle? errorTextStyle;

  /// Color used for the cursor, if null, inherits the primary color of the Theme
  final Color? cursorColor;

  /// Time to wait until showing the loading indicator when retrieving Stripe token, defaults to 0 milliseconds.
  final Duration delayToShowLoading;

  /// Whether to show the internal loading widget on calls to Stripe
  final bool showInternalLoadingWidget;

  /// Whether to automatically call `getStripeResponse` when the `_cardDetails` are valid.
  final bool autoFetchStripektoken;

  /// Stripe publishable key, starts with 'pk_'
  final String? stripePublishableKey;

  /// Callback when the http request is made to Stripe
  final void Function()? onCallToStripe;

  /// Callback that returns the stripe token for the card
  final void Function(Map<String, dynamic>?)? onStripeResponse;

  /// Callback that returns the completed CardDetails object
  final void Function(CardDetails)? onValidCardDetails;

  /// Callback when the user hits enter or done in the postal code field
  /// Optionally returns the `CardDetails` object if it is valid
  final void Function(CardDetails?)? onSubmitted;

  /// Can manually override the ValidState to surface errors returned from Stripe
  final CardDetailsValidState? overrideValidState;

  /// Can manually override the errorText displayed to surface errors returned from Stripe
  final String? errorText;

  /// GlobalKey used for calling `getStripeToken` in the `CardTextFieldState`
  // final GlobalKey<CardTextFieldState> _key = GlobalKey<CardTextFieldState>();

  // CardTextFieldState? get state => _key.currentState;

  @override
  State<CardTextField> createState() => CardTextFieldState();
}

/// State Widget for CardTextField
/// Should not be used directly, except to
/// create a GlobalKey for directly accessing
/// the `getStripeResponse` function
class CardTextFieldState extends State<CardTextField> {
  late final TextEditingController _cardNumberController;
  late final TextEditingController _expirationController;
  late final TextEditingController _securityCodeController;
  late final TextEditingController _postalCodeController;
  final List<TextEditingController> _controllers = [];

  // Not made private for access in widget tests
  late final FocusNode cardNumberFocusNode;
  late final FocusNode expirationFocusNode;
  late final FocusNode securityCodeFocusNode;
  late final FocusNode postalCodeFocusNode;

  // Not made private for access in widget tests
  late bool isWideFormat;

  // Widget configurable styles
  late BoxDecoration _normalBoxDecoration;
  late BoxDecoration _errorBoxDecoration;
  late TextStyle _errorTextStyle;
  late TextStyle _normalTextStyle;
  late TextStyle _hintTextSyle;
  late Color _cursorColor;

  /// Width of the card number text field
  late double _cardFieldWidth;

  /// Width of the expiration text field
  late double _expirationFieldWidth;

  /// Width of the security code text field
  late double _securityFieldWidth;

  /// Width of the postal code text field
  late double _postalFieldWidth;

  /// Width of the internal scrollable field, is potentially larger than the provided `widget.width`
  late double _internalFieldWidth;

  /// Width of the gap between card number and expiration text fields when expanded
  late double _expanderWidthExpanded;

  /// Width of the gap between card number and expiration text fields when collapsed
  late double _expanderWidthCollapsed;

  String? _validationErrorText;
  bool _showBorderError = false;
  late bool _isMobile;

  /// If a request to Stripe is being made
  bool _loading = false;
  final CardDetails _cardDetails = CardDetails.blank();
  int _prevErrorOverrideHash = 0;

  final _currentCardEntryStepController = StreamController<CardEntryStep>();
  final _horizontalScrollController = ScrollController();
  CardEntryStep _currentStep = CardEntryStep.number;

  final _formFieldKey = GlobalKey<FormState>();

  @override
  void initState() {
    _calculateProperties();

    // No way to get backspace events on soft keyboards, so add invisible character to detect delete
    _cardNumberController = TextEditingController();
    _expirationController =
        TextEditingController(text: _isMobile ? '\u200b' : '');
    _securityCodeController =
        TextEditingController(text: _isMobile ? '\u200b' : '');
    _postalCodeController =
        TextEditingController(text: _isMobile ? '\u200b' : '');

    _controllers.addAll([
      _cardNumberController,
      _expirationController,
      _securityCodeController,
      _postalCodeController,
    ]);

    cardNumberFocusNode = FocusNode();
    expirationFocusNode = FocusNode();
    securityCodeFocusNode = FocusNode();
    postalCodeFocusNode = FocusNode();

    // Add backspace transition listener for non mobile clients
    if (!_isMobile) {
      RawKeyboard.instance.addListener(_backspaceTransitionListener);
    }

    // Add listener to change focus and whatnot between fields
    _currentCardEntryStepController.stream.listen(
      _onStepChange,
    );

    // Add listeners to know when card details are completed
    _cardDetails.onCompleteController.stream.listen((card) async {
      if (widget.stripePublishableKey != null &&
          widget.onStripeResponse != null &&
          widget.autoFetchStripektoken) {
        final res = await getStripeResponse();
        widget.onStripeResponse!(res);
      }
      if (widget.onValidCardDetails != null) widget.onValidCardDetails!(card);
    });

    super.initState();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expirationController.dispose();
    _securityCodeController.dispose();
    _postalCodeController.dispose();

    cardNumberFocusNode.dispose();
    expirationFocusNode.dispose();
    securityCodeFocusNode.dispose();
    postalCodeFocusNode.dispose();

    if (!_isMobile) {
      RawKeyboard.instance.removeListener(_backspaceTransitionListener);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _calculateProperties();
    _initStyles();
    _checkErrorOverride();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Form(
          key: _formFieldKey,
          child: GestureDetector(
            onTap: () {
              // Focuses to the current field
              _currentCardEntryStepController.add(_currentStep);
            },
            // Enable scrolling on mobile and if its narrow (not all fields visible)
            onHorizontalDragUpdate: (details) {
              const minOffset = 0.0;
              final maxOffset =
                  _horizontalScrollController.position.maxScrollExtent;
              if (!_isMobile || isWideFormat) return;
              final newOffset =
                  _horizontalScrollController.offset - details.delta.dx;

              if (newOffset < minOffset) {
                _horizontalScrollController.jumpTo(minOffset);
              } else if (newOffset > maxOffset) {
                _horizontalScrollController.jumpTo(maxOffset);
              } else {
                _horizontalScrollController.jumpTo(newOffset);
              }
            },
            onHorizontalDragEnd: (details) {
              if (!_isMobile ||
                  isWideFormat ||
                  details.primaryVelocity == null) {
                return;
              }

              const dur = Duration(milliseconds: 300);
              const cur = Curves.ease;

              // final max = _horizontalScrollController.position.maxScrollExtent;
              final newOffset = _horizontalScrollController.offset -
                  details.primaryVelocity! * 0.15;
              _horizontalScrollController.animateTo(newOffset,
                  curve: cur, duration: dur);
            },
            child: Container(
              width: widget.width,
              height: widget.height ?? 60.0,
              decoration:
                  _showBorderError ? _errorBoxDecoration : _normalBoxDecoration,
              child: ClipRect(
                child: IgnorePointer(
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _internalFieldWidth,
                      height: widget.height ?? 60.0,
                      child: Column(
                        children: [
                          if (widget.loadingWidgetLocation ==
                              LoadingLocation.above)
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity:
                                  _loading && widget.showInternalLoadingWidget
                                      ? 1.0
                                      : 0.0,
                              child: widget.loadingWidget ??
                                  const LinearProgressIndicator(),
                            ),
                          Padding(
                            padding: switch (widget.loadingWidgetLocation) {
                              LoadingLocation.above =>
                                const EdgeInsets.only(top: 0, bottom: 4.0),
                              LoadingLocation.below =>
                                const EdgeInsets.only(top: 4.0, bottom: 0),
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0),
                                  child: CardProviderIcon(
                                    cardDetails: _cardDetails,
                                    size: widget.iconSize,
                                    defaultCardColor: widget.cardIconColor,
                                    errorCardColor: widget.cardIconErrorColor,
                                  ),
                                ),
                                SizedBox(
                                  width: _cardFieldWidth,
                                  child: TextFormField(
                                    key: const Key('card_field'),
                                    focusNode: cardNumberFocusNode,
                                    controller: _cardNumberController,
                                    keyboardType: TextInputType.number,
                                    style: _isRedText([
                                      CardDetailsValidState.invalidCard,
                                      CardDetailsValidState.missingCard,
                                      CardDetailsValidState.blank
                                    ])
                                        ? _errorTextStyle
                                        : _normalTextStyle,
                                    validator: (content) {
                                      if (content == null || content.isEmpty) {
                                        return null;
                                      }
                                      // setState(() => _cardDetails.cardNumber = content);

                                      if (_cardDetails.validState ==
                                          CardDetailsValidState.invalidCard) {
                                        _setValidationState(
                                            'Your card number is invalid.');
                                      } else if (_cardDetails.validState ==
                                          CardDetailsValidState.missingCard) {
                                        _setValidationState(
                                            'Your card number is incomplete.');
                                      }
                                      return null;
                                    },
                                    onChanged: (str) {
                                      _onTextFieldChanged(
                                          str, CardEntryStep.number);
                                      final numbers = str.replaceAll(' ', '');
                                      if (str.length <=
                                          _cardDetails.maxINNLength) {
                                        _cardDetails.detectCardProvider();
                                      }
                                      if (numbers.length == 16) {
                                        _currentCardEntryStepController
                                            .add(CardEntryStep.exp);
                                      }
                                    },
                                    onFieldSubmitted: (_) =>
                                        _currentCardEntryStepController
                                            .add(CardEntryStep.exp),
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(19),
                                      FilteringTextInputFormatter.allow(
                                          RegExp('[0-9 ]')),
                                      CardNumberInputFormatter(),
                                    ],
                                    cursorColor: _cursorColor,
                                    decoration: InputDecoration(
                                      hintText: 'Card number',
                                      contentPadding: EdgeInsets.zero,
                                      hintStyle: _hintTextSyle,
                                      fillColor: Colors.transparent,
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                if (isWideFormat)
                                  Flexible(
                                    fit: FlexFit.loose,
                                    // fit: _currentStep == CardEntryStep.number ? FlexFit.loose : FlexFit.tight,
                                    child: AnimatedContainer(
                                      curve: Curves.easeInOut,
                                      duration:
                                          const Duration(milliseconds: 400),
                                      constraints: _currentStep ==
                                              CardEntryStep.number
                                          ? BoxConstraints.loose(
                                              Size(_expanderWidthExpanded, 0.0),
                                            )
                                          : BoxConstraints.tight(
                                              Size(
                                                  _expanderWidthCollapsed, 0.0),
                                            ),
                                    ),
                                  ),

                                // Spacer(flex: _currentStep == CardEntryStep.number ? 100 : 1),
                                SizedBox(
                                  width: _expirationFieldWidth,
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      // Must manually add hint label because they wont show on mobile with backspace hack
                                      if (_isMobile &&
                                          _expirationController.text ==
                                              '\u200b')
                                        Text('MM/YY', style: _hintTextSyle),
                                      TextFormField(
                                        key: const Key('expiration_field'),
                                        focusNode: expirationFocusNode,
                                        controller: _expirationController,
                                        keyboardType: TextInputType.number,
                                        style: _isRedText([
                                          CardDetailsValidState.dateTooLate,
                                          CardDetailsValidState.dateTooEarly,
                                          CardDetailsValidState.missingDate,
                                          CardDetailsValidState.invalidMonth
                                        ])
                                            ? _errorTextStyle
                                            : _normalTextStyle,
                                        validator: (content) {
                                          if (content == null ||
                                              content.isEmpty ||
                                              _isMobile &&
                                                  content == '\u200b') {
                                            return null;
                                          }

                                          // if (_isMobile) {
                                          //   setState(
                                          //       () => _cardDetails.expirationString = content.replaceAll('\u200b', ''));
                                          // } else {
                                          //   setState(() => _cardDetails.expirationString = content);
                                          // }

                                          if (_cardDetails.validState ==
                                              CardDetailsValidState
                                                  .dateTooEarly) {
                                            _setValidationState(
                                                'Your card\'s expiration date is in the past.');
                                          } else if (_cardDetails.validState ==
                                              CardDetailsValidState
                                                  .dateTooLate) {
                                            _setValidationState(
                                                'Your card\'s expiration year is invalid.');
                                          } else if (_cardDetails.validState ==
                                              CardDetailsValidState
                                                  .missingDate) {
                                            _setValidationState(
                                                'You must include your card\'s expiration date.');
                                          } else if (_cardDetails.validState ==
                                              CardDetailsValidState
                                                  .invalidMonth) {
                                            _setValidationState(
                                                'Your card\'s expiration month is invalid.');
                                          }
                                          return null;
                                        },
                                        onChanged: (str) {
                                          _onTextFieldChanged(
                                              str, CardEntryStep.exp);
                                          if (str.length == 5) {
                                            _currentCardEntryStepController
                                                .add(CardEntryStep.cvc);
                                          }
                                        },
                                        onFieldSubmitted: (_) =>
                                            _currentCardEntryStepController
                                                .add(CardEntryStep.cvc),
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(5),
                                          FilteringTextInputFormatter.allow(
                                              RegExp('[0-9/]')),
                                          CardExpirationFormatter(),
                                        ],
                                        cursorColor: _cursorColor,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.zero,
                                          hintText: _isMobile ? '' : 'MM/YY',
                                          hintStyle: _hintTextSyle,
                                          fillColor: Colors.transparent,
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: _securityFieldWidth,
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      if (_isMobile &&
                                          _securityCodeController.text ==
                                              '\u200b')
                                        Text(
                                          'CVC',
                                          style: _hintTextSyle,
                                        ),
                                      TextFormField(
                                        key: const Key('security_field'),
                                        focusNode: securityCodeFocusNode,
                                        controller: _securityCodeController,
                                        keyboardType: TextInputType.number,
                                        style: _isRedText([
                                          CardDetailsValidState.invalidCVC,
                                          CardDetailsValidState.missingCVC
                                        ])
                                            ? _errorTextStyle
                                            : _normalTextStyle,
                                        validator: (content) {
                                          if (content == null ||
                                              content.isEmpty ||
                                              _isMobile &&
                                                  content == '\u200b') {
                                            return null;
                                          }

                                          // if (_isMobile) {
                                          //   setState(
                                          //       () => _cardDetails.securityCode = content.replaceAll('\u200b', ''));
                                          // } else {
                                          //   setState(() => _cardDetails.securityCode = content);
                                          // }

                                          if (_cardDetails.validState ==
                                              CardDetailsValidState
                                                  .invalidCVC) {
                                            _setValidationState(
                                                'Your card\'s security code is invalid.');
                                          } else if (_cardDetails.validState ==
                                              CardDetailsValidState
                                                  .missingCVC) {
                                            _setValidationState(
                                                'Your card\'s security code is incomplete.');
                                          }
                                          return null;
                                        },
                                        onFieldSubmitted: (_) =>
                                            _currentCardEntryStepController
                                                .add(CardEntryStep.postal),
                                        onChanged: (str) {
                                          _onTextFieldChanged(
                                              str, CardEntryStep.cvc);

                                          if (str.length ==
                                              _cardDetails
                                                  .provider?.cvcLength) {
                                            _currentCardEntryStepController
                                                .add(CardEntryStep.postal);
                                          }
                                        },
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(
                                              _cardDetails.provider == null
                                                  ? 4
                                                  : _cardDetails
                                                      .provider!.cvcLength),
                                          FilteringTextInputFormatter.allow(
                                              RegExp('[0-9]')),
                                        ],
                                        cursorColor: _cursorColor,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.zero,
                                          hintText: _isMobile ? '' : 'CVC',
                                          hintStyle: _hintTextSyle,
                                          fillColor: Colors.transparent,
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if(widget.enablePostalCode)
                                SizedBox(
                                  width: _postalFieldWidth,
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      if (_isMobile &&
                                          _postalCodeController.text ==
                                              '\u200b')
                                        Text(
                                          'Postal Code',
                                          style: _hintTextSyle,
                                        ),
                                      TextFormField(
                                        key: const Key('postal_field'),
                                        focusNode: postalCodeFocusNode,
                                        controller: _postalCodeController,
                                        keyboardType: TextInputType.number,
                                        style: _isRedText([
                                          CardDetailsValidState.invalidZip,
                                          CardDetailsValidState.missingZip
                                        ])
                                            ? _errorTextStyle
                                            : _normalTextStyle,
                                        validator: (content) {
                                          if (content == null ||
                                              content.isEmpty ||
                                              _isMobile &&
                                                  content == '\u200b') {
                                            return null;
                                          }

                                          // if (_isMobile) {
                                          //   setState(() => _cardDetails.postalCode = content.replaceAll('\u200b', ''));
                                          // } else {
                                          //   setState(() => _cardDetails.postalCode = content);
                                          // }

                                          if (_cardDetails.validState ==
                                              CardDetailsValidState
                                                  .invalidZip) {
                                            _setValidationState(
                                                'The postal code you entered is not correct.');
                                          } else if (_cardDetails.validState ==
                                              CardDetailsValidState
                                                  .missingZip) {
                                            _setValidationState(
                                                'You must enter your card\'s postal code.');
                                          }
                                          return null;
                                        },
                                        onChanged: (str) {
                                          _onTextFieldChanged(
                                              str, CardEntryStep.postal);
                                        },
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) {
                                          _postalFieldSubmitted();
                                        },
                                        cursorColor: _cursorColor,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.zero,
                                          hintText:
                                              _isMobile ? '' : 'Postal Code',
                                          hintStyle: _hintTextSyle,
                                          fillColor: Colors.transparent,
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.loadingWidgetLocation ==
                              LoadingLocation.below)
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity:
                                  _loading && widget.showInternalLoadingWidget
                                      ? 1.0
                                      : 0.0,
                              child: widget.loadingWidget ??
                                  const LinearProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 525),
          opacity: _validationErrorText == null ? 0.0 : 1.0,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 14.0),
            child: Text(
              // Spacing changes by like a pixel if its an empty string, slight jitter when error appears and disappears
              _validationErrorText ?? ' ',
              style: _errorTextStyle,
            ),
          ),
        ),
      ],
    );
  }

  void _onTextFieldChanged(String str, CardEntryStep step) {
    String cleanedStr;
    if (_isMobile) {
      cleanedStr = str.replaceAll('\u200b', '');
    } else {
      cleanedStr = str;
    }

    switch (step) {
      case CardEntryStep.number:
        setState(
            () => _cardDetails.cardNumber = cleanedStr.replaceAll(' ', ''));
        break;
      case CardEntryStep.exp:
        setState(() => _cardDetails.expirationString = cleanedStr);
        break;
      case CardEntryStep.cvc:
        setState(() => _cardDetails.securityCode = cleanedStr);
        break;
      case CardEntryStep.postal:
        setState(() => _cardDetails.postalCode = cleanedStr);
        break;
    }

    if (_isMobile && str.isEmpty) {
      _mobileBackspaceDetected();
    }

    // Check if card is complete and broadcast
    _cardDetails.broadcastStatus();
  }

  /// Called in `initState()` as well as `build()`, determines form factor and target device
  void _calculateProperties() {
    // TODO skip if not needing to recalc
    _cardFieldWidth = widget.cardFieldWidth ?? 180.0;
    _expirationFieldWidth = widget.expFieldWidth ?? 70.0;
    _securityFieldWidth = widget.securityFieldWidth ?? 40.0;
    _postalFieldWidth = widget.postalFieldWidth ?? 95.0;
    isWideFormat = widget.width >=
        _cardFieldWidth +
            _expirationFieldWidth +
            _securityFieldWidth +
            _postalFieldWidth +
            60.0;
    if (isWideFormat) {
      _internalFieldWidth = widget.width + _postalFieldWidth + 35;
      _expanderWidthExpanded = widget.width -
          _cardFieldWidth -
          _expirationFieldWidth -
          _securityFieldWidth -
          35;
      _expanderWidthCollapsed = widget.width -
          _cardFieldWidth -
          _expirationFieldWidth -
          _securityFieldWidth -
          _postalFieldWidth -
          70;
    } else {
      _internalFieldWidth = _cardFieldWidth +
          _expirationFieldWidth +
          _securityFieldWidth +
          _postalFieldWidth +
          80;
    }

    _isMobile = kIsWeb ? !isWideFormat : Platform.isAndroid || Platform.isIOS;

    // int index = 0;
    // for (final controller in _controllers) {
    //   if (controller.text.isNotEmpty || index == 0) continue;
    //   controller.text = '\u200b';
    //   index += 1;
    // }

    if(!widget.enablePostalCode){
      //add a mock postal code
      _postalCodeController.text = '90001';
    }
  }

  /// Called every `build()` invocation, combines passed in styles with the defaults
  void _initStyles() {
    _errorTextStyle =
        const TextStyle(color: Colors.red, fontSize: 14, inherit: true)
            .merge(widget.errorTextStyle ?? widget.textStyle);
    _normalTextStyle =
        const TextStyle(color: Colors.black87, fontSize: 14, inherit: true)
            .merge(widget.textStyle);
    _hintTextSyle =
        const TextStyle(color: Colors.black54, fontSize: 14, inherit: true)
            .merge(widget.hintTextStyle ?? widget.textStyle);

    _normalBoxDecoration = BoxDecoration(
      color: const Color(0xfff6f9fc),
      border: Border.all(
        color: const Color(0xffdde0e3),
        width: 2.0,
      ),
      borderRadius: BorderRadius.circular(8.0),
    ).copyWith(
      backgroundBlendMode: widget.boxDecoration?.backgroundBlendMode,
      border: widget.boxDecoration?.border,
      borderRadius: widget.boxDecoration?.borderRadius,
      boxShadow: widget.boxDecoration?.boxShadow,
      color: widget.boxDecoration?.color,
      gradient: widget.boxDecoration?.gradient,
      image: widget.boxDecoration?.image,
      shape: widget.boxDecoration?.shape,
    );

    _errorBoxDecoration = BoxDecoration(
      color: const Color(0xfff6f9fc),
      border: Border.all(
        color: Colors.red,
        width: 2.0,
      ),
      borderRadius: BorderRadius.circular(8.0),
    ).copyWith(
      backgroundBlendMode: widget.errorBoxDecoration?.backgroundBlendMode,
      border: widget.errorBoxDecoration?.border,
      borderRadius: widget.errorBoxDecoration?.borderRadius,
      boxShadow: widget.errorBoxDecoration?.boxShadow,
      color: widget.errorBoxDecoration?.color,
      gradient: widget.errorBoxDecoration?.gradient,
      image: widget.errorBoxDecoration?.image,
      shape: widget.errorBoxDecoration?.shape,
    );
    _cursorColor = widget.cursorColor ?? Theme.of(context).primaryColor;
  }

  void _checkErrorOverride() {
    if ((widget.errorText != null || widget.overrideValidState != null) &&
        Object.hashAll([widget.errorText, widget.overrideValidState]) !=
            _prevErrorOverrideHash) {
      _prevErrorOverrideHash =
          Object.hashAll([widget.errorText, widget.overrideValidState]);
      _validateFields();
    }
  }

  // Makes an http call to stripe API with provided card credentials and returns the result
  Future<Map<String, dynamic>?> getStripeResponse() async {
    if (widget.stripePublishableKey == null) {
      if (kDebugMode) {
        print(
            '***ERROR tried calling `getStripeResponse()` but no stripe key provided');
      }
      return null;
    }

    _validateFields();

    if (!_cardDetails.isComplete) {
      if (kDebugMode) {
        print(
            '***ERROR Could not get stripe response, card details not complete: ${_cardDetails.validState}');
      }
      return null;
    }

    if (widget.onCallToStripe != null) widget.onCallToStripe!();

    bool returned = false;
    Future.delayed(
      widget.delayToShowLoading,
      () => returned ? null : setState(() => _loading = true),
    );

    const stripeCardUrl = 'https://api.stripe.com/v1/tokens';
    final response = await http.post(
      Uri.parse(stripeCardUrl),
      body: {
        'card[number]': _cardDetails.cardNumber,
        'card[cvc]': _cardDetails.securityCode,
        'card[exp_month]': _cardDetails.expMonth,
        'card[exp_year]': _cardDetails.expYear,
        'card[address_zip]': _cardDetails.postalCode,
        'key': widget.stripePublishableKey,
      },
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
    );

    returned = true;
    final Map<String, dynamic> jsonBody = jsonDecode(response.body);
    if (_loading) setState(() => _loading = false);
    return jsonBody;
  }

  Future<void> _postalFieldSubmitted() async {
    _validateFields();
    if (widget.onSubmitted != null) {
      widget.onSubmitted!(_cardDetails.isComplete ? _cardDetails : null);
    }
    if (_cardDetails.isComplete) {
      if (widget.onValidCardDetails != null) {
        widget.onValidCardDetails!(_cardDetails);
      } else if (widget.onStripeResponse != null &&
          !widget.autoFetchStripektoken) {
        // Callback that stripe call is being made
        if (widget.onCallToStripe != null) widget.onCallToStripe!();
        final jsonBody = await getStripeResponse();

        widget.onStripeResponse!(jsonBody);
      }
    }
  }

  /// Provided a list of `ValidState`, returns whether
  /// make the text field red
  bool _isRedText(List<CardDetailsValidState> args) {
    return _showBorderError && args.contains(_cardDetails.validState);
  }

  /// Helper function to change the `_showBorderError` and
  /// `_validationErrorText`.
  void _setValidationState(String? text) {
    setState(() {
      _validationErrorText = text;
      _showBorderError = text != null;
    });
  }

  /// Calls `validate()` on the form state and resets
  /// the validation state
  void _validateFields() {
    _validationErrorText = null;
    if (widget.overrideValidState != null) {
      _cardDetails.overrideValidState = widget.overrideValidState!;
      _setValidationState(widget.errorText);
    } else {
      _formFieldKey.currentState!.validate();

      // Clear up validation state if everything is valid
      if (_validationErrorText == null) {
        _setValidationState(null);
      }
    }
    return;
  }

  /// Used when `_isWideFormat == false`, scrolls
  /// the `_horizontalScrollController` to a given offset
  void _scrollRow(CardEntryStep step) async {
    await Future.delayed(const Duration(milliseconds: 25));
    const dur = Duration(milliseconds: 150);
    const cur = Curves.easeOut;
    switch (step) {
      case CardEntryStep.number:
        _horizontalScrollController.animateTo(-20.0, duration: dur, curve: cur);
        break;
      case CardEntryStep.exp:
        _horizontalScrollController.animateTo(_cardFieldWidth / 2,
            duration: dur, curve: cur);
        break;
      case CardEntryStep.cvc:
        _horizontalScrollController.animateTo(
            _cardFieldWidth / 2 + _expirationFieldWidth,
            duration: dur,
            curve: cur);
        break;
      case CardEntryStep.postal:
        _horizontalScrollController.animateTo(
            _cardFieldWidth / 2 + _expirationFieldWidth + _securityFieldWidth,
            duration: dur,
            curve: cur);
        break;
    }
  }

  /// Function that is listening to the `_currentCardEntryStepController`
  /// StreamController. Manages validation and tracking of the current step
  /// as well as scrolling the text fields.
  void _onStepChange(CardEntryStep step) {
    // Validated fields only when progressing, not when regressing in step
    if (_currentStep.index < step.index) {
      _validateFields();
    } else if (_currentStep != step) {
      _setValidationState(null);
    }
    // If field tapped, and has focus, dismiss focus
    if (_currentStep == step && _anyHaveFocus()) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    setState(() {
      _currentStep = step;
    });
    switch (_currentStep) {
      case CardEntryStep.number:
        cardNumberFocusNode.requestFocus();
        break;
      case CardEntryStep.exp:
        expirationFocusNode.requestFocus();
        break;
      case CardEntryStep.cvc:
        securityCodeFocusNode.requestFocus();
        break;
      case CardEntryStep.postal:
        postalCodeFocusNode.requestFocus();
        break;
    }

    // Make the selection adjustment only on web, other platforms dont select on focus change
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _adjustSelection());
    }

    if (!isWideFormat) {
      _scrollRow(step);
    }
  }

  /// Returns true if any field in the `CardTextField` has focus.
  bool _anyHaveFocus() {
    return cardNumberFocusNode.hasFocus ||
        expirationFocusNode.hasFocus ||
        securityCodeFocusNode.hasFocus ||
        postalCodeFocusNode.hasFocus;
  }

  /// On web, selection gets screwy when changing focus, workaround for placing cursor at the end of the text content only
  void _adjustSelection() {
    switch (_currentStep) {
      case CardEntryStep.number:
        final len = _cardNumberController.text.length;
        _cardNumberController.value = _cardNumberController.value.copyWith(
            selection: TextSelection(baseOffset: len, extentOffset: len));
        break;
      case CardEntryStep.exp:
        final len = _expirationController.text.length;
        _expirationController.value = _expirationController.value.copyWith(
            selection: TextSelection(baseOffset: len, extentOffset: len));
        break;
      case CardEntryStep.cvc:
        final len = _securityCodeController.text.length;
        _securityCodeController.value = _securityCodeController.value.copyWith(
            selection: TextSelection(baseOffset: len, extentOffset: len));
        break;
      case CardEntryStep.postal:
        final len = _postalCodeController.text.length;
        _postalCodeController.value = _postalCodeController.value.copyWith(
            selection: TextSelection(baseOffset: len, extentOffset: len));
        break;
    }
  }

  /// Function that is listening to the keyboard events.
  ///
  /// This provides the functionality of hitting backspace
  /// and the focus changing between fields when the current
  /// entry step is empty.
  void _backspaceTransitionListener(RawKeyEvent value) {
    if (!value.isKeyPressed(LogicalKeyboardKey.backspace)) {
      return;
    }
    switch (_currentStep) {
      case CardEntryStep.number:
        return;
      case CardEntryStep.exp:
        if (_expirationController.text.isNotEmpty) return;
      case CardEntryStep.cvc:
        if (_securityCodeController.text.isNotEmpty) return;
      case CardEntryStep.postal:
        if (_postalCodeController.text.isNotEmpty) return;
    }
    _transitionStepFocus();
  }

  /// Called whenever a text field is emptied and the mobile flag is set
  void _mobileBackspaceDetected() {
    // Put the empty char back into the controller to detect backspace on mobile
    switch (_currentStep) {
      case CardEntryStep.number:
        break;
      case CardEntryStep.exp:
        _expirationController.text = '\u200b';
      case CardEntryStep.cvc:
        _securityCodeController.text = '\u200b';
      case CardEntryStep.postal:
        _postalCodeController.text = '\u200b';
    }
    _transitionStepFocus();
  }

  void _transitionStepFocus() {
    switch (_currentStep) {
      case CardEntryStep.number:
        break;
      case CardEntryStep.exp:
        _currentCardEntryStepController.add(CardEntryStep.number);

        final String numStr = _cardNumberController.text;
        final endIndex = numStr.isEmpty ? 0 : numStr.length - 1;
        _cardNumberController.text = numStr.substring(0, endIndex);
        break;
      case CardEntryStep.cvc:
        _currentCardEntryStepController.add(CardEntryStep.exp);
        final String expStr = _expirationController.text;
        final endIndex = expStr.isEmpty ? 0 : expStr.length - 1;
        _expirationController.text = expStr.substring(0, endIndex);
        break;
      case CardEntryStep.postal:
        _currentCardEntryStepController.add(CardEntryStep.cvc);
        final String cvcStr = _securityCodeController.text;
        final endIndex = cvcStr.isEmpty ? 0 : cvcStr.length - 1;
        _securityCodeController.text = cvcStr.substring(0, endIndex);
        break;
    }
  }
}

/// Formatter that adds the appropriate space ' ' characters
/// to make the card number display cleanly.
class CardNumberInputFormatter implements TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String cardNum = newValue.text;
    if (cardNum.length <= 4) return newValue;

    cardNum = cardNum.replaceAll(' ', '');
    StringBuffer buffer = StringBuffer();

    for (int i = 0; i < cardNum.length; i++) {
      buffer.write(cardNum[i]);
      int nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != cardNum.length) {
        buffer.write(' ');
      }
    }

    return newValue.copyWith(
        text: buffer.toString(),
        selection: TextSelection.collapsed(offset: buffer.length));
  }
}

/// Formatter that adds a backslash '/' character in between
/// the month and the year for the expiration date.
class CardExpirationFormatter implements TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String cardExp = newValue.text;
    if (cardExp.length == 1) {
      if (cardExp[0] == '0' || cardExp[0] == '1') {
        return newValue;
      } else {
        cardExp = '0$cardExp';
      }
    }
    if (cardExp.length == 2 && oldValue.text.length == 3) return newValue;

    cardExp = cardExp.replaceAll('/', '');
    StringBuffer buffer = StringBuffer();

    for (int i = 0; i < cardExp.length; i++) {
      buffer.write(cardExp[i]);
      int nonZeroIndex = i + 1;
      if (nonZeroIndex == 2) {
        buffer.write('/');
      }
    }
    return newValue.copyWith(
        text: buffer.toString(),
        selection: TextSelection.collapsed(offset: buffer.length));
  }
}
