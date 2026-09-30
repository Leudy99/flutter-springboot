import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/user_form_viewmodel.dart';
import 'common_widgets.dart';

/// Formulario para crear o editar (y ver) un usuario.
class UserFormView extends StatefulWidget {
  const UserFormView({super.key});

  @override
  State<UserFormView> createState() => _UserFormViewState();
}

class _UserFormViewState extends State<UserFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _filled = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save(UserFormViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await vm.save(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (ok && mounted) {
      Navigator.pop(context, true); // true = la lista debe recargarse
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserFormViewModel>();

    // Al editar, rellenar el formulario una sola vez con los datos cargados
    if (vm.user != null && !_filled) {
      _nameController.text = vm.user!.name;
      _emailController.text = vm.user!.email;
      _filled = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.isEditing ? 'Editar usuario' : 'Nuevo usuario'),
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vm.user != null) ...[
                      Card(
                        child: ListTile(
                          leading: UserAvatar(name: vm.user!.name, radius: 26),
                          title: Text(vm.user!.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              Text('${vm.user!.email}\nID ${vm.user!.id}'),
                          isThreeLine: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Escribe el nombre'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
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
                      decoration: InputDecoration(
                        labelText: 'Contrasena',
                        prefixIcon: const Icon(Icons.lock_outline),
                        helperText: vm.isEditing
                            ? 'Dejala vacia para conservar la actual'
                            : null,
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        final value = v ?? '';
                        if (vm.isEditing && value.isEmpty) return null;
                        return value.length < 6
                            ? 'Necesita al menos 6 caracteres'
                            : null;
                      },
                    ),
                    if (vm.error != null) ...[
                      const SizedBox(height: 16),
                      ErrorBanner(vm.error!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: vm.isSaving ? null : () => _save(vm),
                      icon: const Icon(Icons.check),
                      label: Text(vm.isSaving
                          ? 'Guardando...'
                          : vm.isEditing
                              ? 'Guardar cambios'
                              : 'Crear usuario'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
