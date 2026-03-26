import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final _db = Supabase.instance.client;
  static const _table = 'Recordings';

  static Stream<List<Map<String, dynamic>>> watchRecordings() {
    return _db
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('recorded_at', ascending: false);
  }
}
