import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../services/notification_service.dart';

class AuthState extends ChangeNotifier {
  AuthState({
    required this.dbHelper,
    required this.notificationService,
  });

  final DatabaseHelper dbHelper;
  final NotificationService notificationService;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _rememberMeKey = 'remember_me';
  static const String _loggedInUserIdKey = 'logged_in_user_id';
  static const String _loggedInUserEmailKey = 'logged_in_user_email';

  bool isInitialising = true;
  bool isLoading = false;

  int? currentUserId;
  String? currentUserEmail;
  String? errorMessage;

  bool get isLoggedIn => currentUserId != null;

  Future<void> init() async {
    isInitialising = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
      final firebaseUser = _auth.currentUser;

      if (!rememberMe) {
        await _auth.signOut();
        await _clearSavedSession(prefs);
        currentUserId = null;
        currentUserEmail = null;
      } else if (firebaseUser != null) {
        await firebaseUser.reload();
        final refreshedUser = _auth.currentUser;

        if (refreshedUser == null || !refreshedUser.emailVerified) {
          await _auth.signOut();
          await _clearSavedSession(prefs);
          currentUserId = null;
          currentUserEmail = null;
        } else {
          await _syncLocalUserFromFirebase(refreshedUser);
        }
      } else {
        await _clearSavedSession(prefs);
        currentUserId = null;
        currentUserEmail = null;
      }
    } catch (e, stackTrace) {
      errorMessage = 'Failed to restore login session: $e';
      debugPrint('AuthState init error: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      isInitialising = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String confirmPassword,
    required bool rememberMe,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final safeEmail = email.trim().toLowerCase();
      final safePassword = password;
      final safeConfirmPassword = confirmPassword;

      if (safeEmail.isEmpty || safePassword.isEmpty) {
        errorMessage = 'Email and password are required.';
        return false;
      }

      if (!_isValidEmail(safeEmail)) {
        errorMessage = 'Please enter a valid email address.';
        return false;
      }

      if (!safeEmail.endsWith('@hallam.shu.ac.uk')) {
        errorMessage =
        'Please use your university email address (@hallam.shu.ac.uk).';
        return false;
      }

      if (safePassword.length < 6) {
        errorMessage = 'Password must be at least 6 characters long.';
        return false;
      }

      if (safePassword != safeConfirmPassword) {
        errorMessage = 'Passwords do not match.';
        return false;
      }

      debugPrint('Register started for $safeEmail');

      final credential = await _auth.createUserWithEmailAndPassword(
        email: safeEmail,
        password: safePassword,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        errorMessage = 'Failed to create account.';
        return false;
      }

      debugPrint('Firebase user created: ${firebaseUser.email}');

      await firebaseUser.sendEmailVerification();
      debugPrint('Verification email sent');

      final prefs = await SharedPreferences.getInstance();

      await _auth.signOut();
      await _clearSavedSession(prefs);

      currentUserId = null;
      currentUserEmail = null;

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('register FirebaseAuthException: ${e.code} ${e.message}');

      if (e.code == 'email-already-in-use') {
        errorMessage =
        'An account with that email already exists. If you have not verified it yet, use Login or Resend verification email.';
        return false;
      }

      errorMessage = _mapFirebaseAuthError(e);
      return false;
    } catch (e, stackTrace) {
      errorMessage = 'Failed to create account: $e';
      debugPrint('register error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final safeEmail = email.trim().toLowerCase();
      final safePassword = password;

      if (safeEmail.isEmpty || safePassword.isEmpty) {
        errorMessage = 'Email and password are required.';
        return false;
      }

      if (!_isValidEmail(safeEmail)) {
        errorMessage = 'Please enter a valid email address.';
        return false;
      }

      debugPrint('Login started for $safeEmail');

      final credential = await _auth.signInWithEmailAndPassword(
        email: safeEmail,
        password: safePassword,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        errorMessage = 'Failed to sign in.';
        return false;
      }

      debugPrint('Firebase sign-in success');

      await firebaseUser.reload();
      final refreshedUser = _auth.currentUser;

      debugPrint(
        'User after reload: ${refreshedUser?.email}, verified=${refreshedUser?.emailVerified}',
      );

      if (refreshedUser == null) {
        errorMessage = 'Failed to sign in.';
        return false;
      }

      if (!refreshedUser.emailVerified) {
        await _auth.signOut();
        currentUserId = null;
        currentUserEmail = null;

        errorMessage =
        'Your email is not verified yet. Check your inbox or junk folder, then return and log in again. You can also resend the verification email.';
        return false;
      }

      await _syncLocalUserFromFirebase(refreshedUser);

      if (currentUserId == null || currentUserEmail == null) {
        await _auth.signOut();
        currentUserId = null;
        currentUserEmail = null;
        errorMessage = 'Failed to load your local planner profile.';
        return false;
      }

      await _saveSession(
        userId: currentUserId!,
        email: currentUserEmail!,
        rememberMe: rememberMe,
      );

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('login FirebaseAuthException: ${e.code} ${e.message}');
      errorMessage = _mapFirebaseAuthError(e);
      return false;
    } catch (e, stackTrace) {
      errorMessage = 'Failed to sign in: $e';
      debugPrint('login error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final safeEmail = email.trim().toLowerCase();
      final safePassword = password;

      if (safeEmail.isEmpty || safePassword.isEmpty) {
        errorMessage =
        'Enter your email and password to resend the verification email.';
        return false;
      }

      if (!_isValidEmail(safeEmail)) {
        errorMessage = 'Please enter a valid email address.';
        return false;
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: safeEmail,
        password: safePassword,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        errorMessage = 'Unable to resend verification email.';
        return false;
      }

      await firebaseUser.reload();
      final refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        errorMessage = 'Unable to resend verification email.';
        return false;
      }

      if (refreshedUser.emailVerified) {
        await _auth.signOut();
        errorMessage = 'This email is already verified. You can log in now.';
        return false;
      }

      await refreshedUser.sendEmailVerification();
      await _auth.signOut();

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'resendVerificationEmail FirebaseAuthException: ${e.code} ${e.message}',
      );
      errorMessage = _mapFirebaseAuthError(e);
      return false;
    } catch (e, stackTrace) {
      errorMessage = 'Failed to resend verification email: $e';
      debugPrint('resendVerificationEmail error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkVerificationStatus({
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final safeEmail = email.trim().toLowerCase();
      final safePassword = password;

      if (safeEmail.isEmpty || safePassword.isEmpty) {
        errorMessage =
        'Enter your email and password to check verification status.';
        return false;
      }

      if (!_isValidEmail(safeEmail)) {
        errorMessage = 'Please enter a valid email address.';
        return false;
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: safeEmail,
        password: safePassword,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        errorMessage = 'Unable to check verification status.';
        return false;
      }

      await firebaseUser.reload();
      final refreshedUser = _auth.currentUser;

      final isVerified = refreshedUser?.emailVerified ?? false;

      await _auth.signOut();

      if (!isVerified) {
        errorMessage =
        'Your email is still not verified. Open the latest verification email, tap the link, then try again.';
        return false;
      }

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'checkVerificationStatus FirebaseAuthException: ${e.code} ${e.message}',
      );
      errorMessage = _mapFirebaseAuthError(e);
      return false;
    } catch (e, stackTrace) {
      errorMessage = 'Failed to check verification status: $e';
      debugPrint('checkVerificationStatus error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordReset({
    required String email,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final safeEmail = email.trim().toLowerCase();

      if (safeEmail.isEmpty) {
        errorMessage = 'Email is required.';
        return false;
      }

      if (!_isValidEmail(safeEmail)) {
        errorMessage = 'Please enter a valid email address.';
        return false;
      }

      await _auth.sendPasswordResetEmail(email: safeEmail);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'sendPasswordReset FirebaseAuthException: ${e.code} ${e.message}',
      );
      errorMessage = _mapFirebaseAuthError(e);
      return false;
    } catch (e, stackTrace) {
      errorMessage = 'Failed to send password reset email: $e';
      debugPrint('sendPasswordReset error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      await _auth.signOut();
      await _clearSavedSession(prefs);

      currentUserId = null;
      currentUserEmail = null;

      await notificationService.cancelAll();
      notificationService.setFastTestMode(false);
    } catch (e, stackTrace) {
      errorMessage = 'Failed to log out: $e';
      debugPrint('logout error: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _syncLocalUserFromFirebase(User firebaseUser) async {
    final firebaseUid = firebaseUser.uid.trim();
    final safeEmail = (firebaseUser.email ?? '').trim().toLowerCase();

    if (firebaseUid.isEmpty) {
      throw Exception('Firebase user UID is missing.');
    }

    if (safeEmail.isEmpty) {
      throw Exception('Firebase user email is missing.');
    }

    debugPrint(
      'Syncing local SQLite user for email=$safeEmail firebaseUid=$firebaseUid',
    );

    final existingByUid = await dbHelper.getUserByFirebaseUid(firebaseUid);

    int localUserId;

    if (existingByUid != null) {
      localUserId = existingByUid['id'] as int;
      debugPrint('Found existing local user by firebaseUid id=$localUserId');
    } else {
      final existingByEmail = await dbHelper.getUserByEmail(safeEmail);

      if (existingByEmail != null) {
        localUserId = existingByEmail['id'] as int;

        final existingFirebaseUid =
        (existingByEmail['firebaseUid'] ?? '').toString().trim();

        if (existingFirebaseUid.isEmpty) {
          await dbHelper.updateUserFirebaseUid(
            userId: localUserId,
            firebaseUid: firebaseUid,
          );
          debugPrint(
            'Attached firebaseUid to existing local user id=$localUserId',
          );
        } else if (existingFirebaseUid != firebaseUid) {
          throw Exception(
            'Local user email is already linked to a different Firebase account.',
          );
        }

        debugPrint('Found existing local user by email id=$localUserId');
      } else {
        localUserId = await dbHelper.insertUser({
          'email': safeEmail,
          'firebaseUid': firebaseUid,
          'passwordHash': '',
        });
        debugPrint('Created local user id=$localUserId');
      }
    }

    currentUserId = localUserId;
    currentUserEmail = safeEmail;
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters long.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  Future<void> _saveSession({
    required int userId,
    required String email,
    required bool rememberMe,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_rememberMeKey, rememberMe);

    if (rememberMe) {
      await prefs.setInt(_loggedInUserIdKey, userId);
      await prefs.setString(_loggedInUserEmailKey, email);
    } else {
      await prefs.remove(_loggedInUserIdKey);
      await prefs.remove(_loggedInUserEmailKey);
    }
  }

  Future<void> _clearSavedSession(SharedPreferences prefs) async {
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_loggedInUserIdKey);
    await prefs.remove(_loggedInUserEmailKey);
  }
}