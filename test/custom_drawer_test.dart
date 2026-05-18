import 'package:flutter_test/flutter_test.dart';

// función pura extraída del controlador para su testeo unitario
bool verificarPasswordSegura(String password) {
  // la contraseña debe tener entre 6 y 12 caracteres y contener caracteres especiales
  final regExp = RegExp(r'^(?=.*[!@#\$&*~\.])(?=.{6,12}$)');
  return regExp.hasMatch(password);
}

void main() {
  group('Pruebas Unitarias Automatizadas - Validadores de Credenciales', () {

    test('Camino de Éxito: Contraseña válida con caracteres especiales', () {
      final resultado = verificarPasswordSegura('onda!2026');
      expect(resultado, isTrue); // el test verifica que devuelve true de forma automática
    });

    test('Camino de Fallo: Contraseña demasiado corta', () {
      final resultado = verificarPasswordSegura('123!');
      expect(resultado, isFalse); // detecta automáticamente la vulnerabilidad
    });

    test('Camino de Fallo: Falta carácter especial requerido', () {
      final resultado = verificarPasswordSegura('ondaUrbanita2026');
      expect(resultado, isFalse); // rechaza la cadena por falta de robustez
    });
  });
}