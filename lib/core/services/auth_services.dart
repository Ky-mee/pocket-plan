import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_plan/models/user_model.dart';
import 'package:pocket_plan/core/services/database_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final DatabaseService _db = DatabaseService();

  // Current logged-in user stream
  Stream<User?> get authStateStream => _auth.authStateChanges();

  // Current user (nullable)
  User? get currentUser => _auth.currentUser;

  // ─────────────────────────────────────────
  // EMAIL + PASSWORD AUTH
  // ─────────────────────────────────────────

  Future<UserCredential> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required double monthlyAllowance,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update display name
    await credential.user?.updateDisplayName(name);

    // Create Firestore user profile
    final userModel = UserModel(
      uid: credential.user!.uid,
      name: name,
      email: email,
      monthlyAllowance: monthlyAllowance,
      createdAt: DateTime.now(),
    );
    await _db.createUser(userModel);

    return credential;
  }

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ─────────────────────────────────────────
  // BIOMETRIC AUTH (Fingerprint + Face ID)
  // ─────────────────────────────────────────

  // Check if device supports biometrics
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  // Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Authenticate using biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint or face to access PocketPlan',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true, // keeps prompt open if user switches apps
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // Save biometric preference for this user
  Future<void> setBiometricEnabled(String uid, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled_$uid', enabled);
    await _db.updateUser(uid, {'biometricEnabled': enabled});
  }

  // Check if biometric is enabled for this user
  Future<bool> isBiometricEnabled(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled_$uid') ?? false;
  }
}
