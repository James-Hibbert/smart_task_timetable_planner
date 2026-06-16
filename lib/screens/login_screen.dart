import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showVerificationPrompt = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthState>();

    final success = _isRegisterMode
        ? await authState.register(
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      rememberMe: _rememberMe,
    )
        : await authState.login(
      email: _emailController.text,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    if (success) {
      if (_isRegisterMode) {
        setState(() {
          _isRegisterMode = false;
          _showVerificationPrompt = true;
          _confirmPasswordController.clear();
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Account created. Check your inbox or junk folder, open the verification email, then return here and tap "I’ve verified my email".',
              ),
            ),
          );
        return;
      }

      setState(() {
        _showVerificationPrompt = false;
      });

      await context.read<AppState>().setCurrentUserContext(
        context.read<AuthState>().currentUserId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Logged in successfully.'),
          ),
        );
    } else {
      final error = context.read<AuthState>().errorMessage;

      if (!_isRegisterMode &&
          error != null &&
          error.toLowerCase().contains('not verified')) {
        setState(() {
          _showVerificationPrompt = true;
        });
      }

      if (error != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(error)),
          );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final forgotFormKey = GlobalKey<FormState>();
    final forgotEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Forgot Password'),
              content: Form(
                key: forgotFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your email and we’ll send you a password reset link.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: forgotEmailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Please enter your email.';
                        }
                        if (!text.contains('@') || !text.contains('.')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (!forgotFormKey.currentState!.validate()) return;

                    setDialogState(() {
                      isSubmitting = true;
                    });

                    final success =
                    await context.read<AuthState>().sendPasswordReset(
                      email: forgotEmailController.text.trim(),
                    );

                    if (!mounted) return;

                    Navigator.of(dialogContext).pop();

                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Password reset email sent.'
                                : context.read<AuthState>().errorMessage ??
                                'Failed to send reset email.',
                          ),
                        ),
                      );
                  },
                  child: isSubmitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    );

    forgotEmailController.dispose();
  }

  Future<void> _resendVerificationEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Enter your email and password first, then try resending the verification email.',
            ),
          ),
        );
      return;
    }

    final success = await context.read<AuthState>().resendVerificationEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    final message = success
        ? 'Verification email sent. Check your inbox and junk folder, then return here after verifying.'
        : context.read<AuthState>().errorMessage ??
        'Unable to resend verification email.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _checkVerificationStatus() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Enter your email and password first so verification can be checked.',
            ),
          ),
        );
      return;
    }

    final success = await context.read<AuthState>().checkVerificationStatus(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _showVerificationPrompt = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Email verified successfully. You can now log in.',
            ),
          ),
        );
    } else {
      final message = context.read<AuthState>().errorMessage ??
          'Your email is still not verified.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  Widget _buildVerificationPrompt(AuthState authState) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                color: Colors.amber.shade800,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verify your email before logging in',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '1. Open the latest verification email.\n'
                '2. Tap the verification link.\n'
                '3. Return to the app and tap "I’ve verified my email".',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed:
                authState.isLoading ? null : _checkVerificationStatus,
                child: const Text('I’ve verified my email'),
              ),
              OutlinedButton(
                onPressed:
                authState.isLoading ? null : _resendVerificationEmail,
                child: const Text('Resend email'),
              ),
              TextButton(
                onPressed: authState.isLoading
                    ? null
                    : () {
                  setState(() {
                    _showVerificationPrompt = false;
                  });
                },
                child: const Text('Back to login'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_showVerificationPrompt)
                          _buildVerificationPrompt(authState),
                        Text(
                          'Smart Task & Timetable Planner',
                          style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRegisterMode
                              ? 'Create an account to access your planner.'
                              : 'Log in to continue to your planner.',
                          style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Please enter your email.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final text = value ?? '';
                            if (text.isEmpty) {
                              return 'Please enter your password.';
                            }
                            if (_isRegisterMode && text.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        if (!_isRegisterMode) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: authState.isLoading
                                  ? null
                                  : _showForgotPasswordDialog,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: authState.isLoading
                                  ? null
                                  : _resendVerificationEmail,
                              child: const Text('Resend verification email'),
                            ),
                          ),
                        ],
                        if (_isRegisterMode) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (!_isRegisterMode) return null;
                              final text = value ?? '';
                              if (text.isEmpty) {
                                return 'Please confirm your password.';
                              }
                              if (text != _passwordController.text) {
                                return 'Passwords do not match.';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: _rememberMe,
                          onChanged: authState.isLoading
                              ? null
                              : (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          title: const Text('Remember me'),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            authState.errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _submit,
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              child: authState.isLoading
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : Text(
                                _isRegisterMode
                                    ? 'Create Account'
                                    : 'Login',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: authState.isLoading
                                ? null
                                : () {
                              setState(() {
                                _isRegisterMode = !_isRegisterMode;
                                _showVerificationPrompt = false;
                              });
                              context.read<AuthState>().clearError();
                            },
                            child: Text(
                              _isRegisterMode
                                  ? 'Already have an account? Login'
                                  : 'Need an account? Register',
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
        ),
      ),
    );
  }
}