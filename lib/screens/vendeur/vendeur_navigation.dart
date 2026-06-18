import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vendeur_home_screen.dart';
import 'mes_produits_screen.dart';
import 'commandes_recues_screen.dart';
import '../conversations_screen.dart';
import 'vendeur_profil_screen.dart';
import '../notifications_screen.dart';
import '../../services/notification_service.dart';
import '../../services/order_service.dart';

class VendeurNavigation extends StatefulWidget {
  const VendeurNavigation({super.key});
  @override
  State<VendeurNavigation> createState() => VendeurNavigationState();
}

class VendeurNavigationState extends State<VendeurNavigation> {
  int currentIndex = 0;

  void navigateTo(int index) => setState(() => currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    NotificationService().init();

    final pages = [
      VendeurHomeScreen(onNavigate: navigateTo),
      const MesProduitsScreen(),
      const CommandesRecuesScreen(),
      const ConversationsScreen(isVendeur: true), // ← messagerie vendeur
      VendeurProfilScreen(onNavigate: navigateTo),
    ];

    return Scaffold(
      body: Stack(
        children: [
          pages[currentIndex],
          Positioned(
            top: 50, right: 16,
            child: SafeArea(
              child: StreamBuilder<int>(
                stream: NotificationService().getUnreadCount(uid),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => NotificationsScreen(
                            isVendeur: true, onNavigateVendeur: navigateTo))),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                      ),
                      child: Stack(clipBehavior: Clip.none, children: [
                        const Icon(Icons.notifications_outlined, color: Colors.orange, size: 22),
                        if (count > 0)
                          Positioned(
                            top: -4, right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text(count > 9 ? '9+' : '$count',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center),
                            ),
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _navItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                _navItem(1, Icons.inventory_2_outlined, Icons.inventory_2, 'Produits'),
                _navItemCommandes(uid),
                _navItemMessages(uid),
                _navItem(4, Icons.person_outline, Icons.person, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Item normal ──
  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final active = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              color: active ? Colors.orange : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.orange : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Item Commandes avec badge des commandes confirmees (non traitees) ──
  Widget _navItemCommandes(String uid) {
    final active = currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentIndex = 2),
        behavior: HitTestBehavior.opaque,
        child: StreamBuilder<int>(
          stream: OrderService().getOrdersCountByStatus(uid, 'confirmée'),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      active ? Icons.receipt_long : Icons.receipt_long_outlined,
                      color: active ? Colors.orange : Colors.grey.shade400,
                      size: 24,
                    ),
                    if (count > 0)
                      Positioned(
                        top: -6,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Commandes',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? Colors.orange : Colors.grey.shade400,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Item messages avec badge non lus ──
  Widget _navItemMessages(String uid) {
    final active = currentIndex == 3;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentIndex = 3),
        behavior: HitTestBehavior.opaque,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .where('participants', arrayContains: uid)
              .snapshots(),
          builder: (context, snap) {
            int unread = 0;
            for (final doc in snap.data?.docs ?? []) {
              final d = doc.data() as Map<String, dynamic>;
              final lastSenderId = d['lastSenderId'] ?? '';
              final isRead = d['isRead_$uid'] ?? true;
              if (lastSenderId != uid && isRead == false) unread++;
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      active ? Icons.chat : Icons.chat_outlined,
                      color: active ? Colors.orange : Colors.grey.shade400,
                      size: 24,
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -6,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? Colors.orange : Colors.grey.shade400,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}