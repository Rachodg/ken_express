// ══════════════════════════════════════════════════════════════
// lib/screens/profile_screen.dart
// ══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'dart:io';
import 'complaint_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _uploadingPhoto = false;

  // ── Changer photo ──
  Future<void> _changePhoto() async {
    if (kIsWeb) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 400,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _uploadingPhoto = true);
      try {
        final imageUrl =
        await _uploadToCloudinary(bytes: bytes, filename: picked.name);
        if (imageUrl != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .update({'photoUrl': imageUrl});
        }
      } finally {
        if (mounted) setState(() => _uploadingPhoto = false);
      }
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.clientPrimary,
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _uploadPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.clientSecondary,
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _uploadPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked =
    await picker.pickImage(source: source, imageQuality: 75, maxWidth: 400);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final imageUrl = await _uploadToCloudinary(file: File(picked.path));
      if (imageUrl != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .update({'photoUrl': imageUrl});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Photo mise à jour !'),
            backgroundColor: AppColors.clientPrimary,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<String?> _uploadToCloudinary(
      {File? file, Uint8List? bytes, String? filename}) async {
    const cloudName = 'dv24hyvho';
    const uploadPreset = 'kenexpress_preset';
    final uri =
    Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset;
    if (kIsWeb && bytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: filename ?? 'photo.jpg'));
    } else if (file != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    }
    final response = await request.send();
    final body = await response.stream.bytesToString();
    final json = jsonDecode(body);
    return json['secure_url'];
  }

  // ── Modifier le profil (nom, prénom, téléphone) ──
  void _showEditProfil(
      BuildContext context, String nom, String prenom, String telephone) {
    final nomCtrl = TextEditingController(text: nom);
    final prenomCtrl = TextEditingController(text: prenom);
    final telCtrl = TextEditingController(text: telephone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modifier mon profil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: prenomCtrl,
              decoration: InputDecoration(
                labelText: 'Prénom',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nomCtrl,
              decoration: InputDecoration(
                labelText: 'Nom',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.clientPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .update({
                    'nom': nomCtrl.text.trim(),
                    'prenom': prenomCtrl.text.trim(),
                    'telephone': telCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Profil mis à jour !'),
                      backgroundColor: AppColors.clientPrimary,
                    ));
                  }
                },
                child: const Text('Enregistrer',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = user?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final nom = data['nom'] ?? '';
          final prenom = data['prenom'] ?? '';
          final email = data['email'] ?? user?.email ?? '';
          final telephone = data['telephone'] ?? '';
          final photoUrl = data['photoUrl'] ?? '';
          // Récupère la liste des favoris (tableau d'IDs de produits)
          final List favoris = data['favoris'] ?? [];

          return SingleChildScrollView(
            child: Column(
              children: [
                // ── Header dégradé rouge→bleu ──
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.clientPrimary, AppColors.clientSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 28),
                  child: Column(
                    children: [
                      // ── Photo de profil ──
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4)),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.white24,
                              child: _uploadingPhoto
                                  ? const CircularProgressIndicator(
                                  color: Colors.white)
                                  : photoUrl.isNotEmpty
                                  ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  width: 104,
                                  height: 104,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                  const Icon(Icons.person,
                                      size: 52,
                                      color: Colors.white),
                                ),
                              )
                                  : const Icon(Icons.person,
                                  size: 52, color: Colors.white),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _uploadingPhoto ? null : _changePhoto,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.15),
                                        blurRadius: 6)
                                  ],
                                ),
                                child: const Icon(Icons.camera_alt,
                                    color: AppColors.clientPrimary, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // ── Nom + bouton éditer ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$prenom $nom',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                _showEditProfil(context, nom, prenom, telephone),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(email,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      if (telephone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone,
                                  color: Colors.white60, size: 13),
                              const SizedBox(width: 4),
                              Text(telephone,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ]),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text('Client KenExpress',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Stats rapides (toutes dynamiques) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Commandes — compté en temps réel
                      _statBoxStream(
                        stream: FirebaseFirestore.instance
                            .collection('orders')
                            .where('userId', isEqualTo: uid)
                            .snapshots()
                            .map((s) => s.docs.length),
                        icon: Icons.shopping_bag,
                        label: 'Commandes',
                        color: AppColors.clientPrimary,
                        onTap: () => _showMesAchats(context, uid),
                      ),
                      const SizedBox(width: 12),
                      // Favoris — compté depuis le champ favoris du user
                      _statBoxTap(
                        icon: Icons.favorite,
                        label: 'Favoris',
                        value: '${favoris.length}',
                        color: Colors.pink,
                        onTap: () => _showMesFavoris(context, favoris, uid),
                      ),
                      const SizedBox(width: 12),
                      // Adresses — compté depuis la sous-collection adresses
                      _statBoxStream(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('adresses')
                            .snapshots()
                            .map((s) => s.docs.isEmpty ? 1 : s.docs.length),
                        icon: Icons.location_on,
                        label: 'Adresses',
                        color: AppColors.clientSecondary,
                        onTap: () =>
                            _showMesAdresses(context, data, uid),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Section Mon compte ──
                _section('Mon compte', [
                  _menuItem(
                    context,
                    Icons.shopping_bag_outlined,
                    'Mes achats',
                    AppColors.clientPrimary,
                        () => _showMesAchats(context, uid),
                  ),
                  _menuItem(
                    context,
                    Icons.favorite_outline,
                    'Mes favoris',
                    Colors.pink,
                        () => _showMesFavoris(context, favoris, uid),
                  ),
                  _menuItem(
                    context,
                    Icons.location_on_outlined,
                    'Mes adresses',
                    AppColors.clientSecondary,
                        () => _showMesAdresses(context, data, uid),
                  ),
                  _menuItem(
                    context,
                    Icons.person_outline,
                    'Modifier mon profil',
                    Colors.indigo,
                        () => _showEditProfil(context, nom, prenom, telephone),
                  ),
                  _menuItem(
                    context,
                    Icons.report_problem_outlined,
                    'Mes réclamations',
                    Colors.red,
                        () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const ComplaintScreen())),
                  ),
                ]),

                const SizedBox(height: 12),

                // ── Section Paramètres ──
                _section('Paramètres', [
                  _menuItem(
                    context,
                    Icons.notifications_outlined,
                    'Notifications',
                    Colors.orange,
                        () => _showInfo(context, 'Notifications',
                        'Fonctionnalité bientôt disponible'),
                  ),
                  _menuItem(
                    context,
                    Icons.language,
                    'Langue',
                    Colors.purple,
                        () => _showInfo(context, 'Langue', 'Français'),
                  ),
                  _menuItem(
                    context,
                    Icons.help_outline,
                    'Aide & Support',
                    Colors.teal,
                        () => _showAide(context),
                  ),
                  _menuItem(
                    context,
                    Icons.info_outline,
                    'À propos de KenExpress',
                    Colors.grey,
                        () => _showInfo(context, 'KenExpress',
                        'Version 1.0.0\nApplication de vente, achat et livraison au Burkina Faso.'),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Bouton déconnexion ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async => await AuthService().signOut(),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Se déconnecter',
                          style:
                          TextStyle(color: Colors.red, fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Stat box avec Stream (count en temps réel) ──
  Widget _statBoxStream({
    required Stream<int> stream,
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: StreamBuilder<int>(
        stream: stream,
        builder: (_, snap) {
          final count = snap.data ?? 0;
          return _statCard(icon, label, '$count', color, onTap: onTap);
        },
      ),
    );
  }

  // ── Stat box statique avec onTap ──
  Widget _statBoxTap({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(child: _statCard(icon, label, value, color, onTap: onTap));
  }

  Widget _statCard(IconData icon, String label, String value, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
          ],
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _section(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(title,
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String title,
      Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style:
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing:
      const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
      onTap: onTap,
      dense: true,
    );
  }

  // ── Modal : Mes achats ──
  void _showMesAchats(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Mes achats',
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .where('userId', isEqualTo: uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.clientPrimary));
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_bag_outlined,
                                  size: 60, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Aucun achat pour le moment',
                                  style: TextStyle(color: Colors.grey)),
                            ]),
                      );
                    }
                    return ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d =
                        docs[i].data() as Map<String, dynamic>;
                        final status = d['status'] ?? '';
                        final statusColor = status == 'livrée'
                            ? Colors.green
                            : status == 'en_livraison'
                            ? Colors.orange
                            : status == 'confirmée'
                            ? AppColors.clientSecondary
                            : Colors.grey;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.clientPrimary
                                  .withValues(alpha: 0.1),
                              child: const Icon(Icons.receipt,
                                  color: AppColors.clientPrimary,
                                  size: 18),
                            ),
                            title: Text(
                                'Commande #${docs[i].id.substring(0, 6).toUpperCase()}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            subtitle: Text(
                                '${(d['total'] ?? 0).toStringAsFixed(0)} FCFA'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(status,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Modal : Mes favoris (depuis le champ favoris[] du user) ──
  void _showMesFavoris(
      BuildContext context, List favorisIds, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Mes favoris',
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: favorisIds.isEmpty
                    ? const Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_outline,
                            size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Aucun favori pour le moment',
                            style: TextStyle(color: Colors.grey)),
                      ]),
                )
                    : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .where(FieldPath.documentId,
                      whereIn: favorisIds
                          .map((e) => e.toString())
                          .toList())
                      .snapshots(),
                  builder: (_, snap) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.pink));
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                          child: Text('Aucun produit trouvé',
                              style:
                              TextStyle(color: Colors.grey)));
                    }
                    return ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data()
                        as Map<String, dynamic>;
                        final productId = docs[i].id;
                        return Card(
                          margin:
                          const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(12)),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius:
                              BorderRadius.circular(8),
                              child: d['imageUrl'] != null &&
                                  (d['imageUrl'] as String)
                                      .isNotEmpty
                                  ? CachedNetworkImage(
                                imageUrl: d['imageUrl'],
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    Container(
                                        width: 48,
                                        height: 48,
                                        color: Colors
                                            .grey.shade200,
                                        child: const Icon(
                                            Icons
                                                .image_not_supported,
                                            color:
                                            Colors.grey)),
                              )
                                  : Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                      Icons.shopping_bag,
                                      color: Colors.grey)),
                            ),
                            title: Text(d['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            subtitle: Text(
                                '${(d['price'] ?? 0).toStringAsFixed(0)} FCFA'),
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite,
                                  color: Colors.pink),
                              onPressed: () async {
                                // Retirer des favoris
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .update({
                                  'favoris':
                                  FieldValue.arrayRemove(
                                      [productId]),
                                });
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Modal : Mes adresses ──
  void _showMesAdresses(
      BuildContext context, Map<String, dynamic> data, String uid) {
    final adresseCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mes adresses',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Adresse principale toujours présente
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color:
                    AppColors.clientPrimary.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.clientPrimary,
                  child:
                  Icon(Icons.location_on, color: Colors.white),
                ),
                title: const Text('Adresse principale',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['adresse'] ??
                    'Bobo-Dioulasso, Burkina Faso'),
                trailing: const Icon(Icons.check_circle,
                    color: AppColors.clientPrimary),
              ),
            ),
            const SizedBox(height: 16),
            // Champ pour ajouter une adresse
            TextField(
              controller: adresseCtrl,
              decoration: InputDecoration(
                labelText: 'Nouvelle adresse',
                hintText: 'Ex : Secteur 12, Bobo-Dioulasso',
                prefixIcon: const Icon(Icons.add_location_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final newAddr = adresseCtrl.text.trim();
                  if (newAddr.isEmpty) return;
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('adresses')
                      .add({
                    'adresse': newAddr,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Adresse ajoutée !'),
                          backgroundColor: AppColors.clientSecondary),
                    );
                  }
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Ajouter cette adresse',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.clientSecondary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Modal : Aide & Support ──
  void _showAide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Aide & Support',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.report_problem, color: Colors.white),
              ),
              title: const Text('Faire une réclamation'),
              subtitle: const Text('Contacter le support KenExpress'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ComplaintScreen()));
              },
            ),
            const SizedBox(height: 8),
            _contactTile(Icons.phone, 'Appelez-nous', '+226 XX XX XX XX',
                AppColors.clientPrimary),
            _contactTile(Icons.email, 'Email', 'support@kenexpress.com',
                AppColors.clientSecondary),
            _contactTile(Icons.chat, 'WhatsApp', '+226 XX XX XX XX',
                Colors.green),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(
      IconData icon, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title:
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
      ),
    );
  }

  // ── Dialog : Info simple ──
  void _showInfo(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.clientPrimary),
            child: const Text('OK',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}