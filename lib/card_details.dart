import 'dart:async';

import 'package:flutter/foundation.dart';

/// Class encapsulating the card's data
/// as well as validation of the data.
///
/// `CardDetails.validState == ValidState.ok`
/// when fields are filled and validated as correct.
class CardDetails {
  CardDetails({
    required String? cardNumber,
    required this.securityCode,
    required this.expirationString,
    required this.postalCode,
  }) : _cardNumber = cardNumber {
    checkIsValid();
  }

  /// Sets every field to null, a default
  /// `CardDetails` when nothing has been entered.
  factory CardDetails.blank() {
    return CardDetails(cardNumber: null, securityCode: null, expirationString: null, postalCode: null);
  }

  /// Returns the CardNumber as a `String` with the spaces removed.
  String? get cardNumber => _cardNumber?.replaceAll(' ', '');

  set cardNumber(String? num) => _cardNumber = num;

  String? _cardNumber;
  String? securityCode;
  String? postalCode;
  String? expirationString;
  DateTime? expirationDate;
  bool _complete = false;
  CardDetailsValidState _validState = CardDetailsValidState.blank;
  int _lastCheckHash = 0;
  CardProvider? provider;
  StreamController<CardDetails> onCompleteController = StreamController();

  set overrideValidState(CardDetailsValidState state) => _validState = state;

  /// Checks the validity of the `CardDetails` and returns the result.
  CardDetailsValidState get validState {
    checkIsValid();
    return _validState;
  }

  String get expMonth => isComplete ? expirationString!.split('/').first : '';
  String get expYear => isComplete ? expirationString!.split('/').last : '';

  /// Returns true if `_cardNumber` is null, or
  /// if the _cardNumber matches the detected `provider`'s
  /// card lenght, defaulting to 16.
  bool get cardNumberFilled =>
      _cardNumber == null ? false : (provider?.cardLength ?? 16) == _cardNumber!.replaceAll(' ', '').length;

  /// Returns true if all details are complete and valid
  /// otherwise, return false.
  bool get isComplete {
    checkIsValid();
    return _complete;
  }

  /// Detects if the card is complete, then broadcasts
  /// card details to `onCompleteController`
  void broadcastStatus() {
    if (isComplete) {
      onCompleteController.add(this);
    }
  }

  /// The maximum length of the INN (identifier)
  /// of a card provider.
  int get maxINNLength => 4;

  /// Validates each field of the `CardDetails` object in entry order,
  /// namely _cardNumber -> expirationString -> securityCode -> postalCode
  ///
  /// If all fields are filled out and valid, `CardDetails.isComplete == true`
  /// and `CardDetails.validState == ValidState.ok`.
  void checkIsValid() {
    try {
      int currentHash = hash;
      if (currentHash == _lastCheckHash) {
        return;
      }

      _complete = false;
      _lastCheckHash = currentHash;
      if (_cardNumber == null && expirationString == null && securityCode == null && postalCode == null) {
        _validState = CardDetailsValidState.blank;
        return;
      }
      final nums = _cardNumber!
          .replaceAll(' ', '')
          .split('')
          .map(
            (i) => int.parse(i),
          )
          .toList();
      if (!_luhnAlgorithmCheck(nums)) {
        _validState = CardDetailsValidState.invalidCard;
        return;
      }
      if (_cardNumber == null || !cardNumberFilled) {
        _validState = CardDetailsValidState.missingCard;
        return;
      }
      if (expirationString == null) {
        _validState = CardDetailsValidState.missingDate;
        return;
      }
      final expSplits = expirationString!.split('/');
      if (expSplits.length != 2 || expSplits.last == '') {
        _validState = CardDetailsValidState.missingDate;
        return;
      }
      final month = int.parse(expSplits.first[0] == '0' ? expSplits.first[1] : expSplits.first);
      if (month < 1 || month > 12) {
        _validState = CardDetailsValidState.invalidMonth;
        return;
      }
      final year = 2000 + int.parse(expSplits.last);
      final date = DateTime(year, month);
      if (date.isBefore(DateTime.now())) {
        _validState = CardDetailsValidState.dateTooEarly;
        return;
      } else if (date.isAfter(DateTime.now().add(const Duration(days: 365 * 50)))) {
        _validState = CardDetailsValidState.dateTooLate;
        return;
      }
      expirationDate = date;
      if (securityCode == null) {
        _validState = CardDetailsValidState.missingCVC;
        return;
      }
      if (provider != null && securityCode!.length != provider!.cvcLength) {
        _validState = CardDetailsValidState.invalidCVC;
        return;
      }
      if (postalCode == null) {
        _validState = CardDetailsValidState.missingZip;
        return;
      }
      if (!RegExp(r'^\d{5}(-\d{4})?$').hasMatch(postalCode!)) {
        _validState = CardDetailsValidState.invalidZip;
        return;
      }
      _complete = true;
      _validState = CardDetailsValidState.ok;
    } catch (err, st) {
      if (kDebugMode) {
        print('Error while validating CardDetails: $err\n$st');
      }
      _complete = false;
      _validState = CardDetailsValidState.error;
    }
  }

  /// Provides a hash of the CardDetails object
  /// Hashes `_cardNumber`, `expirationString`,
  /// `securityCode`, and `postalCode`.
  int get hash {
    return Object.hash(_cardNumber, expirationString, securityCode, postalCode);
  }

  /// Iterates over the list `_providers`, detecting which
  /// provider the current `_cardNumber` falls under.
  void detectCardProvider() {
    bool found = false;
    if (_cardNumber == null) {
      return;
    }
    for (var cardPvd in _providers) {
      if (cardPvd.innValidNums != null) {
        // trim card number to correct length
        String trimmedNum = _cardNumber!;
        String innNumStr = '${cardPvd.innValidNums!.first}';
        if (trimmedNum.length > innNumStr.length) {
          trimmedNum = trimmedNum.substring(0, innNumStr.length);
        }
        final num = int.tryParse(trimmedNum);
        if (num == null) continue;

        if (cardPvd.innValidNums!.contains(num)) {
          provider = cardPvd;
          found = true;
          break;
        }
      }
      if (cardPvd.innValidRanges != null) {
        // trim card number to correct length
        String trimmedNum = _cardNumber!;
        String innNumStr = '${cardPvd.innValidRanges!.first.low}';
        if (trimmedNum.length > innNumStr.length) {
          trimmedNum = trimmedNum.substring(0, innNumStr.length);
        }
        final num = int.tryParse(trimmedNum);
        if (num == null) continue;

        if (cardPvd.innValidRanges!.any((range) => range.isWithin(num))) {
          provider = cardPvd;
          found = true;
          break;
        }
      }
    }
    if (!found) provider = null;
  }

  @override
  String toString() {
    return 'Number: "$_cardNumber" - Exp: "$expirationString" CVC: $securityCode Zip: "$postalCode"';
  }

  /// https://en.wikipedia.org/wiki/Luhn_algorithm
  /// The Luhn algorithm is used in industry to check
  /// for valid credit / debit card numbers
  ///
  /// The algorithm adds together all the numbers, every
  /// other number is doubled, then the sum is checked to
  /// see if it is a multiple of 10.
  /// https://en.wikipedia.org/wiki/Luhn_algorithm
  bool _luhnAlgorithmCheck(List<int> digits) {
    int sum = 0;
    bool isSecond = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int d = digits[i];
      if (isSecond) {
        d *= 2;

        if (d > 9) {
          d -= 9;
        }
      }

      sum += d;
      isSecond = !isSecond;
    }
    return (sum % 10) == 0;
  }
}

/// Enum of validation states a `CardDetails` object can have.
enum CardDetailsValidState {
  ok,
  error,
  blank,
  missingCard,
  invalidCard,
  missingDate,
  invalidMonth,
  dateTooEarly,
  dateTooLate,
  missingCVC,
  invalidCVC,
  missingZip,
  invalidZip,
}

/// Enum of supported Card Providers
enum CardProviderID {
  americanExpress,
  dinersClub,
  discoverCard,
  mastercard,
  jcb,
  visa,
}

/// Encapsulates criteria for Card Providers in the U.S.
/// Used by `CardDetails.detectCardProvider()` to determine
/// a card's Provider.
class CardProvider {
  CardProviderID id;
  List<int>? innValidNums;
  List<Range>? innValidRanges;
  int cardLength;
  int cvcLength;

  CardProvider(
      {required this.id, required this.cardLength, required this.cvcLength, this.innValidNums, this.innValidRanges}) {
    // Must provide one or the other
    assert(innValidNums != null || innValidRanges != null);
    // Do not provide empty list of valid nums
    assert(innValidNums == null || innValidNums!.isNotEmpty);
  }

  @override
  String toString() {
    return id.toString();
  }
}

/// Object for `CardProvider` to determine valid number ranges.
/// A loose wrapper on a tuple, that provides assertion of
/// valid inputs and the `isWithin()` helper function.
class Range {
  int high;
  int low;

  Range({required this.low, required this.high}) {
    assert(low <= high);
  }

  /// Returns bool whether or not `val` is between `low` and `high`.
  /// The range includes the `val`, so
  /// ```dart
  /// Range(low: 1, high: 3).isWithin(3);
  /// ```
  /// would return true.
  bool isWithin(int val) {
    return low <= val && val <= high;
  }
}

/// List of CardProviders for US-based Credit / Debit Cards.
List<CardProvider> _providers = [
  CardProvider(
    id: CardProviderID.americanExpress,
    cardLength: 15,
    cvcLength: 4,
    innValidNums: [34, 37],
  ),
  CardProvider(
    id: CardProviderID.dinersClub,
    cardLength: 16,
    cvcLength: 3,
    innValidNums: [30, 36, 38, 39],
  ),
  CardProvider(
    id: CardProviderID.discoverCard,
    cardLength: 16,
    cvcLength: 3,
    innValidNums: [60, 65],
    innValidRanges: [Range(low: 644, high: 649)],
  ),
  CardProvider(
    id: CardProviderID.jcb,
    cardLength: 16,
    cvcLength: 3,
    innValidNums: [35],
  ),
  CardProvider(
    id: CardProviderID.mastercard,
    cardLength: 16,
    cvcLength: 3,
    innValidRanges: [Range(low: 22, high: 27), Range(low: 51, high: 55)],
  ),
  CardProvider(
    id: CardProviderID.visa,
    cardLength: 16,
    cvcLength: 3,
    innValidNums: [4],
  )
];
