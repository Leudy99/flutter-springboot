import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../viewmodels/login_viewmodel.dart';
import 'common_widgets.dart';

/// Pantalla de acceso: iniciar sesion (POST /auth/login) o crear cuenta (POST /auth/register).
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(LoginViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final ok = vm.isRegisterMode
        ? await vm.register(_nameController.text.trim(), email, password)
        : await vm.login(email, password);

    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    // Iconos claros en la barra de estado sobre la cabecera oscura
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildPanel(vm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(LoginViewModel vm) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Iniciar sesion')),
                  ButtonSegment(value: true, label: Text('Crear cuenta')),
                ],
                selected: {vm.isRegisterMode},
                onSelectionChanged: vm.isLoading
                    ? null
                    : (s) {
                        if (s.first != vm.isRegisterMode) vm.toggleMode();
                      },
              ),
              const SizedBox(height: 24),
              if (vm.isRegisterMode) ...[
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Escribe tu nombre'
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Correo electronico',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (v) => v == null || !v.contains('@')
                    ? 'Escribe un correo valido'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(vm),
                decoration: InputDecoration(
                  labelText: 'Contrasena',
                  helperText: vm.isRegisterMode ? 'Minimo 6 caracteres' : null,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => v == null || v.length < 6
                    ? 'La contrasena necesita al menos 6 caracteres'
                    : null,
              ),
              if (vm.error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(vm.error!),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.isLoading ? null : () => _submit(vm),
                child: vm.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(vm.isRegisterMode ? 'Crear cuenta' : 'Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
