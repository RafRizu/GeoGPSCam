import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isAdFree;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isAdFree = false,
  });

  /// Create from Firebase User
  factory UserModel.fromFirebaseUser(User user, {bool isAdFree = false}) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isAdFree: isAdFree,
    );
  }

  /// Copy with ad-free status
  UserModel copyWith({bool? isAdFree}) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      isAdFree: isAdFree ?? this.isAdFree,
    );
  }

  /// Get initials for avatar fallback
  String get initials {
    if (displayName == null || displayName!.isEmpty) {
      return email.isNotEmpty ? email[0].toUpperCase() : '?';
    }
    final parts = displayName!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
