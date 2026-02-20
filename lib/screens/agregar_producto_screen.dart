import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _primary = Color(0xFFB25A45);
const _bg = Color(0xFFF7F7F7);
const _cardBg = Colors.white;
const _textDark = Color(0xFF1A1A1A);
const _textMuted = Color(0xFF8A8A8A);

class AgregarProductoScreen extends StatefulWidget {
  final int idPedido;
  final int idMesa;
  final String numeroMesa;

  const AgregarProductoScreen({
    super.key,
    required this.idPedido,
    required this.idMesa,
    required this.numeroMesa,
  });

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  List<dynamic> productos = [];
  List<Map<String, dynamic>> detalles = [];

  // ✅ RENDIMIENTO: controllers persistentes por índice
  final Map<int, TextEditingController> _controllers = {};
  bool isLoading = true;
  bool isProcesando = false;

  // ✅ TabController igual que PedidoScreen
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

  // ── API ──────────────────────────────────────────────────────────────────────

  Future<void> _cargarProductos() async {
    try {
      final data = await apiService.getProductos();
      if (!mounted) return;

      // Ejecutivo primero, luego el resto — igual que PedidoScreen
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

      setState(() {
        productos = data;
        _categorias = cats;
        isLoading = false;
        _tabController = TabController(length: cats.length, vsync: this);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack('Error cargando productos', isError: true);
    }
  }

  Future<void> _guardarProductos() async {
    if (detalles.isEmpty) {
      _showSnack('Agrega al menos un producto', isError: false);
      return;
    }
    setState(() => isProcesando = true);
    try {
      await apiService.agregarProductosLote(widget.idPedido, detalles);
      if (!mounted) return;
      _showSnack('Productos agregados', isError: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isProcesando = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

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
      _controllers.remove(index)?.dispose();
      detalles.removeAt(index);
    });
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[400] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Tab label ────────────────────────────────────────────────────────────────

  String _labelCategoria(String cat) {
    if (cat == 'ejecutivo') return 'Ejecutivo';
    return cat[0].toUpperCase() + cat.substring(1);
  }

  // ── Lista de productos por categoría (igual que PedidoScreen) ────────────────

  Widget _buildProductosList(String categoria) {
    final items = productos.where((p) => p['categoria'] == categoria).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      itemCount: items.length,
      // ✅ RENDIMIENTO: itemBuilder puro, sin closures anidados en build
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

  // ── Card de detalle seleccionado ─────────────────────────────────────────────

  Widget _buildDetalleCard(int index) {
    final detalle = detalles[index];
    final controller = _controllers.putIfAbsent(
      index,
      () => TextEditingController(text: detalle['detalle']),
    );

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
            // ✅ Builder para ensureVisible igual que PedidoScreen
            Builder(
              builder: (itemContext) => TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 17, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Nota para cocina...',
                  hintStyle: const TextStyle(color: _textMuted, fontSize: 17),
                  filled: true,
                  fillColor: _bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.edit_note,
                    color: _textMuted,
                    size: 22,
                  ),
                ),
                onChanged: (value) => detalle['detalle'] = value,
                onTap: () {
                  Future.delayed(
                    const Duration(milliseconds: 300),
                    () => Scrollable.ensureVisible(
                      itemContext,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: 0.5,
                    ),
                  );
                },
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

  // ── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalItems = detalles.fold<int>(
      0,
      (s, d) => s + (d['cantidad'] as int),
    );
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final kbOpen = keyboardH > 0;

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
            // ✅ Muestra conteo dinámico igual que PedidoScreen
            if (totalItems > 0)
              Text(
                '$totalItems ${totalItems == 1 ? 'item' : 'items'}',
                style: const TextStyle(fontSize: 15, color: _textMuted),
              )
            else
              const Text(
                'Agregar productos',
                style: TextStyle(fontSize: 15, color: _textMuted),
              ),
          ],
        ),
        centerTitle: true,
        // ✅ TabBar en el AppBar — igual que PedidoScreen
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
                // ── MENÚ con tabs ─────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  height: kbOpen
                      ? MediaQuery.of(context).size.height * 0.18
                      : MediaQuery.of(context).size.height * 0.42,
                  child: TabBarView(
                    controller: _tabController,
                    children: _categorias
                        .map((c) => _buildProductosList(c))
                        .toList(),
                  ),
                ),

                Container(height: 1, color: Colors.grey.withOpacity(0.15)),

                // ── SELECCIONADOS ─────────────────────────────────
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
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  keyboardH + 8,
                                ),
                                itemCount: detalles.length,
                                itemBuilder: (_, i) => _buildDetalleCard(i),
                              ),
                      ),

                      // Botón confirmar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        height: kbOpen ? 0 : 52 + 24,
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Padding(
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
                                onPressed: isProcesando
                                    ? null
                                    : _guardarProductos,
                                child: isProcesando
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 22,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Agregar Productos',
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
