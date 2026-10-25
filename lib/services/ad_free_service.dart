import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Checks Firestore `ad_free_users` collection to determine
/// if a given email has ad-free access.
class AdFreeService {
  static final AdFreeService _instance = AdFreeService._internal();
  factory AdFreeService() => _instance;
  AdFreeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache keys
  static const String _cacheKey = 'ad_free_status';
  static const String _cacheTimestampKey = 'ad_free_status_timestamp';
  static const Duration _cacheDuration = Duration(hours: 6);

  bool _isAdFree = false;
  bool get isAdFree => _isAdFree;

  /// Check if the given email is in the ad_free_users collection.
  /// Uses local cache to avoid excessive Firestore reads.
  Future<bool> checkAdFreeStatus(String email) async {
    if (email.isEmpty) return false;

    try {
      // Check local cache first
      final cached = await _getCachedStatus(email);
      if (cached != null) {
        _isAdFree = cached;
        return cached;
      }

      // Query Firestore
      final doc = await _firestore
          .collection('ad_free_users')
          .doc(email.toLowerCase())
          .get();

      if (doc.exists) {
        final data = doc.data();
        final enabled = data?['enabled'] == true;
        _isAdFree = enabled;
        await _cacheStatus(email, enabled);
        return enabled;
      }

      // Fallback: Query by field 'email' in case custom document ID was used
      final query = await _firestore
          .collection('ad_free_users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        final enabled = data['enabled'] == true;
        _isAdFree = enabled;
        await _cacheStatus(email, enabled);
        return enabled;
      }

      _isAdFree = false;
      await _cacheStatus(email, false);
      return false;
    } catch (e) {
      debugPrint('AdFreeService error: $e');
      // On error, return cached value or false
      final cached = await _getCachedStatus(email, ignoreExpiry: true);
      _isAdFree = cached ?? false;
      return _isAdFree;
    }
  }

  /// Get cached ad-free status
  Future<bool?> _getCachedStatus(String email, {bool ignoreExpiry = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedEmail = prefs.getString('${_cacheKey}_email');
      if (cachedEmail != email.toLowerCase()) return null;

      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return null;

      if (!ignoreExpiry) {
        final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cachedTime) > _cacheDuration) {
          return null; // Cache expired
        }
      }

      return prefs.getBool(_cacheKey);
    } catch (_) {
      return null;
    }
  }

  /// Cache the ad-free status locally
  Future<void> _cacheStatus(String email, bool status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_cacheKey}_email', email.toLowerCase());
      await prefs.setBool(_cacheKey, status);
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Silently fail caching
    }
  }

  /// Clear cached status (e.g., on logout)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove('${_cacheKey}_email');
      await prefs.remove(_cacheTimestampKey);
      _isAdFree = false;
    } catch (_) {}
  }
}
