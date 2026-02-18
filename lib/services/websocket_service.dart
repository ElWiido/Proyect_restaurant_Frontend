import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:io';

class WebSocketService {
  IO.Socket? socket;
  Function(dynamic)? _onMessage;
  late String _socketUrl;

  void connect(Function(dynamic) onMessage) {
    _onMessage = onMessage;

    // Lista de URLs a intentar (celular primero, emulador después)
    List<String> urls = Platform.isAndroid
        ? ['http://192.168.0.2:3333', 'http://10.0.2.2:3333']
        : ['http://localhost:3333'];

    _connectWithRetry(urls, 0);
  }

  void _connectWithRetry(List<String> urls, int index) {
    if (index >= urls.length) {
      print('No se pudo conectar a ningún servidor');
      return;
    }

    _socketUrl = urls[index];
    print('Conectando a WebSocket en: $_socketUrl');

    try {
      socket = IO.io(_socketUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'reconnectionAttempts': 99999,
        'secure': false,
        'rejectUnauthorized': false,
      });

      socket!.on('connect', (_) {
        print('WebSocket conectado');
        socket!.emit('join_mesas');
        socket!.emit('join_pagos');
      });

      socket!.onReconnect((_) {
        print('Reconectado');

        socket!.emit('join_mesas');
        socket!.emit('join_pagos');
      });

      socket!.on('mesa_actualizada', (data) {
        print('Evento recibido - mesa_actualizada: $data');
        _onMessage?.call({'event': 'mesa_actualizada', 'mesa': data});
      });

      socket!.on('pago_completado', (data) {
        print('Evento recibido - pago_completado: $data');
        _onMessage?.call({'event': 'pago_completado', 'pago': data});
      });

      socket!.on('disconnect', (_) {
        print('WebSocket desconectado');
      });

      socket!.on('error', (error) {
        print('⚠️ Error WebSocket: $error');
        _tryNextUrl(urls, index);
      });

      socket!.on('connect_error', (error) {
        print('Error de conexión en $_socketUrl: $error');
        _tryNextUrl(urls, index);
      });
    } catch (e) {
      print('Error conectando WebSocket: $e');
      _tryNextUrl(urls, index);
    }
  }

  void _tryNextUrl(List<String> urls, int currentIndex) {
    Future.delayed(const Duration(seconds: 2), () {
      _connectWithRetry(urls, currentIndex + 1);
    });
  }

  void disconnect() {
    socket?.disconnect();
  }
}
