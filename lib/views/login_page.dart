import 'package:flutter/material.dart';

import '../api_service.dart';
import '../biometria.dart';
import 'ponto_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formulario = GlobalKey<FormState>();
  final _identificador = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;
  bool _usarBiometria = false;
  String? _erro;

  @override
  void dispose() {
    _identificador.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar({bool comBiometria = false}) async {
    if (!comBiometria && !_formulario.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      Map<String, dynamic> usuario;
      if (comBiometria) {
        await Biometria.autenticar();
        final salvo = await Biometria.armazenamento.read(key: 'token');
        if (salvo == null) {
          throw Exception(
            'Entre com senha e marque a opção de biometria primeiro.',
          );
        }
        ApiService.token = salvo;
        // A biometria desbloqueia uma sessão que a API ainda precisa validar.
        usuario = await ApiService.obter('/usuario');
      } else {
        final resposta = await ApiService.enviar('/login', {
          'identificador': _identificador.text.trim(),
          'senha': _senha.text,
        });
        usuario = Map<String, dynamic>.from(resposta['usuario']);
        ApiService.token = resposta['token'];

        if (_usarBiometria) {
          await Biometria.autenticar();
          // Guarda apenas o token criptografado, nunca a senha do usuário.
          await Biometria.armazenamento.write(
            key: 'token',
            value: ApiService.token,
          );
        } else {
          await Biometria.armazenamento.delete(key: 'token');
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PontoPage(usuario: usuario)),
      );
    } catch (erro) {
      ApiService.token = null;
      if (mounted) {
        setState(() => _erro = erro.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de ponto')),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Entre com seu NIF ou e-mail e senha.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _identificador,
              enabled: !_carregando,
              decoration: const InputDecoration(labelText: 'NIF ou e-mail'),
              validator: (valor) => valor == null || valor.trim().isEmpty
                  ? 'Informe o NIF ou e-mail.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _senha,
              enabled: !_carregando,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
              validator: (valor) =>
                  valor == null || valor.isEmpty ? 'Informe a senha.' : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permitir login por biometria neste aparelho'),
              value: _usarBiometria,
              onChanged: _carregando
                  ? null
                  : (valor) => setState(() => _usarBiometria = valor!),
            ),
            if (_erro != null)
              Text(_erro!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _carregando ? null : () => _entrar(),
              child: Text(_carregando ? 'Aguarde...' : 'Entrar'),
            ),
            OutlinedButton.icon(
              onPressed: _carregando ? null : () => _entrar(comBiometria: true),
              icon: const Icon(Icons.fingerprint),
              label: const Text('Entrar com biometria'),
            ),
          ],
        ),
      ),
    );
  }
}
