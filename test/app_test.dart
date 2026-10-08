import 'dart:convert';

import 'package:exercicio_biometria/api_service.dart';
import 'package:exercicio_biometria/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const canalBiometria = MethodChannel('plugins.flutter.io/local_auth');

  setUp(() {
    ApiService.token = null;
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canalBiometria, null);
  });

  for (final temBiometria in [false, true]) {
    testWidgets(
      temBiometria
          ? 'biometria recusada não libera o token salvo'
          : 'aparelho sem biometria não libera o token salvo',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({'token': 'sessao-salva'});
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(canalBiometria, (chamada) async {
              if (chamada.method == 'getAvailableBiometrics') {
                return temBiometria ? ['fingerprint'] : <String>[];
              }
              expect(chamada.method, 'authenticate');
              expect(chamada.arguments['biometricOnly'], isTrue);
              return false;
            });
        await http.runWithClient(
          () async {
            await tester.pumpWidget(const MainApp());
            await tester.tap(find.text('Entrar com biometria'));
            await tester.pumpAndSettle();
            expect(ApiService.token, isNull);
            expect(
              find.text(
                temBiometria
                    ? 'Biometria cancelada ou não reconhecida.'
                    : 'Cadastre uma biometria nas configurações do aparelho.',
              ),
              findsOneWidget,
            );
          },
          () => MockClient((_) async {
            fail('Biometria recusada não deve acessar a API.');
          }),
        );
      },
    );
  }

  testWidgets('login vazio exige identificação e senha', (tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Informe o NIF ou e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
    expect(find.text('Cadastrar funcionário'), findsNothing);
  });

  testWidgets('biometria aceita ainda exige uma sessão válida na API', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'token': 'sessao-expirada'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canalBiometria, (chamada) async {
          return chamada.method == 'getAvailableBiometrics' ? ['face'] : true;
        });
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MainApp());
        await tester.tap(find.text('Entrar com biometria'));
        await tester.pumpAndSettle();
        expect(ApiService.token, isNull);
        expect(
          find.text('Sessão encerrada. Entre novamente com sua senha.'),
          findsOneWidget,
        );
      },
      () => MockClient((requisicao) async {
        expect(requisicao.url.path, '/usuario');
        expect(requisicao.headers['Authorization'], 'Bearer sessao-expirada');
        return http.Response(
          jsonEncode({
            'erro': 'Sessão encerrada. Entre novamente com sua senha.',
          }),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  testWidgets('senha incorreta mostra o erro da API e mantém o login', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MainApp());
        await tester.enterText(find.byType(TextFormField).at(0), '1001');
        await tester.enterText(find.byType(TextFormField).at(1), 'errada');
        await tester.tap(find.text('Entrar'));
        await tester.pumpAndSettle();
        expect(find.text('NIF/e-mail ou senha incorretos.'), findsOneWidget);
        expect(ApiService.token, isNull);
      },
      () => MockClient((requisicao) async {
        expect(requisicao.url.path, '/login');
        return http.Response(
          jsonEncode({'erro': 'NIF/e-mail ou senha incorretos.'}),
          401,
        );
      }),
    );
  });

  testWidgets('login válido abre o ponto e histórico usa o token', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MainApp());
        await tester.enterText(find.byType(TextFormField).at(0), '1001');
        await tester.enterText(find.byType(TextFormField).at(1), 'senha123');
        await tester.tap(find.text('Entrar'));
        await tester.pumpAndSettle();
        expect(find.text('Olá, Ana Silva!'), findsOneWidget);
        await tester.tap(find.text('Ver histórico'));
        await tester.pumpAndSettle();
        expect(find.text('Nenhum ponto registrado.'), findsOneWidget);
      },
      () => MockClient((requisicao) async {
        if (requisicao.url.path == '/login') {
          expect(jsonDecode(requisicao.body)['senha'], 'senha123');
          return http.Response(
            jsonEncode({
              'token': 'sessao-teste',
              'usuario': {'id': '1', 'nome': 'Ana Silva', 'nif': '1001'},
            }),
            200,
          );
        }
        expect(requisicao.headers['Authorization'], 'Bearer sessao-teste');
        if (requisicao.url.path == '/local-trabalho') {
          return http.Response(
            jsonEncode({
              'nome': 'Escola',
              'latitude': -23.55,
              'longitude': -46.63,
            }),
            200,
          );
        }
        expect(requisicao.url.path, '/pontos');
        return http.Response('[]', 200);
      }),
    );
  });
}
