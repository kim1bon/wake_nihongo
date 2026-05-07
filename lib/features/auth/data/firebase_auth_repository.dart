import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_repository.dart';
import 'firebase_auth_service.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._service);

  final FirebaseAuthService _service;

  @override
  Stream<User?> authStateChanges() => _service.authStateChanges();

  @override
  User? get currentUser => _service.currentUser;

  @override
  Future<void> ensureSignedInAnonymously() => _service.ensureSignedInAnonymously();

  @override
  Future<void> signInWithPlatformProvider() => _service.signInWithPlatformProvider();

  @override
  Future<void> signOut() => _service.signOut();

  @override
  Future<void> deleteCurrentAccount() => _service.deleteCurrentAccount();
}
