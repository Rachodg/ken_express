import 'package:flutter/material.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import '../main.dart'; // AppColors

class ComplaintScreen extends StatefulWidget {
  final bool isVendeur;

  const ComplaintScreen({super.key, this.isVendeur = false});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _complaintService = ComplaintService();
  bool _sending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Color get _color =>
      widget.isVendeur ? Colors.orange : AppColors.clientPrimary;

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir le sujet et le message')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _complaintService.submitComplaint(
        subject: subject,
        message: message,
        userRole: widget.isVendeur ? 'vendeur' : 'client',
      );
      if (mounted) {
        _subjectCtrl.clear();
        _messageCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Votre reclamation a ete envoyee au service client'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Service client'),
        backgroundColor: _color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Formulaire ──
          Container(
            padding: const EdgeInsets.all(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.support_agent, color: _color, size: 22),
                  const SizedBox(width: 8),
                  const Text('Faire une reclamation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                const Text(
                  'Decrivez votre probleme, notre equipe vous repondra dans les plus brefs delais.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _subjectCtrl,
                  decoration: InputDecoration(
                    labelText: 'Sujet',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Votre message',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                    label: Text(_sending ? 'Envoi...' : 'Envoyer',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Historique de mes plaintes ──
          const Text('Mes reclamations',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          StreamBuilder<List<Complaint>>(
            stream: _complaintService.getMyComplaints(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _color));
              }
              final complaints = snap.data ?? [];
              if (complaints.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Aucune reclamation envoyee pour le moment',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                );
              }
              return Column(
                children: complaints.map((c) => _complaintCard(c)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _complaintCard(Complaint c) {
    final statusColor = _statusColor(c.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(c.subject,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(_statusLabel(c.status),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.message, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 6),
          Text('${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}',
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
          if (c.response != null && c.response!.isNotEmpty) ...[
            const Divider(height: 16),
            Row(children: [
              Icon(Icons.support_agent, color: _color, size: 16),
              const SizedBox(width: 6),
              const Text('Reponse du support',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text(c.response!, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'en_cours': return Colors.blue;
      case 'resolue': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'en_cours': return 'En cours';
      case 'resolue': return 'Resolue';
      default: return 'En attente';
    }
  }
}