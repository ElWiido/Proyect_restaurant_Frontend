import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'package:intl/intl.dart';
import 'agregar_producto_screen.dart';
import 'pago_screen.dart';

const _primary = Color(0xFFB25A45);
const _bg = Color(0xFFF7F7F7);
const _cardBg = Colors.white;
const _textDark = Color(0xFF1A1A1A);
const _textMuted = Color(0xFF8A8A8A);

final _formatoPesos = NumberFormat.currency(
  locale: 'es_CO',
  symbol: '\$',
  decimalDigits: 0,
  customPattern: '\u00A4 #,##0',
);

class DomicilioScreen extends StatefulWidget {
  final int idMesa;
  final String rol;

  const DomicilioScreen({super.key, required this.idMesa, required this.rol});

  @override
  State<DomicilioScreen> createState() => _DomicilioScreenState();
}

class _DomicilioScreenState extends State<DomicilioScreen> {
  final ApiService apiService = ApiService();
  List<dynamic> domiciliosPendientes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDomicilios();
  }

  Future<void> _cargarDomicilios() async {
    setState(() => isLoading = true);
    try {
      final data = await apiService.getPedidosPendientesPorMesa(widget.idMesa);
      if (!mounted) return;
      setState(() {
        domiciliosPendientes = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack('Error al cargar domicilios: $e', isError: true);
    }
  }

  double _calcularTotalPedido(Map<String, dynamic> pedido) {
    final detalles = pedido['detalles'] as List? ?? [];
    return detalles.fold(0.0, (total, detalle) {
      final precioRaw =
          detalle['precioUnitario'] ?? detalle['producto']?['precio'];
      final cantidadRaw = detalle['cantidad'] ?? 1;
      final precio = precioRaw is num
          ? precioRaw.toDouble()
          : double.tryParse(precioRaw?.toString() ?? '') ?? 0.0;
      final cantidad = cantidadRaw is int
          ? cantidadRaw
          : int.tryParse(cantidadRaw.toString()) ?? 1;
      return total + precio * cantidad;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[400] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Nuevo domicilio ───────────────────────────────────────────────────────

  Future<void> _nuevoDomicilio() async {
    final sesion = await SessionManager.getUser();
    final idUsuario = sesion?['id_usuario'] ?? sesion?['idUsuario'];

    if (idUsuario == null) {
      _showSnack('Error: sesión no encontrada', isError: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarProductoScreen(
          idPedido: -1,
          idMesa: widget.idMesa,
          numeroMesa: 'Domicilio',
          esDomicilioNuevo: true,
          idUsuario: idUsuario is int
              ? idUsuario
              : int.parse(idUsuario.toString()),
        ),
      ),
    );
    _cargarDomicilios();
  }

  // ── Parsea info del cliente desde el detalle ──────────────────────────────

  Map<String, String> _parsearInfoCliente(Map<String, dynamic> pedido) {
    final detalles = pedido['detalles'] as List? ?? [];
    if (detalles.isEmpty) return {};

    final primerDetalle = detalles.first['detalle']?.toString() ?? '';
    String telefono = '';
    String direccion = '';

    if (primerDetalle.contains('Tel:') || primerDetalle.contains('Dir:')) {
      final partes = primerDetalle.split('|');
      for (final p in partes) {
        final limpio = p.trim();
        if (limpio.startsWith('Tel:')) {
          telefono = limpio.replaceFirst('Tel:', '').trim();
        }
        if (limpio.startsWith('Dir:')) {
          direccion = limpio.replaceFirst('Dir:', '').trim();
        }
      }
    }

    return {'telefono': telefono, 'direccion': direccion};
  }

  // ── Card de cada domicilio pendiente ─────────────────────────────────────

  Widget _buildDomicilioCard(Map<String, dynamic> pedido) {
    final idPedido = pedido['idPedido'] ?? pedido['id_pedido'];
    final total = _calcularTotalPedido(pedido);
    final detalles = pedido['detalles'] as List? ?? [];
    final info = _parsearInfoCliente(pedido);
    final telefono = info['telefono'] ?? '';
    final direccion = info['direccion'] ?? '';

    // Parsea la hora del pedido
    final fechaRaw =
        pedido['fecha'] ?? pedido['creado'] ?? pedido['created_at'];
    String horaTexto = '';
    if (fechaRaw != null) {
      try {
        final fecha = DateTime.parse(fechaRaw.toString()).toLocal();
        horaTexto =
            '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delivery_dining,
                    color: Colors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dirección primero (más prominente)
                      if (direccion.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: _textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                direccion,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      // Teléfono abajo (secundario)
                      if (telefono.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: _textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              telefono,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (telefono.isEmpty && direccion.isEmpty)
                        const Text(
                          'Sin datos de contacto',
                          style: TextStyle(fontSize: 15, color: _textMuted),
                        ),
                    ],
                  ),
                ),
                // Hora en vez del id
                if (horaTexto.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      horaTexto,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Productos
                ...detalles.map((d) {
                  final prod = d['producto'];
                  final cant = d['cantidad'] ?? 1;
                  final precioRaw = d['precioUnitario'] ?? prod?['precio'] ?? 0;
                  final precio = precioRaw is num
                      ? precioRaw.toDouble()
                      : double.tryParse(precioRaw.toString()) ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'x$cant',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            prod?['nombre'] ?? 'Producto',
                            style: const TextStyle(
                              fontSize: 15,
                              color: _textDark,
                            ),
                          ),
                        ),
                        Text(
                          _formatoPesos.format(precio * cant),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const Divider(height: 20),

                // Total
                Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatoPesos.format(total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Botones acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Añadir'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: const BorderSide(color: _primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AgregarProductoScreen(
                                idPedido: idPedido,
                                idMesa: widget.idMesa,
                                numeroMesa: 'Domicilio',
                              ),
                            ),
                          );
                          _cargarDomicilios();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('Cobrar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PagoScreen(
                                idMesa: widget.idMesa,
                                idPedido: idPedido,
                                numeroMesa: 'Domicilio',
                                rol: widget.rol,
                              ),
                            ),
                          );
                          _cargarDomicilios();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withOpacity(0.15)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: _textDark,
            ),
          ),
        ),
        title: const Column(
          children: [
            Text(
              'Domicilios',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            Text(
              'Pedidos pendientes',
              style: TextStyle(fontSize: 14, color: _textMuted),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : RefreshIndicator(
              color: _primary,
              onRefresh: _cargarDomicilios,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  // Botón tomar nuevo pedido
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delivery_dining, size: 22),
                      label: const Text(
                        'Tomar pedido a domicilio',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _nuevoDomicilio,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Lista pendientes
                  if (domiciliosPendientes.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text(
                          'PENDIENTES',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: _textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${domiciliosPendientes.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...domiciliosPendientes.map(
                      (p) => _buildDomicilioCard(p as Map<String, dynamic>),
                    ),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.delivery_dining_outlined,
                              size: 56,
                              color: _textMuted.withOpacity(0.3),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Sin domicilios pendientes',
                              style: TextStyle(fontSize: 16, color: _textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
