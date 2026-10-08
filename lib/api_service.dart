import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  // 10.0.2.2 acessa o computador a partir do emulador Android.
  // No celular físico, informe o IP do computador com --dart-define=API_URL=...
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static String? token;

  static Map<String, String> get _cabecalhos => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Future<dynamic> obter(String caminho) async {
    return _lerResposta(
      http.get(Uri.parse('$baseUrl$caminho'), headers: _cabecalhos),
    );
  }

  static Future<dynamic> enviar(
    String caminho,
    Map<String, dynamic> dados,
  ) async {
    return _lerResposta(
      http.post(
        Uri.parse('$baseUrl$caminho'),
        headers: _cabecalhos,
        body: jsonEncode(dados),
      ),
    );
  }

  // Todas as telas recebem a mensagem de erro enviada pela API.
  static Future<dynamic> _lerResposta(Future<http.Response> requisicao) async {
    try {
      final resposta = await requisicao.timeout(const Duration(seconds: 15));
      if (resposta.statusCode >= 400) {
        final dados = resposta.body.isEmpty
            ? null
            : jsonDecode(utf8.decode(resposta.bodyBytes));
        throw Exception(
          dados is Map && dados['erro'] != null
              ? dados['erro']
              : 'Não foi possível concluir a operação (${resposta.statusCode}).',
        );
      }
      return jsonDecode(utf8.decode(resposta.bodyBytes));
    } on TimeoutException {
      throw Exception('A API demorou para responder. Tente novamente.');
    } on SocketException {
      throw Exception('Não foi possível conectar. Verifique a API e seu IP.');
    } on http.ClientException {
      throw Exception('Não foi possível conectar. Verifique a API e seu IP.');
    } on FormatException {
      throw Exception('A API enviou uma resposta inválida.');
    }
  }
}
