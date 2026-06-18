// ══════════════════════════════════════════════════════════════
// vendeur_profil_screen.dart — Profil vendeur + Solde + Retrait
// AJOUTS :
//  1. Carte "Mon Solde" visible dans le profil avec :
//     - Solde disponible (vert)
//     - Solde en attente (orange)
//     - Solde bloqué retrait (gris)
//  2. Bouton "Demander un retrait" → BottomSheet avec choix
//     méthode de paiement + numéro + montant
//  3. Historique des retraits
// ══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/payment_service.dart';
import '../complaint_screen.dart';
import '../notifications_screen.dart';

class VendeurProfilScreen extends StatefulWidget {
  // Permet de changer d'onglet dans VendeurNavigation (0=Dashboard, 1=Produits,
  // 2=Commandes, 3=Messages, 4=Profil) au lieu de pousser un écran sans bouton retour.
  final void Function(int) onNavigate;
  const VendeurProfilScreen({super.key, required this.onNavigate});
  @override
  State<VendeurProfilScreen> createState() => _VendeurProfilScreenState();
}

class _VendeurProfilScreenState extends State<VendeurProfilScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _uploadingPhoto = false;
  bool _loadingLocation = false;

  // ══════════════════════════════════════════════════════════════
  // PHOTO
  // ══════════════════════════════════════════════════════════════
  Future<void> _changePhoto() async {
    if (kIsWeb) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 75, maxWidth: 400);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _uploadingPhoto = true);
      try {
        final url = await _uploadToCloudinary(bytes: bytes, filename: picked.name);
        if (url != null) {
          await FirebaseFirestore.instance
              .collection('users').doc(user!.uid).update({'photoUrl': url});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Photo mise à jour !'), backgroundColor: Colors.orange));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Echec de l\'envoi de la photo'), backgroundColor: Colors.red));
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
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.orange,
                child: Icon(Icons.photo_library, color: Colors.white)),
            title: const Text('Galerie'),
            onTap: () { Navigator.pop(context); _uploadPhoto(ImageSource.gallery); },
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.deepOrange,
                child: Icon(Icons.camera_alt, color: Colors.white)),
            title: const Text('Appareil photo'),
            onTap: () { Navigator.pop(context); _uploadPhoto(ImageSource.camera); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _uploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 400);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await _uploadToCloudinary(file: File(picked.path));
      if (url != null) {
        await FirebaseFirestore.instance
            .collection('users').doc(user!.uid).update({'photoUrl': url});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Photo mise à jour !'), backgroundColor: Colors.orange));
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

  // ══════════════════════════════════════════════════════════════
  // LOCALISATION RÉELLE (GPS)
  // ══════════════════════════════════════════════════════════════
  Future<void> _majLocalisation() async {
    setState(() => _loadingLocation = true);
    try {
      // 1. Vérifier que le service de localisation est activé
      final serviceActif = await Geolocator.isLocationServiceEnabled();
      if (!serviceActif) {
        throw Exception('Activez la localisation (GPS) sur votre appareil');
      }

      // 2. Vérifier / demander la permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Permission de localisation refusée');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission refusée définitivement. Activez-la dans les paramètres de l\'application.');
      }

      // 3. Récupérer la position GPS réelle
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 4. Enregistrer dans Firestore
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'localisation': {
          'latitude':  position.latitude,
          'longitude': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Localisation mise à jour !'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<String?> _uploadToCloudinary({File? file, Uint8List? bytes, String? filename}) async {
    Uint8List? imageBytes;
    String ext = 'jpg';
    if (kIsWeb && bytes != null) {
      imageBytes = bytes;
      ext = (filename?.split('.').last ?? 'jpg').toLowerCase();
    } else if (file != null) {
      imageBytes = await file.readAsBytes();
      ext = file.path.split('.').last.toLowerCase();
    }
    if (!['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext)) ext = 'jpg';
    if (imageBytes == null) return null;
    final base64Image = base64Encode(imageBytes);
    final dataUri = 'data:image/$ext;base64,$base64Image';

    // public_id propre, sans slash ni caractère spécial
    final safePublicId =
        'profil_${user?.uid ?? "anonyme"}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/dv24hyvho/image/upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file': dataUri,
          'upload_preset': 'kenexpress_preset',
          'public_id': safePublicId,
          // filename_override est autorisé en unsigned upload et empêche
          // Cloudinary de dériver un nom depuis le fichier original.
          // (display_name n'est PAS autorisé en unsigned upload — à éviter)
          'filename_override': safePublicId,
        }),
      ).timeout(const Duration(seconds: 60));
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json.containsKey('error')) throw Exception(json['error']['message']);
      return json['secure_url'] as String?;
    } catch (e) { rethrow; }
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final uid = user?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final photoUrl   = data['photoUrl'] ?? '';
          final prenom     = data['prenom'] ?? '';
          final nom        = data['nom'] ?? '';
          final email      = data['email'] ?? user?.email ?? '';
          final telephone  = data['telephone'] ?? '';

          return SingleChildScrollView(
            child: Column(
              children: [
                // ── Header dégradé orange ──
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6F00), Color(0xFFFFA726)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 52, 16, 28),
                  child: Column(children: [
                    Stack(children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.white24,
                          child: _uploadingPhoto
                              ? const CircularProgressIndicator(color: Colors.white)
                              : photoUrl.isNotEmpty
                              ? ClipOval(child: CachedNetworkImage(
                            imageUrl: photoUrl, width: 104, height: 104, fit: BoxFit.cover,
                            placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
                            errorWidget: (_, __, ___) => const Icon(Icons.store, size: 52, color: Colors.white),
                          ))
                              : const Icon(Icons.store, size: 52, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: GestureDetector(
                          onTap: _uploadingPhoto ? null : _changePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.orange, size: 18),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Text('$prenom $nom',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    if (telephone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.phone, color: Colors.white60, size: 13),
                        const SizedBox(width: 4),
                        Text(telephone, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ]),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white24, borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('Vendeur KenExpress',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── Stats ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(child: _statStream(uid, 'Produits', Icons.inventory_2, Colors.blue, 'products')),
                    const SizedBox(width: 10),
                    Expanded(child: _statStream(uid, 'Commandes', Icons.receipt_long, Colors.green, 'orders')),
                    const SizedBox(width: 10),
                    Expanded(child: _revenueBox(uid)),
                  ]),
                ),

                const SizedBox(height: 20),

                // ══════════════════════════════════════════
                // CARTE SOLDE VIRTUEL (NOUVEAU)
                // ══════════════════════════════════════════
                _SoldeCard(uid: uid),

                const SizedBox(height: 20),

                // ── Ma boutique ──
                _section('Ma boutique', [
                  _menuItem(Icons.store_outlined, 'Informations boutique', Colors.orange,
                          () => _showEditBoutique(context, data)),
                  _menuItem(Icons.location_on_outlined, 'Localisation', Colors.red,
                          () => _showLocalisationDialog(context, data)),
                  _menuItem(Icons.photo_camera_outlined, 'Photo de profil', Colors.purple,
                          () => _changePhoto()),
                ]),

                const SizedBox(height: 12),

                _section('Mon compte', [
                  _menuItem(Icons.inventory_2_outlined, 'Mes produits', Colors.blue,
                          () => widget.onNavigate(1)),
                  _menuItem(Icons.receipt_long_outlined, 'Mes commandes', Colors.green,
                          () => widget.onNavigate(2)),
                  _menuItem(Icons.payments_outlined, 'Mes revenus', const Color(0xFF2E7D32),
                          () => _showRevenus(context, uid)),
                  _menuItem(Icons.report_problem_outlined, 'Mes réclamations', Colors.red, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintScreen()));
                  }),
                ]),

                const SizedBox(height: 12),

                _section('Paramètres', [
                  _menuItem(Icons.notifications_outlined, 'Notifications', Colors.orange,
                          () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => NotificationsScreen(
                              isVendeur: true, onNavigateVendeur: widget.onNavigate)))),
                  _menuItem(Icons.help_outline, 'Aide & Support', Colors.teal, () => _showAide(context)),
                  _menuItem(Icons.info_outline, 'À propos', Colors.grey,
                          () => _showInfo(context, 'KenExpress', 'Version 1.0.0\nPlateforme de vente au Burkina Faso.')),
                ]),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity, height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async => await FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Se déconnecter', style: TextStyle(color: Colors.red, fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ══════════════════════════════════════════════════════════════
  // WIDGETS HELPERS
  // ══════════════════════════════════════════════════════════════
  Widget _statStream(String uid, String label, IconData icon, Color color, String type) {
    final stream = type == 'products'
        ? FirebaseFirestore.instance.collection('products').where('vendeurId', isEqualTo: uid).snapshots()
        : FirebaseFirestore.instance.collection('orders').where('vendeurId', isEqualTo: uid).snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) => _statBox(icon, label, '${snap.data?.docs.length ?? 0}', color),
    );
  }

  Widget _revenueBox(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('sellers').doc(uid).snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final total = (data?['totalGagne'] as num?)?.toDouble() ?? 0;
        final display = total >= 1000 ? '${(total / 1000).toStringAsFixed(0)}K' : total.toStringAsFixed(0);
        return _statBox(Icons.payments, 'Revenus', '${display}F', const Color(0xFF2E7D32));
      },
    );
  }

  Widget _statBox(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ]),
    );
  }

  Widget _section(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
      onTap: onTap, dense: true,
    );
  }

  void _showEditBoutique(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Informations boutique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _infoRow(Icons.person, 'Nom', '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'),
          _infoRow(Icons.email, 'Email', data['email'] ?? ''),
          _infoRow(Icons.phone, 'Téléphone', data['telephone'] ?? ''),
          _infoRow(Icons.location_on, 'Localisation', (() {
            final loc = data['localisation'] as Map<String, dynamic>?;
            final lat = (loc?['latitude'] as num?)?.toDouble();
            final lng = (loc?['longitude'] as num?)?.toDouble();
            if (lat == null || lng == null) return 'Non renseignée';
            return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
          })()),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Fermer', style: TextStyle(color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: Colors.orange, size: 18), const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ]),
      ]),
    );
  }

  void _showRevenus(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Mes revenus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('sellers').doc(uid).snapshots(),
              builder: (_, snap) {
                final data = snap.data?.data() as Map<String, dynamic>?;
                final solde         = (data?['solde'] as num?)?.toDouble() ?? 0;
                final soldeAttente  = (data?['soldeEnAttente'] as num?)?.toDouble() ?? 0;
                final soldeBloque   = (data?['soldeBloque'] as num?)?.toDouble() ?? 0;
                final totalGagne    = (data?['totalGagne'] as num?)?.toDouble() ?? 0;
                return Column(children: [
                  _revRow(Icons.payments, 'Total gagné', '${totalGagne.toStringAsFixed(0)} FCFA', const Color(0xFF2E7D32)),
                  const SizedBox(height: 8),
                  _revRow(Icons.account_balance_wallet, 'Solde disponible', '${solde.toStringAsFixed(0)} FCFA', Colors.green),
                  const SizedBox(height: 8),
                  _revRow(Icons.hourglass_bottom, 'En attente', '${soldeAttente.toStringAsFixed(0)} FCFA', Colors.orange),
                  const SizedBox(height: 8),
                  _revRow(Icons.send_to_mobile, 'Retrait en cours', '${soldeBloque.toStringAsFixed(0)} FCFA', Colors.blueGrey),
                ]);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _revRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: color), const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  void _showAide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Support vendeur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.report_problem, color: Colors.white)),
            title: const Text('Faire une réclamation'),
            subtitle: const Text('Contacter le support KenExpress'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintScreen())); },
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.chat, color: Colors.white)),
            title: const Text('WhatsApp'), subtitle: const Text('+226 XX XX XX XX'),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.phone, color: Colors.white)),
            title: const Text('Téléphone'), subtitle: const Text('+226 XX XX XX XX'),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.email, color: Colors.white)),
            title: const Text('Email'), subtitle: const Text('support@kenexpress.com'),
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  void _showLocalisationDialog(BuildContext context, Map<String, dynamic> data) {
    final loc = data['localisation'] as Map<String, dynamic>?;
    final lat = (loc?['latitude'] as num?)?.toDouble();
    final lng = (loc?['longitude'] as num?)?.toDouble();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Localisation de ma boutique'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (lat != null && lng != null) ...[
              Text('Latitude : ${lat.toStringAsFixed(6)}'),
              Text('Longitude : ${lng.toStringAsFixed(6)}'),
              const SizedBox(height: 8),
            ] else
              const Text('Aucune position enregistrée pour le moment.',
                  style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            const Text(
              'Activez votre GPS et appuyez sur le bouton ci-dessous pour partager votre position réelle. '
                  'Les clients pourront ainsi voir où se trouve votre boutique.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
            ElevatedButton.icon(
              onPressed: _loadingLocation ? null : () async {
                await _majLocalisation();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: _loadingLocation
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18, color: Colors.white),
              label: Text(_loadingLocation ? 'Localisation...' : 'Utiliser ma position actuelle',
                  style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title), content: Text(content),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════
// CARTE SOLDE VIRTUEL (NOUVEAU)
// ══════════════════════════════════════════════════════════════
class _SoldeCard extends StatelessWidget {
  final String uid;
  const _SoldeCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('sellers').doc(uid).snapshots(),
      builder: (context, snap) {
        final data          = snap.data?.data() as Map<String, dynamic>?;
        final solde         = (data?['solde'] as num?)?.toDouble() ?? 0;
        final soldeAttente  = (data?['soldeEnAttente'] as num?)?.toDouble() ?? 0;
        final soldeBloque   = (data?['soldeBloque'] as num?)?.toDouble() ?? 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            children: [
              // ── Solde principal ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.account_balance_wallet, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                    const SizedBox(height: 8),
                    Text('${solde.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    // Solde en attente + bloqué
                    Row(children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('En attente', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text('${soldeAttente.toStringAsFixed(0)} F',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Retrait en cours', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text('${soldeBloque.toStringAsFixed(0)} F',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ]),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),

              // ── Bouton retrait ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: solde <= 0
                        ? null
                        : () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                      builder: (_) => _RetraitSheet(uid: uid, solde: solde),
                    ),
                    icon: const Icon(Icons.send_to_mobile, size: 18),
                    label: Text(
                      solde <= 0 ? 'Solde insuffisant' : 'Demander un retrait',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2E7D32),
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
                      disabledForegroundColor: Colors.white60,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

              // ── Historique retraits ──
              _HistoriqueRetraits(uid: uid),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HISTORIQUE DES RETRAITS
// ══════════════════════════════════════════════════════════════
class _HistoriqueRetraits extends StatelessWidget {
  final String uid;
  const _HistoriqueRetraits({required this.uid});

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      return '—';
    }
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('retraits')
          .where('sellerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        // Tri local
        docs.sort((a, b) {
          final aTs = (a.data() as Map)['createdAt'];
          final bTs = (b.data() as Map)['createdAt'];
          if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
          return 0;
        });
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: const Text('Historique des retraits',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            ...docs.take(5).map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final statut    = d['statut'] ?? 'en_attente';
              final montant   = (d['montant'] as num?)?.toDouble() ?? 0;
              final methode   = d['methode'] ?? '';
              final motifRejet = (d['motifRejet'] ?? '').toString();

              Color sColor;
              IconData sIcon;
              switch (statut) {
                case 'paye':    sColor = Colors.greenAccent; sIcon = Icons.check_circle; break;
                case 'rejete':  sColor = Colors.redAccent;   sIcon = Icons.cancel;       break;
                default:        sColor = Colors.orangeAccent; sIcon = Icons.hourglass_bottom;
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(sIcon, color: sColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${montant.toStringAsFixed(0)} FCFA · $methode',
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                      Text(_formatDate(d['createdAt']),
                          style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ]),
                    if (statut == 'rejete' && motifRejet.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 24, top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Motif du rejet : $motifRejet',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FORMULAIRE DEMANDE DE RETRAIT
// ══════════════════════════════════════════════════════════════
class _RetraitSheet extends StatefulWidget {
  final String uid;
  final double solde;
  const _RetraitSheet({required this.uid, required this.solde});

  @override
  State<_RetraitSheet> createState() => _RetraitSheetState();
}

class _RetraitSheetState extends State<_RetraitSheet> {
  String? _methode;
  final _montantCtrl = TextEditingController();
  final _numeroCtrl  = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _methodes = [
    (key: 'orange_money',  label: 'Orange Money',  color: Color(0xFFFF6600)),
    (key: 'moov_money',    label: 'Moov Money',    color: Color(0xFF0066CC)),
    (key: 'telecel_money', label: 'Telecel Money', color: Color(0xFFCC0000)),
    (key: 'wave',          label: 'Wave',          color: Color(0xFF009688)),
  ];

  @override
  void dispose() {
    _montantCtrl.dispose();
    _numeroCtrl.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    if (_methode == null) { setState(() => _error = 'Choisissez un moyen de retrait'); return; }
    final montant = double.tryParse(_montantCtrl.text.trim().replaceAll(' ', ''));
    if (montant == null || montant <= 0) { setState(() => _error = 'Entrez un montant valide'); return; }
    if (montant > widget.solde) { setState(() => _error = 'Montant supérieur à votre solde disponible'); return; }
    if (_numeroCtrl.text.trim().isEmpty) { setState(() => _error = 'Entrez votre numéro de réception'); return; }

    setState(() { _loading = true; _error = null; });
    try {
      await PaymentService().demanderRetrait(
        sellerId:      widget.uid,
        montant:       montant,
        methode:       _methode!,
        numeroRetrait: _numeroCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande de retrait soumise ! L\'admin va traiter votre demande.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Titre
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.send_to_mobile, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Demande de retrait',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Solde disponible : ${widget.solde.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 20),

          // Choix méthode
          const Text('Moyen de retrait', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 2.8,
            children: _methodes.map((m) {
              final selected = _methode == m.key;
              return GestureDetector(
                onTap: () => setState(() => _methode = m.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? m.color : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? m.color : Colors.grey.shade300, width: selected ? 2 : 1),
                  ),
                  child: Center(
                    child: Text(m.label, style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Montant
          const Text('Montant à retirer (FCFA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _montantCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Ex : 5000',
              prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.green, width: 2)),
            ),
          ),
          const SizedBox(height: 12),

          // Numéro
          const Text('Numéro de réception', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _numeroCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Ex : 07X XXX XXX',
              prefixIcon: const Icon(Icons.phone, color: Colors.green),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.green, width: 2)),
            ),
          ),
          const SizedBox(height: 16),

          // Erreur
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200)),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),

          // Bouton
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _soumettre,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(_loading ? 'Envoi...' : 'Soumettre la demande',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'admin traitera votre demande et vous enverra l\'argent sur le numéro indiqué.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ]),
      ),
    );
  }
}
