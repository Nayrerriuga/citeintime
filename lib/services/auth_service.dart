import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _sanitizeId(String idNumber) =>
      idNumber.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '');

  String _idToInternalEmail(String idNumber) =>
      '${_sanitizeId(idNumber)}@citeintime.local';

  String _idToInternalPassword(String idNumber) =>
      'CiteInTime#${_sanitizeId(idNumber)}#2026';

  Future<void> signInWithId(String rawId) async {
    final trimmedId = rawId.trim();

    final userRecord = await _supabase
        .from('student_masterlist')
        .select('id_number, role')
        .eq('id_number', trimmedId)
        .maybeSingle();

    if (userRecord == null) {
      throw const AuthException(
        'ID Number not found in the CiteInTime master list.',
      );
    }

    final email = _idToInternalEmail(trimmedId);
    final password = _idToInternalPassword(trimmedId);

    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'id_number': trimmedId, 'role': userRecord['role'] ?? 'student'},
      );
    }
  }
}
