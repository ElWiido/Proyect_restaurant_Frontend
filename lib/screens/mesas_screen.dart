import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/session_service.dart';
import 'pedido_screen.dart';
import 'pago_screen.dart';
import 'login_screen.dart';
import 'detalle_pagos_screen.dart';

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

  ValueNotifier<double?> totalPagosHoy = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _cargarMesas();
    _cargarTotalPagos();
    _conectarWebSocket();
  }

  // --- Cargar mesas ---
  Future<void> _cargarMesas() async {
    try {
      final data = await apiService.getMesas();
      setState(() {
        mesas = List.from(data)
          ..sort((a, b) => (a['numero'] ?? 0).compareTo(b['numero'] ?? 0));
        isLoading = false;
      });
    } catch (e) {
      print("Error al cargar mesas: $e");
      setState(() => isLoading = false);
    }
  }

  // --- Cargar total de pagos ---
  Future<void> _cargarTotalPagos() async {
    if (widget.rol != 'administrador') return;
    try {
      final hoy = DateTime.now().toLocal();
      final fecha =
          '${hoy.year.toString().padLeft(4, '0')}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
      print("UTC: ${DateTime.now()}");
      print("LOCAL: ${DateTime.now().toLocal()}");
      final total = await apiService.getTotalPagos(fecha);
      totalPagosHoy.value = total.toDouble();
    } catch (e) {
      print('Error cargando total pagos: $e');
    }
  }

  // --- Conectar WebSocket ---
  void _conectarWebSocket() {
    wsService.connect((data) {
      if (data['event'] == 'mesa_actualizada') {
        final mesaAct = data['mesa'];
        final int id = mesaAct['idMesa'] ?? mesaAct['id_mesa'];
        setState(() {
          final idx = mesas.indexWhere(
            (m) => (m['idMesa'] ?? m['id_mesa']) == id,
          );
          if (idx != -1) {
            mesas[idx]['estado'] = mesaAct['estado'];
            if (mesaAct['numero'] != null) {
              mesas[idx]['numero'] = mesaAct['numero'];
            }
            mesas.sort(
              (a, b) => (a['numero'] ?? 0).compareTo(b['numero'] ?? 0),
            );
          }
        });
      }

      // Actualizar total si llega un nuevo pago
      if (widget.rol == 'administrador' && data['event'] == 'pago_completado') {
        final monto = (data['pago']['monto'] ?? 0).toDouble();
        totalPagosHoy.value = (totalPagosHoy.value ?? 0) + monto;
      }
    });
  }

  Color _colorPorEstado(String estado) {
    switch (estado) {
      case 'libre':
        return Colors.green[400]!;
      case 'ocupada':
        return Colors.red[400]!;
      case 'pendiente':
        return Colors.orange[400]!;
      default:
        return Colors.grey;
    }
  }

  void _abrirOpcionDrawer(String opcion) async {
    Navigator.pop(context);
    switch (opcion) {
      case 'Actualizar':
        _cargarMesas();
        _cargarTotalPagos();
        break;

      case 'Configuración':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Abrir configuración')));
        break;

      case 'Cerrar sesión':
        await SessionManager.logout();
        if (!mounted) return;
        // Redirigir a LoginScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        break;
    }
  }

  @override
  void dispose() {
    wsService.disconnect();
    super.dispose();
  }

  // --- Formatear con separador de miles ---
  String formatMiles(int number) {
    final str = number.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (match) => '.');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final crossAxisCount = isDesktop ? 5 : 3;
    final childAspectRatio = isDesktop ? 1.2 : 0.95;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Mesas",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (widget.rol == 'administrador')
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: ValueListenableBuilder<double?>(
                  valueListenable: totalPagosHoy,
                  builder: (context, value, _) {
                    if (value == null) {
                      return const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    return GestureDetector(
                      onTap: () {
                        // Abrimos la pantalla de detalle de pagos con la fecha actual
                        final hoy = DateTime.now();
                        final fechaStr =
                            '${hoy.year.toString().padLeft(4, '0')}-'
                            '${hoy.month.toString().padLeft(2, '0')}-'
                            '${hoy.day.toString().padLeft(2, '0')}';

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetallePagosScreen(fecha: fechaStr),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '\$${formatMiles(value.toInt())}',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFFB25A45)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Menú',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Opciones disponibles',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Actualizar mesas'),
              onTap: () => _abrirOpcionDrawer('Actualizar'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
              onTap: () => _abrirOpcionDrawer('Configuración'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () => _abrirOpcionDrawer('Cerrar sesión'),
            ),
          ],
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: mesas.length,
        itemBuilder: (context, index) {
          final mesa = mesas[index];
          final estado = mesa['estado'] ?? 'libre';
          final libre = estado == 'libre';
          final colorFondo = _colorPorEstado(estado);

          return GestureDetector(
            onTap: () {
              if (libre) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PedidoScreen(
                      idMesa: mesa['idMesa'] ?? mesa['id_mesa'],
                      numeroMesa: mesa['numero'],
                      idUsuario: widget.idUsuario,
                    ),
                  ),
                ).then((_) => _cargarMesas());
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PagoScreen(
                      idMesa: mesa['idMesa'] ?? mesa['id_mesa'],
                      numeroMesa: mesa['numero'],
                      rol: widget.rol,
                    ),
                  ),
                ).then((_) => _cargarMesas());
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.table_restaurant_sharp,
                    size: isDesktop ? 42 : 48,
                    color: colorFondo,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Mesa ${mesa['numero']}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorFondo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      estado.toUpperCase(),
                      style: TextStyle(
                        color: colorFondo,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
