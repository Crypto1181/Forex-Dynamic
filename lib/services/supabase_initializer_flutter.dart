import 'package:supabase_flutter/supabase_flutter.dart';

Future<SupabaseClient> initializeSupabase(String url, String key) async {
  await Supabase.initialize(url: url, anonKey: key);
  return Supabase.instance.client;
}
