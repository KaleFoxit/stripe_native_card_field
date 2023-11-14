
import 'package:flutter/foundation.dart';

class CardDetails {
  CardDetails({required this.cardNumber, required String? securityCode, required this.expirationDate}) {
    this.securityCode = int.tryParse(securityCode ?? '');
    checkIsValid();
  }

  factory CardDetails.blank() {
    return CardDetails(cardNumber: null, securityCode: null, expirationDate: null);
  }

  String? cardNumber;
  int? securityCode;
  String? postalCode;
  String? expirationDate;
  bool _complete = false;
  ValidState _validState = ValidState.blank;
  int _lastCheckHash = 0;
  CardProvider? provider;

  ValidState get validState {
    checkIsValid();
    return _validState;
  }

  bool get cardNumberFilled => provider == null || provider?.cardLength == cardNumber?.replaceAll(' ', '').length;

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
      if (cardNumber == null && expirationDate == null && securityCode == null && postalCode == null) {
        _complete = false;
        _validState = ValidState.blank;
        return;
      }
      final nums = cardNumber!
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
      if (cardNumber == null || !cardNumberFilled) {
        _complete = false;
        _validState = ValidState.missingCard;
        return;
      }
      if (expirationDate == null) {
        _complete = false;
        _validState = ValidState.missingDate;
        return;
      }
      final expSplits = expirationDate!.split('/');
      if (expSplits.length != 2 || expSplits.last == '') {
        _complete = false;
        _validState = ValidState.missingDate;
        return;
      }
      final date = DateTime(2000 + int.parse(expSplits.last),
          int.parse(expSplits.first[0] == '0' ? expSplits.first[1] : expSplits.first));
      if (date.isBefore(DateTime.now())) {
        _complete = false;
        _validState = ValidState.dateTooEarly;
        return;
      } else if (date.isAfter(DateTime.now().add(const Duration(days: 365 * 50)))) {
        _complete = false;
        _validState = ValidState.dateTooLate;
        return;
      }
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
    return Object.hash(cardNumber, expirationDate, securityCode, postalCode);
  }

  void detectCardProvider() {
    bool found = false;
    if (cardNumber == null) {
      return;
    }
    for (var cardPvd in providers) {
      if (cardPvd.INN_VALID_NUMS != null) {
        // trim card number to correct length
        String trimmedNum = cardNumber!;
        String innNumStr = '${cardPvd.INN_VALID_NUMS!.first}';
        if (trimmedNum.length > innNumStr.length) {
          trimmedNum = trimmedNum.substring(0, innNumStr.length);
        }
        final num = int.tryParse(trimmedNum);
        if (num == null) continue;

        if (cardPvd.INN_VALID_NUMS!.contains(num)) {
          provider = cardPvd;
          found = true;
          break;
        }
      }
      if (cardPvd.INN_VALID_RANGES != null) {
        // trim card number to correct length
        String trimmedNum = cardNumber!;
        String innNumStr = '${cardPvd.INN_VALID_RANGES!.first.low}';
        if (trimmedNum.length > innNumStr.length) {
          trimmedNum = trimmedNum.substring(0, innNumStr.length);
        }
        final num = int.tryParse(trimmedNum);
        if (num == null) continue;

        if (cardPvd.INN_VALID_RANGES!.any((range) => range.isWithin(num))) {
          provider = cardPvd;
          found = true;
          break;
        }
      }
    }
    if (!found) provider = null;
    // print('Got provider $provider');
  }

  @override
    String toString() {
      return 'Number: "$cardNumber" - Exp: "$expirationDate" CVC: $securityCode Zip: "$postalCode"';
    }
}

enum ValidState {
  ok,
  error,
  blank,
  missingCard,
  invalidCard,
  missingDate,
  dateTooEarly,
  dateTooLate,
  missingCVC,
  invalidCVC,
  missingZip,
  invalidZip,
}

enum CardProviderID {
  AmericanExpress,
  DinersClub,
  DiscoverCard,
  Mastercard,
  JCB,
  Visa,
}

class CardProvider {
  CardProviderID id;
  List<int>? INN_VALID_NUMS;
  List<Range>? INN_VALID_RANGES;
  int cardLength;
  int cvcLength;

  CardProvider(
      {required this.id,
      required this.cardLength,
      required this.cvcLength,
      this.INN_VALID_NUMS,
      this.INN_VALID_RANGES}) {
    // Must provide one or the other
    assert(INN_VALID_NUMS != null || INN_VALID_RANGES != null);
    // Do not provide empty list of valid nums
    assert(INN_VALID_NUMS == null || INN_VALID_NUMS!.isNotEmpty);
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
    id: CardProviderID.AmericanExpress,
    cardLength: 15,
    cvcLength: 4,
    INN_VALID_NUMS: [34, 37],
  ),
  CardProvider(
    id: CardProviderID.DinersClub,
    cardLength: 16,
    cvcLength: 3,
    INN_VALID_NUMS: [30, 36, 38, 39],
  ),
  CardProvider(
    id: CardProviderID.DiscoverCard,
    cardLength: 16,
    cvcLength: 3,
    INN_VALID_NUMS: [60, 65],
    INN_VALID_RANGES: [Range(low: 644, high: 649)],
  ),
  CardProvider(
    id: CardProviderID.JCB,
    cardLength: 16,
    cvcLength: 3,
    INN_VALID_NUMS: [35],
  ),
  CardProvider(
    id: CardProviderID.Mastercard,
    cardLength: 16,
    cvcLength: 3,
    INN_VALID_RANGES: [Range(low: 22, high: 27), Range(low: 51, high: 55)],
  ),
  CardProvider(
    id: CardProviderID.Visa,
    cardLength: 16,
    cvcLength: 3,
    INN_VALID_NUMS: [4],
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
