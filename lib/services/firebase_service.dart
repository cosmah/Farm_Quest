import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/player_profile.dart';
import '../models/game_state.dart';

/// Firebase service for authentication and Firestore operations
class FirebaseService {
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Check if Firebase is initialized
  bool get _isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Lazy initialization of Firebase instances
  FirebaseAuth get _authInstance {
    if (!_isFirebaseInitialized) {
      throw Exception('Firebase not initialized');
    }
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  FirebaseFirestore get _firestoreInstance {
    if (!_isFirebaseInitialized) {
      throw Exception('Firebase not initialized');
    }
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  /// Get current user
  User? get currentUser {
    try {
      if (!_isFirebaseInitialized) return null;
      return _authInstance.currentUser;
    } catch (e) {
      return null;
    }
  }

  /// Check if user is signed in
  bool get isSignedIn {
    try {
      return _isFirebaseInitialized && currentUser != null;
    } catch (e) {
      return false;
    }
  }

  /// Get current user display name
  String get displayName => currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'Anonymous';

  /// Sign in anonymously
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _authInstance.signInAnonymously();
      return credential.user;
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  /// Sign up with email and password
  Future<User?> signUpWithEmail(String email, String password, String displayName) async {
    try {
      final credential = await _authInstance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await credential.user?.updateDisplayName(displayName);
      
      return credential.user;
    } catch (e) {
      print('Error signing up: $e');
      return null;
    }
  }

  /// Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _authInstance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  /// Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _authInstance.signInWithCredential(credential);
      
      return userCredential.user;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _authInstance.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Update player profile in Firestore
  Future<void> updatePlayerProfile(GameState gameState) async {
    if (!isSignedIn) return;

    final score = PlayerProfile.calculateScore(
      level: gameState.level,
      money: gameState.money,
      cropsHarvested: gameState.totalCropsHarvested,
      plotsUnlocked: gameState.unlockedPlots.length,
    );

    final profile = PlayerProfile(
      uid: currentUser!.uid,
      displayName: displayName,
      level: gameState.level,
      totalMoney: gameState.money,
      cropsHarvested: gameState.totalCropsHarvested,
      plotsUnlocked: gameState.unlockedPlots.length,
      daysPlayed: gameState.daysPlayed,
      score: score,
      lastUpdated: DateTime.now(),
      createdAt: gameState.gameStartDate,
    );

    try {
      await _firestoreInstance
          .collection('players')
          .doc(currentUser!.uid)
          .set(profile.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('Error updating profile: $e');
    }
  }

  /// Get current player profile
  Future<PlayerProfile?> getPlayerProfile() async {
    if (!isSignedIn) return null;

    try {
      final doc = await _firestoreInstance
          .collection('players')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists) {
        return PlayerProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting profile: $e');
      return null;
    }
  }

  /// Get top players for leaderboard
  Future<List<PlayerProfile>> getLeaderboard({int limit = 100}) async {
    try {
      final snapshot = await _firestoreInstance
          .collection('players')
          .orderBy('score', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => PlayerProfile.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get player rank
  Future<int> getPlayerRank() async {
    if (!isSignedIn) return 0;

    try {
      final profile = await getPlayerProfile();
      if (profile == null) return 0;

      final snapshot = await _firestoreInstance
          .collection('players')
          .where('score', isGreaterThan: profile.score)
          .get();

      return snapshot.docs.length + 1;
    } catch (e) {
      print('Error getting rank: $e');
      return 0;
    }
  }

  /// Delete player profile
  Future<void> deletePlayerProfile() async {
    if (!isSignedIn) return;

    try {
      await _firestoreInstance
          .collection('players')
          .doc(currentUser!.uid)
          .delete();
    } catch (e) {
      print('Error deleting profile: $e');
    }
  }

  /// Stream of leaderboard updates
  Stream<List<PlayerProfile>> leaderboardStream({int limit = 100}) {
    try {
      return _firestoreInstance
          .collection('players')
          .orderBy('score', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => PlayerProfile.fromMap(doc.data()))
              .toList());
    } catch (e) {
      print('Error getting leaderboard stream: $e');
      return Stream.value([]);
    }
  }
}

