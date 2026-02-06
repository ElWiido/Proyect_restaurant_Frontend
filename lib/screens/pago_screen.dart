import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'agregar_producto_screen.dart';

final formatoPesos = NumberFormat.currency(
  locale: 'es_CO',
  symbol: '\$',
  decimalDigits: 0,
);

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
  TextEditingController montoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarPedido();
    // Inicializar el monto con el total calculado (cuando se cargue el pedido)
  }

  Future<void> _editarPrecioDetalle(Map<String, dynamic> detalle) async {
    final TextEditingController precioController = TextEditingController(
      text:
          detalle['precio_unitario']?.toString() ??
          detalle['producto']?['precio']?.toString() ??
          '0',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar precio unitario'),
        content: TextField(
          controller: precioController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Nuevo precio',
            prefixText: '\$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevoPrecio = double.tryParse(
                precioController.text.replaceAll(',', '.'),
              );

              if (nuevoPrecio == null || nuevoPrecio <= 0) return;

              try {
                final int idDetalle = detalle['idDetalle'];

                await apiService.actualizarDetallePedido(
                  idDetalle,
                  precioUnitario: nuevoPrecio,
                );

                Navigator.pop(context);
                _cargarPedido(); // 🔁 refrescar pedido
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al actualizar precio: $e')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cargarPedido() async {
    try {
      final data = await apiService.getPedidoPorMesa(widget.idMesa);
      setState(() {
        pedido = data;
        isLoading = false;
        // Si es admin, inicializa el monto editable
        if (widget.rol == 'administrador') {
          montoController.text = _calcularTotal().toStringAsFixed(2);
        }
      });
    } catch (e) {
      print('Error cargando pedido: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar pedido: $e')));
    }
  }

  Future<void> _procesarPago() async {
    if (widget.rol != 'administrador') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo administradores pueden procesar pagos'),
        ),
      );
      return;
    }

    if (pedido == null) return;

    setState(() => isProcesando = true);

    try {
      // Si el campo monto está vacío o no es válido, usar el total calculado
      double monto = _calcularTotal();
      if (widget.rol == 'administrador') {
        final montoInput = double.tryParse(
          montoController.text.replaceAll(',', '.'),
        );
        if (montoInput != null && montoInput > 0) {
          monto = montoInput;
        }
      }
      final resultado = await apiService.crearPago({
        'id_pedido': pedido!['idPedido'] ?? pedido!['id_pedido'],
        'metodo_pago': metodoPago,
        'monto': monto,
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pago exitoso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monto: \$${resultado['monto']}'),
              Text('Método: ${resultado['metodo_pago']}'),
              const SizedBox(height: 8),
              const Text(
                'La mesa ahora está libre',
                style: TextStyle(color: Colors.green),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar diálogo
                Navigator.pop(context); // Volver a mesas
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al procesar pago: $e')));
    } finally {
      if (mounted) setState(() => isProcesando = false);
    }
  }

  double _calcularTotal() {
    if (pedido == null || pedido!['detalles'] == null) return 0.0;

    double total = 0.0;

    for (var detalle in pedido!['detalles']) {
      final cantidadRaw = detalle['cantidad'] ?? 1;

      double precio = 0.0;
      int cantidad = 1;

      final precioUnitario = detalle['precioUnitario'];

      if (precioUnitario != null) {
        if (precioUnitario is String) {
          precio = double.tryParse(precioUnitario) ?? 0.0;
        } else if (precioUnitario is num) {
          precio = precioUnitario.toDouble();
        }
      } else {
        // 🔁 SOLO SI NO EXISTE precio_unitario
        final precioProducto = detalle['producto']?['precio'];
        if (precioProducto is String) {
          precio = double.tryParse(precioProducto) ?? 0.0;
        } else if (precioProducto is num) {
          precio = precioProducto.toDouble();
        }
      }

      // Normalizar cantidad
      if (cantidadRaw is int) {
        cantidad = cantidadRaw;
      } else if (cantidadRaw is String) {
        cantidad = int.tryParse(cantidadRaw) ?? 1;
      }

      total += precio * cantidad;
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = widget.rol == 'administrador';

    return Scaffold(
      appBar: AppBar(
        title: Text('Pago - Mesa ${widget.numeroMesa}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pedido == null
          ? const Center(
              child: Text(
                'No hay pedido para esta mesa',
                style: TextStyle(fontSize: 16),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Pedido #${pedido!['idPedido'] ?? pedido!['id_pedido']}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: pedido!['estado'] == 'pendiente'
                                          ? Colors.orange[100]
                                          : Colors.green[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      pedido!['estado']
                                          .toString()
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: pedido!['estado'] == 'pendiente'
                                            ? Colors.orange[900]
                                            : Colors.green[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (pedido!['estado'] == 'pendiente')
                                SizedBox(
                                  width: double.infinity,
                                  height: 45,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Añadir productos'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFB25A45),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
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

                                      // Recargar pedido al volver
                                      _cargarPedido();
                                    },
                                  ),
                                ),
                              const Divider(height: 24),
                              const Text(
                                'Productos:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...((pedido!['detalles'] ?? []) as List).map((
                                detalle,
                              ) {
                                final producto = detalle['producto'];
                                final precioRaw =
                                    detalle['precioUnitario'] ??
                                    producto?['precio'];
                                final cantidadRaw = detalle['cantidad'] ?? 1;

                                double precio = 0.0;
                                int cantidad = 1;

                                // Normalizar precio
                                if (precioRaw is String) {
                                  precio = double.tryParse(precioRaw) ?? 0.0;
                                } else if (precioRaw is num) {
                                  precio = precioRaw.toDouble();
                                }
                                // Normalizar cantidad
                                if (cantidadRaw is int) {
                                  cantidad = cantidadRaw;
                                } else if (cantidadRaw is String) {
                                  cantidad = int.tryParse(cantidadRaw) ?? 1;
                                }

                                final subtotal = precio * cantidad;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    onTap: esAdmin
                                        ? () => _editarPrecioDetalle(detalle)
                                        : null,
                                    title: Text(
                                      producto?['nombre'] ?? 'Producto',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Cantidad: $cantidad'),
                                        Text(
                                          'Precio unitario: ${formatoPesos.format(precio)}',
                                        ),
                                        if (detalle['detalle']?.isNotEmpty ==
                                            true)
                                          Text(
                                            'Nota: ${detalle['detalle']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Text(
                                      formatoPesos.format(subtotal),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFB25A45),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              const Divider(height: 24),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F0EC),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total:',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    esAdmin
                                        ? SizedBox(
                                            width: 140,
                                            child: TextField(
                                              controller: montoController,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: const InputDecoration(
                                                prefixText: '\$',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 8,
                                                    ),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFB25A45),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            '\$${_calcularTotal().toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFB25A45),
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (esAdmin) ...[
                        const SizedBox(height: 16),
                        Card(
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Método de pago:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                RadioListTile<String>(
                                  title: const Text('Efectivo'),
                                  value: 'efectivo',
                                  groupValue: metodoPago,
                                  activeColor: const Color(0xFFB25A45),
                                  onChanged: (value) {
                                    setState(() => metodoPago = value!);
                                  },
                                ),
                                RadioListTile<String>(
                                  title: const Text('Tarjeta'),
                                  value: 'tarjeta',
                                  groupValue: metodoPago,
                                  activeColor: const Color(0xFFB25A45),
                                  onChanged: (value) {
                                    setState(() => metodoPago = value!);
                                  },
                                ),
                                RadioListTile<String>(
                                  title: const Text('Transferencia'),
                                  value: 'transferencia',
                                  groupValue: metodoPago,
                                  activeColor: const Color(0xFFB25A45),
                                  onChanged: (value) {
                                    setState(() => metodoPago = value!);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (esAdmin)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB25A45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: isProcesando ? null : _procesarPago,
                        child: isProcesando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Procesar Pago',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      '🔒 Solo administradores pueden procesar pagos',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
    );
  }
}
