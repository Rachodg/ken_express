import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../main.dart';
import '../notifications_screen.dart';
import '../../services/notification_service.dart';
import '../../services/payment_service.dart';
import 'admin_complaints_screen.dart';
import 'admin_pubs_screen.dart';
import 'admin_livraisons_tab.dart';
import 'package:intl/intl.dart';

const String kAdminEmail = 'ouedraogokrachid@gmail.com';

// ── Barre de recherche réutilisable pour les onglets admin ──
class AdminSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const AdminSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hint = 'Rechercher...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: onClear,
          )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late final Stream<int> _commandesEnAttente = FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'en_attente')
      .snapshots()
      .map((s) => s.docs.length);

  late final Stream<int> _paiementsEnAttente = FirebaseFirestore.instance
      .collection('paiements')
      .where('statut', isEqualTo: 'en_attente')
      .snapshots()
      .map((s) => s.docs.length);

  late final Stream<int> _retraitsEnAttente = FirebaseFirestore.instance
      .collection('retraits')
      .where('statut', isEqualTo: 'en_attente')
      .snapshots()
      .map((s) => s.docs.length);

  late final Stream<int> _reclamationsOuvertes = FirebaseFirestore.instance
      .collection('complaints')
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((s) => s.docs.length);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
    NotificationService().init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _tabAvecBadge({
    required IconData icon,
    required String label,
    required Stream<int> stream,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Tab(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 11)),
                ],
              ),
              if (count > 0)
                Positioned(
                  top: -6,
                  right: -14,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    constraints:
                    const BoxConstraints(minWidth: 17, minHeight: 17),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Administration KenExpress'),
        ]),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          StreamBuilder<int>(
            stream: NotificationService().getUnreadCount(uid),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(clipBehavior: Clip.none, children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                          const NotificationsScreen(isVendeur: false))),
                ),
                if (count > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: const BoxDecoration(
                          color: Colors.amber, shape: BoxShape.circle),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ]);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: [
            const Tab(icon: Icon(Icons.people, size: 18), text: 'Utilisateurs'),
            const Tab(icon: Icon(Icons.inventory_2, size: 18), text: 'Produits'),
            const Tab(icon: Icon(Icons.star, size: 18), text: 'Recommandes'),
            const Tab(icon: Icon(Icons.local_offer, size: 18), text: 'Promos'),
            const Tab(icon: Icon(Icons.campaign, size: 18), text: 'Publicites'),
            _tabAvecBadge(
              icon: Icons.receipt_long,
              label: 'Commandes',
              stream: _commandesEnAttente,
            ),
            _tabAvecBadge(
              icon: Icons.support_agent,
              label: 'Reclamations',
              stream: _reclamationsOuvertes,
            ),
            _tabAvecBadge(
              icon: Icons.payments,
              label: 'Paiements',
              stream: _paiementsEnAttente,
            ),
            _tabAvecBadge(
              icon: Icons.account_balance_wallet,
              label: 'Retraits',
              stream: _retraitsEnAttente,
            ),
            const Tab(
                icon: Icon(Icons.delivery_dining, size: 18),
                text: 'Livraisons'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UsersTab(),
          _ProduitsTab(),
          _RecommandesTab(),
          _PromosTab(),
          const AdminPubsScreen(),
          _CommandesTab(),
          const AdminComplaintsScreen(embedded: true),
          const _PaiementsTab(),
          const _RetraitsTab(),
          const AdminLivraisonsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
enum _Periode { tout, jour, semaine, mois }

extension on _Periode {
  String get label {
    switch (this) {
      case _Periode.tout:
        return 'Tout';
      case _Periode.jour:
        return 'Aujourd\'hui';
      case _Periode.semaine:
        return '7 jours';
      case _Periode.mois:
        return '30 jours';
    }
  }

  DateTime? get debut {
    final now = DateTime.now();
    switch (this) {
      case _Periode.tout:
        return null;
      case _Periode.jour:
        return DateTime(now.year, now.month, now.day);
      case _Periode.semaine:
        return now.subtract(const Duration(days: 7));
      case _Periode.mois:
        return now.subtract(const Duration(days: 30));
    }
  }
}

DateTime? _dateDeChamp(dynamic ts) {
  if (ts is Timestamp) return ts.toDate();
  if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
  return null;
}

List<QueryDocumentSnapshot> _filtrerParPeriode(
    List<QueryDocumentSnapshot> docs, _Periode periode) {
  final debut = periode.debut;
  if (debut == null) return docs;
  return docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = _dateDeChamp(data['createdAt']);
    return date != null && date.isAfter(debut);
  }).toList();
}

Widget _periodeSelector(_Periode value, ValueChanged<_Periode> onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      const Icon(Icons.filter_list, size: 16, color: Colors.grey),
      const SizedBox(width: 8),
      const Text('Periode :',
          style: TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(width: 8),
      DropdownButton<_Periode>(
        value: value,
        underline: const SizedBox(),
        style: const TextStyle(
            color: AppColors.adminPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold),
        items: _Periode.values
            .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
            .toList(),
        onChanged: (p) {
          if (p != null) onChanged(p);
        },
      ),
    ]),
  );
}

// ─────────────────────────────────────────────
// HELPER : vérification montant paiement vs commande
// Retourne null si OK, sinon le montant attendu
// ─────────────────────────────────────────────
Future<double?> _getMontantCommandeAttendu(String commandeId) async {
  if (commandeId.isEmpty) return null;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(commandeId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    return (data['total'] ?? 0).toDouble();
  } catch (_) {
    return null;
  }
}

bool _montantCorrespond(double montantPaiement, double montantCommande) {
  // Tolérance de 1 FCFA pour les arrondis
  return (montantPaiement - montantCommande).abs() <= 1;
}

// ─────────────────────────────────────────────
// ONGLET PAIEMENTS
// ─────────────────────────────────────────────
class _PaiementsTab extends StatefulWidget {
  const _PaiementsTab();
  @override
  State<_PaiementsTab> createState() => _PaiementsTabState();
}

class _PaiementsTabState extends State<_PaiementsTab> {
  bool _historique = false;
  _Periode _periode = _Periode.tout;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late final Stream<QuerySnapshot> _enAttenteTous =
  PaymentService().paiementsEnAttente();
  late final Stream<QuerySnapshot> _enAttenteOrange =
  PaymentService().paiementsEnAttenteParMethode('orange_money');
  late final Stream<QuerySnapshot> _enAttenteMoov =
  PaymentService().paiementsEnAttenteParMethode('moov_money');
  late final Stream<QuerySnapshot> _enAttenteTelecel =
  PaymentService().paiementsEnAttenteParMethode('telecel_money');
  late final Stream<QuerySnapshot> _enAttenteWave =
  PaymentService().paiementsEnAttenteParMethode('wave');

  late final Stream<QuerySnapshot> _histTous =
  PaymentService().historiquePaiements();
  late final Stream<QuerySnapshot> _histOrange =
  PaymentService().historiquePaiementsParMethode('orange_money');
  late final Stream<QuerySnapshot> _histMoov =
  PaymentService().historiquePaiementsParMethode('moov_money');
  late final Stream<QuerySnapshot> _histTelecel =
  PaymentService().historiquePaiementsParMethode('telecel_money');
  late final Stream<QuerySnapshot> _histWave =
  PaymentService().historiquePaiementsParMethode('wave');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          AdminSearchBar(
            controller: _searchCtrl,
            hint: 'Rechercher un paiement (numero, reference)...',
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          ),
          Container(
            color: Colors.white,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Expanded(
                      child: _toggleBtn('En attente', !_historique,
                              () => setState(() => _historique = false))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _toggleBtn('Historique', _historique,
                              () => setState(() => _historique = true))),
                ]),
              ),
              if (_historique)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _periodeSelector(
                      _periode, (p) => setState(() => _periode = p)),
                ),
              const TabBar(
                isScrollable: true,
                indicatorColor: AppColors.adminPrimary,
                labelColor: AppColors.adminPrimary,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Tous'),
                  Tab(text: 'Orange'),
                  Tab(text: 'Moov'),
                  Tab(text: 'Telecel'),
                  Tab(text: 'Wave'),
                ],
              ),
            ]),
          ),
          Expanded(
            child: _historique
                ? TabBarView(
              children: [
                _PaiementsHistoriqueList(
                    stream: _histTous,
                    periode: _periode,
                    searchQuery: _searchQuery),
                _PaiementsHistoriqueList(
                    stream: _histOrange,
                    periode: _periode,
                    searchQuery: _searchQuery),
                _PaiementsHistoriqueList(
                    stream: _histMoov,
                    periode: _periode,
                    searchQuery: _searchQuery),
                _PaiementsHistoriqueList(
                    stream: _histTelecel,
                    periode: _periode,
                    searchQuery: _searchQuery),
                _PaiementsHistoriqueList(
                    stream: _histWave,
                    periode: _periode,
                    searchQuery: _searchQuery),
              ],
            )
                : TabBarView(
              children: [
                _PaiementsList(
                    stream: _enAttenteTous,
                    searchQuery: _searchQuery),
                _PaiementsList(
                    stream: _enAttenteOrange,
                    searchQuery: _searchQuery),
                _PaiementsList(
                    stream: _enAttenteMoov,
                    searchQuery: _searchQuery),
                _PaiementsList(
                    stream: _enAttenteTelecel,
                    searchQuery: _searchQuery),
                _PaiementsList(
                    stream: _enAttenteWave,
                    searchQuery: _searchQuery),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.adminPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            )),
      ),
    );
  }
}

class _PaiementsList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String searchQuery;
  const _PaiementsList({required this.stream, this.searchQuery = ''});

  static Color _couleurMethode(String methode) {
    switch (methode) {
      case 'orange_money':
        return const Color(0xFFFF6600);
      case 'moov_money':
        return const Color(0xFF0066CC);
      case 'telecel_money':
        return const Color(0xFFCC0000);
      case 'wave':
        return const Color(0xFF009688);
      default:
        return Colors.grey;
    }
  }

  static String _labelMethode(String methode) {
    switch (methode) {
      case 'orange_money':
        return 'Orange Money';
      case 'moov_money':
        return 'Moov Money';
      case 'telecel_money':
        return 'Telecel Money';
      case 'wave':
        return 'Wave';
      default:
        return methode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: AppColors.adminPrimary));
        }
        if (snap.hasError) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                const Text('Erreur de chargement des paiements',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${snap.error}',
                    textAlign: TextAlign.center,
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        var docs = snap.data?.docs ?? [];
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final numero =
            (data['numeroPaiement'] ?? '').toString().toLowerCase();
            final reference =
            (data['referenceTransaction'] ?? '').toString().toLowerCase();
            final commande =
            (data['commandeId'] ?? '').toString().toLowerCase();
            final montant =
            (data['montant'] ?? '').toString().toLowerCase();
            return numero.contains(q) ||
                reference.contains(q) ||
                commande.contains(q) ||
                montant.contains(q);
          }).toList();
        }
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.check_circle_outline,
                    size: 64,
                    color: searchQuery.isNotEmpty
                        ? Colors.grey.shade400
                        : Colors.green.shade300),
                const SizedBox(height: 16),
                Text(
                    searchQuery.isNotEmpty
                        ? 'Aucun résultat pour "$searchQuery"'
                        : 'Aucun paiement en attente',
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final methode = data['methode'] ?? '';
            return _PaiementCard(
              paiementId: doc.id,
              data: data,
              service: PaymentService(),
              couleur: _couleurMethode(methode),
              labelMethode: _labelMethode(methode),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// CARTE PAIEMENT EN ATTENTE — avec vérification montant commande
// ─────────────────────────────────────────────
class _PaiementCard extends StatefulWidget {
  final String paiementId;
  final Map<String, dynamic> data;
  final PaymentService service;
  final Color couleur;
  final String labelMethode;

  const _PaiementCard({
    required this.paiementId,
    required this.data,
    required this.service,
    required this.couleur,
    required this.labelMethode,
  });

  @override
  State<_PaiementCard> createState() => _PaiementCardState();
}

class _PaiementCardState extends State<_PaiementCard> {
  double? _montantCommande;
  bool _chargementCommande = false;
  bool _commandeChargee = false;

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
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  @override
  void initState() {
    super.initState();
    _chargerMontantCommande();
  }

  Future<void> _chargerMontantCommande() async {
    final commandeId = widget.data['commandeId'] ?? '';
    if (commandeId.isEmpty) return;
    setState(() => _chargementCommande = true);
    final montant = await _getMontantCommandeAttendu(commandeId);
    if (mounted) {
      setState(() {
        _montantCommande = montant;
        _chargementCommande = false;
        _commandeChargee = true;
      });
    }
  }

  bool get _montantIncorrect {
    if (_montantCommande == null) return false;
    final montantPaiement =
    (widget.data['montant'] ?? 0).toDouble();
    return !_montantCorrespond(montantPaiement, _montantCommande!);
  }

  /// Annule le paiement et remet la commande en attente automatiquement
  Future<void> _annulerPourMontantIncorrect(BuildContext context) async {
    final commandeId = widget.data['commandeId'] ?? '';
    final montantPaiement = (widget.data['montant'] ?? 0).toDouble();
    final montantCmd = _montantCommande ?? 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.error, color: Colors.red, size: 24),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Montant non correspondant',
                  style: TextStyle(color: Colors.red, fontSize: 16))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.receipt_long,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    const Text('Montant commande :',
                        style:
                        TextStyle(color: Colors.grey, fontSize: 13)),
                    const Spacer(),
                    Text(
                      '${montantCmd.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 13),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.payments,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    const Text('Montant payé :',
                        style:
                        TextStyle(color: Colors.grey, fontSize: 13)),
                    const Spacer(),
                    Text(
                      '${montantPaiement.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 13),
                    ),
                  ]),
                  const Divider(height: 16),
                  Row(children: [
                    const Icon(Icons.calculate,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    const Text('Ecart :',
                        style:
                        TextStyle(color: Colors.grey, fontSize: 13)),
                    const Spacer(),
                    Text(
                      '${(montantPaiement - montantCmd).toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 13),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Le paiement sera rejeté et le client remboursé. La commande sera annulée.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer le rejet',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Rejeter le paiement avec motif explicite
      await widget.service.rejetterPaiement(
        widget.paiementId,
        'Montant non correspondant : payé ${montantPaiement.toStringAsFixed(0)} FCFA, attendu ${montantCmd.toStringAsFixed(0)} FCFA',
      );

      // 2. Annuler la commande associée si elle existe
      if (commandeId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(commandeId)
            .update({
          'status': 'annulee',
          'motifAnnulation':
          'Paiement rejeté : montant non correspondant (payé ${montantPaiement.toStringAsFixed(0)} FCFA, attendu ${montantCmd.toStringAsFixed(0)} FCFA)',
          'annuleeAt': FieldValue.serverTimestamp(),
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Paiement rejeté et commande annulée. Client à rembourser.')),
            ]),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _valider(BuildContext context) async {
    // Si le montant est incorrect, on bloque la validation et on propose l'annulation
    if (_montantIncorrect) {
      await _annulerPourMontantIncorrect(context);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Valider le paiement ?'),
        content: Text(
            'Confirmer la reception de ${widget.data['montant']} FCFA\nRef: ${widget.data['referenceTransaction']}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child:
            const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.service.validerPaiement(widget.paiementId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Paiement valide'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejeter(BuildContext context) async {
    final motifCtrl = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejeter le paiement'),
        content: TextField(
          controller: motifCtrl,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Ex: Reference incorrecte, montant insuffisant...',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, motifCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
            const Text('Rejeter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (motif == null || motif.isEmpty) return;
    try {
      await widget.service.rejetterPaiement(widget.paiementId, motif);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Paiement rejete'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final montantPaiement = (widget.data['montant'] ?? 0).toDouble();
    final alerteMontant = _commandeChargee && _montantIncorrect;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: alerteMontant
            ? Border.all(color: Colors.red.shade400, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
              color: alerteMontant
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: alerteMontant ? 16 : 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── En-tête coloré ──
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: alerteMontant ? Colors.red.shade600 : widget.couleur,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(
                    alerteMontant
                        ? Icons.warning_amber_rounded
                        : Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    alerteMontant
                        ? '${widget.labelMethode} — ALERTE'
                        : widget.labelMethode,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ]),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('En attente',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // ── Bannière rouge montant non correspondant ──
          if (alerteMontant)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.red.shade50,
              child: Row(children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MONTANT NON CORRESPONDANT',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      Text(
                        'Payé : ${montantPaiement.toStringAsFixed(0)} FCFA  •  Attendu : ${_montantCommande!.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ]),
            ),

          // ── Corps ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Ligne montant avec couleur rouge si alerte
                _ligne(
                  'Montant',
                  '${montantPaiement.toStringAsFixed(0)} FCFA',
                  bold: true,
                  color: alerteMontant ? Colors.red : widget.couleur,
                ),
                if (alerteMontant && _montantCommande != null)
                  _ligne(
                    'Attendu',
                    '${_montantCommande!.toStringAsFixed(0)} FCFA',
                    bold: true,
                    color: Colors.green,
                  ),
                _ligne('Numero', widget.data['numeroPaiement'] ?? '—'),
                _ligne(
                    'Reference', widget.data['referenceTransaction'] ?? '—'),
                _ligne('Commande', widget.data['commandeId'] ?? '—'),
                _ligne('Description', widget.data['description'] ?? '—'),
                _ligne('Soumis le', _formatDate(widget.data['createdAt'])),

                if (_chargementCommande)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Vérification du montant commande...',
                          style:
                          TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                  ),

                const Divider(height: 24),

                // ── Boutons ──
                if (alerteMontant)
                // Cas montant incorrect : seul bouton "Annuler & Rembourser"
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _annulerPourMontantIncorrect(context),
                      icon: const Icon(Icons.cancel),
                      label: const Text(
                          'Annuler & Informer le client'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                else
                // Cas normal : Rejeter + Valider
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejeter(context),
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Rejeter',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _valider(context),
                          icon: const Icon(Icons.check),
                          label: const Text('Valider'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligne(String label, String valeur,
      {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style:
                  const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(valeur,
                  style: TextStyle(
                    fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                    color: color,
                    fontSize: 13,
                  )),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
// HISTORIQUE PAIEMENTS
// ─────────────────────────────────────────────
class _PaiementsHistoriqueList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final _Periode periode;
  final String searchQuery;
  const _PaiementsHistoriqueList(
      {required this.stream, required this.periode, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: AppColors.adminPrimary));
        }
        if (snap.hasError) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                const Text('Erreur de chargement de l\'historique',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${snap.error}',
                    textAlign: TextAlign.center,
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        var docs = _filtrerParPeriode(snap.data?.docs ?? [], periode);
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final numero =
            (data['numeroPaiement'] ?? '').toString().toLowerCase();
            final reference =
            (data['referenceTransaction'] ?? '').toString().toLowerCase();
            final commande =
            (data['commandeId'] ?? '').toString().toLowerCase();
            final montant =
            (data['montant'] ?? '').toString().toLowerCase();
            return numero.contains(q) ||
                reference.contains(q) ||
                commande.contains(q) ||
                montant.contains(q);
          }).toList();
        }
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    searchQuery.isNotEmpty ? Icons.search_off : Icons.history,
                    size: 64,
                    color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                    searchQuery.isNotEmpty
                        ? 'Aucun résultat pour "$searchQuery"'
                        : 'Aucun paiement dans l\'historique',
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final methode = data['methode'] ?? '';
            return _PaiementHistoriqueCard(
              data: data,
              couleur: _PaiementsList._couleurMethode(methode),
              labelMethode: _PaiementsList._labelMethode(methode),
            );
          },
        );
      },
    );
  }
}

class _PaiementHistoriqueCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color couleur;
  final String labelMethode;
  const _PaiementHistoriqueCard(
      {required this.data,
        required this.couleur,
        required this.labelMethode});

  String _formatDate(dynamic ts) {
    final dt = _dateDeChamp(ts);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final statut = data['statut'] ?? '';
    final estValide = statut == 'valide';
    final statutColor = estValide ? Colors.green : Colors.red;
    final statutLabel = estValide ? 'Valide' : 'Rejete';
    final statutIcon = estValide ? Icons.check_circle : Icons.cancel;
    final dateTraitement = estValide ? data['valideAt'] : null;

    // Détection rejet pour montant non correspondant dans l'historique
    final motifRejet = data['motifRejet'] ?? '';
    final estRejetMontant = !estValide &&
        motifRejet.toString().toLowerCase().contains('montant non correspondant');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: estRejetMontant
            ? Border.all(color: Colors.red.shade300, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: couleur,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.account_balance_wallet,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(labelMethode,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ]),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statutIcon, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(statutLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ),
          ),

          // Bannière "Montant non correspondant" dans l'historique
          if (estRejetMontant)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade50,
              child: Row(children: [
                const Icon(Icons.error, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Rejeté : Montant non correspondant',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ]),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ligne('Montant', '${data['montant']} FCFA',
                    bold: true,
                    color: estRejetMontant ? Colors.red : couleur),
                _ligne('Numero', data['numeroPaiement'] ?? '—'),
                _ligne(
                    'Reference', data['referenceTransaction'] ?? '—'),
                _ligne('Commande', data['commandeId'] ?? '—'),
                _ligne('Description', data['description'] ?? '—'),
                _ligne('Soumis le', _formatDate(data['createdAt'])),
                if (!estValide && data['motifRejet'] != null)
                  _ligne('Motif rejet', data['motifRejet'],
                      color: Colors.red),
                if (estValide && dateTraitement != null)
                  _ligne('Valide le', _formatDate(dateTraitement)),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statutColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(statutLabel,
                        style: TextStyle(
                            color: statutColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligne(String label, String valeur,
      {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style:
                  const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(valeur,
                  style: TextStyle(
                    fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                    color: color,
                    fontSize: 13,
                  )),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
// ONGLET RETRAITS
// ─────────────────────────────────────────────
class _RetraitsTab extends StatefulWidget {
  const _RetraitsTab();
  @override
  State<_RetraitsTab> createState() => _RetraitsTabState();
}

class _RetraitsTabState extends State<_RetraitsTab> {
  bool _historique = false;
  _Periode _periode = _Periode.tout;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late final Stream<QuerySnapshot> _enAttenteTous =
  PaymentService().retraitsEnAttente();
  late final Stream<QuerySnapshot> _enAttenteOrange =
  PaymentService().retraitsEnAttenteParMethode('orange_money');
  late final Stream<QuerySnapshot> _enAttenteMoov =
  PaymentService().retraitsEnAttenteParMethode('moov_money');
  late final Stream<QuerySnapshot> _enAttenteTelecel =
  PaymentService().retraitsEnAttenteParMethode('telecel_money');
  late final Stream<QuerySnapshot> _enAttenteWave =
  PaymentService().retraitsEnAttenteParMethode('wave');

  late final Stream<QuerySnapshot> _histTous =
  PaymentService().historiqueRetraits();
  late final Stream<QuerySnapshot> _histOrange =
  PaymentService().historiqueRetraitsParMethode('orange_money');
  late final Stream<QuerySnapshot> _histMoov =
  PaymentService().historiqueRetraitsParMethode('moov_money');
  late final Stream<QuerySnapshot> _histTelecel =
  PaymentService().historiqueRetraitsParMethode('telecel_money');
  late final Stream<QuerySnapshot> _histWave =
  PaymentService().historiqueRetraitsParMethode('wave');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          AdminSearchBar(
            controller: _searchCtrl,
            hint: 'Rechercher un retrait (numero, reference)...',
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          ),
          Container(
            color: Colors.white,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Expanded(
                      child: _toggleBtn('En attente', !_historique,
                              () => setState(() => _historique = false))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _toggleBtn('Historique', _historique,
                              () => setState(() => _historique = true))),
                ]),
              ),
              if (_historique)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _periodeSelector(
                      _periode, (p) => setState(() => _periode = p)),
                ),
              const TabBar(
                isScrollable: true,
                indicatorColor: AppColors.adminPrimary,
                labelColor: AppColors.adminPrimary,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Tous'),
                  Tab(text: 'Orange'),
                  Tab(text: 'Moov'),
                  Tab(text: 'Telecel'),
                  Tab(text: 'Wave'),
                ],
              ),
            ]),
          ),
          Expanded(
            child: _historique
                ? TabBarView(
              children: [
                _RetraitsHistoriqueList(
                    stream: _histTous,
                    periode: _periode,
                    searchQuery: _searchQuery),
                _RetraitsHistoriqueList(
                    stream: _histOrange,
                    periode: _periode,
                    searchQuery: _searchQuery),
                _RetraitsHistoriqueList(
                    stream: _histMoov,
                    periode: _periode,
                    searchQuery: _searchQuery),
                _RetraitsHistoriqueList(
                    stream: _histTelecel,
                    periode: _periode,
                    searchQuery: _searchQuery),
                _RetraitsHistoriqueList(
                    stream: _histWave,
                    periode: _periode,
                    searchQuery: _searchQuery),
              ],
            )
                : TabBarView(
              children: [
                _RetraitsList(
                    stream: _enAttenteTous,
                    searchQuery: _searchQuery),
                _RetraitsList(
                    stream: _enAttenteOrange,
                    searchQuery: _searchQuery),
                _RetraitsList(
                    stream: _enAttenteMoov,
                    searchQuery: _searchQuery),
                _RetraitsList(
                    stream: _enAttenteTelecel,
                    searchQuery: _searchQuery),
                _RetraitsList(
                    stream: _enAttenteWave,
                    searchQuery: _searchQuery),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.adminPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            )),
      ),
    );
  }
}

class _RetraitsList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String searchQuery;
  const _RetraitsList({required this.stream, this.searchQuery = ''});

  static Color _couleurMethode(String methode) {
    switch (methode) {
      case 'orange_money':
        return const Color(0xFFFF6600);
      case 'moov_money':
        return const Color(0xFF0066CC);
      case 'telecel_money':
        return const Color(0xFFCC0000);
      case 'wave':
        return const Color(0xFF009688);
      default:
        return Colors.grey;
    }
  }

  static String _labelMethode(String methode) {
    switch (methode) {
      case 'orange_money':
        return 'Orange Money';
      case 'moov_money':
        return 'Moov Money';
      case 'telecel_money':
        return 'Telecel Money';
      case 'wave':
        return 'Wave';
      default:
        return methode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: AppColors.adminPrimary));
        }
        if (snap.hasError) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                const Text('Erreur de chargement des retraits',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${snap.error}',
                    textAlign: TextAlign.center,
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        var docs = snap.data?.docs ?? [];
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final numero =
            (data['numeroRetrait'] ?? '').toString().toLowerCase();
            final montant =
            (data['montant'] ?? '').toString().toLowerCase();
            return numero.contains(q) || montant.contains(q);
          }).toList();
        }
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.check_circle_outline,
                    size: 64,
                    color: searchQuery.isNotEmpty
                        ? Colors.grey.shade400
                        : Colors.green.shade300),
                const SizedBox(height: 16),
                Text(
                    searchQuery.isNotEmpty
                        ? 'Aucun résultat pour "$searchQuery"'
                        : 'Aucune demande de retrait',
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final methode = data['methode'] ?? '';
            return _RetraitCard(
              retraitId: doc.id,
              data: data,
              service: PaymentService(),
              couleur: _couleurMethode(methode),
              labelMethode: _labelMethode(methode),
            );
          },
        );
      },
    );
  }
}

class _RetraitCard extends StatelessWidget {
  final String retraitId;
  final Map<String, dynamic> data;
  final PaymentService service;
  final Color couleur;
  final String labelMethode;

  const _RetraitCard({
    required this.retraitId,
    required this.data,
    required this.service,
    required this.couleur,
    required this.labelMethode,
  });

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
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<void> _valider(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Marquer ce retrait comme paye ?'),
        content: Text(
          'Confirmez-vous avoir envoye ${data['montant']} FCFA au numero ${data['numeroRetrait']} via $labelMethode ?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await service.validerRetrait(retraitId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Retrait marque comme paye'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejeter(BuildContext context) async {
    final motifCtrl = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejeter la demande de retrait'),
        content: TextField(
          controller: motifCtrl,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Ex: Numero invalide, demande en double...',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, motifCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
            const Text('Rejeter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (motif == null || motif.isEmpty) return;
    try {
      await service.rejeterRetrait(retraitId, motif);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Retrait rejete, fonds restitues au vendeur'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = data['sellerId'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: couleur,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.account_balance_wallet,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(labelMethode,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('En attente',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ligne('Montant', '${data['montant']} FCFA',
                    bold: true, color: couleur),
                _ligne('Numero retrait', data['numeroRetrait'] ?? '—'),
                _vendeurLigne(sellerId),
                _ligne('Demande le', _formatDate(data['createdAt'])),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejeter(context),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('Rejeter',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _valider(context),
                        icon: const Icon(Icons.check),
                        label: const Text('Marquer paye'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vendeurLigne(String sellerId) {
    if (sellerId.isEmpty) return _ligne('Vendeur', '—');
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get(),
      builder: (context, snap) {
        String nom = sellerId;
        if (snap.hasData && snap.data!.exists) {
          final u = snap.data!.data() as Map<String, dynamic>;
          final n = '${u['prenom'] ?? ''} ${u['nom'] ?? ''}'.trim();
          if (n.isNotEmpty) nom = n;
        }
        return _ligne('Vendeur', nom);
      },
    );
  }

  Widget _ligne(String label, String valeur,
      {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style:
                  const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(valeur,
                  style: TextStyle(
                    fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                    color: color,
                    fontSize: 13,
                  )),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
// HISTORIQUE RETRAITS
// ─────────────────────────────────────────────
class _RetraitsHistoriqueList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final _Periode periode;
  final String searchQuery;
  const _RetraitsHistoriqueList(
      {required this.stream, required this.periode, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: AppColors.adminPrimary));
        }
        if (snap.hasError) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                const Text('Erreur de chargement de l\'historique',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${snap.error}',
                    textAlign: TextAlign.center,
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        var docs = _filtrerParPeriode(snap.data?.docs ?? [], periode);
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final numero =
            (data['numeroRetrait'] ?? '').toString().toLowerCase();
            final montant =
            (data['montant'] ?? '').toString().toLowerCase();
            return numero.contains(q) || montant.contains(q);
          }).toList();
        }
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    searchQuery.isNotEmpty ? Icons.search_off : Icons.history,
                    size: 64,
                    color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                    searchQuery.isNotEmpty
                        ? 'Aucun résultat pour "$searchQuery"'
                        : 'Aucun retrait dans l\'historique',
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final methode = data['methode'] ?? '';
            return _RetraitHistoriqueCard(
              data: data,
              couleur: _RetraitsList._couleurMethode(methode),
              labelMethode: _RetraitsList._labelMethode(methode),
            );
          },
        );
      },
    );
  }
}

class _RetraitHistoriqueCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color couleur;
  final String labelMethode;
  const _RetraitHistoriqueCard(
      {required this.data,
        required this.couleur,
        required this.labelMethode});

  String _formatDate(dynamic ts) {
    final dt = _dateDeChamp(ts);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Widget _vendeurLigne(String sellerId) {
    if (sellerId.isEmpty) return _ligne('Vendeur', '—');
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get(),
      builder: (context, snap) {
        String nom = sellerId;
        if (snap.hasData && snap.data!.exists) {
          final u = snap.data!.data() as Map<String, dynamic>;
          final n = '${u['prenom'] ?? ''} ${u['nom'] ?? ''}'.trim();
          if (n.isNotEmpty) nom = n;
        }
        return _ligne('Vendeur', nom);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = data['sellerId'] ?? '';
    final statut = data['statut'] ?? '';
    final estPaye = statut == 'paye';
    final statutColor = estPaye ? Colors.green : Colors.red;
    final statutLabel = estPaye ? 'Paye' : 'Rejete';
    final statutIcon = estPaye ? Icons.check_circle : Icons.cancel;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: couleur,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.account_balance_wallet,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(labelMethode,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ]),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statutIcon, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(statutLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ligne('Montant', '${data['montant']} FCFA',
                    bold: true, color: couleur),
                _ligne('Numero retrait', data['numeroRetrait'] ?? '—'),
                _vendeurLigne(sellerId),
                _ligne('Demande le', _formatDate(data['createdAt'])),
                if (!estPaye && data['motifRejet'] != null)
                  _ligne('Motif rejet', data['motifRejet'],
                      color: Colors.red),
                if (data['traiteAt'] != null)
                  _ligne('Traite le', _formatDate(data['traiteAt'])),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statutColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(statutLabel,
                        style: TextStyle(
                            color: statutColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligne(String label, String valeur,
      {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style:
                  const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(valeur,
                  style: TextStyle(
                    fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                    color: color,
                    fontSize: 13,
                  )),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
// ONGLET UTILISATEURS
// ─────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late final Stream<QuerySnapshot> _usersStream =
  FirebaseFirestore.instance.collection('users').snapshots();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filtrer(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    final q = _searchQuery.toLowerCase();
    return docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final nom =
      '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final phone = (data['telephone'] ?? '').toString().toLowerCase();
      return nom.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AdminSearchBar(
        controller: _searchCtrl,
        hint: 'Rechercher un utilisateur (nom, email, telephone)...',
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        onClear: () {
          _searchCtrl.clear();
          setState(() => _searchQuery = '');
        },
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _usersStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.adminPrimary));
            }
            final docs = snap.data?.docs ?? [];
            final filtres = _filtrer(docs);
            final clients = filtres
                .where((d) => (d.data() as Map)['role'] == 'client')
                .toList();
            final vendeurs = filtres
                .where((d) => (d.data() as Map)['role'] == 'vendeur')
                .toList();

            if (_searchQuery.isNotEmpty && filtres.isEmpty) {
              return Center(
                child: Text('Aucun résultat pour "$_searchQuery"',
                    style: const TextStyle(color: Colors.grey)),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _statBox('Total', '${docs.length}', Icons.people,
                          Colors.indigo),
                      const SizedBox(width: 10),
                      _statBox('Clients', '${clients.length}',
                          Icons.shopping_bag, Colors.blue),
                      const SizedBox(width: 10),
                      _statBox('Vendeurs', '${vendeurs.length}',
                          Icons.store, Colors.orange),
                    ]),
                    const SizedBox(height: 20),
                    _sectionTitle(
                        'Vendeurs (${vendeurs.length})', Colors.orange),
                    const SizedBox(height: 8),
                    ...vendeurs.map(
                            (doc) => _userCard(context, doc, Colors.orange)),
                    const SizedBox(height: 20),
                    _sectionTitle('Clients (${clients.length})', Colors.blue),
                    const SizedBox(height: 8),
                    ...clients
                        .map((doc) => _userCard(context, doc, Colors.blue)),
                  ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _userCard(
      BuildContext context, QueryDocumentSnapshot doc, Color color) {
    final data = doc.data() as Map<String, dynamic>;
    final nom = '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
    final email = data['email'] ?? '';
    final phone = data['telephone'] ?? '';
    final photo = data['photoUrl'] ?? '';
    final bloque = data['bloque'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo.isEmpty ? Icon(Icons.person, color: color) : null,
        ),
        title: Row(children: [
          Expanded(
              child: Text(nom.isEmpty ? 'Sans nom' : nom,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14))),
          if (bloque)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300)),
              child: const Text('Bloque',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(email, style: const TextStyle(fontSize: 12)),
              if (phone.isNotEmpty)
                Text(phone,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (val) =>
              _handleUserAction(context, doc.id, val, bloque),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: bloque ? 'debloquer' : 'bloquer',
              child: Row(children: [
                Icon(bloque ? Icons.lock_open : Icons.block,
                    color: bloque ? Colors.green : Colors.red, size: 18),
                const SizedBox(width: 8),
                Text(bloque ? 'Debloquer' : 'Bloquer',
                    style: TextStyle(
                        color: bloque ? Colors.green : Colors.red)),
              ]),
            ),
            const PopupMenuItem(
              value: 'supprimer',
              child: Row(children: [
                Icon(Icons.delete_forever, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Supprimer compte',
                    style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUserAction(
      BuildContext context, String uid, String action, bool bloque) async {
    if (action == 'bloquer' || action == 'debloquer') {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'bloque': !bloque});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'bloquer'
              ? 'Utilisateur bloque'
              : 'Utilisateur debloque'),
          backgroundColor:
          action == 'bloquer' ? Colors.red : Colors.green,
        ));
      }
    } else if (action == 'supprimer') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Supprimer ce compte ?'),
          content: const Text('Cette action est irreversible.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer',
                    style: TextStyle(color: Colors.white))),
          ],
        ),
      );
      if (confirm == true) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .delete();
      }
    }
  }
}

// ─────────────────────────────────────────────
// ONGLET PRODUITS
// ─────────────────────────────────────────────
class _ProduitsTab extends StatefulWidget {
  @override
  State<_ProduitsTab> createState() => _ProduitsTabState();
}

class _ProduitsTabState extends State<_ProduitsTab> {
  String _filter = 'tous';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late final Stream<QuerySnapshot> _produitsStream = FirebaseFirestore
      .instance
      .collection('products')
      .orderBy('createdAt', descending: true)
      .snapshots();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AdminSearchBar(
        controller: _searchCtrl,
        hint: 'Rechercher un produit (nom, categorie)...',
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        onClear: () {
          _searchCtrl.clear();
          setState(() => _searchQuery = '');
        },
      ),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          _filterChip('tous', 'Tous'),
          const SizedBox(width: 8),
          _filterChip('actif', 'Actifs'),
          const SizedBox(width: 8),
          _filterChip('bloque', 'Bloques'),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _produitsStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.adminPrimary));
            }
            var docs = snap.data?.docs ?? [];
            if (_filter != 'tous') {
              docs = docs
                  .where((d) =>
              (d.data() as Map<String, dynamic>)['status'] ==
                  _filter)
                  .toList();
            }
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              docs = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final nom = (data['name'] ?? '').toString().toLowerCase();
                final cat =
                (data['category'] ?? '').toString().toLowerCase();
                return nom.contains(q) || cat.contains(q);
              }).toList();
            }
            if (docs.isEmpty)
              return Center(
                  child: Text(
                      _searchQuery.isNotEmpty
                          ? 'Aucun résultat pour "$_searchQuery"'
                          : 'Aucun produit',
                      style: const TextStyle(color: Colors.grey)));
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_, i) => _produitCard(context, docs[i]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.adminPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey,
                fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12)),
      ),
    );
  }

  Widget _produitCard(
      BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'actif';
    final statusColor =
    status == 'actif' ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        ClipRRect(
          borderRadius:
          const BorderRadius.horizontal(left: Radius.circular(12)),
          child: SizedBox(
            width: 80,
            height: 80,
            child: (data['imageUrl'] ?? '').isNotEmpty
                ? CachedNetworkImage(
                imageUrl: data['imageUrl'],
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image,
                        color: Colors.grey)))
                : Container(
                color: Colors.grey.shade200,
                child:
                const Icon(Icons.image, color: Colors.grey)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                      '${(data['price'] ?? 0).toStringAsFixed(0)} FCFA  •  ${data['category'] ?? ''}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                        status == 'actif' ? 'Actif' : 'Bloque',
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (val) =>
              _handleAction(context, doc.id, val, status),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: status == 'bloque' ? 'activer' : 'bloquer',
              child: Row(children: [
                Icon(
                    status == 'bloque'
                        ? Icons.check_circle
                        : Icons.block,
                    color: status == 'bloque'
                        ? Colors.green
                        : Colors.orange,
                    size: 18),
                const SizedBox(width: 8),
                Text(status == 'bloque' ? 'Activer' : 'Bloquer'),
              ]),
            ),
            const PopupMenuItem(
              value: 'supprimer',
              child: Row(children: [
                Icon(Icons.delete_forever, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Supprimer', style: TextStyle(color: Colors.red))
              ]),
            ),
          ],
        ),
      ]),
    );
  }

  Future<void> _handleAction(BuildContext context, String id,
      String action, String status) async {
    if (action == 'bloquer') {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(id)
          .update({'status': 'bloque'});
    } else if (action == 'activer') {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(id)
          .update({'status': 'actif'});
    } else if (action == 'supprimer') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Supprimer ce produit ?'),
          content: const Text('Cette action est irreversible.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer',
                    style: TextStyle(color: Colors.white))),
          ],
        ),
      );
      if (confirm == true)
        await FirebaseFirestore.instance
            .collection('products')
            .doc(id)
            .delete();
    }
  }
}

// ─────────────────────────────────────────────
// ONGLET RECOMMANDES
// ─────────────────────────────────────────────
class _RecommandesTab extends StatefulWidget {
  @override
  State<_RecommandesTab> createState() => _RecommandesTabState();
}

class _RecommandesTabState extends State<_RecommandesTab> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late final Stream<QuerySnapshot> _produitsActifsStream = FirebaseFirestore
      .instance
      .collection('products')
      .where('status', isEqualTo: 'actif')
      .snapshots();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _produitsActifsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: AppColors.adminPrimary));
        }
        var docs = snap.data?.docs ?? [];
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final nom = (data['name'] ?? '').toString().toLowerCase();
            final cat = (data['category'] ?? '').toString().toLowerCase();
            return nom.contains(q) || cat.contains(q);
          }).toList();
        }

        return Column(children: [
          AdminSearchBar(
            controller: _searchCtrl,
            hint: 'Rechercher un produit (nom, categorie)...',
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          ),
          if (docs.isEmpty)
            Expanded(
              child: Center(
                  child: Text(
                      _searchQuery.isNotEmpty
                          ? 'Aucun résultat pour "$_searchQuery"'
                          : 'Aucun produit actif',
                      style: const TextStyle(color: Colors.grey))),
            )
          else ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.adminPrimary, Color(0xFF283593)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Produits recommandes',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          Text(
                              'Ces produits apparaissent en premier sur l\'accueil des clients',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ])),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data =
                  docs[i].data() as Map<String, dynamic>;
                  final isRecommande = data['recommande'] ?? false;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: (data['imageUrl'] ?? '').isNotEmpty
                              ? CachedNetworkImage(
                              imageUrl: data['imageUrl'],
                              fit: BoxFit.cover)
                              : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image,
                                  color: Colors.grey)),
                        ),
                      ),
                      title: Text(data['name'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      subtitle: Text(
                          '${(data['price'] ?? 0).toStringAsFixed(0)} FCFA  •  ${data['category'] ?? ''}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Switch(
                        value: isRecommande,
                        activeColor: Colors.amber,
                        onChanged: (val) async {
                          await FirebaseFirestore.instance
                              .collection('products')
                              .doc(docs[i].id)
                              .update({'recommande': val});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                              content: Text(val
                                  ? '${data['name']} ajoute aux recommandes'
                                  : '${data['name']} retire des recommandes'),
                              backgroundColor: val
                                  ? Colors.amber.shade700
                                  : Colors.grey,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────
// ONGLET PROMOS
// ─────────────────────────────────────────────
class _PromosTab extends StatefulWidget {
  @override
  State<_PromosTab> createState() => _PromosTabState();
}

class _PromosTabState extends State<_PromosTab> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late final Stream<QuerySnapshot> _produitsActifsStream = FirebaseFirestore
      .instance
      .collection('products')
      .where('status', isEqualTo: 'actif')
      .snapshots();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _produitsActifsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: AppColors.adminPrimary));
        }
        var docs = snap.data?.docs ?? [];
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final nom = (data['name'] ?? '').toString().toLowerCase();
            final cat = (data['category'] ?? '').toString().toLowerCase();
            return nom.contains(q) || cat.contains(q);
          }).toList();
        }

        return Column(children: [
          AdminSearchBar(
            controller: _searchCtrl,
            hint: 'Rechercher un produit (nom, categorie)...',
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          ),
          if (docs.isEmpty)
            Expanded(
              child: Center(
                  child: Text(
                      _searchQuery.isNotEmpty
                          ? 'Aucun résultat pour "$_searchQuery"'
                          : 'Aucun produit actif',
                      style: const TextStyle(color: Colors.grey))),
            )
          else ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.local_offer, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gestion des promotions',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          Text(
                              'Definissez un % de reduction visible sur les produits',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ])),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data =
                  docs[i].data() as Map<String, dynamic>;
                  final promoPercent =
                  (data['promoPercent'] ?? 0) as int;
                  final price = (data['price'] ?? 0).toDouble();
                  final prixPromo = promoPercent > 0
                      ? price * (1 - promoPercent / 100)
                      : price;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: (data['imageUrl'] ?? '').isNotEmpty
                                ? CachedNetworkImage(
                                imageUrl: data['imageUrl'],
                                fit: BoxFit.cover)
                                : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image,
                                    color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(data['name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Row(children: [
                                  Text(
                                      '${price.toStringAsFixed(0)} FCFA',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: promoPercent > 0
                                              ? Colors.grey
                                              : Colors.orange,
                                          decoration: promoPercent > 0
                                              ? TextDecoration.lineThrough
                                              : null)),
                                  if (promoPercent > 0) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                        '${prixPromo.toStringAsFixed(0)} FCFA',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.purple,
                                            fontWeight:
                                            FontWeight.bold)),
                                  ],
                                ]),
                              ]),
                        ),
                        TextButton(
                          onPressed: () => _showPromoDialog(
                              context,
                              docs[i].id,
                              data['name'] ?? '',
                              promoPercent),
                          style: TextButton.styleFrom(
                            backgroundColor: promoPercent > 0
                                ? Colors.purple.shade50
                                : Colors.grey.shade100,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10)),
                          ),
                          child: Text(
                              promoPercent > 0
                                  ? '-$promoPercent%'
                                  : 'Ajouter',
                              style: TextStyle(
                                  color: promoPercent > 0
                                      ? Colors.purple
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        ]);
      },
    );
  }

  void _showPromoDialog(BuildContext context, String productId,
      String productName, int currentPromo) {
    int selectedPercent = currentPromo;
    final percents = [0, 5, 10, 15, 20, 25, 30, 40, 50, 60, 70];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.local_offer, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(
                child: Text(productName,
                    style: const TextStyle(fontSize: 15),
                    overflow: TextOverflow.ellipsis)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choisissez le pourcentage de reduction :',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: percents
                  .map((p) => GestureDetector(
                onTap: () =>
                    setDlgState(() => selectedPercent = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selectedPercent == p
                        ? Colors.purple
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                      p == 0 ? 'Aucune' : '-$p%',
                      style: TextStyle(
                          color: selectedPercent == p
                              ? Colors.white
                              : Colors.grey,
                          fontWeight: FontWeight.bold)),
                ),
              ))
                  .toList(),
            ),
          ]),
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
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(selectedPercent == 0
                        ? 'Promotion retiree'
                        : 'Promo -$selectedPercent% appliquee !'),
                    backgroundColor:
                    selectedPercent == 0 ? Colors.grey : Colors.purple,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple),
              child: const Text('Appliquer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ONGLET COMMANDES
// ─────────────────────────────────────────────
class _CommandesTab extends StatefulWidget {
  @override
  State<_CommandesTab> createState() => _CommandesTabState();
}

class _CommandesTabState extends State<_CommandesTab> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  // Filtre rapide : null = tous, sinon statut exact
  String? _filtreStatut;

  late final Stream<QuerySnapshot> _ordersStream =
  FirebaseFirestore.instance
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .snapshots();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Statuts où l'admin peut annuler (vendeur n'a PAS encore mis en livraison)
  static const _annulables = {'en_attente', 'confirmée'};

  static Color _couleurStatut(String status) {
    switch (status) {
      case 'livrée':      return Colors.green;
      case 'en_livraison':return Colors.orange;
      case 'confirmée':   return Colors.blue;
      case 'annulee':     return Colors.red;
      default:            return Colors.grey; // en_attente
    }
  }

  static String _labelStatut(String status) {
    switch (status) {
      case 'livrée':       return 'Livrée';
      case 'en_livraison': return 'En livraison';
      case 'confirmée':    return 'Confirmée';
      case 'annulee':      return 'Annulée';
      case 'en_attente':   return 'En attente';
      default:             return status.replaceAll('_', ' ');
    }
  }

  static IconData _iconeStatut(String status) {
    switch (status) {
      case 'livrée':       return Icons.done_all;
      case 'en_livraison': return Icons.delivery_dining;
      case 'confirmée':    return Icons.thumb_up_alt;
      case 'annulee':      return Icons.cancel;
      default:             return Icons.hourglass_empty;
    }
  }

  Future<void> _annulerCommande(
      BuildContext context, String orderId, Map<String, dynamic> data) async {
    final motifCtrl = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.cancel, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Annuler la commande #${orderId.substring(0, 6).toUpperCase()}',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résumé de la commande
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Montant',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text(
                        '${(data['total'] ?? 0).toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Statut actuel',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _couleurStatut(data['status'] ?? '')
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _labelStatut(data['status'] ?? ''),
                          style: TextStyle(
                            color:
                            _couleurStatut(data['status'] ?? ''),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Motif d\'annulation :',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: motifCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText:
                'Ex: Délai trop long, erreur de commande, client introuvable...',
                hintStyle:
                const TextStyle(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.info_outline,
                  size: 14, color: Colors.orange),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Le paiement lié sera également rejeté si en attente.',
                  style: TextStyle(color: Colors.orange, fontSize: 11),
                ),
              ),
            ]),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer')),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.pop(context, motifCtrl.text.trim()),
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('Confirmer l\'annulation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (motif == null || motif.isEmpty) return;

    try {
      // 1. Annuler la commande
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'annulee',
        'motifAnnulation': motif,
        'annuleeAt': FieldValue.serverTimestamp(),
        'annuleeParAdmin': true,
      });

      // 2. Rejeter aussi le paiement en attente lié à cette commande, si existant
      final paiementsSnap = await FirebaseFirestore.instance
          .collection('paiements')
          .where('commandeId', isEqualTo: orderId)
          .where('statut', isEqualTo: 'en_attente')
          .get();

      for (final p in paiementsSnap.docs) {
        await PaymentService().rejetterPaiement(
          p.id,
          'Commande annulée par l\'admin : $motif',
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Commande #${orderId.substring(0, 6).toUpperCase()} annulée.'
                      '${paiementsSnap.docs.isNotEmpty ? ' Paiement rejeté.' : ''}',
                ),
              ),
            ]),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: AppColors.adminPrimary));
        }
        final docs = snap.data?.docs ?? [];

        // ── Stats ──
        final enAttente = docs
            .where((d) => (d.data() as Map)['status'] == 'en_attente')
            .length;
        final enLivraison = docs
            .where((d) => (d.data() as Map)['status'] == 'en_livraison')
            .length;
        final livrees = docs
            .where((d) => (d.data() as Map)['status'] == 'livrée')
            .length;
        final annulees = docs
            .where((d) => (d.data() as Map)['status'] == 'annulee')
            .length;
        final totalRevenu = docs.fold<double>(0, (sum, d) {
          final data = d.data() as Map<String, dynamic>;
          return data['status'] == 'livrée'
              ? sum + (data['total'] ?? 0).toDouble()
              : sum;
        });

        // ── Filtrage ──
        var docsAffiches = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final status = data['status'] ?? '';
          // filtre statut
          if (_filtreStatut != null && status != _filtreStatut) return false;
          // filtre recherche
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final numero = (d.id).toLowerCase();
            final statusStr = status.toString().toLowerCase();
            final total =
            (data['total'] ?? '').toString().toLowerCase();
            return numero.contains(q) ||
                statusStr.contains(q) ||
                total.contains(q);
          }
          return true;
        }).toList();

        return Column(children: [
          AdminSearchBar(
            controller: _searchCtrl,
            hint: 'Rechercher (numéro, statut, montant)...',
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          ),

          // ── Filtres rapides par statut ──
          Container(
            color: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filtreChip(null, 'Tous', Colors.indigo),
                const SizedBox(width: 6),
                _filtreChip('en_attente', 'En attente', Colors.grey),
                const SizedBox(width: 6),
                _filtreChip('confirmée', 'Confirmées', Colors.blue),
                const SizedBox(width: 6),
                _filtreChip(
                    'en_livraison', 'En livraison', Colors.orange),
                const SizedBox(width: 6),
                _filtreChip('livrée', 'Livrées', Colors.green),
                const SizedBox(width: 6),
                _filtreChip('annulee', 'Annulées', Colors.red),
              ]),
            ),
          ),

          if (docs.isEmpty)
            const Expanded(
              child: Center(
                  child: Text('Aucune commande',
                      style: TextStyle(color: Colors.grey))),
            )
          else
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stat boxes
                          Row(children: [
                            _statBox('Total', '${docs.length}',
                                Icons.receipt_long, Colors.indigo),
                            const SizedBox(width: 6),
                            _statBox('Attente', '$enAttente',
                                Icons.hourglass_empty, Colors.grey),
                            const SizedBox(width: 6),
                            _statBox('Livraison', '$enLivraison',
                                Icons.delivery_dining, Colors.orange),
                            const SizedBox(width: 6),
                            _statBox('Livrées', '$livrees',
                                Icons.done_all, Colors.green),
                            const SizedBox(width: 6),
                            _statBox('Annulées', '$annulees',
                                Icons.cancel, Colors.red),
                          ]),
                          const SizedBox(height: 12),
                          // Chiffre d'affaires
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                AppColors.adminPrimary,
                                Color(0xFF283593)
                              ]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const Icon(Icons.payments,
                                  color: Colors.amber),
                              const SizedBox(width: 10),
                              Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                        'Chiffre d\'affaires total',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                    Text(
                                        '${totalRevenu.toStringAsFixed(0)} FCFA',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight:
                                            FontWeight.bold)),
                                  ]),
                            ]),
                          ),
                          const SizedBox(height: 16),
                          // Info annulation
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.orange.shade200),
                            ),
                            child: Row(children: [
                              Icon(Icons.info_outline,
                                  color: Colors.orange.shade700,
                                  size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'L\'annulation est disponible pour les commandes En attente et Confirmées (avant mise en livraison par le vendeur).',
                                  style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 11),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filtreStatut != null
                                ? '${_labelStatut(_filtreStatut!)} (${docsAffiches.length})'
                                : _searchQuery.isNotEmpty
                                ? 'Résultats (${docsAffiches.length})'
                                : 'Toutes les commandes (${docs.length})',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Liste des commandes ──
                  if (docsAffiches.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off,
                                  size: 52,
                                  color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Aucun résultat pour "$_searchQuery"'
                                    : 'Aucune commande dans cette catégorie',
                                style: const TextStyle(
                                    color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, i) {
                            final doc = docsAffiches[i];
                            final d =
                            doc.data() as Map<String, dynamic>;
                            final status = d['status'] ?? '';
                            final peutAnnuler =
                            _annulables.contains(status);
                            final statusColor = _couleurStatut(status);

                            return _CommandeCard(
                              orderId: doc.id,
                              data: d,
                              statusColor: statusColor,
                              labelStatut: _labelStatut(status),
                              iconeStatut: _iconeStatut(status),
                              peutAnnuler: peutAnnuler,
                              onAnnuler: () => _annulerCommande(
                                  context, doc.id, d),
                            );
                          },
                          childCount: docsAffiches.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ]);
      },
    );
  }

  Widget _filtreChip(String? statut, String label, Color color) {
    final selected = _filtreStatut == statut;
    return GestureDetector(
      onTap: () => setState(() => _filtreStatut = statut),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CARTE COMMANDE
// ─────────────────────────────────────────────
class _CommandeCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Color statusColor;
  final String labelStatut;
  final IconData iconeStatut;
  final bool peutAnnuler;
  final VoidCallback onAnnuler;

  const _CommandeCard({
    required this.orderId,
    required this.data,
    required this.statusColor,
    required this.labelStatut,
    required this.iconeStatut,
    required this.peutAnnuler,
    required this.onAnnuler,
  });

  String _formatDate(dynamic ts) {
    final dt = _dateDeChamp(ts);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final total = (data['total'] ?? 0).toDouble();
    final status = data['status'] ?? '';
    final estAnnulee = status == 'annulee';
    final motifAnnulation = data['motifAnnulation'] ?? '';
    final parAdmin = data['annuleeParAdmin'] == true;

    // Items de la commande
    final items = (data['items'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: peutAnnuler
            ? Border.all(
            color: Colors.orange.withValues(alpha: 0.4), width: 1)
            : estAnnulee
            ? Border.all(
            color: Colors.red.withValues(alpha: 0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: estAnnulee ? 0.15 : 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.2),
                  child: Icon(iconeStatut, color: statusColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commande #${orderId.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        _formatDate(data['createdAt']),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    labelStatut,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bannière annulée par admin ──
          if (estAnnulee && parAdmin)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.red.shade50,
              child: Row(children: [
                const Icon(Icons.admin_panel_settings,
                    color: Colors.red, size: 14),
                const SizedBox(width: 6),
                const Text('Annulée par l\'administrateur',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),

          // ── Corps ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Infos client
                if ((data['clientNom'] ?? '').isNotEmpty ||
                    (data['clientPhone'] ?? '').isNotEmpty)
                  _infoRow(
                    Icons.person_outline,
                    '${data['clientNom'] ?? ''}'
                        '${(data['clientPhone'] ?? '').isNotEmpty ? '  •  ${data['clientPhone']}' : ''}',
                  ),

                // Articles (3 max)
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...items.take(3).map((item) {
                    final nom = item['name'] ?? item['productName'] ?? '—';
                    final qte = item['quantity'] ?? 1;
                    final prix = (item['price'] ?? 0).toDouble();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 8, top: 1),
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$nom  x$qte',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(prix * qte).toStringAsFixed(0)} FCFA',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600),
                        ),
                      ]),
                    );
                  }),
                  if (items.length > 3)
                    Text(
                      '+ ${items.length - 3} autre(s) article(s)',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                ],

                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      '${total.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: statusColor),
                    ),
                  ],
                ),

                // Motif annulation
                if (estAnnulee && motifAnnulation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Motif : $motifAnnulation',
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Bouton annulation ──
                if (peutAnnuler) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onAnnuler,
                      icon: const Icon(Icons.cancel_outlined,
                          color: Colors.red, size: 18),
                      label: const Text(
                        'Annuler cette commande',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.red.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style:
            const TextStyle(color: Colors.grey, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
    ]),
  );
}

// ── Widgets partagés ──
Widget _statBox(String label, String value, IconData icon, Color color) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
        ],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ]),
    ),
  );
}

Widget _sectionTitle(String title, Color color) {
  return Row(children: [
    Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(title,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: color)),
  ]);
}