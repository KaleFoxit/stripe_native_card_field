library stripe_native_card_field;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'card_details.dart';
import 'card_provider_icon.dart';

/// Enum to track each step of the card detail
/// entry process.
enum CardEntryStep { number, exp, cvc, postal }

// enum LoadingLocation { ontop, rightInside }

/// A uniform text field for entering card details, based
/// on the behavior of Stripe's various html elements.
///
/// Required `width`.
///
/// If the provided `width < 450.0`, the `CardTextField`
/// will scroll its content horizontally with the cursor
/// to compensate.
class CardTextField extends StatefulWidget {
  CardTextField({
    Key? key,
    this.onStripeResponse,
    this.onCardDetailsComplete,
    required this.width,
    this.stripePublishableKey,
    this.height,
    this.textStyle,
    this.hintTextStyle,
    this.errorTextStyle,
    this.boxDecoration,
    this.errorBoxDecoration,
    this.loadingWidget,
    this.delayToShowLoading = const Duration(milliseconds: 750),
    this.overrideValidState,
    this.errorText,
    // this.loadingWidgetLocation = LoadingLocation.rightInside,
  }) : super(key: key) {
    if (stripePublishableKey != null) {
      assert(stripePublishableKey!.startsWith('pk_'));
      if (kReleaseMode && !stripePublishableKey!.startsWith('pk_live_')) {
        print('StripeNativeCardField: *WARN* You are not using a live publishableKey in production.');
      } else if ((kDebugMode || kProfileMode) && stripePublishableKey!.startsWith('pk_live_')) {
        print(
            'StripeNativeCardField: *WARN* You are using a live stripe key in a debug environment, proceed with caution!');
        print('StripeNativeCardField: *WARN* Ideally you should be using your test keys whenever not in production.');
      }
    } else {
      if (onStripeResponse != null) {
        print(
            'StripeNativeCardField: *ERROR* You provided the onTokenReceived callback, but did not provide a stripePublishableKey.');
        assert(false);
      }
    }
  }

  /// Overrides the default box decoration of the text field
  final BoxDecoration? boxDecoration;

  /// Overrides the default box decoration of the text field when there is a validation error
  final BoxDecoration? errorBoxDecoration;

  /// Width of the entire CardTextField
  final double width;

  /// Height of the entire CardTextField
  final double? height;

  /// Stripe publishable key, starts with 'pk_'
  final String? stripePublishableKey;

  /// Shown and overrides CircularProgressIndicator() if the request to stripe takes longer than `delayToShowLoading`
  final Widget? loadingWidget;

  /// Default TextStyle
  final TextStyle? textStyle;

  /// Default TextStyle for the hint text in each TextFormField
  final TextStyle? hintTextStyle;

  /// TextStyle used when any TextFormField's have a validation error
  final TextStyle? errorTextStyle;

  /// Time to wait until showing the loading indicator when retrieving Stripe token
  final Duration delayToShowLoading;

  /// Determines where the loading indicator appears when contacting stripe
  // final LoadingLocation loadingWidgetLocation;

  /// Callback that returns the stripe token for the card
  final void Function(Map<String, dynamic>)? onStripeResponse;

  /// Callback that returns the completed CardDetails object
  final void Function(CardDetails)? onCardDetailsComplete;

  /// Can manually override the ValidState to surface errors returned from Stripe
  final ValidState? overrideValidState;

  /// Can manually override the errorText displayed to surface errors returned from Stripe
  final String? errorText;

  @override
  State<CardTextField> createState() => CardTextFieldState();
}

/// State Widget for CardTextField
/// Should not be used directly, create a
/// `CardTextField()` instead.
@visibleForTesting
class CardTextFieldState extends State<CardTextField> {
  late TextEditingController _cardNumberController;
  late TextEditingController _expirationController;
  late TextEditingController _securityCodeController;
  late TextEditingController _postalCodeController;

  // Not made private for access in widget tests
  late FocusNode cardNumberFocusNode;
  late FocusNode expirationFocusNode;
  late FocusNode securityCodeFocusNode;
  late FocusNode postalCodeFocusNode;

  // Not made private for access in widget tests
  late final bool isWideFormat;

  // Widget configurable styles
  late final BoxDecoration _normalBoxDecoration;
  late final BoxDecoration _errorBoxDecoration;
  late final TextStyle _errorTextStyle;
  late final TextStyle _normalTextStyle;
  late final TextStyle _hintTextSyle;

  final double _cardFieldWidth = 180.0;
  final double _expirationFieldWidth = 70.0;
  final double _securityFieldWidth = 40.0;
  final double _postalFieldWidth = 95.0;
  late final double _internalFieldWidth;
  late final double _expanderWidthExpanded;
  late final double _expanderWidthContracted;

  String? _validationErrorText;
  bool _showBorderError = false;
  bool _loading = false;
  final CardDetails _cardDetails = CardDetails.blank();
  int _prevErrorOverrideHash = 0;

  final _currentCardEntryStepController = StreamController<CardEntryStep>();
  final _horizontalScrollController = ScrollController();
  CardEntryStep _currentStep = CardEntryStep.number;

  final _formFieldKey = GlobalKey<FormState>();

  @override
  void initState() {
    _cardNumberController = TextEditingController();
    _expirationController = TextEditingController();
    _securityCodeController = TextEditingController();
    _postalCodeController = TextEditingController();

    cardNumberFocusNode = FocusNode();
    expirationFocusNode = FocusNode();
    securityCodeFocusNode = FocusNode();
    postalCodeFocusNode = FocusNode();

    _errorTextStyle = const TextStyle(color: Colors.red, fontSize: 14, inherit: true).merge(widget.errorTextStyle);
    _normalTextStyle = const TextStyle(color: Colors.black87, fontSize: 14, inherit: true).merge(widget.textStyle);
    _hintTextSyle = const TextStyle(color: Colors.black54, fontSize: 14, inherit: true).merge(widget.hintTextStyle);

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

    _currentCardEntryStepController.stream.listen(
      _onStepChange,
    );
    RawKeyboard.instance.addListener(_backspaceTransitionListener);
    isWideFormat = widget.width >= 450;
    if (isWideFormat) {
      _internalFieldWidth = widget.width + _postalFieldWidth + 35;
      _expanderWidthExpanded = widget.width - _cardFieldWidth - _expirationFieldWidth - _securityFieldWidth - 35;
      _expanderWidthContracted =
          widget.width - _cardFieldWidth - _expirationFieldWidth - _securityFieldWidth - _postalFieldWidth - 70;
    } else {
      _internalFieldWidth = _cardFieldWidth + _expirationFieldWidth + _securityFieldWidth + _postalFieldWidth + 80;
    }

    super.initState();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expirationController.dispose();
    _securityCodeController.dispose();

    cardNumberFocusNode.dispose();
    expirationFocusNode.dispose();
    securityCodeFocusNode.dispose();

    RawKeyboard.instance.removeListener(_backspaceTransitionListener);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if ((widget.errorText != null || widget.overrideValidState != null) &&
        Object.hashAll([widget.errorText, widget.overrideValidState]) != _prevErrorOverrideHash) {
      _prevErrorOverrideHash = Object.hashAll([widget.errorText, widget.overrideValidState]);
      _validateFields();
    }
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
            child: Container(
              width: widget.width,
              height: widget.height ?? 60.0,
              decoration: _showBorderError ? _errorBoxDecoration : _normalBoxDecoration,
              child: ClipRect(
                child: IgnorePointer(
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _internalFieldWidth,
                      height: widget.height ?? 60.0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: CardProviderIcon(
                              cardDetails: _cardDetails,
                            ),
                          ),
                          SizedBox(
                            width: _cardFieldWidth,
                            child: TextFormField(
                              key: const Key('card_field'),
                              focusNode: cardNumberFocusNode,
                              controller: _cardNumberController,
                              keyboardType: TextInputType.number,
                              style: _isRedText([ValidState.invalidCard, ValidState.missingCard, ValidState.blank])
                                  ? _errorTextStyle
                                  : _normalTextStyle,
                              validator: (content) {
                                if (content == null || content.isEmpty) {
                                  return null;
                                }
                                _cardDetails.cardNumber = content;
                                if (_cardDetails.validState == ValidState.invalidCard) {
                                  _setValidationState('Your card number is invalid.');
                                } else if (_cardDetails.validState == ValidState.missingCard) {
                                  _setValidationState('Your card number is incomplete.');
                                }
                                return null;
                              },
                              onChanged: (str) {
                                final numbers = str.replaceAll(' ', '');
                                setState(() => _cardDetails.cardNumber = numbers);
                                if (str.length <= _cardDetails.maxINNLength) {
                                  _cardDetails.detectCardProvider();
                                }
                                if (numbers.length == 16) {
                                  _currentCardEntryStepController.add(CardEntryStep.exp);
                                }
                              },
                              onFieldSubmitted: (_) => _currentCardEntryStepController.add(CardEntryStep.exp),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(19),
                                FilteringTextInputFormatter.allow(RegExp('[0-9 ]')),
                                CardNumberInputFormatter(),
                              ],
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
                                duration: const Duration(milliseconds: 400),
                                constraints: _currentStep == CardEntryStep.number
                                    ? BoxConstraints.loose(
                                        Size(_expanderWidthExpanded, 0.0),
                                      )
                                    : BoxConstraints.tight(
                                        Size(_expanderWidthContracted, 0.0),
                                      ),
                              ),
                            ),

                          // Spacer(flex: _currentStep == CardEntryStep.number ? 100 : 1),
                          SizedBox(
                            width: _expirationFieldWidth,
                            child: TextFormField(
                              key: const Key('expiration_field'),
                              focusNode: expirationFocusNode,
                              controller: _expirationController,
                              style: _isRedText([
                                ValidState.dateTooLate,
                                ValidState.dateTooEarly,
                                ValidState.missingDate,
                                ValidState.invalidMonth
                              ])
                                  ? _errorTextStyle
                                  : _normalTextStyle,
                              validator: (content) {
                                if (content == null || content.isEmpty) {
                                  return null;
                                }
                                setState(() => _cardDetails.expirationString = content);
                                if (_cardDetails.validState == ValidState.dateTooEarly) {
                                  _setValidationState('Your card\'s expiration date is in the past.');
                                } else if (_cardDetails.validState == ValidState.dateTooLate) {
                                  _setValidationState('Your card\'s expiration year is invalid.');
                                } else if (_cardDetails.validState == ValidState.missingDate) {
                                  _setValidationState('You must include your card\'s expiration date.');
                                } else if (_cardDetails.validState == ValidState.invalidMonth) {
                                  _setValidationState('Your card\'s expiration month is invalid.');
                                }
                                return null;
                              },
                              onChanged: (str) {
                                setState(() => _cardDetails.expirationString = str);
                                if (str.length == 5) {
                                  _currentCardEntryStepController.add(CardEntryStep.cvc);
                                }
                              },
                              onFieldSubmitted: (_) => _currentCardEntryStepController.add(CardEntryStep.cvc),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(5),
                                FilteringTextInputFormatter.allow(RegExp('[0-9/]')),
                                CardExpirationFormatter(),
                              ],
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.zero,
                                hintText: 'MM/YY',
                                hintStyle: _hintTextSyle,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: _securityFieldWidth,
                            child: TextFormField(
                              key: const Key('security_field'),
                              focusNode: securityCodeFocusNode,
                              controller: _securityCodeController,
                              style: _isRedText([ValidState.invalidCVC, ValidState.missingCVC])
                                  ? _errorTextStyle
                                  : _normalTextStyle,
                              validator: (content) {
                                if (content == null || content.isEmpty) {
                                  return null;
                                }
                                setState(() => _cardDetails.securityCode = content);
                                if (_cardDetails.validState == ValidState.invalidCVC) {
                                  _setValidationState('Your card\'s security code is invalid.');
                                } else if (_cardDetails.validState == ValidState.missingCVC) {
                                  _setValidationState('Your card\'s security code is incomplete.');
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _currentCardEntryStepController.add(CardEntryStep.postal),
                              onChanged: (str) {
                                setState(() => _cardDetails.expirationString = str);
                                if (str.length == _cardDetails.provider?.cvcLength) {
                                  _currentCardEntryStepController.add(CardEntryStep.postal);
                                }
                              },
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                    _cardDetails.provider == null ? 4 : _cardDetails.provider!.cvcLength),
                                FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                              ],
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.zero,
                                hintText: 'CVC',
                                hintStyle: _hintTextSyle,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: _postalFieldWidth,
                            child: TextFormField(
                              key: const Key('postal_field'),
                              focusNode: postalCodeFocusNode,
                              controller: _postalCodeController,
                              style: _isRedText([ValidState.invalidZip, ValidState.missingZip])
                                  ? _errorTextStyle
                                  : _normalTextStyle,
                              validator: (content) {
                                if (content == null || content.isEmpty) {
                                  return null;
                                }
                                setState(() => _cardDetails.postalCode = content);

                                if (_cardDetails.validState == ValidState.invalidZip) {
                                  _setValidationState('The postal code you entered is not correct.');
                                } else if (_cardDetails.validState == ValidState.missingZip) {
                                  _setValidationState('You must enter your card\'s postal code.');
                                }
                                return null;
                              },
                              onChanged: (str) {
                                setState(() => _cardDetails.postalCode = str);
                              },
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) async {
                                _validateFields();
                                if (_cardDetails.isComplete) {
                                  if (widget.onCardDetailsComplete != null) {
                                    widget.onCardDetailsComplete!(_cardDetails);
                                  } else if (widget.onStripeResponse != null) {
                                    bool returned = false;

                                    Future.delayed(
                                      const Duration(milliseconds: 750),
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
                                    final jsonBody = jsonDecode(response.body);

                                    widget.onStripeResponse!(jsonBody);
                                    if (_loading) setState(() => _loading = false);
                                  }
                                }
                              },
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Postal Code',
                                hintStyle: _hintTextSyle,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _loading ? 1.0 : 0.0,
                            child: widget.loadingWidget ?? const CircularProgressIndicator(),
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
              _validationErrorText ?? '',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  /// Provided a list of `ValidState`, returns whether
  /// make the text field red
  bool _isRedText(List<ValidState> args) {
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
  void _scrollRow(CardEntryStep step) {
    const dur = Duration(milliseconds: 150);
    const cur = Curves.easeOut;
    switch (step) {
      case CardEntryStep.number:
        _horizontalScrollController.animateTo(0.0, duration: dur, curve: cur);
        break;
      case CardEntryStep.exp:
        _horizontalScrollController.animateTo(_cardFieldWidth / 2, duration: dur, curve: cur);
        break;
      case CardEntryStep.cvc:
        _horizontalScrollController.animateTo(_cardFieldWidth / 2 + _expirationFieldWidth, duration: dur, curve: cur);
        break;
      case CardEntryStep.postal:
        _horizontalScrollController.animateTo(_cardFieldWidth / 2 + _expirationFieldWidth + _securityFieldWidth,
            duration: dur, curve: cur);
        break;
    }
  }

  /// Function that is listening to the `_currentCardEntryStepController`
  /// StreamController. Manages validation and tracking of the current step
  /// as well as scrolling the text fields.
  void _onStepChange(CardEntryStep step) {
    if (_currentStep.index < step.index) {
      _validateFields();
    } else if (_currentStep != step) {
      _setValidationState(null);
    }

    setState(() {
      _currentStep = step;
    });
    switch (step) {
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
    if (!isWideFormat) {
      _scrollRow(step);
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
        break;
      case CardEntryStep.exp:
        final expStr = _expirationController.text;
        if (expStr.isNotEmpty) break;
        _currentCardEntryStepController.add(CardEntryStep.number);
        String numStr = _cardNumberController.text;
        _cardNumberController.text = numStr.substring(0, numStr.length - 1);
        break;
      case CardEntryStep.cvc:
        final cvcStr = _securityCodeController.text;
        if (cvcStr.isNotEmpty) break;
        _currentCardEntryStepController.add(CardEntryStep.exp);
        final expStr = _expirationController.text;
        _expirationController.text = expStr.substring(0, expStr.length - 1);
      case CardEntryStep.postal:
        final String postalStr = _postalCodeController.text;
        if (postalStr.isNotEmpty) break;
        _currentCardEntryStepController.add(CardEntryStep.cvc);
        final String cvcStr = _securityCodeController.text;
        _securityCodeController.text = cvcStr.substring(0, cvcStr.length - 1);
    }
  }
}

/// Formatter that adds the appropriate space ' ' characters
/// to make the card number display cleanly.
class CardNumberInputFormatter implements TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
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

    return newValue.copyWith(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}

/// Formatter that adds a backslash '/' character in between
/// the month and the year for the expiration date.
class CardExpirationFormatter implements TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
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
    return newValue.copyWith(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}
