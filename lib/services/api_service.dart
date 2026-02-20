import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

class ApiService {
  late String baseUrl;
  final http.Client _client = http.Client();

  // ── ENTORNOS ─────────────────────────────────────────────────────────────────

  //RESTAURANTE (IP local)
  //static const String _restaurante = 'http://192.168.0.101:3333';

  //CASA — dispositivo físico
  static const String _casa = 'http://192.168.0.2:3333';

  //CASA — emulador Android
  static const String _emulador = 'http://10.0.2.2:3333';

  //ACTIVO — cambia esto según dónde estés:
  // -- RESTAURANTE --
  //static const String _entornoActivo = _restaurante;

  //CASA (elige automáticamente físico o emulador) --
  static const String _entornoActivo = _autoDetectar;

  // -- PRODUCCIÓN --
  // static const String _entornoActivo = _produccion;

  // Constante especial para modo auto (casa)
  static const String _autoDetectar = 'auto';

  // ─────────────────────────────────────────────────────────────────────────────

  ApiService() {
    if (Platform.isAndroid) {
      baseUrl = _entornoActivo == 'auto' ? _detectarUrl() : _entornoActivo;
    } else {
      baseUrl = 'http://localhost:3333';
    }
  }

  //Solo se usa cuando _entornoActivo = _autoDetectar (modo casa)
  String _detectarUrl() {
    try {
      final hostname = Platform.localHostname.toLowerCase();
      final isEmulador =
          hostname.contains('generic') ||
          hostname.contains('sdk') ||
          hostname.contains('emulator');
      final url = isEmulador ? _emulador : _casa;
      print('Detectado: ${isEmulador ? "emulador" : "físico"} → $url');
      return url;
    } catch (_) {
      return _casa;
    }
  }

  // ── Auth ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String usuario, String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/login'),
            headers: _headers,
            body: jsonEncode({
              'nombre_usuario': usuario,
              'contrasena': password,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Credenciales incorrectas');
    } catch (e) {
      print('❌ Error en login: $e');
      rethrow;
    }
  }

  // ── Mesas ─────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getMesas() async {
    final response = await _get('/mesas');
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['data'] != null) {
      return data['data'] as List<dynamic>;
    }
    throw Exception('Estructura de respuesta inválida');
  }

  // ── Productos ─────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getProductos() async {
    final response = await _get('/productos');
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['data'] != null) {
      return data['data'] as List<dynamic>;
    }
    return data as List<dynamic>;
  }

  // ── Pedidos ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> crearPedido(Map<String, dynamic> payload) async {
    final response = await _post('/pedidos', payload);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getPedidoPorMesa(int idMesa) async {
    final response = await _get('/pedidos/mesa/$idMesa');
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getPedidoById(int id) async {
    final response = await _get('/pedido/$id');
    return jsonDecode(response.body);
  }

  Future<void> agregarProductosLote(
    int idPedido,
    List<Map<String, dynamic>> detalles,
  ) async {
    final payload = {
      "productos": detalles
          .map(
            (d) => {
              "id_producto": d['id_producto'],
              "cantidad": d['cantidad'],
              "detalle": d['detalle'] ?? "",
            },
          )
          .toList(),
    };
    final response = await _post('/pedidos/$idPedido/productos', payload);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error agregando lote: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> actualizarDetallePedido(
    int idDetalle, {
    double? precioUnitario,
    int? cantidad,
    String? detalle,
  }) async {
    final body = <String, dynamic>{};
    if (precioUnitario != null) body['precio_unitario'] = precioUnitario;
    if (cantidad != null) body['cantidad'] = cantidad;
    if (detalle != null) body['detalle'] = detalle;

    final response = await _put('/detalle_pedidos/$idDetalle', body);
    return jsonDecode(response.body);
  }

  // ── Pagos ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> crearPago(Map<String, dynamic> payload) async {
    final response = await _post('/pagos', payload);
    return jsonDecode(response.body);
  }

  Future<double> getTotalPagos(String fecha) async {
    final response = await _get('/pagos/date/$fecha');
    final data = jsonDecode(response.body);
    return (data['total'] ?? 0).toDouble();
  }

  Future<List<Map<String, dynamic>>> getPagosByDate(String fecha) async {
    final response = await _get('/pagos/all/$fecha');
    final List<dynamic> data = jsonDecode(response.body);
    return data.cast<Map<String, dynamic>>();
  }

  // ── HTTP helpers ──────────────────────────────────────────────────────────────

  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<http.Response> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      _checkStatus(response);
      return response;
    } on TimeoutException {
      print('⚠️ Timeout en GET $path, reintentando...');
      final response = await _client
          .get(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      _checkStatus(response);
      return response;
    } catch (e) {
      print('❌ GET $path → $e');
      rethrow;
    }
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      _checkStatus(response);
      return response;
    } on TimeoutException {
      print('⚠️ Timeout en POST $path, reintentando...');
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      _checkStatus(response);
      return response;
    } catch (e) {
      print('❌ POST $path → $e');
      rethrow;
    }
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .put(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      _checkStatus(response);
      return response;
    } on TimeoutException {
      print('⚠️ Timeout en PUT $path, reintentando...');
      final response = await _client
          .put(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      _checkStatus(response);
      return response;
    } catch (e) {
      print('❌ PUT $path → $e');
      rethrow;
    }
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }
}
