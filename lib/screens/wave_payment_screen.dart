import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/payment_service.dart';

class WavePaymentScreen extends StatefulWidget {
  final double montant;
  final String commandeId;
  final String description;

  const WavePaymentScreen({
    super.key,
    required this.montant,
    required this.commandeId,
    required this.description,
  });

  @override
  State<WavePaymentScreen> createState() => _WavePaymentScreenState();
}

class _WavePaymentScreenState extends State<WavePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numeroCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  bool _loading = false;
  bool _etapeApp = true; // étape 1 = instructions app Wave, étape 2 = confirmation

  static const Color waveTeal = Color(0xFF009688);
  static const Color waveLight = Color(0xFFE0F2F1);
  static const String numeroMarchand = '09XXXXXXXX'; // ← remplacez

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  void _copierNumero() {
    Clipboard.setData(const ClipboardData(text: numeroMarchand));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Numéro copié !'), backgroundColor: waveTeal, duration: Duration(seconds: 2)),
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
        methode: 'wave',
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
                  decoration: const BoxDecoration(color: waveLight, shape: BoxShape.circle),
                  child: const Icon(Icons.hourglass_top_rounded, color: waveTeal, size: 48),
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
                child: const Text('OK', style: TextStyle(color: waveTeal)),
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
        backgroundColor: waveTeal,
        foregroundColor: Colors.white,
        title: const Text('Wave'),
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
                gradient: const LinearGradient(colors: [waveTeal, Color(0xFF26A69A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: waveTeal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  const Icon(Icons.waves_rounded, color: Colors.white, size: 40),
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
                _stepIndicator(1, 'Envoyer', _etapeApp),
                Expanded(child: Container(height: 2, color: _etapeApp ? Colors.grey.shade300 : waveTeal)),
                _stepIndicator(2, 'Confirmer', !_etapeApp),
              ],
            ),
            const SizedBox(height: 24),

            if (_etapeApp) ...[
              // Badge "Application mobile"
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: waveLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: waveTeal.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smartphone, color: waveTeal, size: 16),
                    SizedBox(width: 6),
                    Text('Via l\'application Wave', style: TextStyle(color: waveTeal, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              _card(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Étape 1 : Effectuez le transfert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _instructionRow('1', 'Ouvrez l\'application Wave sur votre téléphone'),
                  _instructionRow('2', 'Appuyez sur "Envoyer de l\'argent"'),
                  _instructionRow('3', 'Entrez le numéro du marchand :'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: waveLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: waveTeal.withOpacity(0.4))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(numeroMarchand, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: waveTeal, letterSpacing: 2)),
                        IconButton(icon: const Icon(Icons.copy, color: waveTeal), tooltip: 'Copier', onPressed: _copierNumero),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _instructionRow('4', 'Entrez le montant : ${widget.montant.toStringAsFixed(0)} FCFA'),
                  _instructionRow('5', 'Validez avec votre code PIN Wave'),
                  _instructionRow('6', 'Notez l\'ID de transaction affiché dans l\'app'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Wave est disponible sur iOS et Android. Assurez-vous d\'avoir un solde suffisant.',
                            style: TextStyle(fontSize: 12, color: Colors.orange, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _etapeApp = false),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("J'ai effectué le transfert"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: waveTeal, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            if (!_etapeApp) ...[
              _card(child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Étape 2 : Confirmez votre paiement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Renseignez les informations de votre transfert Wave.',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _numeroCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 10,
                      decoration: _inputDeco(label: 'Votre numéro Wave', hint: 'Ex: 0900000000', icon: Icons.phone_android),
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
                      decoration: _inputDeco(label: 'ID de transaction Wave', hint: 'Ex: WV-XXXXXXXXXX', icon: Icons.confirmation_number_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Champ obligatoire';
                        if (v.length < 6) return 'ID trop court';
                        return null;
                      },
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(() => _etapeApp = true),
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
                    backgroundColor: waveTeal, foregroundColor: Colors.white,
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
          decoration: const BoxDecoration(color: waveTeal, shape: BoxShape.circle),
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
        decoration: BoxDecoration(color: actif ? waveTeal : Colors.grey.shade300, shape: BoxShape.circle),
        child: Text('$num', style: TextStyle(color: actif ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: actif ? waveTeal : Colors.grey, fontWeight: actif ? FontWeight.bold : FontWeight.normal)),
    ],
  );

  InputDecoration _inputDeco({required String label, required String hint, required IconData icon}) => InputDecoration(
    labelText: label, hintText: hint,
    prefixIcon: Icon(icon, color: waveTeal),
    filled: true, fillColor: const Color(0xFFFAFAFA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: waveTeal, width: 2)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
  );
}
