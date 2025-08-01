import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/version_checker_service.dart';
import '../../widgets/sphere_3d_view.dart';


class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isDarkMode = false;
  String _locale = 'es';
  bool _showSensitiveData = true;
  List<int> highlightedIndices = [];


  final Map<String, Map<String, String>> _translations = {
    'es': {
      'panelTitle': 'Panel de Administración',
      'darkMode': 'Modo oscuro',
      'logout': 'Cerrar sesión',
      'settings': 'Ajustes',
      'noRestaurants': 'No hay restaurantes registrados.',
      'approve': 'Aprobar',
      'reject': 'Rechazar',
      'toggleRole': 'Cambiar Rol',
      'language': 'Idioma',
      'showData': 'Mostrar datos',
      'hideData': 'Ocultar datos',
    },
    'en': {
      'panelTitle': 'Admin Panel',
      'darkMode': 'Dark Mode',
      'logout': 'Log out',
      'settings': 'Settings',
      'noRestaurants': 'No restaurants registered.',
      'approve': 'Approve',
      'reject': 'Reject',
      'toggleRole': 'Toggle Role',
      'language': 'Language',
      'showData': 'Show data',
      'hideData': 'Hide data',
    }
  };

  String t(String key) => _translations[_locale]?[key] ?? key;

  @override
  void initState() {
    super.initState();
    VersionCheckerService.startPeriodicCheck(context);
    _loadPreferences();
    Future.microtask(() async {
      await _loadRestaurantIndices();
    });
  }

  @override
  void dispose() {
    VersionCheckerService.stop();
    super.dispose();
  }

  Future<void> _loadRestaurantIndices() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('restaurants').get();
      final indices = List.generate(snapshot.docs.length, (index) => index % 300)
          .toSet()
          .toList();
      // ✅ CORRECCIÓN: Asignar 'indices' a 'highlightedIndices'
      setState(() {
        highlightedIndices = indices;
      });
    } catch (e) {
      print('Error al cargar restaurantes: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      _locale = prefs.getString('locale') ?? 'es';
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _isDarkMode);
    await prefs.setString('locale', _locale);
  }

  IconData _getStarIcon(String? plan) {
    switch (plan) {
      case 'premium':
        return Icons.star;
      case 'pro':
        return Icons.star_border;
      default:
        return Icons.star_border;
    }
  }

  Color _getStarColor(String? plan) {
    switch (plan) {
      case 'premium':
      case 'pro':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantsRef = FirebaseFirestore.instance.collection('restaurants');
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Theme(
      data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('panelTitle')),
          actions: [
            IconButton(
              icon: Icon(_showSensitiveData ? Icons.visibility : Icons.visibility_off),
              tooltip: _showSensitiveData ? t('hideData') : t('showData'),
              onPressed: () => setState(() => _showSensitiveData = !_showSensitiveData),
            ),
          ],
        ),
        drawer: SizedBox(
          width: 260, // << AQUI el cambio de ancho
          child: _buildDrawer(currentUserUid),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: restaurantsRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return Center(child: Text(t('noRestaurants'), style: const TextStyle(fontSize: 18)));
            }

            final adminDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['role'] == 'admin';
            }).toList();

            final restoDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['role'] != 'admin';
            }).toList();

            final combinedDocs = [...adminDocs, if (adminDocs.isNotEmpty && restoDocs.isNotEmpty) null, ...restoDocs];

            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: combinedDocs.length,
                itemBuilder: (context, index) {
                  final doc = combinedDocs[index];

                  if (doc == null) return const Divider(height: 32, thickness: 2);

                  final data = doc.data() as Map<String, dynamic>;
                  final isAdmin = data['role'] == 'admin';
                  final status = data['status'] ?? 'pending';
                  final isCurrentUser = doc.id == currentUserUid;

                  Color statusColor;
                  IconData statusIcon;
                  if (status == 'approved') {
                    statusColor = Colors.green.shade600;
                    statusIcon = Icons.check_circle;
                  } else {
                    statusColor = Colors.orange.shade600;
                    statusIcon = Icons.hourglass_empty;
                  }

                  return _buildRestaurantCard(
                    docId: doc.id,
                    data: data,
                    isAdmin: isAdmin,
                    isCurrentUser: isCurrentUser,
                    status: status,
                    statusColor: statusColor,
                    statusIcon: statusIcon,
                    restaurantsRef: restaurantsRef,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawer(String? currentUserUid) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _isDarkMode ? Colors.black87 : Colors.white,
              _isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 50),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    height: 58, // Aumenta un poco para permitir centrado vertical
                    child: Center(
                      child: Sphere3DView(
                        pointCount: 300,
                        pointSize: 1.0,
                        highlightedIndices: highlightedIndices,
                        nameTextSize: 14.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 1, top: 35), // << Aumentado top
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start, // << Cambiado de center
                        children: [
                          Text(
                            FirebaseAuth.instance.currentUser?.email ?? "Admin",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4), // Más espacio si quieres
                          Text(
                            "Administrador",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(0),
                children: [
                  const SizedBox(height: 10),
                  ListTileTheme(
                    iconColor: _isDarkMode ? Colors.white : Color(0xFF928DAB),
                    textColor: _isDarkMode ? Colors.white : Colors.black87,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: Row(
                            children: [
                              Text("${t('language')}: "),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                dropdownColor: _isDarkMode ? Colors.grey[850] : Colors.white,
                                value: _locale,
                                style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'es', child: Text('Español')),
                                  DropdownMenuItem(value: 'en', child: Text('English')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _locale = value);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.brightness_6),
                          title: Text(t('darkMode')),
                          trailing: Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: _isDarkMode,
                              onChanged: (value) => setState(() {
                                _isDarkMode = value;
                                _savePreferences();
                              }),
                              activeColor: Color(0xFF928DAB),
                            ),
                          ),
                        ),
                        const Divider(height: 30, thickness: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 1.0),
                            dense: true,
                            leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                            title: Text(
                              t('logout'),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () async {
                              await FirebaseAuth.instance.signOut();
                              if (!mounted) return;
                              Navigator.of(context).pushReplacementNamed('/');
                            },
                          ),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildRestaurantCard({
    required String docId,
    required Map<String, dynamic> data,
    required bool isAdmin,
    required bool isCurrentUser,
    required String status,
    required Color statusColor,
    required IconData statusIcon,
    required CollectionReference restaurantsRef,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xA3757575) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isAdmin ? Colors.green.shade700 : Colors.grey.shade400,
                  child: Icon(isAdmin ? Icons.verified_user : Icons.restaurant, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          data["restaurantName"] ?? "Sin nombre",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _isDarkMode ? Colors.white : const Color(0xFF2F2F2F),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _getStarIcon(data["plan"]),
                        size: 18,
                        color: _getStarColor(data["plan"]),
                      ),
                    ],
                  ),
                ),
                if (!isCurrentUser)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: _isDarkMode ? Colors.white : Theme.of(context).primaryColor,
                    ),
                    onSelected: (value) async {
                      if (value == "approve") {
                        await restaurantsRef.doc(docId).update({"status": "approved"});
                      } else if (value == "reject") {
                        await restaurantsRef.doc(docId).update({"status": "pending"});
                      } else if (value == "toggleRole") {
                        final currentRole = data["role"] ?? "guest";
                        final newRole = currentRole == "admin" ? "guest" : "admin";
                        await restaurantsRef.doc(docId).update({"role": newRole});
                      } else if (value == "editPlan") {
                        final selectedPlan = await showDialog<String>(
                          context: context,
                          builder: (ctx) {
                            String? selected = data['plan'] ?? 'basic';
                            return AlertDialog(
                              title: const Text("Seleccionar Plan"),
                              content: StatefulBuilder(
                                builder: (context, setState) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: ['basic', 'pro', 'premium'].map((plan) {
                                    return RadioListTile<String>(
                                      title: Text(plan),
                                      value: plan,
                                      groupValue: selected,
                                      onChanged: (value) {
                                        setState(() => selected = value!);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                                TextButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text("Guardar")),
                              ],
                            );
                          },
                        );

                        if (selectedPlan != null && selectedPlan != data['plan']) {
                          await restaurantsRef.doc(docId).update({"plan": selectedPlan});
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: "approve", child: Text(t('approve'))),
                      PopupMenuItem(value: "reject", child: Text(t('reject'))),
                      PopupMenuItem(value: "toggleRole", child: Text(t('toggleRole'))),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: "editPlan", child: Text("Editar plan")),
                    ],
                  )
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Email: ${_showSensitiveData ? (data["ownerEmail"] ?? "") : "••••••••"}",
              style: TextStyle(fontSize: 12, color: _isDarkMode ? Colors.white : const Color(0xFF6C6C6C)),
            ),
            const SizedBox(height: 2),
            Text(
              "Rol: ${_showSensitiveData ? (data["role"] ?? "guest") : "••••"}",
              style: TextStyle(fontSize: 12, color: _isDarkMode ? Colors.white : const Color(0xFF6C6C6C)),
            ),
            const SizedBox(height: 2),
            Text(
              "Plan: ${_showSensitiveData ? (data["plan"] ?? "basic") : "••••"}",
              style: TextStyle(fontSize: 12, color: _isDarkMode ? Colors.white : const Color(0xFF6C6C6C)),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 4),
                Text(status, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
