import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String keyLoggedIn = 'isLoggedIn';
  static const String keyUserId = 'userId';
  static const String keyRol = 'rol';
  static const String keyExpiry = 'expiry';

  // Guardar sesión con expiración de 1 día
  static Future<void> setLoggedIn({
    required int userId,
    required String rol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final expiry = now.add(const Duration(days: 1));
    await prefs.setBool(keyLoggedIn, true);
    await prefs.setInt(keyUserId, userId);
    await prefs.setString(keyRol, rol);
    await prefs.setString(keyExpiry, expiry.toIso8601String());
  }

  // Revisar si la sesión sigue válida
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(keyLoggedIn) ?? false;
    if (!loggedIn) return false;

    final expiryStr = prefs.getString(keyExpiry);
    if (expiryStr == null) return false;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;

    if (DateTime.now().isAfter(expiry)) {
      await logout(); // sesión expirada, limpiar
      return false;
    }

    return true;
  }

  // Obtener datos del usuario guardados
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await isLoggedIn()) return null;

    final userId = prefs.getInt(keyUserId);
    final rol = prefs.getString(keyRol);

    if (userId == null || rol == null) return null;

    return {'id_usuario': userId, 'rol': rol};
  }

  // Cerrar sesión
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyLoggedIn);
    await prefs.remove(keyUserId);
    await prefs.remove(keyRol);
    await prefs.remove(keyExpiry);
  }
}
