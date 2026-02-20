import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'pago_detallado_screen.dart';

const _primary = Color(0xFFB25A45);
const _bg = Color(0xFFF7F7F7);
const _cardBg = Colors.white;
const _textDark = Color(0xFF1A1A1A);
const _textMuted = Color(0xFF8A8A8A);

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
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _cargarPagos();
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _formatHora(String? datetime) {
    if (datetime == null) return '';
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(datetime));
    } catch (_) {
      return datetime;
    }
  }

  String _formatFechaLabel(DateTime dt) {
    return DateFormat("d 'de' MMMM, yyyy", 'es').format(dt);
  }

  double _parseMonto(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  // ✅ No suma los pagos con método 'anotar'
  double _totalVentas(List<Map<String, dynamic>> pagos) => pagos
      .where(
        (p) =>
            (p['metodoPago'] ?? p['metodo'] ?? '').toString().toLowerCase() !=
            'anotar',
      )
      .fold(0, (s, p) => s + _parseMonto(p['monto']));

  double _totalPorMetodo(List<Map<String, dynamic>> pagos, String metodo) =>
      pagos.fold(0, (s, p) {
        final m = (p['metodoPago'] ?? p['metodo'] ?? '')
            .toString()
            .toLowerCase();
        return m == metodo.toLowerCase() ? s + _parseMonto(p['monto']) : s;
      });

  String _formatMoneda(double value) {
    final f = NumberFormat('#,###', 'es_CO');
    return '\$${f.format(value)}';
  }

  String _labelMetodo(String metodo) {
    switch (metodo.toLowerCase()) {
      case 'efectivo':
        return 'Efectivo';
      case 'transferencia':
        return 'Transferencia';
      default:
        return metodo;
    }
  }

  // ── Widgets ──────────────────────────────────────────────────────────────────

  Widget _buildResumenCard({
    required String titulo,
    required double monto,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatMoneda(monto),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total general',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            _formatMoneda(total),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagoCard(Map<String, dynamic> pago) {
    final metodo = (pago['metodoPago'] ?? pago['metodo'] ?? '').toString();
    final isEfectivo = metodo.toLowerCase() == 'efectivo';
    final isAnotar = metodo.toLowerCase() == 'anotar';
    final metodoColor = isEfectivo
        ? Colors.green
        : isAnotar
        ? Colors.orange
        : Colors.blue;
    final metodoIcon = isEfectivo
        ? Icons.attach_money
        : isAnotar
        ? Icons.edit_note
        : Icons.account_balance;

    return GestureDetector(
      onTap: () {
        final idPedido = int.parse(pago['idPedido'].toString());
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetallePedidoScreen(
              idPedido: idPedido,
              mesa: pago['Mesa']?.toString() ?? '',
              usuario: pago['Usuario']?.toString() ?? '',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          children: [
            // Ícono método
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: metodoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(metodoIcon, color: metodoColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Mesa + usuario
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mesa ${pago['Mesa'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pago['Usuario'] ?? ''}',
                    style: const TextStyle(fontSize: 14, color: _textMuted),
                  ),
                ],
              ),
            ),

            // Monto + hora + método
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMoneda(_parseMonto(pago['monto'])),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatHora(pago['createdAt']),
                  style: const TextStyle(fontSize: 13, color: _textMuted),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: metodoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _labelMetodo(metodo),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: metodoColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ), // Container
    ); // GestureDetector
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
            const Text(
              'Detalle de pagos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            Text(
              _formatFechaLabel(selectedDate),
              style: const TextStyle(fontSize: 13, color: _textMuted),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.15)),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: _textDark,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: pagosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: _textMuted),
              ),
            );
          }

          final pagos = (snapshot.data ?? [])
            ..sort((a, b) {
              final fa =
                  DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(1970);
              final fb =
                  DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(1970);
              return fb.compareTo(fa);
            });

          if (pagos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 56,
                    color: _textMuted.withOpacity(0.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sin pagos registrados',
                    style: TextStyle(
                      fontSize: 16,
                      color: _textMuted.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          final total = _totalVentas(pagos);
          final totalEfectivo = _totalPorMetodo(pagos, 'efectivo');
          final totalTransferencia = _totalPorMetodo(pagos, 'transferencia');
          final totalAnotar = _totalPorMetodo(pagos, 'anotar');

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // ── Resumen por método ──────────────────────────────
              _buildResumenCard(
                titulo: 'EFECTIVO',
                monto: totalEfectivo,
                color: Colors.green,
                icon: Icons.attach_money,
              ),
              const SizedBox(height: 10),
              _buildResumenCard(
                titulo: 'TRANSFERENCIA',
                monto: totalTransferencia,
                color: Colors.blue,
                icon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: 10),
              // ✅ Anotar se muestra pero no suma al total
              if (totalAnotar > 0) ...[
                _buildResumenCard(
                  titulo: 'ANOTADOS (no incluidos)',
                  monto: totalAnotar,
                  color: Colors.orange,
                  icon: Icons.edit_note,
                ),
                const SizedBox(height: 10),
              ],
              _buildTotalCard(total),
              const SizedBox(height: 24),

              // ── Header lista ────────────────────────────────────
              const Text(
                'Transacciones',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 12),

              // ── Lista de pagos ──────────────────────────────────
              ...pagos.map((p) => _buildPagoCard(p)),
            ],
          );
        },
      ),
    );
  }
}
