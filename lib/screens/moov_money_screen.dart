import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/payment_service.dart';

class MoovMoneyPaymentScreen extends StatefulWidget {
  final double montant;
  final String commandeId;
  final String description;

  const MoovMoneyPaymentScreen({
    super.key,
    required this.montant,
    required this.commandeId,
    required this.description,
  });

  @override
  State<MoovMoneyPaymentScreen> createState() => _MoovMoneyPaymentScreenState();
}

class _MoovMoneyPaymentScreenState extends State<MoovMoneyPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numeroCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  bool _loading = false;
  bool _etapeUssd = true;

  static const Color moovBlue = Color(0xFF0066CC);
  static const Color moovLight = Color(0xFFE3F0FF);
  static const String numeroMarchand = '06XXXXXXXX'; // ← remplacez

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  void _copierNumero() {
    Clipboard.setData(const ClipboardData(text: numeroMarchand));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Numéro copié !'), backgroundColor: moovBlue, duration: Duration(seconds: 2)),
    );
  }

  Future<void> _soumettre() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await PaymentService().soumettreGeneral(
        uid: uid,
        commandeId: widget.commandeId,
        montant: widget.montant,
        numeroPaiement: _numeroCtrl.text.trim(),
        referenceTransaction: _referenceCtrl.text.trim(),
        description: widget.description,
        methode: 'moov_money',
      );
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: moovLight, shape: BoxShape.circle),
                  child: const Icon(Icons.hourglass_top_rounded, color: moovBlue, size: 48),
                ),
                const SizedBox(height: 16),
                const Text('Paiement en attente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Votre paiement a été soumis.\nL\'administrateur va vérifier et valider sous peu.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(true); },
                child: const Text('OK', style: TextStyle(color: moovBlue)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: moovBlue,
        foregroundColor: Colors.white,
        title: const Text('Moov Money'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header montant
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [moovBlue, Color(0xFF0099FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: moovBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text('Montant à payer', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${widget.montant.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(widget.description, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stepper
            Row(
              children: [
                _stepIndicator(1, 'Transférer', _etapeUssd),
                Expanded(child: Container(height: 2, color: _etapeUssd ? Colors.grey.shade300 : moovBlue)),
                _stepIndicator(2, 'Confirmer', !_etapeUssd),
              ],
            ),
            const SizedBox(height: 24),

            if (_etapeUssd) ...[
              _card(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Étape 1 : Effectuez le transfert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _instructionRow('1', 'Composez *155# sur votre téléphone Moov'),
                  _instructionRow('2', 'Choisissez "Transfert" puis "Paiement marchand"'),
                  _instructionRow('3', 'Entrez le numéro marchand :'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: moovLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: moovBlue.withOpacity(0.4))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(numeroMarchand, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: moovBlue, letterSpacing: 2)),
                        IconButton(icon: const Icon(Icons.copy, color: moovBlue), tooltip: 'Copier', onPressed: _copierNumero),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _instructionRow('4', 'Entrez le montant : ${widget.montant.toStringAsFixed(0)} FCFA'),
                  _instructionRow('5', 'Notez la référence de transaction affichée'),
                ],
              )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _etapeUssd = false),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("J'ai effectué le transfert"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: moovBlue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            if (!_etapeUssd) ...[
              _card(child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Étape 2 : Confirmez votre paiement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Renseignez les informations de votre transfert Moov Money.',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _numeroCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 10,
                      decoration: _inputDeco(label: 'Votre numéro Moov Money', hint: 'Ex: 0650000000', icon: Icons.phone_android),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Champ obligatoire';
                        if (v.length < 8) return 'Numéro invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _referenceCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDeco(label: 'Référence de transaction', hint: 'Ex: MM241213XXXXXXX', icon: Icons.confirmation_number_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Champ obligatoire';
                        if (v.length < 6) return 'Référence trop courte';
                        return null;
                      },
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(() => _etapeUssd = true),
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                label: const Text('Retour aux instructions', style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _soumettre,
                  icon: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(_loading ? 'Envoi en cours...' : 'Soumettre le paiement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: moovBlue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: child,
  );

  Widget _instructionRow(String num, String texte) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, height: 24, alignment: Alignment.center,
          decoration: const BoxDecoration(color: moovBlue, shape: BoxShape.circle),
          child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(texte, style: const TextStyle(fontSize: 14, height: 1.5))),
      ],
    ),
  );

  Widget _stepIndicator(int num, String label, bool actif) => Column(
    children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 32, height: 32, alignment: Alignment.center,
        decoration: BoxDecoration(color: actif ? moovBlue : Colors.grey.shade300, shape: BoxShape.circle),
        child: Text('$num', style: TextStyle(color: actif ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: actif ? moovBlue : Colors.grey, fontWeight: actif ? FontWeight.bold : FontWeight.normal)),
    ],
  );

  InputDecoration _inputDeco({required String label, required String hint, required IconData icon}) => InputDecoration(
    labelText: label, hintText: hint,
    prefixIcon: Icon(icon, color: moovBlue),
    filled: true, fillColor: const Color(0xFFFAFAFA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: moovBlue, width: 2)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
  );
}
