/// Base failure class for the VaultKey application.
abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class CryptoFailure extends Failure {
  const CryptoFailure([super.message = 'A cryptographic error occurred']);
}

class StorageFailure extends Failure {
  const StorageFailure([super.message = 'A storage error occurred']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

class LockoutFailure extends Failure {
  final int remainingSeconds;
  const LockoutFailure(this.remainingSeconds)
    : super('Too many failed attempts. Try again in $remainingSeconds seconds');
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation failed']);
}

class BackupFailure extends Failure {
  const BackupFailure([super.message = 'Backup operation failed']);
}
