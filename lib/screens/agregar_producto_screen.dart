import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
      await apiService.agregarProductosLote(widget.idPedido, detalles);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Productos agregados')));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isProcesando = false);
    }
  }

  ///MENÚ EJECUTIVO ARRIBA
  List<Widget> _buildMenuEjecutivo() {
    final ejecutivos = productos
        .where((p) => p['categoria'].toString().toLowerCase() == 'ejecutivo')
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
        .where((p) => p['categoria'].toString().toLowerCase() != 'ejecutivo')
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
                                      hintText: 'Nota',
                                      filled: true,
                                      fillColor: Color.fromARGB(
                                        255,
                                        245,
                                        245,
                                        245,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
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
