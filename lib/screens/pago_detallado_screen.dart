import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

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

class DetallePedidoScreen extends StatefulWidget {
  final int idPedido;
  final String mesa;
  final String usuario;

  const DetallePedidoScreen({
    super.key,
    required this.idPedido,
    required this.mesa,
    required this.usuario,
  });

  @override
  State<DetallePedidoScreen> createState() => _DetallePedidoScreenState();
}

class _DetallePedidoScreenState extends State<DetallePedidoScreen> {
  final ApiService apiService = ApiService();
  late Future<Map<String, dynamic>> pedidoFuture;

  @override
  void initState() {
    super.initState();
    pedidoFuture = apiService.getPedidoById(widget.idPedido);
  }

  double _calcularTotal(List detalles) {
    return detalles.fold(0.0, (total, d) {
      final precioRaw = d['precioUnitario'] ?? d['producto']?['precio'];
      final cantidadRaw = d['cantidad'] ?? 1;
      // ✅ precioUnitario llega como String "21000.00"
      final precio = double.tryParse(precioRaw?.toString() ?? '') ?? 0.0;
      final cantidad = cantidadRaw is int
          ? cantidadRaw
          : int.tryParse(cantidadRaw.toString()) ?? 1;
      return total + precio * cantidad;
    });
  }

  Widget _buildDetalleItem(Map<String, dynamic> detalle) {
    final producto = detalle['producto'] as Map<String, dynamic>?;
    // ✅ precioUnitario viene como String "21000.00" desde el backend
    final precioRaw = detalle['precioUnitario'] ?? producto?['precio'];
    final cantidadRaw = detalle['cantidad'] ?? 1;
    final precio = double.tryParse(precioRaw?.toString() ?? '') ?? 0.0;
    final cantidad = cantidadRaw is int
        ? cantidadRaw
        : int.tryParse(cantidadRaw.toString()) ?? 1;
    final subtotal = precio * cantidad;
    final nota = detalle['detalle']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge cantidad
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                'x$cantidad',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Nombre + precio + nota
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto?['nombre'] ?? 'Producto',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatoPesos.format(precio),
                  style: const TextStyle(fontSize: 15, color: _textMuted),
                ),
                if (nota.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.sticky_note_2_outlined,
                        size: 14,
                        color: _textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          nota,
                          style: const TextStyle(
                            fontSize: 14,
                            color: _textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Subtotal
          Text(
            _formatoPesos.format(subtotal),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }

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
        title: Column(
          children: [
            Text(
              'Mesa ${widget.mesa}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            Text(
              widget.usuario,
              style: const TextStyle(fontSize: 13, color: _textMuted),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: pedidoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: _textMuted),
              ),
            );
          }

          final pedido = snapshot.data!;
          final detalles = (pedido['detalles'] ?? []) as List;
          final total = _calcularTotal(detalles);
          final estado = pedido['estado']?.toString() ?? '';
          final isPendiente = estado == 'pendiente';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Cabecera
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Pedido #${pedido['idPedido'] ?? widget.idPedido}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPendiente
                            ? Colors.orange.withOpacity(0.12)
                            : Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        estado.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isPendiente
                              ? Colors.orange[800]
                              : Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'PRODUCTOS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 8),

              // Lista de productos
              ...detalles.map(
                (d) => _buildDetalleItem(d as Map<String, dynamic>),
              ),

              const SizedBox(height: 8),

              // Total
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _formatoPesos.format(total),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
