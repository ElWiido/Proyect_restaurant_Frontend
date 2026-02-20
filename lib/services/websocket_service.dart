import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';

class WebSocketService {
  IO.Socket? socket;
  Function(dynamic)? _onMessage;

  void connect(Function(dynamic) onMessage) {
    _onMessage = onMessage;
    //usa la misma URL que ApiService — un solo lugar para cambiar
    final url = ApiService().baseUrl;
    print('🔌 Conectando WebSocket a: $url');
    _conectar(url);
  }

  void _conectar(String url) {
    try {
      socket = IO.io(url, <String, dynamic>{
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
        print('✅ WebSocket conectado');
        socket!.emit('join_mesas');
        socket!.emit('join_pagos');
      });

      socket!.onReconnect((_) {
        print('🔁 Reconectado');
        socket!.emit('join_mesas');
        socket!.emit('join_pagos');
      });

      socket!.on('mesa_actualizada', (data) {
        _onMessage?.call({'event': 'mesa_actualizada', 'mesa': data});
      });

      socket!.on('pago_completado', (data) {
        _onMessage?.call({'event': 'pago_completado', 'pago': data});
      });

      socket!.on('disconnect', (_) => print('❌ WebSocket desconectado'));
      socket!.on('connect_error', (e) => print('⚠️ Error conexión: $e'));
      socket!.on('error', (e) => print('⚠️ Error WebSocket: $e'));
    } catch (e) {
      print('❌ Error conectando WebSocket: $e');
    }
  }

  void disconnect() {
    socket?.disconnect();
    socket = null;
  }
}
