import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth_cubit.dart';
import 'register_screen.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background environment with gradient and subtle blur
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  theme.colorScheme.surface.withValues(alpha: 0.9),
                  theme.colorScheme.surface,
                ],
                radius: 1.5,
              ),
            ),
          ),
          
          // Luminous Depth Orbs
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25,
            left: MediaQuery.of(context).size.width * 0.25,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2), // primary-container color
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    blurRadius: 100,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25,
            right: MediaQuery.of(context).size.width * 0.25,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0053DB).withValues(alpha: 0.1), // secondary-container
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0053DB).withValues(alpha: 0.1),
                    blurRadius: 100,
                  )
                ],
              ),
            ),
          ),

          // Main Login Canvas
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 440),
                    padding: const EdgeInsets.all(48.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 32,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Header
                        Text(
                          'TEAMUP',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            letterSpacing: -1.0,
                            shadows: [
                              Shadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                blurRadius: 15,
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Initialize connection sequence.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Email Form Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMAIL ADDRESS',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _emailController,
                              style: theme.textTheme.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'player@teamup.gg',
                                prefixIcon: const Icon(Icons.mail_outline),
                                fillColor: const Color(0xFF2D3449).withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Password Form Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PASSWORD',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: theme.textTheme.bodyMedium,
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline),
                                fillColor: const Color(0xFF2D3449).withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        BlocConsumer<AuthCubit, AuthState>(
                          listener: (context, state) {
                            if (state.successMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(state.successMessage!),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              context.read<AuthCubit>().clearSuccessMessage();
                            }
                            if (state.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(state.error!),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                            }
                          },
                          builder: (context, state) {
                            return FilledButton.icon(
                              onPressed: state.loading ? null : () {
                                final email = _emailController.text.trim();
                                final password = _passwordController.text.trim();
                                if (email.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Veuillez entrer votre adresse email.')),
                                  );
                                  return;
                                }
                                if (password.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Veuillez entrer votre mot de passe.')),
                                  );
                                  return;
                                }
                                context.read<AuthCubit>().signIn(email, password);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED), // primary-container
                                foregroundColor: const Color(0xFFEDE0FF), // on-primary-container
                                elevation: 8,
                                shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              icon: state.loading 
                                ? const SizedBox(
                                    width: 24, 
                                    height: 24, 
                                    child: CircularProgressIndicator(color: Color(0xFFEDE0FF), strokeWidth: 2)
                                  )
                                : const Icon(Icons.login),
                              label: Text(
                                state.loading ? 'Connexion en cours...' : 'Se connecter',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                children: [
                                  const TextSpan(text: 'No account yet? '),
                                  TextSpan(
                                    text: 'Register here',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }
}
