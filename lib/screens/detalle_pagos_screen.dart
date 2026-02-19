import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class DetallePagosScreen extends StatefulWidget {
  final String fecha; // Formato 'yyyy-MM-dd'

  const DetallePagosScreen({super.key, required this.fecha});

  @override
  State<DetallePagosScreen> createState() => _DetallePagosScreenState();
}

class _DetallePagosScreenState extends State<DetallePagosScreen> {
  final ApiService apiService = ApiService();
  late Future<List<Map<String, dynamic>>> pagosFuture;
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.parse(widget.fecha);
    _cargarPagos();
  }

  void _cargarPagos() {
    final fechaStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    pagosFuture = apiService.getPagosByDate(fechaStr);
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _cargarPagos();
      });
    }
  }

  String _formatHora(String? datetime) {
    if (datetime == null) return '';
    try {
      final dt = DateTime.parse(datetime);
      return DateFormat('hh:mm a').format(dt); // AM/PM
    } catch (_) {
      return datetime;
    }
  }

  double _parseMonto(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  double _totalVentas(List<Map<String, dynamic>> pagos) {
    return pagos.fold(0, (sum, p) => sum + _parseMonto(p['monto']));
  }

  double _totalPorMetodo(List<Map<String, dynamic>> pagos, String metodo) {
    return pagos.fold(0, (sum, p) {
      final m = (p['metodoPago'] ?? p['metodo'] ?? '').toString().toLowerCase();

      if (m == metodo.toLowerCase()) {
        return sum + _parseMonto(p['monto']);
      }
      return sum;
    });
  }

  String formatMoneda(double value) {
    final formatter = NumberFormat('#,###', 'es_CO');
    return '\$${formatter.format(value)}';
  }

  Widget _buildMetodoCard(
    String titulo,
    double monto,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            titulo,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            formatMoneda(monto),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('Pagos del $fechaStr'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
            tooltip: 'Seleccionar fecha',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: pagosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final pagos = (snapshot.data ?? [])
            ..sort((a, b) {
              final fechaA =
                  DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(1970);
              final fechaB =
                  DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(1970);
              return fechaB.compareTo(fechaA); //más reciente primero
            });

          if (pagos.isEmpty) {
            return const Center(child: Text('No hay pagos registrados'));
          }

          final total = _totalVentas(pagos);
          final totalEfectivo = _totalPorMetodo(pagos, 'efectivo');
          final totalTransferencia = _totalPorMetodo(pagos, 'transferencia');

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // TOTAL
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetodoCard(
                            'EFECTIVO',
                            totalEfectivo,
                            Colors.green,
                            Icons.attach_money,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetodoCard(
                            'TRANSFERENCIA',
                            totalTransferencia,
                            Colors.blue,
                            Icons.account_balance,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'TOTAL GENERAL',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatMoneda(total),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // TABLA
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width,
                      ),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey.shade200,
                        ),
                        dataRowHeight: 60,
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Mesa',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Usuario',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Método',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Monto',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Hora',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: pagos.map((pago) {
                          return DataRow(
                            cells: [
                              DataCell(Text('${pago['Mesa'] ?? ''}')),
                              DataCell(Text('${pago['Usuario'] ?? ''}')),
                              DataCell(
                                Text(
                                  '${pago['metodoPago'] ?? pago['metodo'] ?? ''}',
                                ),
                              ),
                              DataCell(
                                Text(formatMoneda(_parseMonto(pago['monto']))),
                              ),
                              DataCell(Text(_formatHora(pago['createdAt']))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
