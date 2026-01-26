import 'package:flutter/material.dart';
import 'mesas_screen.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usuarioController = TextEditingController();
  final passwordController = TextEditingController();
  final apiService = ApiService();

  Future<void> login() async {
    try {
      final result = await apiService.login(
        usuarioController.text.trim(),
        passwordController.text.trim(),
      );

      final int? idUsuario =
          result['id_usuario'] ?? result['idUsuario'] ?? result['id'];

      final String rol = result['rol'] ?? 'mesero';

      if (idUsuario == null) throw Exception('No se recibió ID de usuario');

      //Guardar sesión por 1 día
      await SessionManager.setLoggedIn(userId: idUsuario, rol: rol);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MesasScreen(idUsuario: idUsuario, rol: rol),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = MediaQuery.of(context).size.width > 600 ? 220.0 : 180.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0EC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  _logo(logoSize),
                  const SizedBox(height: 20),
                  const Text(
                    "Iniciar sesión",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A2C2A),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _cardLogin(),
                  const SizedBox(height: 24),
                  _botonLogin(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo(double size) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          height: size,
          width: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _cardLogin() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _input(
              controller: usuarioController,
              label: "Usuario",
              icon: Icons.person_outline,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            _input(
              controller: passwordController,
              label: "Contraseña",
              icon: Icons.lock_outline,
              obscure: true,
              action: TextInputAction.done,
              onSubmit: (_) => login(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputAction action = TextInputAction.next,
    Function(String)? onSubmit,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      onSubmitted: onSubmit,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _botonLogin() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB25A45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        onPressed: login,
        child: const Text(
          "Entrar",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
