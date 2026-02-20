import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/session_service.dart';
import 'pedido_screen.dart';
import 'pago_screen.dart';
import 'login_screen.dart';
import 'detalle_pagos_screen.dart';

const _primary = Color(0xFFB25A45);
const _bg = Color(0xFFF7F7F7);
const _cardBg = Colors.white;
const _textDark = Color(0xFF1A1A1A);
const _textMuted = Color(0xFF8A8A8A);

class MesasScreen extends StatefulWidget {
  final int idUsuario;
  final String rol;

  const MesasScreen({super.key, required this.idUsuario, required this.rol});

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  List<dynamic> mesas = [];
  bool isLoading = true;

  final ApiService apiService = ApiService();
  final WebSocketService wsService = WebSocketService();
  final ValueNotifier<double?> totalPagosHoy = ValueNotifier(null);

  late final String _fechaHoy = _calcFecha();

  static String _calcFecha() {
    final h = DateTime.now().toLocal();
    return '${h.year.toString().padLeft(4, '0')}-'
        '${h.month.toString().padLeft(2, '0')}-'
        '${h.day.toString().padLeft(2, '0')}';
  }

  static final _milesReg = RegExp(r'\B(?=(\d{3})+(?!\d))');
  String _miles(int n) => n.toString().replaceAllMapped(_milesReg, (_) => '.');

  @override
  void initState() {
    super.initState();
    _cargarMesas();
    _cargarTotalPagos();
    _conectarWebSocket();
  }

  @override
  void dispose() {
    wsService.disconnect();
    totalPagosHoy.dispose();
    super.dispose();
  }

  Future<void> _cargarMesas() async {
    try {
      final data = await apiService.getMesas();
      if (!mounted) return;
      setState(() {
        mesas = List.from(data)
          ..sort((a, b) {
            final nA = int.tryParse(a['numero']?.toString() ?? '0') ?? 0;
            final nB = int.tryParse(b['numero']?.toString() ?? '0') ?? 0;
            return nA.compareTo(nB);
          });
        isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _cargarTotalPagos() async {
    if (widget.rol != 'administrador') return;
    try {
      final total = await apiService.getTotalPagos(_fechaHoy);
      totalPagosHoy.value = total.toDouble();
    } catch (_) {}
  }

  void _conectarWebSocket() {
    wsService.connect((data) {
      if (data['event'] == 'mesa_actualizada') {
        final m = data['mesa'];
        final int id = m['idMesa'] ?? m['id_mesa'];
        if (!mounted) return;
        setState(() {
          final idx = mesas.indexWhere(
            (x) => (x['idMesa'] ?? x['id_mesa']) == id,
          );
          if (idx != -1) {
            mesas[idx]['estado'] = m['estado'];
            if (m['numero'] != null) mesas[idx]['numero'] = m['numero'];
            mesas.sort((a, b) {
              final nA = int.tryParse(a['numero']?.toString() ?? '0') ?? 0;
              final nB = int.tryParse(b['numero']?.toString() ?? '0') ?? 0;
              return nA.compareTo(nB);
            });
          }
        });
      }
      if (widget.rol == 'administrador' && data['event'] == 'pago_completado') {
        _cargarTotalPagos();
      }
    });
  }

  // Color e ícono por estado
  Color _color(String estado) {
    switch (estado) {
      case 'libre':
        return const Color(0xFF43A047);
      case 'ocupada':
        return const Color(0xFFE53935);
      case 'pendiente':
        return const Color(0xFFFB8C00);
      default:
        return Colors.grey;
    }
  }

  void _navegar(Map<String, dynamic> mesa) {
    final id = (mesa['idMesa'] ?? mesa['id_mesa']) is int
        ? mesa['idMesa'] ?? mesa['id_mesa']
        : int.parse((mesa['idMesa'] ?? mesa['id_mesa']).toString());
    final numero = (mesa['numero'] ?? '').toString();
    final libre = (mesa['estado'] ?? 'libre') == 'libre';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => libre
            ? PedidoScreen(
                idMesa: id,
                numeroMesa: numero,
                idUsuario: widget.idUsuario,
              )
            : PagoScreen(idMesa: id, numeroMesa: numero, rol: widget.rol),
      ),
    ).then((_) => _cargarMesas());
  }

  void _accionDrawer(String op) async {
    Navigator.pop(context);
    if (op == 'actualizar') {
      _cargarMesas();
      _cargarTotalPagos();
    } else if (op == 'logout') {
      await SessionManager.logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 800;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
        title: const Text(
          'Mesas',
          style: TextStyle(
            color: _textDark,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (widget.rol == 'administrador')
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ValueListenableBuilder<double?>(
                valueListenable: totalPagosHoy,
                builder: (_, value, __) {
                  if (value == null) {
                    return const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      ),
                    );
                  }
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetallePagosScreen(fecha: _fechaHoy),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      // ✅ sin doble $: el símbolo ya está hardcodeado
                      child: Text(
                        '\$${_miles(value.toInt())}',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),

      // ── Drawer ────────────────────────────────────────────────────────────
      drawer: Drawer(
        backgroundColor: _cardBg,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              color: _primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menú',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.rol.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _drawerItem(
              Icons.refresh_rounded,
              'Actualizar mesas',
              () => _accionDrawer('actualizar'),
            ),
            _drawerItem(
              Icons.logout_rounded,
              'Cerrar sesión',
              () => _accionDrawer('logout'),
              color: Colors.red[400]!,
            ),
          ],
        ),
      ),

      // ── Body ──────────────────────────────────────────────────────────────
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : mesas.isEmpty
          ? _emptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 5 : 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,

                childAspectRatio: isDesktop ? 1.0 : 0.72,
              ),
              cacheExtent: 400,
              itemCount: mesas.length,
              itemBuilder: (_, i) => _mesaCard(mesas[i]),
            ),
    );
  }

  // ── Card de mesa ──────────────────────────────────────────────────────────
  Widget _mesaCard(Map<String, dynamic> mesa) {
    final estado = mesa['estado']?.toString() ?? 'libre';
    final color = _color(estado);
    final numero = mesa['numero']?.toString() ?? '?';
    final libre = estado == 'libre';

    return GestureDetector(
      onTap: () => _navegar(mesa),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: libre
                ? Colors.grey.withOpacity(0.15)
                : color.withOpacity(0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono con fondo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.restaurant, size: 26, color: color),
            ),

            const SizedBox(height: 6),

            // Número
            Text(
              'Mesa $numero',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),

            const SizedBox(height: 4),

            // Badge estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                estado.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = _textDark,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.table_restaurant_outlined,
          size: 52,
          color: _textMuted.withOpacity(0.35),
        ),
        const SizedBox(height: 12),
        const Text(
          'No hay mesas',
          style: TextStyle(fontSize: 16, color: _textMuted),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reintentar', style: TextStyle(fontSize: 16)),
          onPressed: () {
            setState(() => isLoading = true);
            _cargarMesas();
          },
        ),
      ],
    ),
  );
}
