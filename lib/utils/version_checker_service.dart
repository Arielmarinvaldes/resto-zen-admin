// lib/services/version_checker_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VersionCheckerService {
  static const String _currentVersion = '1.3.9';
  static const String _versionUrl = 'https://raw.githubusercontent.com/Arielmarinvaldes/resto-zen-admin/master/version.json';

  static Timer? _timer;

  static void startPeriodicCheck(BuildContext context, {Duration interval = const Duration(minutes: 1)}) {
    _timer?.cancel(); // cancel previous if exists
    _timer = Timer.periodic(interval, (_) => _checkVersion(context));
  }

  static Future<void> _checkVersion(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(_versionUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['version'];
        final downloadUrl = data['url'];

        if (_isNewerVersion(latestVersion, _currentVersion)) {
          _showUpdateDialog(context, latestVersion, downloadUrl);
        }
      }
    } catch (e) {
      print("⚠️ Error al comprobar versión en background: $e");
    }
  }

  static bool _isNewerVersion(String remote, String local) {
    List<String> r = remote.split('.');
    List<String> l = local.split('.');
    for (int i = 0; i < 3; i++) {
      final ri = int.parse(r[i]);
      final li = int.parse(l[i]);
      if (ri > li) return true;
      if (ri < li) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String latestVersion, String url) {
    if (ModalRoute.of(context)?.isCurrent != true) return; // Evitar superposición en navegación

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Actualización disponible"),
        content: Text("Versión $latestVersion disponible. Actualiza ahora."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Aquí puedes llamar a tu función global de descarga
              // Ej: descargarYMostrarProgreso(context, url);
            },
            child: const Text("Actualizar"),
          ),
        ],
      ),
    );
  }

  static void stop() {
    _timer?.cancel();
  }
}
