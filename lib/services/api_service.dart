import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  late String baseUrl;
  final http.Client _client = http.Client();

  ApiService() {
    if (Platform.isAndroid) {
      // Intenta primero con IP real, si falla usa emulador
      baseUrl = 'http://192.168.0.2:3333';
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      baseUrl = 'http://localhost:3333';
    } else if (Platform.isIOS) {
      baseUrl = 'http://localhost:3333';
    }
  }

  Future<Map<String, dynamic>> login(String usuario, String password) async {
    List<String> urls = Platform.isAndroid
        ? ['http://192.168.0.2:3333', 'http://10.0.2.2:3333']
        : [baseUrl];

    Exception? lastError;

    for (String url in urls) {
      try {
        final response = await _client
            .post(
              Uri.parse('$url/login'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'nombre_usuario': usuario,
                'contrasena': password,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          baseUrl = url;
          print('Conectado a: $url');
          return jsonDecode(response.body);
        }
      } catch (e) {
        print('❌ Intento fallido en $url: $e');
        lastError = Exception('Error en $url: $e');
      }
    }
    throw lastError ?? Exception('No se pudo conectar al servidor');
  }

  Future<List<dynamic>> getMesas() async {
    final url = Uri.parse('$baseUrl/mesas');
    try {
      final response = await _client
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic> && data['data'] != null) {
          return data['data'] as List<dynamic>;
        }

        throw Exception('Estructura de respuesta inválida');
      } else {
        throw Exception('Error al cargar mesas: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getMesas: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getProductos() async {
    final url = Uri.parse('$baseUrl/productos');
    try {
      final response = await _client
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['data'] != null) {
          return data['data'] as List<dynamic>;
        }
        return data as List<dynamic>;
      } else {
        throw Exception('Error al cargar productos');
      }
    } catch (e) {
      print('Error en getProductos: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearPedido(Map<String, dynamic> payload) async {
    final url = Uri.parse('$baseUrl/pedidos');
    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al crear pedido: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en crearPedido: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPedidoPorMesa(int idMesa) async {
    final url = Uri.parse('$baseUrl/pedidos/mesa/$idMesa');
    try {
      final response = await _client
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al obtener pedido: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getPedidoPorMesa: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearPago(Map<String, dynamic> payload) async {
    final url = Uri.parse('$baseUrl/pagos');
    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al crear pago: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en crearPago: $e');
      rethrow;
    }
  }

  Future<double> getTotalPagos(String fecha) async {
    final response = await http.get(Uri.parse('$baseUrl/pagos/date/$fecha'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['total'] ?? 0).toDouble();
    } else {
      throw Exception('Error al obtener total de pagos');
    }
  }

  Future<Map<String, dynamic>> agregarProductoAPedido(
    int idPedido, {
    required int idProducto,
    required int cantidad,
    String? detalle,
  }) async {
    final url = Uri.parse('$baseUrl/pedidos/$idPedido/productos');

    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'id_producto': idProducto,
              'cantidad': cantidad,
              'detalle': detalle ?? '',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Error al agregar producto: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error en agregarProductoAPedido: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPagosByDate(String fecha) async {
    final url = Uri.parse('$baseUrl/pagos/all/$fecha');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al cargar los pagos: ${response.body}');
    }
  }
}
