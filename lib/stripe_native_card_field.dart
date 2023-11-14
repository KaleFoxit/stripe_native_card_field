library stripe_native_card_field;

import 'dart:async';
import 'card_details.dart';
import 'card_provider_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CardEntryStep { number, exp, cvc, postal }

class CardTextField extends StatefulWidget {
  const CardTextField({Key? key, required this.width, this.height, this.inputDecoration}) : super(key: key);

  final InputDecoration? inputDecoration;
  final double width;
  final double? height;

  @override
  State<CardTextField> createState() => _CardTextFieldState();
}

class _CardTextFieldState extends State<CardTextField> {
  late TextEditingController _cardNumberController;
  late TextEditingController _expirationController;
  late TextEditingController _securityCodeController;
  late TextEditingController _postalCodeController;

  late FocusNode _cardNumberFocusNode;
  late FocusNode _expirationFocusNode;
  late FocusNode _securityCodeFocusNode;
  late FocusNode _postalCodeFocusNode;

  final double _cardFieldWidth = 180.0;
  final double _expirationFieldWidth = 70.0;
  final double _securityFieldWidth = 40.0;
  final double _postalFieldWidth = 100.0;
  late final double _internalFieldWidth;
  late final bool _isWideFormat;

  bool _showBorderError = false;
  String? _validationErrorText;

  final _currentCardEntryStepController = StreamController<CardEntryStep>();
  final _horizontalScrollController = ScrollController();
  CardEntryStep _currentStep = CardEntryStep.number;

  final _formFieldKey = GlobalKey<FormState>();

  final CardDetails _cardDetails = CardDetails.blank();

  final normalBoxDecoration = BoxDecoration(
    color: Color(0xfff6f9fc),
    border: Border.all(
      color: Color(0xffdde0e3),
      width: 2.0,
    ),
    borderRadius: BorderRadius.circular(8.0),
  );

  final errorBoxDecoration = BoxDecoration(
    color: Color(0xfff6f9fc),
    border: Border.all(
      color: Colors.red,
      width: 2.0,
    ),
    borderRadius: BorderRadius.circular(8.0),
  );

  final TextStyle _errorTextStyle = TextStyle(color: Colors.red, fontSize: 14);
  final TextStyle _normalTextStyle = TextStyle(color: Colors.black87, fontSize: 14);

  @override
  void initState() {
    _cardNumberController = TextEditingController();
    _expirationController = TextEditingController();
    _securityCodeController = TextEditingController();
    _postalCodeController = TextEditingController();

    _cardNumberFocusNode = FocusNode();
    _expirationFocusNode = FocusNode();
    _securityCodeFocusNode = FocusNode();
    _postalCodeFocusNode = FocusNode();

    _currentCardEntryStepController.stream.listen(
      _onStepChange,
    );
    RawKeyboard.instance.addListener(_backspaceTransitionListener);
    _isWideFormat = widget.width >= 450;
    if (_isWideFormat) {
      _internalFieldWidth = widget.width + 80;
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

    _cardNumberFocusNode.dispose();
    _expirationFocusNode.dispose();
    _securityCodeFocusNode.dispose();

    RawKeyboard.instance.removeListener(_backspaceTransitionListener);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              decoration: _showBorderError ? errorBoxDecoration : normalBoxDecoration,
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
                          Container(
                            width: _cardFieldWidth,
                            child: TextFormField(
                              focusNode: _cardNumberFocusNode,
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
                                  _setValidationState('You card number is invalid.');
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
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(19),
                                FilteringTextInputFormatter.allow(RegExp('[0-9 ]')),
                                CardNumberInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                hintText: 'Card number',
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_isWideFormat)
                            Flexible(
                                fit: FlexFit.loose,
                                // fit: _currentStep == CardEntryStep.number ? FlexFit.loose : FlexFit.tight,
                                child: AnimatedContainer(
                                    curve: Curves.easeOut,
                                    duration: const Duration(milliseconds: 400),
                                    constraints: _currentStep == CardEntryStep.number
                                        ? BoxConstraints.loose(Size(400.0, 1.0))
                                        : BoxConstraints.tight(Size(0, 0)))),

                          // Spacer(flex: _currentStep == CardEntryStep.number ? 100 : 1),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 125),
                            width: _expirationFieldWidth,
                            child: TextFormField(
                              focusNode: _expirationFocusNode,
                              controller: _expirationController,
                              style:
                                  _isRedText([ValidState.dateTooLate, ValidState.dateTooEarly, ValidState.missingDate])
                                      ? _errorTextStyle
                                      : _normalTextStyle,
                              validator: (content) {
                                if (content == null || content.isEmpty) {
                                  return null;
                                }
                                setState(() => _cardDetails.expirationDate = content);
                                if (_cardDetails.validState == ValidState.dateTooEarly) {
                                  _setValidationState('Your card\'s expiration date is in the past.');
                                } else if (_cardDetails.validState == ValidState.dateTooLate) {
                                  _setValidationState('Your card\'s expiration year is invalid.');
                                } else if (_cardDetails.validState == ValidState.missingDate) {
                                  _setValidationState('You must include your card\'s expiration date.');
                                }
                                return null;
                              },
                              onChanged: (str) {
                                setState(() => _cardDetails.expirationDate = str);
                                if (str.length == 5) {
                                  _currentCardEntryStepController.add(CardEntryStep.cvc);
                                }
                              },
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(5),
                                FilteringTextInputFormatter.allow(RegExp('[0-9/]')),
                                CardExpirationFormatter(),
                              ],
                              decoration: InputDecoration(
                                hintText: 'MM/YY',
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: _securityFieldWidth,
                            child: TextFormField(
                              focusNode: _securityCodeFocusNode,
                              controller: _securityCodeController,
                              style: _isRedText([ValidState.invalidCVC, ValidState.missingCVC])
                                  ? _errorTextStyle
                                  : _normalTextStyle,
                              validator: (content) {
                                if (content == null || content.isEmpty) {
                                  return null;
                                }
                                setState(() => _cardDetails.securityCode = int.tryParse(content));
                                if (_cardDetails.validState == ValidState.invalidCVC) {
                                  _setValidationState('Your card\'s security code is invalid.');
                                } else if (_cardDetails.validState == ValidState.missingCVC) {
                                  _setValidationState('You card\'s security code is incomplete.');
                                }
                                return null;
                              },
                              onChanged: (str) {
                                setState(() => _cardDetails.expirationDate = str);
                                if (str.length == _cardDetails.provider?.cvcLength) {
                                  _currentCardEntryStepController.add(CardEntryStep.postal);
                                }
                              },
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                    _cardDetails.provider == null ? 4 : _cardDetails.provider!.cvcLength),
                                FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                              ],
                              decoration: const InputDecoration(
                                hintText: 'CVC',
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: _postalFieldWidth,
                            child: TextFormField(
                              focusNode: _postalCodeFocusNode,
                              controller: _postalCodeController,
                              style: _isRedText([ValidState.invalidZip, ValidState.missingZip])
                                  ? _errorTextStyle
                                  : _normalTextStyle,
                              validator: (content) {
                                print('validate zipcode');
                                if (content == null || content.isEmpty) {
                                  return null;
                                }
                                setState(() => _cardDetails.postalCode = content);

print('checking here\n$_cardDetails');
                                if (_cardDetails.validState == ValidState.invalidZip) {
                                  _setValidationState('The postal code you entered is not correct.');
                                } else if (_cardDetails.validState == ValidState.missingZip) {
                                  _setValidationState('You must enter your card\'s postal code.');
                                }
                                return null;
                              },
                              onChanged: (str) {
                                  print('here');
                                setState(() => _cardDetails.postalCode = str);
                                print(_cardDetails.toString());
                              },
                              onFieldSubmitted: (_) {
                                  print('finished');
                                _validateFields();
                              },
                              decoration: InputDecoration(
                                hintText: _currentStep == CardEntryStep.number ? '' : 'Postal Code',
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                              ),
                            ),
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

  bool _isRedText(List<ValidState> args) {
    return _showBorderError && args.contains(_cardDetails.validState);
  }

  void _setValidationState(String? text) {
    setState(() {
      _validationErrorText = text;
      _showBorderError = text != null;
    });
  }

  void _validateFields() {
    _validationErrorText = null;
    _formFieldKey.currentState!.validate();
    // Clear up validation state if everything is valid
    if (_validationErrorText == null) {
      _setValidationState(null);
    }
    return;
  }

  void _scrollRow(CardEntryStep step) {
    final dur = Duration(milliseconds: 150);
    final cur = Curves.easeOut;
    final fieldLen = widget.width;
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
        _cardNumberFocusNode.requestFocus();
        break;
      case CardEntryStep.exp:
        _expirationFocusNode.requestFocus();
        break;
      case CardEntryStep.cvc:
        _securityCodeFocusNode.requestFocus();
        break;
      case CardEntryStep.postal:
        _postalCodeFocusNode.requestFocus();
        break;
    }
    if (!_isWideFormat) {
      _scrollRow(step);
    }
  }

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
    // Auto delete the slash on backspace
    // if (cardExp.length == 3 && oldValue.text.length == 4 && cardExp[2] == '/') {
    //   return newValue.copyWith(
    //       text: cardExp.substring(0, 2), selection: TextSelection.collapsed(offset: cardExp.length - 1));
    // }

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
