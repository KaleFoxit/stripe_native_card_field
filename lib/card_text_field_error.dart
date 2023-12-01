/// Error class that `CardTextField` throws if any errors are encountered
class CardTextFieldError extends Error {
  /// Details provided for the error
  String? details;
  CardTextFieldErrorType type;

  CardTextFieldError(this.type, {this.details});

  @override
  String toString() {
    return 'CardTextFieldError-${type.name}: $details';
  }
}

/// Enum to add typing to the `CardTextFieldErrorType`
enum CardTextFieldErrorType {
  stripeImplementation,
  unknown,
}
