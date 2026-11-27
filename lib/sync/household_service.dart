import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/repository.dart';
import '../models/operation.dart';
import 'firestore_repository.dart';

/// Identifiant du client « Web » OAuth du projet Firebase (dans
/// google-services.json, client_type 3) : la connexion Google sur Android
/// en a besoin pour obtenir le jeton d'identité.
const webClientId =
    '980333322704-p8aq62ijj79ulh78dbtuklnpvo9v8d8g.apps.googleusercontent.com';

/// Erreur à afficher telle quelle à l'utilisateur.
class HouseholdException implements Exception {
  const HouseholdException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Connexion Google, création d'un foyer partagé, invitation du conjoint.
class HouseholdService {
  HouseholdService({this.authOverride, this.firestoreOverride});

  /// Pour les tests : authentification et base simulées.
  final FirebaseAuth? authOverride;
  final FirebaseFirestore? firestoreOverride;
  static bool _googleReady = false;

  FirebaseAuth get auth => authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore =>
      firestoreOverride ?? FirebaseFirestore.instance;

  User? get currentUser => auth.currentUser;

  /// Connexion avec le compte Google choisi sur le téléphone.
  Future<User> signInWithGoogle() async {
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(serverClientId: webClientId);
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await auth.signInWithCredential(credential);
      return result.user!;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const HouseholdException('Connexion annulée.');
      }
      throw HouseholdException(
        'La connexion Google a échoué (${e.code.name}). Vérifiez la '
        'connexion internet et réessayez.',
      );
    } on FirebaseAuthException catch (e) {
      throw HouseholdException(
        'La connexion a échoué (${e.code}). Réessayez dans un instant.',
      );
    }
  }

  /// Crée un foyer et y copie toutes les données de ce téléphone. Les
  /// références à l'ancien identifiant local du membre sont remplacées par
  /// son compte. Renvoie l'identifiant du foyer.
  Future<String> createHousehold({
    required BudgetData data,
    required String memberId,
    required String memberName,
    required String oldMemberId,
  }) async {
    final ref = firestore.collection(Paths.households).doc();
    await ref.set({
      'nom': 'Foyer de $memberName',
      'devise': 'XOF',
      'membres': [memberId],
      'noms': {memberId: memberName},
      'creePar': memberId,
      'creeLe': FieldValue.serverTimestamp(),
    });

    String? fix(String? id) =>
        id == null || id.isEmpty || id == oldMemberId ? memberId : id;
    final wallets = [
      for (final w in data.wallets)
        w.shared ? w : w.copyWith(ownerId: () => fix(w.ownerId)),
    ];
    bool privateWallet(String id) =>
        wallets.any((w) => w.id == id && w.isPrivate);

    // Écritures par lots (500 au plus par lot).
    final writes =
        <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];
    CollectionReference<Map<String, dynamic>> shared(String name) =>
        ref.collection(name);
    CollectionReference<Map<String, dynamic>> private(String name) =>
        ref.collection(Paths.private).doc(memberId).collection(name);

    for (final w in wallets) {
      writes.add((
        (w.isPrivate ? private : shared)(Paths.wallets).doc(w.id),
        w.toJson(),
      ));
    }
    for (final c in data.categories) {
      writes.add((shared(Paths.categories).doc(c.id), c.toJson()));
    }
    for (final o in data.operations) {
      final op = Operation.fromJson({...o.toJson(), 'auteur': fix(o.authorId)});
      writes.add((
        (isPrivateOperation(op, privateWallet) ? private : shared)(
          Paths.operations,
        ).doc(op.id),
        op.toJson(),
      ));
    }
    for (final g in data.goals) {
      writes.add((shared(Paths.goals).doc(g.id), g.toJson()));
    }
    for (final p in data.projects) {
      writes.add((shared(Paths.projects).doc(p.id), p.toJson()));
    }
    for (final b in data.budgets) {
      writes.add((shared(Paths.budgets).doc(b.id), b.toJson()));
    }
    for (final r in data.recurrences) {
      writes.add((shared(Paths.recurrences).doc(r.id), r.toJson()));
    }
    for (var i = 0; i < writes.length; i += 450) {
      final batch = firestore.batch();
      for (final (doc, json) in writes.skip(i).take(450)) {
        batch.set(doc, json);
      }
      await batch.commit();
    }
    return ref.id;
  }

  /// Code d'invitation valable 7 jours (8 caractères sans ambiguïté :
  /// ni 0/O ni 1/I/L).
  Future<String> createInvitation({
    required String householdId,
    required String memberId,
    DateTime? now,
  }) async {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = List.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    final t = now ?? DateTime.now();
    await firestore.collection(Paths.invitations).doc(code).set({
      'foyer': householdId,
      'creePar': memberId,
      'expire': Timestamp.fromDate(t.add(const Duration(days: 7))),
    });
    return code;
  }

  /// Rejoint le foyer d'une invitation ; renvoie son identifiant.
  Future<String> joinHousehold({
    required String code,
    required String memberId,
    required String memberName,
    DateTime? now,
  }) async {
    final clean = code.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (clean.length != 8) {
      throw const HouseholdException('Le code doit avoir 8 caractères.');
    }
    final invitation = firestore.collection(Paths.invitations).doc(clean);
    final snapshot = await invitation.get();
    final json = snapshot.data();
    if (json == null) {
      throw const HouseholdException(
        'Code inconnu. Vérifiez-le ou demandez-en un nouveau.',
      );
    }
    final expire = (json['expire'] as Timestamp?)?.toDate();
    if (expire != null && expire.isBefore(now ?? DateTime.now())) {
      throw const HouseholdException(
        'Ce code a expiré. Demandez-en un nouveau.',
      );
    }
    final householdId = json['foyer'] as String;
    await firestore.collection(Paths.households).doc(householdId).update({
      'membres': FieldValue.arrayUnion([memberId]),
      'noms.$memberId': memberName,
      'codeUtilise': clean,
    });
    // Code à usage unique.
    await invitation.delete().catchError((Object _) {});
    return householdId;
  }

  Future<void> signOut() async {
    await auth.signOut();
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }
}
