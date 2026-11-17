import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../theme.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'common_widgets.dart';

/// Pestana Chat: mensajes en tiempo real por WebSocket.
/// Nombre de usuario, estado de la conexion, area de mensajes y caja para escribir.
class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageFocus = FocusNode();
  int _shownMessages = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection(ChatViewModel vm) async {
    if (vm.isConnected) {
      await vm.disconnect();
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Escribe tu nombre')));
      return;
    }
    await vm.connect(name);
    if (vm.isConnected) _messageFocus.requestFocus();
  }

  void _send(ChatViewModel vm) {
    vm.send(_messageController.text);
    _messageController.clear();
    _messageFocus.requestFocus();
  }

  /// Baja la lista hasta el ultimo mensaje cuando llega uno nuevo.
  void _scrollToEnd(int count) {
    if (count == _shownMessages) return;
    _shownMessages = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatViewModel>();
    _scrollToEnd(vm.messages.length);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat WebSocket')),
      body: Column(
        children: [
          _buildConnectionBar(vm),
          if (vm.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ErrorBanner(vm.error!),
            ),
          Expanded(child: _buildMessages(vm)),
          _buildInputBar(vm),
        ],
      ),
    );
  }

  /// Nombre + boton Conectar/Desconectar + estado.
  Widget _buildConnectionBar(ChatViewModel vm) {
    final connecting = vm.status == ChatStatus.connecting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  enabled: vm.status == ChatStatus.disconnected,
                  maxLength: 30,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _toggleConnection(vm),
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Leudy',
                    prefixIcon: Icon(Icons.person_outline),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              vm.isConnected
                  ? OutlinedButton.icon(
                      onPressed: () => _toggleConnection(vm),
                      icon: const Icon(Icons.link_off),
                      label: const Text('Desconectar'),
                    )
                  : FilledButton.icon(
                      onPressed: connecting ? null : () => _toggleConnection(vm),
                      icon: connecting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Icon(Icons.link),
                      label: Text(connecting ? 'Conectando...' : 'Conectar'),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          _StatusChip(vm.status),
        ],
      ),
    );
  }

  Widget _buildMessages(ChatViewModel vm) {
    if (vm.messages.isEmpty) {
      return EmptyState(
        icon: Icons.forum_outlined,
        title: vm.isConnected ? 'Aun no hay mensajes' : 'Chat en tiempo real',
        message: vm.isConnected
            ? 'Escribe el primero.'
            : 'Escribe tu nombre y pulsa Conectar. Abre la app en otra '
                'ventana para chatear con otro usuario.',
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: vm.messages.length,
      itemBuilder: (_, i) =>
          _MessageTile(vm.messages[i], mine: vm.messages[i].username == vm.username),
    );
  }

  Widget _buildInputBar(ChatViewModel vm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocus,
              enabled: vm.isConnected,
              maxLength: 500,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(vm),
              decoration: const InputDecoration(
                hintText: 'Escribir mensaje...',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: vm.isConnected ? () => _send(vm) : null,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}

/// Punto de color + texto: Desconectado / Conectando / Conectado.
class _StatusChip extends StatelessWidget {
  final ChatStatus status;

  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ChatStatus.connected => ('Conectado', AppColors.teal),
      ChatStatus.connecting => ('Conectando...', AppColors.amber),
      ChatStatus.disconnected => ('Desconectado', AppColors.inkSoft),
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text('Estado: $label',
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Un mensaje: burbuja (propia a la derecha, ajena a la izquierda) o aviso de sistema.
class _MessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool mine;

  const _MessageTile(this.message, {required this.mine});

  @override
  Widget build(BuildContext context) {
    final time = formatDateTime(message.timestamp);

    // "Leudy se ha conectado." / "Carlos se ha desconectado."
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            '[$time] ${message.message}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.inkSoft,
                fontStyle: FontStyle.italic,
                fontSize: 12),
          ),
        ),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: mine ? AppColors.tealSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mine ? 'Tu' : message.username,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.teal)),
            const SizedBox(height: 2),
            Text(message.message),
            const SizedBox(height: 4),
            Text(time,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
