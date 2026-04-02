import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';

/// User account data model
class UserAccount {
  final String id;
  String name;
  String email;
  String? avatarUrl;
  DateTime createdAt;
  DateTime lastSyncAt;
  bool isLoggedIn;

  UserAccount({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
    required this.lastSyncAt,
    this.isLoggedIn = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt.toIso8601String(),
        'lastSyncAt': lastSyncAt.toIso8601String(),
        'isLoggedIn': isLoggedIn,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        avatarUrl: json['avatarUrl'],
        createdAt: DateTime.parse(json['createdAt']),
        lastSyncAt: DateTime.parse(json['lastSyncAt']),
        isLoggedIn: json['isLoggedIn'] ?? false,
      );

  factory UserAccount.guest() => UserAccount(
        id: 'guest',
        name: 'Guest User',
        email: '',
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isLoggedIn: false,
      );
}

/// Deleted document for recycle bin
class DeletedDocument {
  final Document document;
  final DateTime deletedAt;
  final DateTime expiresAt; // Auto-delete after 30 days

  DeletedDocument({
    required this.document,
    required this.deletedAt,
    DateTime? expiresAt,
  }) : expiresAt = expiresAt ?? deletedAt.add(const Duration(days: 30));

  Map<String, dynamic> toJson() => {
        'document': document.toJson(),
        'deletedAt': deletedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory DeletedDocument.fromJson(Map<String, dynamic> json) =>
      DeletedDocument(
        document: Document.fromJson(json['document']),
        deletedAt: DateTime.parse(json['deletedAt']),
        expiresAt: DateTime.parse(json['expiresAt']),
      );

  int get daysUntilExpiry => expiresAt.difference(DateTime.now()).inDays;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// User Account Service - Manages user profile, sync, and recycle bin
class UserAccountService extends ChangeNotifier {
  static final UserAccountService _instance = UserAccountService._internal();
  factory UserAccountService() => _instance;
  UserAccountService._internal();

  UserAccount _account = UserAccount.guest();
  List<DeletedDocument> _recycleBin = [];
  bool _isSyncing = false;
  bool _backgroundSyncEnabled = true;
  DateTime? _lastBackgroundSync;

  // Getters
  UserAccount get account => _account;
  List<DeletedDocument> get recycleBin =>
      _recycleBin.where((d) => !d.isExpired).toList();
  bool get isSyncing => _isSyncing;
  bool get isLoggedIn => _account.isLoggedIn;
  bool get backgroundSyncEnabled => _backgroundSyncEnabled;
  DateTime? get lastBackgroundSync => _lastBackgroundSync;

  /// Initialize service from storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load account
    final accountJson = prefs.getString('user_account');
    if (accountJson != null) {
      try {
        _account = UserAccount.fromJson(jsonDecode(accountJson));
      } catch (e) {
        debugPrint('Error loading account: $e');
        _account = UserAccount.guest();
      }
    }

    // Load recycle bin
    final binJson = prefs.getString('recycle_bin');
    if (binJson != null) {
      try {
        final list = jsonDecode(binJson) as List;
        _recycleBin = list.map((e) => DeletedDocument.fromJson(e)).toList();
        // Remove expired items
        _recycleBin.removeWhere((d) => d.isExpired);
      } catch (e) {
        debugPrint('Error loading recycle bin: $e');
      }
    }

    // Load sync settings
    _backgroundSyncEnabled = prefs.getBool('background_sync_enabled') ?? true;
    final lastSyncStr = prefs.getString('last_background_sync');
    if (lastSyncStr != null) {
      _lastBackgroundSync = DateTime.tryParse(lastSyncStr);
    }

    notifyListeners();
  }

  /// Save to storage
  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_account', jsonEncode(_account.toJson()));
    await prefs.setString(
        'recycle_bin', jsonEncode(_recycleBin.map((e) => e.toJson()).toList()));
    await prefs.setBool('background_sync_enabled', _backgroundSyncEnabled);
    if (_lastBackgroundSync != null) {
      await prefs.setString(
          'last_background_sync', _lastBackgroundSync!.toIso8601String());
    }
  }

  // ==================== ACCOUNT MANAGEMENT ====================

  /// Sign in with email (stub - implement with your auth provider)
  Future<bool> signIn(String email, String password) async {
    _isSyncing = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));

      _account = UserAccount(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: email.split('@').first,
        email: email,
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isLoggedIn: true,
      );

      await _saveToStorage();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Sign in error: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google (stub)
  Future<bool> signInWithGoogle() async {
    _isSyncing = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));

      _account = UserAccount(
        id: 'google_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Google User',
        email: 'user@gmail.com',
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isLoggedIn: true,
      );

      await _saveToStorage();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Update user profile
  Future<void> updateProfile({String? name, String? email}) async {
    if (name != null) _account.name = name;
    if (email != null) _account.email = email;
    await _saveToStorage();
    notifyListeners();
  }

  /// Sign out
  Future<void> signOut() async {
    _account = UserAccount.guest();
    await _saveToStorage();
    notifyListeners();
  }

  /// Delete account permanently
  Future<bool> deleteAccount() async {
    _isSyncing = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));

      // Clear all data
      _account = UserAccount.guest();
      _recycleBin.clear();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_account');
      await prefs.remove('recycle_bin');

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Delete account error: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  // ==================== RECYCLE BIN ====================

  /// Move document to recycle bin
  void moveToRecycleBin(Document document) {
    _recycleBin.add(DeletedDocument(
      document: document,
      deletedAt: DateTime.now(),
    ));
    _saveToStorage();
    notifyListeners();
  }

  /// Restore document from recycle bin
  Document? restoreFromRecycleBin(String documentId) {
    final index = _recycleBin.indexWhere((d) => d.document.id == documentId);
    if (index == -1) return null;

    final deleted = _recycleBin.removeAt(index);
    _saveToStorage();
    notifyListeners();
    return deleted.document;
  }

  /// Permanently delete from recycle bin
  void permanentlyDelete(String documentId) {
    _recycleBin.removeWhere((d) => d.document.id == documentId);
    _saveToStorage();
    notifyListeners();
  }

  /// Empty recycle bin
  void emptyRecycleBin() {
    _recycleBin.clear();
    _saveToStorage();
    notifyListeners();
  }

  // ==================== SYNC ====================

  /// Sync data with cloud
  Future<bool> syncNow() async {
    if (_isSyncing) return false;

    _isSyncing = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 2));

      _account.lastSyncAt = DateTime.now();
      _lastBackgroundSync = DateTime.now();
      await _saveToStorage();

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Sync error: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggle background sync
  void setBackgroundSync(bool enabled) {
    _backgroundSyncEnabled = enabled;
    _saveToStorage();
    notifyListeners();
  }

  /// Background sync (called by workmanager)
  Future<void> performBackgroundSync() async {
    if (!_backgroundSyncEnabled || !isLoggedIn) return;

    try {
      _lastBackgroundSync = DateTime.now();
      await _saveToStorage();
    } catch (e) {
      debugPrint('Background sync error: $e');
    }
  }

  /// Get sync status text
  String get syncStatusText {
    if (_isSyncing) return 'Syncing...';
    if (!isLoggedIn) return 'Not signed in';

    final lastSync = _account.lastSyncAt;
    final diff = DateTime.now().difference(lastSync);

    if (diff.inMinutes < 1) return 'Just synced';
    if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
    return 'Synced ${diff.inDays}d ago';
  }
}
