import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:geo_gps_cam/models/user_model.dart';
import 'package:geo_gps_cam/services/ad_free_service.dart';

/// Handles Google Sign-In and Firebase Authentication
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  /// Check if user is currently signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Get Firebase Auth stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Check ad-free status from Firestore
        final isAdFree = await AdFreeService().checkAdFreeStatus(
          userCredential.user!.email ?? '',
        );

        _currentUser = UserModel.fromFirebaseUser(
          userCredential.user!,
          isAdFree: isAdFree,
        );
        return _currentUser;
      }

      return null;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return null;
    }
  }

  /// Restore session on app start (silent sign-in)
  Future<UserModel?> restoreSession() async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        // Check ad-free status
        final isAdFree = await AdFreeService().checkAdFreeStatus(
          firebaseUser.email ?? '',
        );

        _currentUser = UserModel.fromFirebaseUser(
          firebaseUser,
          isAdFree: isAdFree,
        );
        return _currentUser;
      }
      return null;
    } catch (e) {
      debugPrint('Restore session error: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  /// Refresh ad-free status (e.g., after Firestore update)
  Future<void> refreshAdFreeStatus() async {
    if (_currentUser != null) {
      final isAdFree = await AdFreeService().checkAdFreeStatus(
        _currentUser!.email,
      );
      _currentUser = _currentUser!.copyWith(isAdFree: isAdFree);
    }
  }
}
