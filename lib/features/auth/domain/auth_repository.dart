import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();

  User? get currentUser;

  Future<void> ensureSignedInAnonymously();

  Future<void> signInWithPlatformProvider();

  Future<void> signOut();

  Future<void> deleteCurrentAccount();
}
