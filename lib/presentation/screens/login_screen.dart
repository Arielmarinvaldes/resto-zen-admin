import 'dart:convert';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../../utils/mensajes.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:url_launcher/url_launcher.dart';

final String _appVersion = '1.0.3'; // Actualízala manualmente cuando subas nueva versión

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _checkForUpdates());
  }

  Future<void> _requestNotificationPermissions() async {
    await FirebaseMessaging.instance.requestPermission();
  }

  Future<void> _subscribeToAdminTopic() async {
    await FirebaseMessaging.instance.subscribeToTopic('pending_approvals');
  }

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
      await _requestNotificationPermissions();
      await _subscribeToAdminTopic();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/admin');
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message;
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    const String updateUrl = 'https://raw.githubusercontent.com/Arielmarinvaldes/resto-zen-admin/master/version.json';

    try {
      final response = await http.get(Uri.parse(updateUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String latestVersion = data['version'];
        String downloadUrl = data['url'];

        if (_isNewVersionAvailable(latestVersion, _appVersion)) {
          _mostrarDialogoActualizacion(downloadUrl, latestVersion);
        }
      }
    } catch (e) {
      print('Error al comprobar actualizaciones: $e');
    }
  }

  bool _isNewVersionAvailable(String latestVersion, String currentVersion) {
    List<String> latestParts = latestVersion.split('.');
    List<String> currentParts = currentVersion.split('.');

    for (int i = 0; i < 3; i++) {
      int latest = i < latestParts.length ? int.parse(latestParts[i]) : 0;
      int current = i < currentParts.length ? int.parse(currentParts[i]) : 0;
      if (latest > current) return true;
      if (latest < current) return false;
    }
    return false;
  }

  void _mostrarDialogoActualizacion(String downloadUrl, String latestVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono de actualización
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_alt,
                    size: 40,
                    color: Color(0xFF667eea),
                  ),
                ),
                const SizedBox(height: 20),

                // Título
                const Text(
                  'Actualización disponible',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Contenido
                Text(
                  'Nueva versión v$latestVersion disponible.\nActualiza para continuar usando la app.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Botón
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      descargarYMostrarProgreso(context, downloadUrl);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF667eea),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Actualizar ahora',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> descargarYMostrarProgreso(BuildContext context, String url) async {
    print("🟢 Iniciando proceso de descarga...");

    final dir = await getExternalStorageDirectory();
    final filePath = '${dir!.path}/update.apk';
    final dio = Dio();

    // Usamos un ValueNotifier para manejar el progreso
    final ValueNotifier<double> progresoNotifier = ValueNotifier<double>(0.0);

    // Variable para controlar si el diálogo está activo
    bool dialogoActivo = true;

    // Guardamos una referencia del context del diálogo
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        dialogContext = ctx; // Guardamos la referencia
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono animado
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_download,
                    size: 40,
                    color: Color(0xFF667eea),
                  ),
                ),
                const SizedBox(height: 20),

                // Título
                const Text(
                  "Descargando actualización",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                const Text(
                  "Por favor espera mientras se descarga la nueva versión",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF718096),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Barra de progreso con animación
                ValueListenableBuilder<double>(
                  valueListenable: progresoNotifier,
                  builder: (context, progreso, child) {
                    return Column(
                      children: [
                        // Contenedor personalizado para la barra de progreso
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: const Color(0xFF667eea).withOpacity(0.1),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    width: (progreso / 100) * constraints.maxWidth,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF1F1C2C),
                                          Color(0xFF928DAB),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Porcentaje con estilo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${progreso.toStringAsFixed(1)}%",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF667eea),
                              ),
                            ),
                            Text(
                              progreso < 100 ? "Descargando..." : "Completado",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF718096),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (recibido, total) {
          if (total > 0 && dialogoActivo) {
            final nuevoProgreso = (recibido / total) * 100;
            if (dialogoActivo) {
              progresoNotifier.value = nuevoProgreso;
            }
          }
        },
      );

      print("✅ Archivo descargado exitosamente en: $filePath");

      // Verificar que el archivo se descargó correctamente
      final file = File(filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        print("📁 Archivo verificado - Tamaño: ${fileSize} bytes");
      } else {
        print("❌ ERROR: El archivo no existe después de la descarga");
        return;
      }

      // Marcamos el diálogo como inactivo antes de cerrarlo
      dialogoActivo = false;
      print("🔄 Cerrando diálogo de progreso...");

      // Cerramos el diálogo de progreso de manera segura usando el context del diálogo
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
        print("✅ Diálogo cerrado correctamente");
      } else {
        print("❌ No se pudo cerrar el diálogo - dialogContext no válido");
      }

      // Esperamos un frame antes de instalar
      print("⏳ Esperando antes de iniciar instalación...");
      await Future.delayed(const Duration(milliseconds: 500));

      // Instalamos automáticamente la actualización SIN DEPENDER DEL CONTEXT
      print("🚀 Iniciando proceso de instalación...");
      await _instalarActualizacion(filePath, context);

    } catch (e) {
      print("❌ Error al descargar: $e");

      // Marcamos el diálogo como inactivo
      dialogoActivo = false;

      // Cerramos el diálogo de progreso de manera segura
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      // Esperamos un frame antes de mostrar el mensaje de error
      await Future.delayed(const Duration(milliseconds: 100));

      if (context.mounted) {
        mostrarMensaje(context, "Error al descargar: $e", MessageType.error);
      }
    } finally {
      // Limpiamos el ValueNotifier de manera segura
      try {
        progresoNotifier.dispose();
      } catch (e) {
        print("⚠️ Error al limpiar ValueNotifier: $e");
      }
    }
  }

  // MÉTODO CORREGIDO PARA INSTALAR APK - AHORA INDEPENDIENTE DEL CONTEXT
  Future<void> _instalarActualizacion(String filePath, BuildContext? contextOriginal) async {
    try {
      print("🔄 === INICIANDO INSTALACIÓN DEL APK ===");
      print("📂 Ruta del archivo: $filePath");

      // Verificar que el archivo existe
      final file = File(filePath);
      if (!await file.exists()) {
        print("❌ ERROR: El archivo no existe en la ruta especificada");
        _mostrarMensajeInstalacionManual(filePath, contextOriginal);
        return;
      }

      final fileSize = await file.length();
      print("📋 Archivo confirmado - Tamaño: $fileSize bytes");

      // Método 1: Usar AndroidIntent con FileProvider
      bool instalacionExitosa = await _intentarInstalacionConFileProvider(filePath);

      if (instalacionExitosa) {
        print("✅ Instalación iniciada con FileProvider");
        return;
      }

      // Método 2: Usar OpenFile
      instalacionExitosa = await _instalarConOpenFile(filePath);

      if (instalacionExitosa) {
        print("✅ Instalación iniciada con OpenFile");
        return;
      }

      // Método 3: AndroidIntent directo
      instalacionExitosa = await _instalarConAndroidIntent(filePath);

      if (instalacionExitosa) {
        print("✅ Instalación iniciada con AndroidIntent directo");
        return;
      }

      // Método 4: URL Launcher
      instalacionExitosa = await _instalarConUrlLauncher(filePath);

      if (instalacionExitosa) {
        print("✅ Instalación iniciada con URL Launcher");
        return;
      }

      // Si todos los métodos fallan, mostrar mensaje de instalación manual
      print("❌ Todos los métodos de instalación fallaron");
      _mostrarMensajeInstalacionManual(filePath, contextOriginal);

    } catch (e) {
      print("❌ ERROR GENERAL en instalación: $e");
      _mostrarMensajeInstalacionManual(filePath, contextOriginal);
    }
  }

  // Método para intentar instalación con FileProvider
  Future<bool> _intentarInstalacionConFileProvider(String filePath) async {
    try {
      print("🔄 === MÉTODO FILEPROVIDER ===");

      final packageName = 'com.example.resto_zen_administration';
      final authority = '$packageName.fileprovider';

      print("📦 Package: $packageName");
      print("🔑 Authority: $authority");

      final AndroidIntent intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'content://$authority/external_files/update.apk',
        type: 'application/vnd.android.package-archive',
        flags: <int>[
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_GRANT_READ_URI_PERMISSION,
        ],
      );

      await intent.launch();
      print("✅ Intent con FileProvider enviado");
      return true;

    } catch (e) {
      print("❌ ERROR con FileProvider: $e");
      return false;
    }
  }

  // Método alternativo usando OpenFile
  Future<bool> _instalarConOpenFile(String filePath) async {
    try {
      print("🔄 === MÉTODO OPENFILE ===");

      final result = await OpenFile.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      print("📋 Resultado OpenFile: ${result.type} - ${result.message}");

      return result.type == ResultType.done;

    } catch (e) {
      print("❌ ERROR en OpenFile: $e");
      return false;
    }
  }

  // Método alternativo usando AndroidIntent directo
  Future<bool> _instalarConAndroidIntent(String filePath) async {
    try {
      print("🔄 === MÉTODO ANDROIDINTENT DIRECTO ===");

      final AndroidIntent intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'file://$filePath',
        type: 'application/vnd.android.package-archive',
        flags: <int>[
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_GRANT_READ_URI_PERMISSION,
        ],
      );

      await intent.launch();
      print("✅ Intent directo enviado");
      return true;

    } catch (e) {
      print("❌ ERROR con AndroidIntent directo: $e");
      return false;
    }
  }

  // Método con url_launcher
  Future<bool> _instalarConUrlLauncher(String filePath) async {
    try {
      print("🔄 === MÉTODO URL_LAUNCHER ===");

      final Uri uri = Uri.file(filePath);

      final canLaunch = await canLaunchUrl(uri);
      print("❓ ¿Se puede lanzar?: $canLaunch");

      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print("✅ URL launcher ejecutado");
        return true;
      }

      return false;

    } catch (e) {
      print("❌ ERROR con url_launcher: $e");
      return false;
    }
  }

  // Mostrar mensaje para instalación manual - AHORA ACEPTA CONTEXT NULLABLE
  void _mostrarMensajeInstalacionManual(String filePath, BuildContext? context) {
    print("🆘 === INSTALACIÓN MANUAL REQUERIDA ===");
    print("📂 Archivo ubicado en: $filePath");

    if (context != null && context.mounted) {
      print("✅ Context válido - Mostrando diálogo de instalación manual");
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Instalación manual requerida'),
          content: Text(
              'No se pudo instalar automáticamente la actualización.\n\n'
                  'Por favor, ve a la carpeta de descargas y busca el archivo "update.apk" para instalarlo manualmente.\n\n'
                  'Ruta: $filePath'
          ),
          actions: [
            TextButton(
              onPressed: () {
                print("👤 Usuario cerró diálogo de instalación manual");
                Navigator.of(context).pop();
              },
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } else {
      print("❌ Context no válido - No se puede mostrar diálogo");
      // Aquí podrías usar un método alternativo como mostrar una notificación
      // o guardar el estado para mostrarlo más tarde
    }
  }

  // MÉTODO ADICIONAL: Usar un servicio independiente para instalación
  static Future<void> instalarApkSinContext(String filePath) async {
    try {
      print("🔄 === INSTALACIÓN SIN CONTEXT ===");

      // Verificar archivo
      final file = File(filePath);
      if (!await file.exists()) {
        print("❌ Archivo no existe: $filePath");
        return;
      }

      // Intentar con OpenFile primero (más confiable)
      final result = await OpenFile.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type == ResultType.done) {
        print("✅ Instalación iniciada con OpenFile");
        return;
      }

      // Fallback con AndroidIntent
      final AndroidIntent intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'file://$filePath',
        type: 'application/vnd.android.package-archive',
        flags: <int>[
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_GRANT_READ_URI_PERMISSION,
        ],
      );

      await intent.launch();
      print("✅ Instalación iniciada con AndroidIntent");

    } catch (e) {
      print("❌ Error en instalación sin context: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF121212),
              Color(0xFF333333),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user, color: Colors.white, size: 60),
                  const SizedBox(height: 20),
                  const Text(
                    "RestoZen Admins",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Acceso exclusivo para administradores",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Contraseña",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        "Entrar",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Tu acceso será registrado",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}