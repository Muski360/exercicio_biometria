import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class Biometria {
  static final _autenticacao = LocalAuthentication();
  static const armazenamento = FlutterSecureStorage();

  static Future<void> autenticar() async {
    try {
      final tipos = await _autenticacao.getAvailableBiometrics();
      if (tipos.isEmpty) {
        throw Exception(
          'Cadastre uma biometria nas configurações do aparelho.',
        );
      }

      // O sistema usa o rosto ou a digital cadastrada, sem aceitar PIN.
      final autorizado = await _autenticacao.authenticate(
        localizedReason:
            'Confirme sua identidade para acessar o registro de ponto',
        biometricOnly: true,
      );
      if (!autorizado) {
        throw Exception('Biometria cancelada ou não reconhecida.');
      }
    } on LocalAuthException {
      throw Exception('Biometria indisponível. Tente entrar com sua senha.');
    }
  }
}
