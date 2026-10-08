import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_service.dart';

class HistoricoPage extends StatefulWidget {
  const HistoricoPage({super.key});

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  List<dynamic> _pontos = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarPontos();
  }

  Future<void> _carregarPontos() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      // O token identifica o funcionário; a API só retorna os pontos dele.
      final pontos = await ApiService.obter('/pontos');
      if (mounted) setState(() => _pontos = pontos);
    } catch (erro) {
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
      appBar: AppBar(
        title: const Text('Histórico de ponto'),
        actions: [
          IconButton(
            onPressed: _carregando ? null : _carregarPontos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar histórico',
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? Center(child: Text(_erro!))
          : _pontos.isEmpty
          ? const Center(child: Text('Nenhum ponto registrado.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pontos.length,
              itemBuilder: (context, index) {
                final ponto = _pontos[index];
                // A API salva em UTC; a tela mostra a hora local do aparelho.
                final data = DateTime.parse(ponto['dataHora']).toLocal();
                return Card(
                  child: ListTile(
                    title: Text(
                      '${ponto['tipo']} - ${DateFormat('dd/MM/yyyy HH:mm:ss').format(data)}',
                    ),
                    subtitle: Text(
                      '${ponto['localTrabalho']}\n'
                      'Latitude: ${ponto['latitude']}\n'
                      'Longitude: ${ponto['longitude']}\n'
                      'Distância: ${(ponto['distancia'] as num).toStringAsFixed(1)} m',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
