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

const _primary = Color(0xFFB25A45);
const _bg = Color(0xFFF7F7F7);
const _cardBg = Colors.white;
const _textDark = Color(0xFF1A1A1A);
const _textMuted = Color(0xFF8A8A8A);

class PagoScreen extends StatefulWidget {
  final int idMesa;
  final int idPedido;
  final String numeroMesa;
  final String rol;

  const PagoScreen({
    super.key,
    required this.idMesa,
    required this.idPedido,
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

  final TextEditingController montoController = TextEditingController();
  final FocusNode _montoFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _montoFocus.addListener(() {
      if (!_montoFocus.hasFocus) {
        final parsed = _parseMonto(montoController.text);
        if (parsed != null && parsed > 0) _guardarMontoEditado(parsed);
      }
    });
    _cargarPedido();
  }

  @override
  void dispose() {
    montoController.dispose();
    _montoFocus.dispose();
    super.dispose();
  }

  double _calcularTotal() {
    final detalles = pedido?['detalles'] as List?;
    if (detalles == null) return 0.0;
    return detalles.fold(0.0, (total, d) {
      final precioRaw = d['precioUnitario'] ?? d['producto']?['precio'];
      final cantidadRaw = d['cantidad'] ?? 1;
      final precio = precioRaw is num
          ? precioRaw.toDouble()
          : double.tryParse(precioRaw?.toString() ?? '') ?? 0.0;
      final cantidad = cantidadRaw is int
          ? cantidadRaw
          : int.tryParse(cantidadRaw.toString()) ?? 1;
      return total + precio * cantidad;
    });
  }

  double _montoActual() {
    final montoGuardado = pedido?['montoEditado'] ?? pedido?['monto_editado'];
    if (montoGuardado != null) {
      return montoGuardado is num
          ? montoGuardado.toDouble()
          : double.tryParse(montoGuardado.toString()) ?? _calcularTotal();
    }
    return _calcularTotal();
  }

  double? _parseMonto(String texto) => double.tryParse(
    texto
        .replaceAll(RegExp(r'[^\d,\.]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim(),
  );

  String _formatMonto(double v) => NumberFormat('#,###', 'es_CO').format(v);

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[400] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _cargarPedido() async {
    try {
      final data = await apiService.getPedidoById(widget.idPedido);
      if (!mounted) return;
      setState(() {
        pedido = data;
        isLoading = false;
        if (puedeEditarTotal) {
          montoController.text = _formatMonto(_montoActual());
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack('Error al cargar pedido: $e', isError: true);
    }
  }

  Future<void> _guardarMontoEditado(double monto) async {
    if (pedido == null || !mounted) return;
    try {
      final idPedido = pedido!['idPedido'] ?? pedido!['id_pedido'];
      await apiService.actualizarMontoPedido(idPedido, monto);
      if (mounted) setState(() => pedido!['monto_editado'] = monto);
    } catch (e) {
      _showSnack('Error al guardar monto: $e', isError: true);
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
      final monto = _parseMonto(montoController.text) ?? _montoActual();

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

  Future<void> _cancelarPedido() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Cancelar pedido',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          '¿Estás seguro de cancelar este pedido? Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: _textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await apiService.cancelarPedido(widget.idPedido);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnack('Error al cancelar pedido: $e', isError: true);
    }
  }

  Future<void> _editarDetalle(Map<String, dynamic> detalle) async {
    List<dynamic> productos = [];
    try {
      productos = await apiService.getProductos();
    } catch (_) {}
    if (!mounted) return;

    final idDetalle = detalle['idDetalle'] ?? detalle['id_detalle'];
    final idProductoRaw =
        detalle['idProducto'] ?? detalle['producto']?['idProducto'] ?? 0;
    final idProductoInicial = idProductoRaw is int
        ? idProductoRaw
        : int.tryParse(idProductoRaw.toString()) ?? 0;
    final notaInicial = detalle['detalle']?.toString() ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditarDetalleModal(
        productos: productos,
        idProductoInicial: idProductoInicial,
        notaInicial: notaInicial,
        onGuardar: (idProductoSeleccionado, nota) async {
          final productoSel = productos.firstWhere(
            (p) =>
                (p['idProducto'] ?? p['id_producto']) == idProductoSeleccionado,
            orElse: () => {},
          );
          final precioNuevo =
              double.tryParse(productoSel['precio']?.toString() ?? '0') ?? 0.0;

          await apiService.actualizarDetallePedido(
            idDetalle is int ? idDetalle : int.parse(idDetalle.toString()),
            idProducto: idProductoSeleccionado,
            precioUnitario: precioNuevo,
            detalle: nota,
          );
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );

    if (mounted) {
      await _cargarPedido();
      _showSnack('Producto actualizado');
    }
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

  // ── Permisos por rol ──────────────────────────────────────────────────────────
  bool get esAdmin => widget.rol == 'administrador';
  bool get puedeEditarTotal =>
      widget.rol == 'administrador' || widget.rol == 'mesero';
  bool get puedeCancelar =>
      widget.rol == 'administrador' || widget.rol == 'mesero';

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

  Widget _buildDetalleItem(Map<String, dynamic> detalle) {
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
                      const Icon(
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
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _editarDetalle(detalle),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: _primary,
                  ),
                ),
              ),
            ],
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
        actions: [
          // Cancelar pedido: admin y mesero
          if (puedeCancelar)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Cancelar pedido',
              onPressed: _cancelarPedido,
            ),
        ],
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
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
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
                            Text(
                              'Pedido #${pedido!['idPedido'] ?? pedido!['id_pedido']}',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            const Spacer(),
                            _estadoBadge(pedido!['estado']?.toString() ?? ''),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

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
                              if (mounted) _cargarPedido();
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

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

                      ...((pedido!['detalles'] ?? []) as List).map(
                        (d) => _buildDetalleItem(d as Map<String, dynamic>),
                      ),

                      const SizedBox(height: 4),

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
                            // Editar total: admin y mesero
                            puedeEditarTotal
                                ? SizedBox(
                                    width: 150,
                                    child: TextField(
                                      controller: montoController,
                                      focusNode: _montoFocus,
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
                                    formatoPesos.format(_montoActual()),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: _primary,
                                    ),
                                  ),
                          ],
                        ),
                      ),

                      // Métodos de pago: solo admin
                      if (esAdmin) ...[
                        const SizedBox(height: 20),
                        _buildMetodosPago(),
                      ],

                      const SizedBox(height: 8),
                    ],
                  ),
                ),

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
                  // Botón procesar pago: solo admin
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

// ── Modal editar detalle ──────────────────────────────────────────────────────

class _EditarDetalleModal extends StatefulWidget {
  final List<dynamic> productos;
  final int idProductoInicial;
  final String notaInicial;
  final Future<void> Function(int idProducto, String nota) onGuardar;

  const _EditarDetalleModal({
    required this.productos,
    required this.idProductoInicial,
    required this.notaInicial,
    required this.onGuardar,
  });

  @override
  State<_EditarDetalleModal> createState() => _EditarDetalleModalState();
}

class _EditarDetalleModalState extends State<_EditarDetalleModal> {
  late final TextEditingController _notaCtrl;
  late int _idProductoSeleccionado;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _notaCtrl = TextEditingController(text: widget.notaInicial);
    _idProductoSeleccionado = widget.idProductoInicial;
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Editar producto',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.productos.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'No se pudieron cargar los productos',
                  style: TextStyle(color: _textMuted),
                ),
              )
            else
              DropdownButtonFormField<int>(
                value: _idProductoSeleccionado,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Producto',
                  labelStyle: const TextStyle(color: _textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: widget.productos.map<DropdownMenuItem<int>>((p) {
                  final id = p['idProducto'] ?? p['id_producto'];
                  final idInt = id is int
                      ? id
                      : int.tryParse(id.toString()) ?? 0;
                  return DropdownMenuItem<int>(
                    value: idInt,
                    child: Text(
                      '${p['nombre']}  •  ${formatoPesos.format(double.tryParse(p['precio'].toString()) ?? 0)}',
                      style: const TextStyle(fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) =>
                    setState(() => _idProductoSeleccionado = val!),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _notaCtrl,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(fontSize: 16, color: _textDark),
              decoration: InputDecoration(
                hintText: 'Nota para cocina...',
                hintStyle: const TextStyle(color: _textMuted, fontSize: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _primary, width: 2),
                ),
                prefixIcon: const Icon(
                  Icons.edit_note,
                  color: _textMuted,
                  size: 22,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _guardando
                    ? null
                    : () async {
                        setState(() => _guardando = true);
                        try {
                          await widget.onGuardar(
                            _idProductoSeleccionado,
                            _notaCtrl.text.trim(),
                          );
                        } catch (e) {
                          if (mounted) setState(() => _guardando = false);
                        }
                      },
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Guardar cambios',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
