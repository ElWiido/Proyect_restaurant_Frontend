import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

class _PedidoScreenState extends State<PedidoScreen> {
  final ApiService apiService = ApiService();
  List<dynamic> productos = [];
  List<Map<String, dynamic>> detalles = [];
  bool isLoading = false;

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
    }
  }

  void _agregarDetalle(int idProducto, String nombre) {
    setState(() {
      final index = detalles.indexWhere((d) => d['id_producto'] == idProducto);

      if (index != -1) {
        // Si ya existe, solo aumenta cantidad
        detalles[index]['cantidad'] += 1;
      } else {
        // Si no existe, se agrega con cantidad 1
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

  Future<void> _crearPedido() async {
    if (detalles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido creado exitosamente')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<Widget> _buildMenuEjecutivo() {
    final ejecutivos = productos
        .where((p) => p['categoria'] == 'ejecutivo')
        .toList();

    if (ejecutivos.isEmpty) return [];

    return [
      const Text(
        "MENÚ EJECUTIVO",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      ...ejecutivos.map((producto) {
        return Card(
          child: ListTile(
            title: Text(producto['nombre']),
            subtitle: Text('\$${producto['precio']}'),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () => _agregarDetalle(
                producto['idProducto'] ?? producto['id_producto'],
                producto['nombre'],
              ),
            ),
          ),
        );
      }).toList(),
    ];
  }

  ///CATEGORÍAS DESPLEGABLES
  List<Widget> _buildCategorias() {
    final categorias = productos
        .where((p) => p['categoria'] != 'ejecutivo')
        .map((p) => p['categoria'])
        .toSet()
        .toList();

    return categorias.map((categoria) {
      final productosCategoria = productos
          .where((p) => p['categoria'] == categoria)
          .toList();

      return ExpansionTile(
        title: Text(
          categoria.toString().toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: productosCategoria.map((producto) {
          return ListTile(
            title: Text(producto['nombre']),
            subtitle: Text('\$${producto['precio']}'),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () => _agregarDetalle(
                producto['idProducto'] ?? producto['id_producto'],
                producto['nombre'],
              ),
            ),
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido - Mesa ${widget.numeroMesa}'),
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
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._buildMenuEjecutivo(),
                      const SizedBox(height: 10),
                      ..._buildCategorias(),
                    ],
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
                                  vertical: 6,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    /// 🔹 FILA SUPERIOR (nombre + cantidad + eliminar)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            detalle['nombre'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),

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
                                            fontSize: 16,
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

                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _eliminarDetalle(index),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    /// CAMPO DE NOTA BONITO
                                    TextField(
                                      decoration: InputDecoration(
                                        hintText: 'nota...',
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        detalles[index]['detalle'] = value;
                                      },
                                      maxLines: 2,
                                    ),
                                  ],
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
                              onPressed: isLoading ? null : _crearPedido,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 25,
                                      height: 25,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Text(
                                      'Crear Pedido',
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
