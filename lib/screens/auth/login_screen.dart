import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }
    if (!_isLogin && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name')),
      );
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    if (_isLogin) {
      await notifier.signInWithEmailAndPassword(email, password);
    } else {
      await notifier.registerWithEmailAndPassword(email, password, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Logo mark ──
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Image.asset(
                                'assets/icon.png',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // ── Heading ──
                        Text(
                          _isLogin ? 'Welcome back' : 'Create account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isLogin
                              ? 'Sign in to continue to PointChat'
                              : 'Start messaging in seconds',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // ── Form ──
                        if (!_isLogin) ...[
                          _label('Display Name'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Your name',
                              prefixIcon: const Icon(Icons.person_outline),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        _label('Email'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'you@example.com',
                            prefixIcon: const Icon(Icons.mail_outline),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _label('Password'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Error ──
                        if (authState.error != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: AppTheme.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.zero,
                              border: Border.all(
                                color: AppTheme.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    authState.error!,
                                    style: GoogleFonts.inter(
                                      color: AppTheme.red,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── Primary button ──
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              disabledBackgroundColor: Colors.black54,
                            ),
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'Sign in' : 'Create account',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Toggle ──
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _isLogin = !_isLogin),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                children: [
                                  TextSpan(
                                    text: _isLogin
                                        ? "Don't have an account? "
                                        : "Already have an account? ",
                                  ),
                                  TextSpan(
                                    text: _isLogin ? 'Sign up' : 'Sign in',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.black,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Divider ──
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'or',
                                style: GoogleFonts.inter(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // ── Google sign-in ──
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: authState.isLoading
                                ? null
                                : () => ref
                                      .read(authProvider.notifier)
                                      .signInWithGoogle(),
                            icon: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.zero,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'G',
                                style: GoogleFonts.inter(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            label: Text(
                              'Continue with Google',
                              style: GoogleFonts.inter(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: GoogleFonts.inter(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    ),
  );
}
