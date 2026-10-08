import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api_service.dart';
import '../biometria.dart';
import 'historico_page.dart';
import 'login_page.dart';

class PontoPage extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const PontoPage({super.key, required this.usuario});

  @override
  State<PontoPage> createState() => _PontoPageState();
}

class _PontoPageState extends State<PontoPage> {
  Map<String, dynamic>? _local;
  double? _distancia;
  String _tipo = 'Entrada';
  String _mensagem = 'Verifique sua localização antes de registrar o ponto.';
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarLocal();
  }

  Future<void> _carregarLocal() async {
    setState(() => _carregando = true);
    try {
      final local = await ApiService.obter('/local-trabalho');
      if (mounted) setState(() => _local = local);
    } catch (erro) {
      if (mounted) {
        setState(
          () => _mensagem = erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<Position> _obterPosicao() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Ative o GPS do aparelho.');
    }
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      throw Exception(
        'Permita o acesso à localização nas configurações do aparelho.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<void> _verificarLocalizacao({bool registrar = false}) async {
    setState(() {
      _carregando = true;
      _distancia = null;
    });
    try {
      // Consulta o GPS novamente a cada registro para não usar uma posição antiga.
      final posicao = await _obterPosicao();
      if (!mounted) return;
      final distancia = Geolocator.distanceBetween(
        posicao.latitude,
        posicao.longitude,
        (_local!['latitude'] as num).toDouble(),
        (_local!['longitude'] as num).toDouble(),
      );
      setState(() => _distancia = distancia);
      if (distancia > 100) {
        throw Exception('Você está fora do limite de 100 metros do trabalho.');
      }
      if (registrar) {
        await ApiService.enviar('/pontos', {
          'tipo': _tipo,
          'latitude': posicao.latitude,
          'longitude': posicao.longitude,
        });
      }
      if (mounted) {
        setState(() {
          _mensagem = registrar
              ? '$_tipo registrada com sucesso!'
              : 'Você está no local permitido para registrar o ponto.';
        });
      }
    } catch (erro) {
      if (mounted) {
        setState(
          () => _mensagem = erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _sair() async {
    setState(() => _carregando = true);
    try {
      await ApiService.enviar('/logout', {});
    } catch (_) {
      // Mesmo sem rede, o logout deve apagar o acesso salvo neste aparelho.
    }
    try {
      await Biometria.armazenamento.delete(key: 'token');
      ApiService.token = null;
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _mensagem = 'Não foi possível limpar a sessão. Tente sair novamente.';
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar ponto'),
        actions: [
          IconButton(
            onPressed: _carregando ? null : _sair,
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Olá, ${widget.usuario['nome']}!'),
          Text('NIF: ${widget.usuario['nif']}'),
          const SizedBox(height: 16),
          if (_local != null) Text('Local de trabalho: ${_local!['nome']}'),
          const Text('Distância máxima permitida: 100 metros.'),
          if (_distancia != null)
            Text('Sua distância: ${_distancia!.toStringAsFixed(1)} metros.'),
          const SizedBox(height: 16),
          Text(_mensagem),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo de ponto'),
            items: const [
              DropdownMenuItem(value: 'Entrada', child: Text('Entrada')),
              DropdownMenuItem(value: 'Saída', child: Text('Saída')),
            ],
            onChanged: _carregando
                ? null
                : (valor) => setState(() => _tipo = valor!),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _carregando
                ? null
                : _local == null
                ? _carregarLocal
                : () => _verificarLocalizacao(),
            icon: const Icon(Icons.my_location),
            label: Text(
              _local == null
                  ? 'Carregar local de trabalho'
                  : 'Verificar localização',
            ),
          ),
          ElevatedButton(
            onPressed: _carregando || _local == null
                ? null
                : () => _verificarLocalizacao(registrar: true),
            child: Text(_carregando ? 'Aguarde...' : 'Registrar ponto'),
          ),
          TextButton.icon(
            onPressed: _carregando
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoricoPage()),
                  ),
            icon: const Icon(Icons.history),
            label: const Text('Ver histórico'),
          ),
        ],
      ),
    );
  }
}
