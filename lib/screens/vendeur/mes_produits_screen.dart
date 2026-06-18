import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

class MesProduitsScreen extends StatelessWidget {
  const MesProduitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mes Produits'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddProductSheet(vendeurId: uid),
        ),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Publier un produit',
            style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('vendeurId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.orange));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erreur: ${snap.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
              ),
            );
          }
          final docs = (snap.data?.docs ?? []).toList();
          docs.sort((a, b) {
            final ta = (a.data() as Map)['createdAt'];
            final tb = (b.data() as Map)['createdAt'];
            if (ta == null) return 1;
            if (tb == null) return -1;
            return (tb as Timestamp).compareTo(ta as Timestamp);
          });
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Aucun produit publié',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Appuyez sur + pour publier',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => AddProductSheet(vendeurId: uid),
                    ),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Publier mon premier produit',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final imageUrl = data['imageUrl'] ?? '';
              final status = data['status'] ?? 'actif';
              final isRecommande = data['recommande'] ?? false;
              final promoPercent = (data['promoPercent'] as num?)?.toInt() ?? 0;
              final isEnPromo = data['isEnPromo'] ?? false;
              final productId = docs[i].id;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: Column(
                  children: [
                    Row(
                      children: [
                        // ── Image ──
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                          ),
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.orange)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image,
                                    color: Colors.grey),
                              ),
                            )
                                : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image,
                                    color: Colors.grey, size: 40)),
                          ),
                        ),

                        // ── Infos ──
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                // Prix barré si promo active
                                if (isEnPromo && promoPercent > 0)
                                  Row(children: [
                                    Text(
                                      '${(data['price'] ?? 0).toStringAsFixed(0)} F',
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                          decoration:
                                          TextDecoration.lineThrough),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${((data['price'] ?? 0) * (1 - promoPercent / 100)).toStringAsFixed(0)} FCFA',
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                  ])
                                else
                                  Text(
                                    '${(data['price'] ?? 0).toStringAsFixed(0)} FCFA',
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold),
                                  ),
                                const SizedBox(height: 6),
                                // Badges
                                Wrap(spacing: 4, runSpacing: 4, children: [
                                  _badge(data['category'] ?? '', Colors.orange),
                                  if (status == 'bloque')
                                    _badge('Bloqué', Colors.red),
                                  if (isRecommande)
                                    _badge('Recommandé', Colors.green),
                                  if (isEnPromo && promoPercent > 0)
                                    _badge('-$promoPercent%', Colors.purple),
                                ]),
                              ],
                            ),
                          ),
                        ),

                        // ── Actions ──
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Éditer
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              tooltip: 'Modifier',
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => AddProductSheet(
                                  vendeurId: uid,
                                  productId: productId,
                                  existingData: data,
                                ),
                              ),
                            ),
                            // ══ NOUVEAU : Bouton promo ══
                            IconButton(
                              icon: Icon(
                                Icons.local_offer,
                                color: isEnPromo && promoPercent > 0
                                    ? Colors.purple
                                    : Colors.grey.shade400,
                              ),
                              tooltip: 'Gérer la promo',
                              onPressed: () => _showPromoDialog(
                                context,
                                productId,
                                data['name'] ?? '',
                                promoPercent,
                              ),
                            ),
                            // Supprimer
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Supprimer',
                              onPressed: () =>
                                  _deleteProduct(context, productId),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // ── Bandeau promo active ──
                    if (isEnPromo && promoPercent > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(14)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.local_offer,
                              color: Colors.purple, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Promo active : -$promoPercent% sur ce produit',
                            style: const TextStyle(
                                color: Colors.purple,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _retirerPromo(context, productId),
                            child: const Text('Retirer',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // DIALOG PROMO VENDEUR
  // ══════════════════════════════════════════════════════════════
  void _showPromoDialog(BuildContext context, String productId,
      String productName, int currentPromo) {
    int selectedPercent = currentPromo;
    final percents = [5, 10, 15, 20, 25, 30, 40, 50];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
              const Icon(Icons.local_offer, color: Colors.purple, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mettre en promo',
                        style: TextStyle(fontSize: 16)),
                    Text(productName,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.normal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choisissez une réduction :',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Option "Pas de promo"
                  GestureDetector(
                    onTap: () => setDlgState(() => selectedPercent = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedPercent == 0
                            ? Colors.grey.shade700
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selectedPercent == 0
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          width: selectedPercent == 0 ? 2 : 1,
                        ),
                      ),
                      child: Text('Aucune',
                          style: TextStyle(
                              color: selectedPercent == 0
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                  // Pourcentages
                  ...percents.map((p) => GestureDetector(
                    onTap: () => setDlgState(() => selectedPercent = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedPercent == p
                            ? Colors.purple
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selectedPercent == p
                              ? Colors.purple
                              : Colors.grey.shade300,
                          width: selectedPercent == p ? 2 : 1,
                        ),
                      ),
                      child: Text('-$p%',
                          style: TextStyle(
                              color: selectedPercent == p
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  )),
                ],
              ),
              if (selectedPercent > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        color: Colors.purple, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Vos clients verront ce produit\navec -$selectedPercent% de réduction.',
                      style: const TextStyle(
                          color: Colors.purple, fontSize: 12),
                    ),
                  ]),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('products')
                    .doc(productId)
                    .update({
                  'promoPercent': selectedPercent,
                  'isEnPromo': selectedPercent > 0,
                  'promoValidee': selectedPercent > 0,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(selectedPercent == 0
                        ? 'Promotion retirée'
                        : 'Promo -$selectedPercent% activée ! Visible par les clients.'),
                    backgroundColor:
                    selectedPercent == 0 ? Colors.grey : Colors.purple,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Appliquer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Retrait rapide depuis le bandeau
  Future<void> _retirerPromo(BuildContext context, String productId) async {
    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .update({
      'promoPercent': 0,
      'isEnPromo': false,
      'promoValidee': false,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Promotion retirée'),
        backgroundColor: Colors.grey,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _deleteProduct(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce produit ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(id)
          .delete();
    }
  }
}

// ─────────────────────────────────────────────
// BOTTOM SHEET — AJOUTER / MODIFIER PRODUIT
// ─────────────────────────────────────────────
class AddProductSheet extends StatefulWidget {
  final String vendeurId;
  final String? productId;
  final Map<String, dynamic>? existingData;

  const AddProductSheet({
    super.key,
    required this.vendeurId,
    this.productId,
    this.existingData,
  });

  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _urlCtrl   = TextEditingController();
  String _category = 'Telephones';
  // ── MODIFIÉ : ajout de 'Véhicules' pour que les vendeurs puissent
  // publier dans cette catégorie, déjà visible côté client ──
  final _categories = ['Telephones', 'Mode', 'Aliments', 'Electronique', 'Véhicules'];

  File? _imageFile;
  Uint8List? _imageBytes;
  String? _imageFileName;
  String? _existingImageUrl;
  _ImageSource _imageSource = _ImageSource.none;

  bool _loading = false;
  bool _urlLoading = false;
  String? _error;
  String? _urlError;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit && widget.existingData != null) {
      final d = widget.existingData!;
      _nameCtrl.text  = d['name'] ?? '';
      _descCtrl.text  = d['description'] ?? '';
      _priceCtrl.text = '${d['price'] ?? ''}';
      _category       = d['category'] ?? 'Telephones';
      _existingImageUrl = d['imageUrl'];
      if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
        _imageSource = _ImageSource.url;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
    if (picked == null) return;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageFileName = picked.name;
        _imageSource = _ImageSource.file;
        _urlError = null;
      });
    } else {
      setState(() {
        _imageFile = File(picked.path);
        _imageSource = _ImageSource.file;
        _urlError = null;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    if (kIsWeb) { await _pickFromGallery(); return; }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 75, maxWidth: 800);
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
      _imageSource = _ImageSource.file;
      _urlError = null;
    });
  }

  Future<void> _validateAndSetUrl(String url) async {
    if (url.trim().isEmpty) return;
    setState(() { _urlLoading = true; _urlError = null; });
    try {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !uri.scheme.startsWith('http')) {
        setState(() => _urlError = 'URL invalide.');
        return;
      }
      setState(() {
        _existingImageUrl = url.trim();
        _imageSource = _ImageSource.url;
        _imageFile = null;
        _imageBytes = null;
        _urlError = null;
      });
    } finally {
      if (mounted) setState(() => _urlLoading = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Choisir une image',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.photo_library, color: Colors.white)),
            title: const Text('Galerie du téléphone'),
            subtitle: const Text('Choisir une photo existante'),
            onTap: () { Navigator.pop(context); _pickFromGallery(); },
          ),
          if (!kIsWeb)
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Colors.deepOrange,
                  child: Icon(Icons.camera_alt, color: Colors.white)),
              title: const Text('Appareil photo'),
              subtitle: const Text('Prendre une nouvelle photo'),
              onTap: () { Navigator.pop(context); _pickFromCamera(); },
            ),
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.language, color: Colors.white)),
            title: const Text('Lien URL depuis internet'),
            subtitle: const Text('Coller un lien image trouvé en ligne'),
            onTap: () { Navigator.pop(context); _showUrlDialog(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showUrlDialog() {
    _urlCtrl.text = _existingImageUrl ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.language, color: Colors.blue),
          SizedBox(width: 8),
          Text('Image depuis internet')
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Copiez le lien image depuis votre navigateur',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'https://exemple.com/image.jpg',
                  prefixIcon: const Icon(Icons.link, color: Colors.blue),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                      const BorderSide(color: Colors.blue, width: 2)),
                ),
              ),
              if (_urlError != null) ...[
                const SizedBox(height: 8),
                Text(_urlError!,
                    style:
                    const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: _urlLoading
                ? null
                : () async {
              await _validateAndSetUrl(_urlCtrl.text);
              if (mounted && _urlError == null) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: _urlLoading
                ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('Utiliser ce lien',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadImage() async {
    if (_imageSource == _ImageSource.url) return _existingImageUrl;
    try {
      final uri =
      Uri.parse('https://api.cloudinary.com/v1_1/dv24hyvho/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = 'kenexpress_preset';

      if (kIsWeb && _imageBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file', _imageBytes!,
          filename: _imageFileName ?? 'image.jpg',
        ));
      } else if (_imageFile != null) {
        request.files
            .add(await http.MultipartFile.fromPath('file', _imageFile!.path));
      } else {
        return null;
      }

      final streamed =
      await request.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json.containsKey('error')) {
        throw Exception(json['error']['message'] ?? 'Erreur Cloudinary');
      }
      return json['secure_url'] as String?;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nom et prix sont obligatoires');
      return;
    }
    final hasImage = _imageFile != null ||
        _imageBytes != null ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);
    if (!hasImage) {
      setState(() => _error = 'Veuillez ajouter une image');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      String? imageUrl;
      if (_imageSource == _ImageSource.url) {
        imageUrl = _existingImageUrl;
      } else if (_imageFile != null || _imageBytes != null) {
        imageUrl = await _uploadImage();
      } else {
        imageUrl = _existingImageUrl;
      }

      final data = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
        'imageUrl': imageUrl ?? '',
        'category': _category,
        'vendeurId': widget.vendeurId,
        'rating': _isEdit ? (widget.existingData!['rating'] ?? 0.0) : 0.0,
        'status': 'actif',
        'recommande':
        _isEdit ? (widget.existingData!['recommande'] ?? false) : false,
        // Conservation des données promo existantes lors d'une modification
        'promoPercent': _isEdit
            ? ((widget.existingData!['promoPercent'] as num?)?.toInt() ?? 0)
            : 0,
        'isEnPromo':
        _isEdit ? (widget.existingData!['isEnPromo'] ?? false) : false,
        'promoValidee':
        _isEdit ? (widget.existingData!['promoValidee'] ?? false) : false,
        'createdAt': Timestamp.now(),
      };

      if (_isEdit) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .update(data);
      } else {
        await FirebaseFirestore.instance.collection('products').add(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Erreur : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildImagePreview() {
    if (_imageBytes != null)
      return Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity);
    if (_imageFile != null)
      return Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity);
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
          imageUrl: _existingImageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          errorWidget: (_, __, ___) => _emptyImagePlaceholder());
    }
    return _emptyImagePlaceholder();
  }

  Widget _emptyImagePlaceholder() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.add_a_photo, color: Colors.orange, size: 48),
      const SizedBox(height: 8),
      const Text('Appuyer pour ajouter une image',
          style: TextStyle(
              color: Colors.orange, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(
          kIsWeb
              ? 'Depuis votre ordinateur ou un lien URL'
              : 'Galerie · Caméra · Lien URL',
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageFile != null ||
        _imageBytes != null ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(_isEdit ? 'Modifier le produit' : 'Publier un produit',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // Image
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange, width: 2)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(children: [
                  _buildImagePreview(),
                  if (hasImage)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: _imageSource == _ImageSource.url
                                ? Colors.blue
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              _imageSource == _ImageSource.url
                                  ? Icons.language
                                  : Icons.photo_library,
                              color: Colors.white,
                              size: 12),
                          const SizedBox(width: 4),
                          Text(
                              _imageSource == _ImageSource.url
                                  ? 'URL web'
                                  : 'Galerie',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                        ]),
                      ),
                    ),
                  if (hasImage)
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('Changer',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration:
              _inputDeco('Nom du produit *', Icons.inventory_2_outlined)),
          const SizedBox(height: 12),
          TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration:
              _inputDeco('Prix (FCFA) *', Icons.payments_outlined)),
          const SizedBox(height: 12),
          TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration:
              _inputDeco('Description', Icons.description_outlined)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: _inputDeco('Catégorie', Icons.category_outlined),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12))),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Icon(_isEdit ? Icons.save : Icons.publish,
                  color: Colors.white),
              label: Text(
                _loading
                    ? (_imageSource == _ImageSource.file
                    ? 'Upload en cours...'
                    : 'Publication en cours...')
                    : _isEdit
                    ? 'Enregistrer'
                    : 'Publier le produit',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: Colors.orange),
    border:
    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange, width: 2)),
    contentPadding:
    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
  );
}

enum _ImageSource { none, file, url }