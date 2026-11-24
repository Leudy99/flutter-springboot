import 'package:flutter/material.dart';
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildForm(vm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(LoginViewModel vm) {
    final register = vm.isRegisterMode;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(register ? 'Crear cuenta' : 'Iniciar sesion',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            register
                ? 'Registrate para usar la app.'
                : 'Entra con tu correo y contrasena.',
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 28),
          if (register) ...[
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Escribe tu nombre' : null,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Correo electronico'),
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
              helperText: register ? 'Minimo 6 caracteres' : null,
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
                : Text(register ? 'Crear cuenta' : 'Entrar'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: vm.isLoading ? null : vm.toggleMode,
            child: Text(register
                ? 'Ya tengo cuenta. Iniciar sesion'
                : 'No tengo cuenta. Crear una'),
          ),
        ],
      ),
    );
  }
}
