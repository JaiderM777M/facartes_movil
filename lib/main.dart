import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core.dart';
import 'screens/auth_screen.dart';
import 'screens/shell.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_url.isEmpty || _key.isEmpty) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Falta la configuración.\nEjecuta con:\nflutter run --dart-define-from-file=env.json',
                textAlign: TextAlign.center),
          ),
        ),
      ),
    ));
    return;
  }
  await Supabase.initialize(url: _url, anonKey: _key);
  runApp(const FacartesApp());
}

class FacartesApp extends StatelessWidget {
  const FacartesApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FACARTES Móvil',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AuthGate(),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, _) => Supabase.instance.client.auth.currentSession == null
            ? const AuthScreen()
            : const Shell(),
      );
}
