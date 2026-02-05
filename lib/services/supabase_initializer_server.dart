import 'package:supabase/supabase.dart';

Future<SupabaseClient> initializeSupabase(String url, String key) async {
  return SupabaseClient(url, key);
}
