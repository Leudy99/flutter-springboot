import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../viewmodels/notification_viewmodel.dart';
import 'common_widgets.dart';

/// Formulario para enviar una notificacion por correo (POST /notifications/send).
class NotificationView extends StatefulWidget {
  const NotificationView({super.key});

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send(NotificationViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ok = await vm.send(
      _emailController.text,
      _subjectController.text,
      _messageController.text,
    );

    // Tras enviar bien se limpian asunto y mensaje (el correo se conserva
    // por si se quiere mandar otro al mismo destinatario).
    if (ok) {
      _subjectController.clear();
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar notificacion')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'El mensaje se publica en AWS y se envia por correo de forma '
                'asincrona. Puede tardar unos segundos en llegar.',
                style: TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Correo destino',
                  hintText: 'usuario@correo.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (v) => v == null || !v.contains('@')
                    ? 'Escribe un correo valido'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _subjectController,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Asunto',
                  hintText: 'Prueba SNS',
                  prefixIcon: Icon(Icons.subject),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe el asunto' : null,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageController,
                keyboardType: TextInputType.multiline,
                minLines: 4,
                maxLines: 8,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  hintText: 'Hola desde AWS Serverless',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe el mensaje' : null,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: vm.isSending ? null : () => _send(vm),
                icon: vm.isSending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(vm.isSending ? 'Enviando...' : 'Enviar mensaje'),
              ),
              if (vm.successMessage != null) ...[
                const SizedBox(height: 16),
                _SuccessBanner(vm.successMessage!),
              ],
              if (vm.error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(vm.error!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Caja verde con el mensaje de exito (par de ErrorBanner).
class _SuccessBanner extends StatelessWidget {
  final String message;

  const _SuccessBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tealSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: AppColors.teal, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
