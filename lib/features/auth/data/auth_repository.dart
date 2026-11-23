import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sesión del ciudadano. Solo usa Supabase **Auth** (nunca su BD ni Storage).
abstract interface class AuthRepository {
  bool get isSignedIn;
  String? get email;

  /// Emite cada vez que la sesión empieza o termina.
  Stream<bool> authChanges();

  /// Token vigente para el header `Authorization`; lo refresca si venció.
  Future<String?> accessToken();

  Future<void> signIn({required String email, required String password});

  /// Devuelve `true` si la cuenta quedó con sesión iniciada, o `false` si
  /// Supabase pide confirmar el correo primero.
  Future<bool> signUp({required String email, required String password});

  Future<void> signOut();
}

/// Se sobrescribe en `main` con la implementación de Supabase y en las pruebas
/// con una falsa.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('authRepositoryProvider sin configurar'),
);

/// `true` mientras haya sesión iniciada.
final signedInProvider = StreamProvider<bool>((ref) async* {
  final auth = ref.watch(authRepositoryProvider);
  yield auth.isSignedIn;
  yield* auth.authChanges();
});

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

  @override
  bool get isSignedIn => _auth.currentSession != null;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Stream<bool> authChanges() =>
      _auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Future<String?> accessToken() async {
    var session = _auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      session = (await _auth.refreshSession()).session;
    }
    return session?.accessToken;
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithPassword(email: email.trim(), password: password);

  @override
  Future<bool> signUp({required String email, required String password}) async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
    );
    return response.session != null;
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
