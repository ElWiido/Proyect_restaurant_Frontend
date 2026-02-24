import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _primary = Color(0xFFB25A45);
const _bg = Color(0xFFF7F7F7);
const _cardBg = Colors.white;
const _textDark = Color(0xFF1A1A1A);
const _textMuted = Color(0xFF8A8A8A);

class PedidoScreen extends StatefulWidget {
  final int idMesa;
  final String numeroMesa;
  final int idUsuario;

  const PedidoScreen({
    super.key,
    required this.idMesa,
    required this.numeroMesa,
    required this.idUsuario,
  });

  @override
  State<PedidoScreen> createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  List<dynamic> productos = [];
  List<Map<String, dynamic>> detalles = [];
  final Map<int, TextEditingController> _controllers = {};
  bool isLoading = false;

  TabController? _tabController;
  List<String> _categorias = [];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────────

  Future<void> _cargarProductos() async {
    try {
      final data = await apiService.getProductos();
      if (!mounted) return;

      final cats = <String>[];
      if (data.any((p) => p['categoria'] == 'ejecutivo')) {
        cats.add('ejecutivo');
      }
      final otras = data
          .where((p) => p['categoria'] != 'ejecutivo')
          .map((p) => p['categoria'] as String)
          .toSet()
          .toList();
      cats.addAll(otras);

      // ✅ FIX 1: dispose FUERA de setState
      _tabController?.dispose();

      setState(() {
        productos = data;
        _categorias = cats;
        isLoading = false;
        _tabController = TabController(length: cats.length, vsync: this);
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _crearPedido() async {
    if (detalles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Agrega al menos un producto'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final payload = {
        'id_mesa': widget.idMesa,
        'id_usuario': widget.idUsuario,
        'detalles': detalles
            .map(
              (d) => {
                'id_producto': d['id_producto'],
                'detalle': d['detalle'],
                'cantidad': d['cantidad'],
              },
            )
            .toList(),
      };
      await apiService.crearPedido(payload);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _agregarDetalle(int idProducto, String nombre) {
    setState(() {
      final idx = detalles.indexWhere((d) => d['id_producto'] == idProducto);
      if (idx != -1) {
        detalles[idx]['cantidad'] += 1;
      } else {
        detalles.add({
          'id_producto': idProducto,
          'nombre': nombre,
          'detalle': '',
          'cantidad': 1,
        });
      }
    });
  }

  void _eliminarDetalle(int index) {
    setState(() {
      final idProducto = detalles[index]['id_producto'] as int;
      _controllers.remove(idProducto)?.dispose();
      detalles.removeAt(index);
    });
  }

  // ── Modal de nota ─────────────────────────────────────────────────────────────
  Future<void> _abrirNotaDialog(Map<String, dynamic> detalle) async {
    // ✅ FIX DEFINITIVO: usamos variable String en lugar de TextEditingController
    // Esto evita completamente el problema de controller disposed durante
    // animaciones del teclado (IME_INSETS_HIDE_ANIMATION)
    String textoTemporal = detalle['detalle'] as String;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotaModal(
        nombreProducto: detalle['nombre'] as String,
        textoInicial: textoTemporal,
        onGuardar: (texto) {
          textoTemporal = texto;
          Navigator.pop(ctx);
        },
      ),
    );

    // Actualiza el padre con el texto guardado
    if (mounted) setState(() => detalle['detalle'] = textoTemporal);
  }

  // ── Tab label ─────────────────────────────────────────────────────────────────
  String _labelCategoria(String cat) {
    if (cat == 'ejecutivo') return 'Ejecutivo';
    return cat[0].toUpperCase() + cat.substring(1);
  }

  // ── Lista de productos por categoría ─────────────────────────────────────────
  Widget _buildProductosList(String categoria) {
    final items = productos.where((p) => p['categoria'] == categoria).toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      itemCount: items.length,
      itemBuilder: (_, i) =>
          _productoCard(items[i], isEjecutivo: categoria == 'ejecutivo'),
    );
  }

  // ── Tarjeta de producto ───────────────────────────────────────────────────────
  Widget _productoCard(dynamic producto, {bool isEjecutivo = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isEjecutivo ? const Color(0xFFFFF4F2) : _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEjecutivo
              ? _primary.withOpacity(0.25)
              : Colors.grey.withOpacity(0.12),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          producto['nombre'],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 19,
            color: _textDark,
          ),
        ),
        subtitle: Text(
          '\$${producto['precio']}',
          style: TextStyle(
            fontSize: 17,
            color: isEjecutivo ? _primary : _textMuted,
            fontWeight: isEjecutivo ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: GestureDetector(
          onTap: () => _agregarDetalle(
            producto['idProducto'] ?? producto['id_producto'],
            producto['nombre'],
          ),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  // ── Card de detalle seleccionado ──────────────────────────────────────────────
  Widget _buildDetalleCard(int index) {
    final detalle = detalles[index];
    final idProducto = detalle['id_producto'] as int;
    final textoActual = detalle['detalle'] as String;

    // ✅ FIX 3: No reutilizar controladores disposed — solo para sync visual
    final controller = _controllers.putIfAbsent(
      idProducto,
      () => TextEditingController(text: textoActual),
    );
    if (controller.text != textoActual) {
      controller.value = controller.value.copyWith(
        text: textoActual,
        selection: TextSelection.collapsed(offset: textoActual.length),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    detalle['nombre'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      color: _textDark,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _eliminarDetalle(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, size: 18, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Cantidad',
                  style: TextStyle(
                    fontSize: 17,
                    color: _textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _countButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (detalle['cantidad'] > 1) {
                      setState(() => detalle['cantidad']--);
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    detalle['cantidad'].toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                ),
                _countButton(
                  icon: Icons.add,
                  filled: true,
                  onTap: () => setState(() => detalle['cantidad']++),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Botón de nota
            GestureDetector(
              onTap: () => _abrirNotaDialog(detalle),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, color: _textMuted, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        textoActual.isEmpty
                            ? 'Agregar nota para cocina...'
                            : textoActual,
                        style: TextStyle(
                          fontSize: 16,
                          color: textoActual.isEmpty ? _textMuted : _textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (textoActual.isNotEmpty)
                      const Icon(
                        Icons.chevron_right,
                        color: _textMuted,
                        size: 20,
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

  Widget _countButton({
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? _primary : _bg,
          borderRadius: BorderRadius.circular(8),
          border: filled
              ? null
              : Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Icon(icon, size: 20, color: filled ? Colors.white : _textDark),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalItems = detalles.fold<int>(
      0,
      (s, d) => s + (d['cantidad'] as int),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
            if (totalItems > 0)
              Text(
                '$totalItems ${totalItems == 1 ? 'item' : 'items'}',
                style: const TextStyle(fontSize: 15, color: _textMuted),
              ),
          ],
        ),
        centerTitle: true,
        bottom: _tabController == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: _bg,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: _primary,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: _primary,
                    unselectedLabelColor: _textMuted,
                    labelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerColor: Colors.grey.withOpacity(0.15),
                    tabs: _categorias
                        .map((c) => Tab(text: _labelCategoria(c)))
                        .toList(),
                  ),
                ),
              ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _tabController == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                // ── Menú tabs ───────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  height: MediaQuery.of(context).size.height * 0.42,
                  child: TabBarView(
                    controller: _tabController,
                    children: _categorias
                        .map((c) => _buildProductosList(c))
                        .toList(),
                  ),
                ),

                Container(height: 1, color: Colors.grey.withOpacity(0.15)),

                // ── Seleccionados ────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Row(
                          children: [
                            const Text(
                              'Seleccionados',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (detalles.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${detalles.length}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: detalles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 48,
                                      color: _textMuted.withOpacity(0.4),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Agrega productos al pedido',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _textMuted.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                itemCount: detalles.length,
                                itemBuilder: (_, i) => _buildDetalleCard(i),
                              ),
                      ),

                      // Botón confirmar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: SizedBox(
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
                            onPressed: isLoading ? null : _crearPedido,
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 22,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Confirmar Pedido',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Modal de nota como StatefulWidget independiente ───────────────────────────
// Al ser un StatefulWidget propio, el TextEditingController vive y muere
// dentro de su propio ciclo de vida, completamente aislado del padre.
// Esto elimina el error "TextEditingController used after being disposed"
// causado por las animaciones IME_INSETS_HIDE_ANIMATION de Android.
class _NotaModal extends StatefulWidget {
  final String nombreProducto;
  final String textoInicial;
  final void Function(String texto) onGuardar;

  const _NotaModal({
    required this.nombreProducto,
    required this.textoInicial,
    required this.onGuardar,
  });

  @override
  State<_NotaModal> createState() => _NotaModalState();
}

class _NotaModalState extends State<_NotaModal> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.textoInicial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Row(
              children: [
                const Icon(Icons.edit_note, color: _primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.nombreProducto,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Nota para cocina',
              style: TextStyle(fontSize: 15, color: _textMuted),
            ),
            const SizedBox(height: 16),

            // ✅ TextField con altura fija — no empuja el botón al crecer
            SizedBox(
              height: 120,
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 17, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Ej: sin cebolla, término medio...',
                  hintStyle: const TextStyle(color: _textMuted, fontSize: 16),
                  filled: true,
                  fillColor: _bg,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ Botón siempre visible, no se mueve
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.check, size: 20),
                label: const Text(
                  'Guardar nota',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                onPressed: () => widget.onGuardar(_ctrl.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
