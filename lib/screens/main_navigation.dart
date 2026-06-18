// ══════════════════════════════════════════════════════════════
// main_navigation.dart  —  Navigation principale CLIENT
// Onglets : Accueil (produits) | Panier | Commandes | Messages | Profil
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../services/cart_service.dart';
import '../services/notification_service.dart';
import '../screens/notifications_screen.dart';
import 'home_screen.dart';           // ClientOrdersScreen (Mes commandes)
import 'cart_screen.dart';           // CartScreen (Panier)
import 'profile_screen.dart';        // ProfileScreen (Profil)
import 'products_screen.dart';        // ProductsScreen (Accueil boutique)
import 'conversations_screen.dart'; // ConversationsScreen (Messages)

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final CartService _cartService = CartService();

  // Appelé depuis CartScreen après une commande → on va sur "Commandes"
  void _onOrderPlaced() => setState(() => _currentIndex = 2);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    NotificationService().init();

    final pages = [
      ProductsScreen(cartService: _cartService),                         // 0 - Accueil
      CartScreen(cartService: _cartService, onOrderPlaced: _onOrderPlaced), // 1 - Panier
      const ClientOrdersScreen(),                                        // 2 - Commandes
      const ConversationsScreen(isVendeur: false),                       // 3 - Messages
      const ProfileScreen(),                                             // 4 - Profil
    ];

    return Scaffold(
      // ── Cloche notifications flottante (comme côté vendeur) ──
      body: Stack(
        children: [
          pages[_currentIndex],
          Positioned(
            top: 50, right: 16,
            child: SafeArea(
              child: StreamBuilder<int>(
                stream: NotificationService().getUnreadCount(uid),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(isVendeur: false)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)
                        ],
                      ),
                      child: Stack(clipBehavior: Clip.none, children: [
                        const Icon(Icons.notifications_outlined,
                            color: AppColors.clientPrimary, size: 22),
                        if (count > 0)
                          Positioned(
                            top: -4, right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              constraints:
                              const BoxConstraints(minWidth: 16, minHeight: 16),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: Text(
                                count > 9 ? '9+' : '$count',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
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

      // ── Barre de navigation en bas ──
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
                _navItem(0, Icons.home_outlined, Icons.home, 'Accueil'),
                _navItemPanier(),
                _navItem(2, Icons.receipt_long_outlined, Icons.receipt_long, 'Commandes'),
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
    final active = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              color: active ? AppColors.clientPrimary : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? AppColors.clientPrimary : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Panier avec badge nombre d'articles ──
  Widget _navItemPanier() {
    final active = _currentIndex == 1;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = 1),
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _cartService,
          builder: (context, _) {
            final count = _cartService.count;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      active ? Icons.shopping_cart : Icons.shopping_cart_outlined,
                      color: active ? AppColors.clientPrimary : Colors.grey.shade400,
                      size: 24,
                    ),
                    if (count > 0)
                      Positioned(
                        top: -6, right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: const BoxDecoration(
                            color: AppColors.clientPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Panier',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? AppColors.clientPrimary : Colors.grey.shade400,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Messages avec badge non lus ──
  Widget _navItemMessages(String uid) {
    final active = _currentIndex == 3;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = 3),
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
                      color: active ? AppColors.clientPrimary : Colors.grey.shade400,
                      size: 24,
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -6, right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
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
                    color: active ? AppColors.clientPrimary : Colors.grey.shade400,
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
