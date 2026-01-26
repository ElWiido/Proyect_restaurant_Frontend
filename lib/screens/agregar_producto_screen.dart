import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AgregarProductoScreen extends StatefulWidget {
  final int idPedido;
  final int idMesa;
  final int numeroMesa;

  const AgregarProductoScreen({
    super.key,
    required this.idPedido,
    required this.idMesa,
    required this.numeroMesa,
  });

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final ApiService apiService = ApiService();
  List<dynamic> productos = [];
  List<Map<String, dynamic>> detalles = [];
  bool isLoading = true;
  bool isProcesando = false;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      final data = await apiService.getProductos();
      setState(() {
        productos = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error cargando productos: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error cargando productos')));
    }
  }

  void _agregarDetalle(int idProducto, String nombre) {
    setState(() {
      final index = detalles.indexWhere((d) => d['id_producto'] == idProducto);

      if (index != -1) {
        detalles[index]['cantidad'] += 1;
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
      detalles.removeAt(index);
    });
  }

  Future<void> _guardarProductos() async {
    if (detalles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }

    setState(() => isProcesando = true);

    try {
      for (var detalle in detalles) {
        await apiService.agregarProductoAPedido(
          widget.idPedido,
          idProducto: detalle['id_producto'],
          cantidad: detalle['cantidad'],
          detalle: detalle['detalle'],
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Productos agregados al pedido')),
      );

      Navigator.pop(context, true); // indica que se actualizaron productos
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error agregando productos: $e')));
    } finally {
      if (mounted) setState(() => isProcesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agregar productos - Mesa ${widget.numeroMesa}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: productos.length,
                    itemBuilder: (context, index) {
                      final producto = productos[index];
                      return Card(
                        child: ListTile(
                          title: Text(producto['nombre'] ?? ''),
                          subtitle: Text('\$${producto['precio']}'),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.green,
                            ),
                            onPressed: () => _agregarDetalle(
                              producto['idProducto'] ?? producto['id_producto'],
                              producto['nombre'],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, thickness: 2),
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Productos seleccionados',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: detalles.length,
                            itemBuilder: (context, index) {
                              final detalle = detalles[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color.fromARGB(255, 0, 0, 0),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: ListTile(
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(detalle['nombre'])),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            if (detalle['cantidad'] > 1) {
                                              detalle['cantidad']--;
                                            }
                                          });
                                        },
                                      ),
                                      Text(
                                        detalle['cantidad'].toString(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: Colors.green,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            detalle['cantidad']++;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  subtitle: TextField(
                                    decoration: const InputDecoration(
                                      hintText: 'Nota (opcional)',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) {
                                      detalles[index]['detalle'] = value;
                                    },
                                    keyboardType: TextInputType.multiline,
                                    maxLines: null,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _eliminarDetalle(index),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB25A45),
                              ),
                              onPressed: isProcesando
                                  ? null
                                  : _guardarProductos,
                              child: isProcesando
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'Agregar Productos',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
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
}
