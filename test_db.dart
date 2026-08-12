import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://hrydivnnodnpzdphwxyu.supabase.co',
    'sb_publishable_iS7--gEg76NC-kQ5kj9s7Q_I9pw2o8B',
  );
  
  try {
    print('Checking RLS...');
    // We can try inserting a dummy row, but actually RLS on medical_appointments 
    // was probably never enabled unless we ran a script for it.
    final data = await client.rpc('check_rls'); // Just checking if we can do rpc, probably not.
    print('RPC: $data');
  } catch (e) {
    print('ERROR: $e');
  }
}
