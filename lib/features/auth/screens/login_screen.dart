import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool    _loading         = false;
  bool    _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Traduce i messaggi di errore di Supabase ──────────────────────────────
  String _translateError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'Email o password non corretti.';
    }
    if (m.contains('email not confirmed')) {
      return 'Email non confermata. Controlla la casella di posta.';
    }
    if (m.contains('too many requests')) {
      return 'Troppi tentativi. Riprova tra qualche minuto.';
    }
    if (m.contains('network') || m.contains('connection')) {
      return 'Errore di connessione. Controlla la rete.';
    }
    return msg;
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authNotifierProvider.notifier).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _translateError(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Errore di connessione. Controlla la rete.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPasswordReset() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _PasswordResetSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charcoal,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          reverse: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
          // ── Sezione brand (dark) ─────────────────────────────────────────
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),

                    // Badge 3F
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.lime, width: 2.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '3F',
                          style: TextStyle(
                            color:        AppTheme.lime,
                            fontSize:     22,
                            fontWeight:   FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'STUDIO',
                      style: TextStyle(
                        color:        AppTheme.white,
                        fontSize:     32,
                        fontWeight:   FontWeight.w900,
                        letterSpacing: 6,
                        height:       1,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      '"Qui non ti alleni.\nImpari ad allenarti."',
                      style: TextStyle(
                        color:        AppTheme.white.withAlpha(140),
                        fontSize:     14,
                        fontStyle:    FontStyle.italic,
                        height:       1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // ── Form (white) ─────────────────────────────────────────────────
          // Force light theme inside the white section so text/input colors
          // are dark-on-white regardless of the global dark ThemeMode.
          Theme(
            data: AppTheme.light,
            child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              28, 32, 28,
              28 + MediaQuery.of(context).padding.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Accedi',
                    style: TextStyle(
                      fontSize:      22,
                      fontWeight:    FontWeight.w900,
                      letterSpacing: -0.5,
                      color:         Color(0xFF0A1726),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bentornato nel tuo studio 👊',
                    style: TextStyle(
                      color:    Color(0x960A1726),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email
                  TextFormField(
                    controller:      _emailController,
                    keyboardType:    TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText:  'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Email non valida' : null,
                  ),
                  const SizedBox(height: 14),

                  // Password
                  TextFormField(
                    controller:       _passwordController,
                    obscureText:      _obscurePassword,
                    textInputAction:  TextInputAction.done,
                    onFieldSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText:  'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Minimo 6 caratteri' : null,
                  ),

                  // Password dimenticata
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showPasswordReset,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xB40A1726),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                      ),
                      child: const Text('Password dimenticata?',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),

                  // Error banner
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color:         const Color(0xFFFFEBEE),
                        borderRadius:  BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFD32F2F).withAlpha(100)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFB71C1C),
                              size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color:    Color(0xFFB71C1C),
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 8),

                  // Accedi button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                          : const Text('ACCEDI'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ), // Theme light
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Password reset bottom sheet ───────────────────────────────────────────────

class _PasswordResetSheet extends StatefulWidget {
  const _PasswordResetSheet();

  @override
  State<_PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<_PasswordResetSheet> {
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
      await Supabase.instance.client.auth
          .resetPasswordForEmail(email);
      if (mounted) setState(() { _sent = true; _loading = false; });
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error   = 'Errore di connessione. Riprova.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_sent) ...[
            // Conferma invio
            Icon(Icons.mark_email_read_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Email inviata!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              'Controlla la tua casella di posta e segui le istruzioni per reimpostare la password.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(180), height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Chiudi'),
              ),
            ),
          ] else ...[
            const Text('Reimposta password',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              'Inserisci la tua email. Ti invieremo un link per reimpostare la password.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(180), height: 1.5),
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
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Invia link'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
