import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../main.dart';

class DeliveryScreen extends StatelessWidget {
  const DeliveryScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmée': return AppColors.clientSecondary;
      case 'en_livraison': return Colors.orange;
      case 'livrée': return Colors.green;
      case 'annulée': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'confirmée': return Icons.check_circle;
      case 'en_livraison': return Icons.delivery_dining;
      case 'livrée': return Icons.done_all;
      case 'annulée': return Icons.cancel;
      default: return Icons.hourglass_empty;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'en_attente': return 'En attente';
      case 'confirmée': return 'Confirmée';
      case 'en_livraison': return 'En livraison';
      case 'livrée': return 'Livrée';
      case 'annulée': return 'Annulée';
      default: return status;
    }
  }

  double _statusProgress(String status) {
    switch (status) {
      case 'en_attente': return 0.15;
      case 'confirmée': return 0.45;
      case 'en_livraison': return 0.75;
      case 'livrée': return 1.0;
      default: return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Connectez-vous')),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mes Commandes'),
        backgroundColor: AppColors.clientPrimary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<AppOrder>>(
        stream: OrderService().getUserOrders(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.clientPrimary));
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }
          final orders = snap.data ?? [];
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.clientPrimary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        size: 64, color: AppColors.clientPrimary),
                  ),
                  const SizedBox(height: 20),
                  const Text('Aucune commande pour le moment',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (_, i) => _orderCard(context, orders[i]),
          );
        },
      ),
    );
  }

  Widget _orderCard(BuildContext context, AppOrder order) {
    final color = _statusColor(order.status);
    final progress = _statusProgress(order.status);
    final isAnnulee = order.status == 'annulée';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(children: [
        Container(
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Commande #${order.id.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon(order.status), color: color, size: 13),
                  const SizedBox(width: 4),
                  Text(_statusLabel(order.status),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
            if (!isAnnulee) ...[
              const SizedBox(height: 14),
              _progressBar(progress, color),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _progressLabel('Passée', order.status, ['en_attente', 'confirmée', 'en_livraison', 'livrée']),
                _progressLabel('Confirmée', order.status, ['confirmée', 'en_livraison', 'livrée']),
                _progressLabel('En route', order.status, ['en_livraison', 'livrée']),
                _progressLabel('Livrée', order.status, ['livrée']),
              ]),
            ],
            const Divider(height: 20),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(width: 6, height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('${item['name']} × ${item['quantity']}',
                      style: const TextStyle(fontSize: 13)),
                ]),
                Text(
                  '${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ]),
            )),
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${order.total.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      color: AppColors.clientPrimary, fontSize: 16)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(order.address,
                  style: const TextStyle(color: Colors.grey, fontSize: 12))),
            ]),
            if (order.status == 'en_livraison') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await OrderService().confirmerReception(order.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reception confirmee !'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Confirmer la reception',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
            if (order.status == 'livrée') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.done_all, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text('Commande livree avec succes !',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _progressBar(double value, Color color) {
    return Stack(children: [
      Container(height: 6,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3))),
      FractionallySizedBox(
        widthFactor: value,
        child: Container(height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.clientPrimary, color]),
              borderRadius: BorderRadius.circular(3),
            )),
      ),
    ]);
  }

  Widget _progressLabel(String label, String currentStatus, List<String> activeStatuses) {
    final active = activeStatuses.contains(currentStatus);
    return Text(label, style: TextStyle(
      fontSize: 9,
      fontWeight: active ? FontWeight.bold : FontWeight.normal,
      color: active ? AppColors.clientPrimary : Colors.grey.shade400,
    ));
  }
}
