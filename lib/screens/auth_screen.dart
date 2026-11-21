import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController(), email = TextEditingController(), pass = TextEditingController();
  bool register = false, busy = false;
  String? err, info;

  Future<void> submit() async {
    setState(() { busy = true; err = null; info = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (register) {
        final r = await auth.signUp(
          email: email.text.trim(), password: pass.text,
          data: {'name': name.text.trim().isEmpty ? email.text.split('@').first : name.text.trim()},
        );
        if (r.session == null) info = 'Cuenta creada. Revisa tu correo para confirmarla.';
      } else {
        await auth.signInWithPassword(email: email.text.trim(), password: pass.text);
      }
    } on AuthException catch (e) {
      err = e.message;
    } catch (e) {
      err = 'Error de conexión: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.palette, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 16),
                const Text('FACARTES Móvil', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const Text('Galería de arte universitaria', style: TextStyle(color: kMuted)),
                const SizedBox(height: 28),
                if (register) ...[
                  TextField(controller: name, decoration: const InputDecoration(hintText: 'Nombre')),
                  const SizedBox(height: 12),
                ],
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Correo')),
                const SizedBox(height: 12),
                TextField(controller: pass, obscureText: true, decoration: const InputDecoration(hintText: 'Contraseña (mín. 6 caracteres)')),
                if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: Colors.red))),
                if (info != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(info!, style: const TextStyle(color: kPrimary))),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(register ? 'Crear cuenta' : 'Iniciar sesión'),
                ),
                TextButton(
                  onPressed: () => setState(() { register = !register; err = null; info = null; }),
                  child: Text(register ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Regístrate',
                      style: const TextStyle(color: kPrimary)),
                ),
              ]),
            ),
          ),
        ),
      );
}
