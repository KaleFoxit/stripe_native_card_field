import 'package:flutter/foundation.dart';

class CardDetails {
  CardDetails({
    required dynamic cardNumber,
    required String? securityCode,
    required this.expirationString,
    required this.postalCode,
  }) : _cardNumber = cardNumber {
    this.securityCode = int.tryParse(securityCode ?? '');
    checkIsValid();
  }

  factory CardDetails.blank() {
    return CardDetails(cardNumber: null, securityCode: null, expirationString: null, postalCode: null);
  }

  String? get cardNumber => _cardNumber?.replaceAll(' ', '');

  set cardNumber(String? num) => _cardNumber = num;

  String? _cardNumber;
  int? securityCode;
  String? postalCode;
  String? expirationString;
  DateTime? expirationDate;
  bool _complete = false;
  ValidState _validState = ValidState.blank;
  int _lastCheckHash = 0;
  CardProvider? provider;

  ValidState get validState {
    checkIsValid();
    return _validState;
  }

  bool get cardNumberFilled =>
      _cardNumber == null ? false : (provider?.cardLength ?? 16) == _cardNumber!.replaceAll(' ', '').length;

  bool get isComplete {
    checkIsValid();
    return _complete;
  }

  int get minInnLength => 1;
  int get maxINNLength => 4;

  void checkIsValid() {
    try {
      int currentHash = hash;
      if (currentHash == _lastCheckHash) {
        return;
      }

      _lastCheckHash = currentHash;
      if (_cardNumber == null && expirationString == null && securityCode == null && postalCode == null) {
        _complete = false;
        _validState = ValidState.blank;
        return;
      }
      final nums = _cardNumber!
          .replaceAll(' ', '')
          .split('')
          .map(
            (i) => int.parse(i),
          )
          .toList();
      if (!luhnAlgorithmCheck(nums)) {
        _complete = false;
        _validState = ValidState.invalidCard;
        return;
      }
      if (_cardNumber == null || !cardNumberFilled) {
        _complete = false;
        _validState = ValidState.missingCard;
        return;
      }
      if (expirationString == null) {
        _complete = false;
        _validState = ValidState.missingDate;
        return;
      }
      final expSplits = expirationString!.split('/');
      if (expSplits.length != 2 || expSplits.last == '') {
        _complete = false;
        _validState = ValidState.missingDate;
        return;
      }
      final month = int.parse(expSplits.first[0] == '0' ? expSplits.first[1] : expSplits.first);
      if (month < 1 || month > 12) {
        _complete = false;
        _validState = ValidState.invalidMonth;
        return;
      }
      final year = 2000 + int.parse(expSplits.last);
      final date = DateTime(year, month);
      if (date.isBefore(DateTime.now())) {
        _complete = false;
        _validState = ValidState.dateTooEarly;
        return;
      } else if (date.isAfter(DateTime.now().add(const Duration(days: 365 * 50)))) {
        _complete = false;
        _validState = ValidState.dateTooLate;
        return;
      }
      expirationDate = date;
      if (securityCode == null) {
        _complete = false;
        _validState = ValidState.missingCVC;
        return;
      }
      if (postalCode == null) {
        _complete = false;
        _validState = ValidState.missingZip;
        return;
      }
      if (!RegExp(r'^\d{5}(-\d{4})?$').hasMatch(postalCode!)) {
        _complete = false;
        _validState = ValidState.invalidZip;
        return;
      }
      _complete = true;
      _validState = ValidState.ok;
    } catch (err, st) {
      if (kDebugMode) {
        print('Error while validating CardDetails: $err\n$st');
      }
      _complete = false;
      _validState = ValidState.error;
    }
  }

  int get hash {
    return Object.hash(_cardNumber, expirationString, securityCode, postalCode);
  }

  void detectCardProvider() {
    bool found = false;
    if (_cardNumber == null) {
      return;
    }
    for (var cardPvd in providers) {
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
}

enum ValidState {
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

enum CardProviderID {
  americanExpress,
  dinersClub,
  discoverCard,
  mastercard,
  jcb,
  visa,
}

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

class Range {
  int high;
  int low;

  Range({required this.low, required this.high}) {
    assert(low <= high);
  }

  bool isWithin(int val) {
    return low <= val && val <= high;
  }
}

List<CardProvider> providers = [
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

// https://en.wikipedia.org/wiki/Luhn_algorithm
// The Luhn algorithm is used in industry to check
// for valid credit / debit card numbers
//
// The algorithm adds together all the numbers, every
// other number is doubled, then the sum is checked to
// see if it is a multiple of 10.
bool luhnAlgorithmCheck(List<int> digits) {
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
