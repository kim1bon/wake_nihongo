import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class FirebaseAuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  // authStateChanges()는 sign-in/sign-out 위주 이벤트라
  // 익명 계정 link(업그레이드) 직후 UI 갱신이 늦을 수 있어 userChanges()를 사용.
  Stream<User?> authStateChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> ensureSignedInAnonymously() async {
    if (_auth.currentUser != null) return;
    await _auth.signInAnonymously();
  }

  Future<void> signInWithPlatformProvider() async {
    if (Platform.isIOS) {
      await _signInWithApple();
      return;
    }
    if (Platform.isAndroid) {
      await _signInWithGoogle();
      return;
    }
    throw UnsupportedError('iOS/Android에서만 소셜 로그인을 지원합니다.');
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  Future<void> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await user.delete();
    await GoogleSignIn().signOut();
  }

  Future<void> _signInWithGoogle() async {
    final account = await GoogleSignIn().signIn();
    if (account == null) {
      throw FirebaseAuthException(
        code: 'sign_in_cancelled',
        message: '로그인이 취소되었습니다.',
      );
    }

    final authData = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: authData.accessToken,
      idToken: authData.idToken,
    );
    await _signInOrLink(credential);
  }

  Future<void> _signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256OfString(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: credential.identityToken,
      rawNonce: rawNonce,
    );

    await _signInOrLink(oauthCredential);
  }

  Future<void> _signInOrLink(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        await user.linkWithCredential(credential);
        await _reloadCurrentUser();
        return;
      } on FirebaseAuthException catch (e) {
        // 이미 다른 Firebase 계정에 연결된 소셜 credential이면
        // 익명 계정 연결(link) 대신 기존 계정으로 로그인(signIn)합니다.
        if (e.code == 'credential-already-in-use' ||
            e.code == 'provider-already-linked' ||
            e.code == 'account-exists-with-different-credential') {
          await _auth.signInWithCredential(credential);
          await _reloadCurrentUser();
          return;
        }
        rethrow;
      }
    }
    await _auth.signInWithCredential(credential);
    await _reloadCurrentUser();
  }

  Future<void> _reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
