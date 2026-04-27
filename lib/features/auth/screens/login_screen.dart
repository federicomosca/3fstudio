import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../providers/auth_provider.dart';
import '../utils/auth_error_translator.dart';
import 'password_reset_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .signIn(_emailController.text.trim(), _passwordController.text);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = translateAuthError(e.message));
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
      builder: (_) => const PasswordResetSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charcoal,
      resizeToAvoidBottomInset: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: _BrandSection()),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Theme(
              data: AppTheme.light,
              child: _LoginFormCard(
                formKey: _formKey,
                emailController: _emailController,
                passwordController: _passwordController,
                obscurePassword: _obscurePassword,
                loading: _loading,
                error: _error,
                onToggleObscure: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onForgotPassword: _showPasswordReset,
                onSubmit: _signIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Brand section ─────────────────────────────────────────────────────────────

class _BrandSection extends StatelessWidget {
  const _BrandSection();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const SizedBox(height: 16),
              const Text(
                'STUDIO',
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 6,
                  height: 1,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Login form card ───────────────────────────────────────────────────────────

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        28,
        32,
        28,
        28 + MediaQuery.of(context).padding.bottom,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const SizedBox(height: 24),

            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Email non valida' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'Minimo 6 caratteri' : null,
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xB40A1726),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Password dimenticata?',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),

            if (error != null) ...[
              ErrorBanner(message: error!),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onSubmit,
                child: loading ? const LoadingSpinner() : const Text('ACCEDI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

