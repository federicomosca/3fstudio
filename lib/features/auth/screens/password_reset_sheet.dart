import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/loading_spinner.dart';

class PasswordResetSheet extends StatefulWidget {
  const PasswordResetSheet({super.key});

  @override
  State<PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<PasswordResetSheet> {
  final _ctrl    = TextEditingController();
  bool    _sent    = false;
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _ctrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Inserisci un indirizzo email valido');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) setState(() { _sent = true; _loading = false; });
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Errore di connessione. Riprova.'; _loading = false; });
    }
  }

  Widget _buildSent(BuildContext context) {
    return Column(
      mainAxisSize:       MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.mark_email_read_outlined,
            size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        const Text('Email inviata!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          'Controlla la tua casella di posta e segui le istruzioni per reimpostare la password.',
          style: TextStyle(
              color:  Theme.of(context).colorScheme.onSurface.withAlpha(180),
              height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      mainAxisSize:       MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reimposta password',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          'Inserisci la tua email. Ti invieremo un link per reimpostare la password.',
          style: TextStyle(
              color:  Theme.of(context).colorScheme.onSurface.withAlpha(180),
              height: 1.5),
        ),
        const SizedBox(height: 24),
        TextField(
          controller:      _ctrl,
          keyboardType:    TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted:     (_) => _send(),
          decoration: const InputDecoration(
            labelText:  'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _send,
            child: _loading ? const LoadingSpinner() : const Text('Invia link'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sent ? _buildSent(context) : _buildForm(context),
        ],
      ),
    );
  }
}
