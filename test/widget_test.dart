import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:facartes_movil/core.dart';
import 'package:facartes_movil/screens/auth_screen.dart';

void main() {
  testWidgets('la pantalla de acceso muestra el formulario', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const AuthScreen()));
    expect(find.text('FACARTES Móvil'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pump();
    expect(find.text('Crear cuenta'), findsOneWidget);
  });
}
