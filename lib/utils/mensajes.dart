import 'package:flutter/material.dart';

enum MessageType { confirmation, error, info, success }

void mostrarMensaje(BuildContext context, String mensaje, MessageType tipo) {
  final color = tipo == MessageType.confirmation ? Colors.green : Colors.redAccent;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: color,
    ),
  );
}

