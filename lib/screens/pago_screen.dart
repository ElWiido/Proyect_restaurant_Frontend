import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'agregar_producto_screen.dart';

final formatoPesos = NumberFormat.currency(
  locale: 'es_CO',
  symbol: '\$',
  decimalDigits: 0,
  customPattern: '\u00A4 #,##0',
);

// ── Colores centralizados ────────────────────────────────────────────────────
const _primary = Color(0xFFB25A45);
const _bg = Color(0xFFF7F7F7);
const _cardBg = Colors.white;
const _textDark = Color(0xFF1A1A1A);
const _textMuted = Color(0xFF8A8A8A);

class PagoScreen extends StatefulWidget {
  final int idMesa;
  final String numeroMesa;
  final String rol;

  const PagoScreen({
    super.key,
    required this.idMesa,
    required this.numeroMesa,
    required this.rol,
  });

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  final ApiService apiService = ApiService();

  Map<String, dynamic>? pedido;
  bool isLoading = true;
  bool isProcesando = false;
  String metodoPago = 'efectivo';

  // RENDIMIENTO: controller único, no se recrea en cada build
  final TextEditingController montoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarPedido();
  }

  @override
  void dispose() {
    montoController.dispose();
    super.dispose();
  }

  ///cálculo extraído, evita re-parsearlo en cada widget build
  double _calcularTotal() {
    final detalles = pedido?['detalles'] as List?;
    if (detalles == null) return 0.0;

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

  String _formatMonto(double v) => NumberFormat('#,###', 'es_CO').format(v);

  // ── API calls ────────────────────────────────────────────────────────────────

  Future<void> _cargarPedido() async {
    try {
      final data = await apiService.getPedidoPorMesa(widget.idMesa);
      if (!mounted) return;
      setState(() {
        pedido = data;
        isLoading = false;
        if (widget.rol == 'administrador') {
          montoController.text = _formatMonto(_calcularTotal());
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack('Error al cargar pedido: $e', isError: true);
    }
  }

  Future<void> _editarPrecioDetalle(Map<String, dynamic> detalle) async {
    final ctrl = TextEditingController(
      text:
          detalle['precio_unitario']?.toString() ??
          detalle['producto']?['precio']?.toString() ??
          '0',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Editar precio unitario',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onTap: () => ctrl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: ctrl.text.length,
          ),
          decoration: InputDecoration(
            labelText: 'Nuevo precio',
            prefixText: '\$ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final nuevoPrecio = double.tryParse(ctrl.text.replaceAll(',', '.'));
    if (nuevoPrecio == null || nuevoPrecio <= 0) return;

    try {
      await apiService.actualizarDetallePedido(
        detalle['idDetalle'] as int,
        precioUnitario: nuevoPrecio,
      );
      _cargarPedido();
    } catch (e) {
      _showSnack('Error al actualizar precio: $e', isError: true);
    }
  }

  Future<void> _procesarPago() async {
    if (widget.rol != 'administrador') {
      _showSnack('Solo administradores pueden procesar pagos', isError: true);
      return;
    }
    if (pedido == null) return;

    setState(() => isProcesando = true);

    try {
      double monto = _calcularTotal();
      if (widget.rol == 'administrador') {
        final parsed = double.tryParse(
          montoController.text
              .replaceAll('\$', '')
              .replaceAll('.', '')
              .replaceAll(',', '.')
              .trim(),
        );
        if (parsed != null && parsed > 0) monto = parsed;
      }

      final resultado = await apiService.crearPago({
        'id_pedido': pedido!['idPedido'] ?? pedido!['id_pedido'],
        'metodo_pago': metodoPago,
        'monto': monto,
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pago exitoso',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Monto', '\$${resultado['monto']}'),
              const SizedBox(height: 4),
              _infoRow('Método', resultado['metodo_pago']),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.table_restaurant, color: Colors.green, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Mesa ahora libre',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error al procesar pago: $e', isError: true);
    } finally {
      if (mounted) setState(() => isProcesando = false);
    }
  }

  // ── Utilidades UI ────────────────────────────────────────────────────────────

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

  Widget _infoRow(String label, String value) => Row(
    children: [
      Text(
        '$label: ',
        style: const TextStyle(color: _textMuted, fontWeight: FontWeight.w500),
      ),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700, color: _textDark),
      ),
    ],
  );

  static const _metodos = [
    {
      'valor': 'efectivo',
      'label': 'Efectivo',
      'icono': Icons.payments_outlined,
    },
    {
      'valor': 'transferencia',
      'label': 'Transferencia',
      'icono': Icons.swap_horiz,
    },
    {'valor': 'anotar', 'label': 'Anotar', 'icono': Icons.edit_note},
  ];

  Widget _buildMetodosPago() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Método de pago',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _metodos.map((m) {
            final selected = metodoPago == m['valor'];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => metodoPago = m['valor'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? _primary : _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _primary : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        m['icono'] as IconData,
                        color: selected ? Colors.white : _textMuted,
                        size: 26,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m['label'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // Banner informativo si selecciona "Anotar"
        if (metodoPago == 'anotar') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El pedido quedará registrado como pendiente de pago.',
                    style: TextStyle(fontSize: 16, color: _textDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Detalle de producto ──────────────────────────────────────────────────────

  /// ✅ RENDIMIENTO: extraído como método, evita lambdas pesadas en el build
  Widget _buildDetalleItem(Map<String, dynamic> detalle) {
    final puedeEditar = widget.rol == 'administrador' || widget.rol == 'mesero';
    final producto = detalle['producto'];
    final precioRaw = detalle['precioUnitario'] ?? producto?['precio'];
    final cantidadRaw = detalle['cantidad'] ?? 1;

    final precio = precioRaw is num
        ? precioRaw.toDouble()
        : double.tryParse(precioRaw?.toString() ?? '') ?? 0.0;

    final cantidad = cantidadRaw is int
        ? cantidadRaw
        : int.tryParse(cantidadRaw.toString()) ?? 1;

    final subtotal = precio * cantidad;
    final nota = detalle['detalle']?.toString() ?? '';

    return GestureDetector(
      onTap: puedeEditar ? () => _editarPrecioDetalle(detalle) : null,
      child: Container(
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
            // Cantidad badge
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
            // Nombre + nota
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto?['nombre'] ?? 'Producto',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatoPesos.format(precio),
                    style: const TextStyle(fontSize: 17, color: _textMuted),
                  ),
                  if (nota.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 16,
                          color: _textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            nota,
                            style: const TextStyle(
                              fontSize: 16,
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
            // Subtotal + editar hint
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatoPesos.format(subtotal),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
                if (puedeEditar)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 13,
                      color: _textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final esAdmin = widget.rol == 'administrador';

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
              'Mesa ${widget.numeroMesa}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const Text(
              'Detalle del pedido',
              style: TextStyle(fontSize: 15, color: _textMuted),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : pedido == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: _textMuted.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay pedido para esta mesa',
                    style: TextStyle(fontSize: 16, color: _textMuted),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ── Lista principal ──────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      // Cabecera pedido
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pedido #${pedido!['idPedido'] ?? pedido!['id_pedido']}',
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    color: _textDark,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            _estadoBadge(pedido!['estado']?.toString() ?? ''),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Botón añadir productos (solo si pendiente)
                      if (pedido!['estado'] == 'pendiente') ...[
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text(
                              'Añadir productos',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AgregarProductoScreen(
                                    idPedido:
                                        pedido!['idPedido'] ??
                                        pedido!['id_pedido'],
                                    idMesa: widget.idMesa,
                                    numeroMesa: widget.numeroMesa,
                                  ),
                                ),
                              );
                              _cargarPedido();
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Label productos
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'PRODUCTOS',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: _textMuted,
                          ),
                        ),
                      ),

                      // ✅ RENDIMIENTO: usa método en vez de lambda anidada
                      ...((pedido!['detalles'] ?? []) as List).map(
                        (d) => _buildDetalleItem(d as Map<String, dynamic>),
                      ),

                      const SizedBox(height: 4),

                      // Total
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            const Spacer(),
                            esAdmin
                                ? SizedBox(
                                    width: 150,
                                    child: TextField(
                                      controller: montoController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[\d,\.]'),
                                        ),
                                      ],
                                      textAlign: TextAlign.right,
                                      decoration: InputDecoration(
                                        prefixText: '\$ ',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: _primary.withOpacity(0.4),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: _primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: _primary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    formatoPesos.format(_calcularTotal()),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: _primary,
                                    ),
                                  ),
                          ],
                        ),
                      ),

                      // Métodos de pago (solo admin)
                      if (esAdmin) ...[
                        const SizedBox(height: 20),
                        _buildMetodosPago(),
                      ],

                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // ── Botón inferior ───────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: esAdmin
                      ? SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: isProcesando ? null : _procesarPago,
                            child: isProcesando
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        metodoPago == 'anotar'
                                            ? Icons.edit_note
                                            : Icons.check_circle_outline,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        metodoPago == 'anotar'
                                            ? 'Anotar Pedido'
                                            : 'Procesar Pago',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: Colors.orange,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'No puedes procesar pagos',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _estadoBadge(String estado) {
    final isPendiente = estado == 'pendiente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPendiente
            ? Colors.orange.withOpacity(0.12)
            : Colors.green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isPendiente ? Colors.orange[800] : Colors.green[800],
        ),
      ),
    );
  }
}
