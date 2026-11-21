import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Exceção amigável para falhas na leitura do GPS (Pessoa 3).
class GpsException implements Exception {
  const GpsException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Serviço de Geolocalização - Pessoa 3.
/// Responsável pela leitura única da posição atual (getCurrentPosition)
/// e pelo cálculo de distância entre duas coordenadas.
class GpsService {
  /// Obtém uma leitura única da posição atual do aparelho.
  Future<Position> obterLocalizacaoAtual({
    LocationAccuracy precisao = LocationAccuracy.high,
  }) async {
    final servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) {
      throw const GpsException(
        'Serviço de localização (GPS) está desligado no aparelho.',
      );
    }

    // Verificação defensiva: o fluxo completo de UI de permissões é da Pessoa 2,
    // mas garantimos o pedido/aviso caso este botão seja acionado antes.
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }

    if (permissao == LocationPermission.denied) {
      throw const GpsException(
        'Permissão de localização negada. Conceda acesso para ler o GPS.',
      );
    }

    if (permissao == LocationPermission.deniedForever) {
      throw const GpsException(
        'Permissão negada definitivamente. Ative nas configurações do app.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: precisao,
          timeLimit: const Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      throw const GpsException(
        'Tempo esgotado ao buscar sinal de GPS. Tente novamente.',
      );
    } catch (e) {
      throw GpsException('Não foi possível obter a localização: $e');
    }
  }

  /// Opcional (Pessoa 3): calcula a distância em metros entre dois pontos.
  double calcularDistanciaMetros(Position origem, Position destino) {
    return Geolocator.distanceBetween(
      origem.latitude,
      origem.longitude,
      destino.latitude,
      destino.longitude,
    );
  }

  /// Formata a distância em metros ou quilômetros para exibição na tela.
  String formatarDistancia(double metros) {
    if (metros < 1000) {
      return '${metros.toStringAsFixed(1)} m';
    }
    return '${(metros / 1000).toStringAsFixed(2)} km';
  }
}
