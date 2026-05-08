import 'dart:convert';
import 'dart:developer' as developer;
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
    _logAuth('ensureSignedInAnonymously:start');
    final current = await _resolveCurrentUserWithRecovery();
    if (current != null) {
      _logAuth(
        'ensureSignedInAnonymously:skip existing user',
        uid: current.uid,
        isAnonymous: current.isAnonymous,
      );
      return;
    }
    _logAuth('ensureSignedInAnonymously:create anonymous');
    await _auth.signInAnonymously();
    _logAuth(
      'ensureSignedInAnonymously:success',
      uid: _auth.currentUser?.uid,
      isAnonymous: _auth.currentUser?.isAnonymous,
    );
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
    _logAuth('signInWithApple:start');
    final rawNonce = _generateNonce();
    final nonce = _sha256OfString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oidcCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    try {
      await _signInOrLink(oidcCredential);
      _logAuth('signInWithApple:oidc success');
    } on FirebaseAuthException catch (e) {
      if (e.code != 'invalid-credential') {
        _logAuth('signInWithApple:oidc failed', errorCode: e.code);
        rethrow;
      }

      _logAuth('signInWithApple:oidc invalid-credential fallback');
      final authorizationCode = appleCredential.authorizationCode;
      if (authorizationCode == null || authorizationCode.isEmpty) {
        _logAuth(
          'signInWithApple:fallback unavailable',
          errorCode: 'authorization-code-missing',
        );
        rethrow;
      }

      final fallbackCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: authorizationCode,
        rawNonce: rawNonce,
      );
      await _signInOrLink(fallbackCredential);
      _logAuth('signInWithApple:fallback success');
    }
    _logAuth(
      'signInWithApple:done',
      uid: _auth.currentUser?.uid,
      isAnonymous: _auth.currentUser?.isAnonymous,
    );
  }

  Future<void> _signInOrLink(AuthCredential credential) async {
    _logAuth('signInOrLink:start');
    final user = await _resolveCurrentUserWithRecovery();
    if (user != null && user.isAnonymous) {
      _logAuth(
        'signInOrLink:link anonymous user',
        uid: user.uid,
        isAnonymous: user.isAnonymous,
      );
      try {
        await user.linkWithCredential(credential);
        await _reloadCurrentUser();
        _logAuth(
          'signInOrLink:link success',
          uid: _auth.currentUser?.uid,
          isAnonymous: _auth.currentUser?.isAnonymous,
        );
        return;
      } on FirebaseAuthException catch (e) {
        // 이미 다른 Firebase 계정에 연결된 소셜 credential이면
        // 익명 계정 연결(link) 대신 기존 계정으로 로그인(signIn)합니다.
        if (e.code == 'credential-already-in-use' ||
            e.code == 'provider-already-linked' ||
            e.code == 'account-exists-with-different-credential') {
          _logAuth('signInOrLink:link fallback signIn', errorCode: e.code);
          await _auth.signInWithCredential(credential);
          await _reloadCurrentUser();
          _logAuth(
            'signInOrLink:fallback signIn success',
            uid: _auth.currentUser?.uid,
            isAnonymous: _auth.currentUser?.isAnonymous,
          );
          return;
        }
        if (_isStaleUserError(e)) {
          _logAuth('signInOrLink:stale user during link', errorCode: e.code);
          await _clearStaleSessionAndSignOut();
          await _auth.signInWithCredential(credential);
          await _reloadCurrentUser();
          _logAuth(
            'signInOrLink:stale recovery success',
            uid: _auth.currentUser?.uid,
            isAnonymous: _auth.currentUser?.isAnonymous,
          );
          return;
        }
        _logAuth('signInOrLink:link failed', errorCode: e.code);
        rethrow;
      }
    }
    try {
      _logAuth('signInOrLink:signIn directly');
      await _auth.signInWithCredential(credential);
      await _reloadCurrentUser();
      _logAuth(
        'signInOrLink:direct signIn success',
        uid: _auth.currentUser?.uid,
        isAnonymous: _auth.currentUser?.isAnonymous,
      );
    } on FirebaseAuthException catch (e) {
      if (_isStaleUserError(e)) {
        _logAuth('signInOrLink:stale user during signIn', errorCode: e.code);
        await _clearStaleSessionAndSignOut();
        await _auth.signInWithCredential(credential);
        await _reloadCurrentUser();
        _logAuth(
          'signInOrLink:stale recovery direct signIn success',
          uid: _auth.currentUser?.uid,
          isAnonymous: _auth.currentUser?.isAnonymous,
        );
        return;
      }
      _logAuth('signInOrLink:direct signIn failed', errorCode: e.code);
      rethrow;
    }
  }

  Future<void> _reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (_isStaleUserError(e)) {
        _logAuth('reloadCurrentUser:stale detected', errorCode: e.code);
        await _clearStaleSessionAndSignOut();
        return;
      }
      _logAuth('reloadCurrentUser:failed', errorCode: e.code);
      rethrow;
    }
  }

  Future<User?> _resolveCurrentUserWithRecovery() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      await user.reload();
      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      if (_isStaleUserError(e)) {
        _logAuth(
          'resolveCurrentUserWithRecovery:stale detected',
          uid: user.uid,
          isAnonymous: user.isAnonymous,
          errorCode: e.code,
        );
        await _clearStaleSessionAndSignOut();
        return null;
      }
      _logAuth(
        'resolveCurrentUserWithRecovery:failed',
        uid: user.uid,
        isAnonymous: user.isAnonymous,
        errorCode: e.code,
      );
      rethrow;
    }
  }

  bool _isStaleUserError(FirebaseAuthException e) {
    return e.code == 'user-not-found' ||
        e.code == 'user-token-expired' ||
        e.code == 'invalid-user-token';
  }

  Future<void> _clearStaleSessionAndSignOut() async {
    _logAuth('clearStaleSessionAndSignOut:start');
    await GoogleSignIn().signOut();
    await _auth.signOut();
    _logAuth('clearStaleSessionAndSignOut:done');
  }

  void _logAuth(
    String message, {
    String? uid,
    bool? isAnonymous,
    String? errorCode,
  }) {
    final details = <String>[
      'uid=${uid ?? _auth.currentUser?.uid ?? 'null'}',
      'isAnonymous=${isAnonymous ?? _auth.currentUser?.isAnonymous}',
      if (errorCode != null) 'errorCode=$errorCode',
    ].join(', ');
    developer.log(
      '$message [$details]',
      name: 'FirebaseAuthService',
    );
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
