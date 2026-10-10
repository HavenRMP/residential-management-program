import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Utils/codigo_helper.dart';

void main() {
  group('CodigoHelper Tests', () {
    test('extrae código directo de llave codigo', () {
      final res = {'codigo': 'ABC-123'};
      expect(CodigoHelper.extractCodigo(res), 'ABC-123');
    });

    test('extrae código de llaves alternativas como Codigo, code o Code', () {
      expect(CodigoHelper.extractCodigo({'Codigo': 'RES-999'}), 'RES-999');
      expect(CodigoHelper.extractCodigo({'code': 'ALPHA1'}), 'ALPHA1');
      expect(CodigoHelper.extractCodigo({'Code': 'BETA2'}), 'BETA2');
      expect(CodigoHelper.extractCodigo({'codigoAcceso': 'ACCESO10'}), 'ACCESO10');
      expect(CodigoHelper.extractCodigo({'token': 'TOK123'}), 'TOK123');
    });

    test('extrae código anidado en data o result', () {
      final resData = {'data': {'codigo': 'DATA-CODE'}};
      expect(CodigoHelper.extractCodigo(resData), 'DATA-CODE');

      final resResult = {'result': {'codigo': 'RESULT-CODE'}};
      expect(CodigoHelper.extractCodigo(resResult), 'RESULT-CODE');

      final resItem = {'item': {'codigo': 'ITEM-CODE'}};
      expect(CodigoHelper.extractCodigo(resItem), 'ITEM-CODE');
    });

    test('extrae código cuando la respuesta es un String plano', () {
      expect(CodigoHelper.extractCodigo('PLAIN_CODE_XYZ'), 'PLAIN_CODE_XYZ');
      expect(CodigoHelper.extractCodigo('   TRIMMED_CODE   '), 'TRIMMED_CODE');
    });

    test('retorna null cuando la respuesta contiene un error', () {
      final resError = {'error': 'No autorizado'};
      expect(CodigoHelper.extractCodigo(resError), isNull);

      final resErrorConCodigo = {'error': 'Error al procesar', 'codigo': 'IGNORE_ME'};
      expect(CodigoHelper.extractCodigo(resErrorConCodigo), isNull);
    });

    test('retorna null cuando el valor es un guión o marcador nulo', () {
      expect(CodigoHelper.extractCodigo({'codigo': '—'}), isNull);
      expect(CodigoHelper.extractCodigo({'codigo': '-'}), isNull);
      expect(CodigoHelper.extractCodigo({'codigo': ''}), isNull);
      expect(CodigoHelper.extractCodigo('—'), isNull);
      expect(CodigoHelper.extractCodigo('-'), isNull);
      expect(CodigoHelper.extractCodigo(''), isNull);
      expect(CodigoHelper.extractCodigo(null), isNull);
    });
  });
}
