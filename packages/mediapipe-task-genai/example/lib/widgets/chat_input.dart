import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  const ChatInput({
    required this.submit,
    required this.controller,
    required this.isLlmTyping,
    super.key,
  });

  final TextEditingController controller;

  final void Function(String) submit;

  /// Prevents submitting new messages when true.
  final bool isLlmTyping;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: TextField(controller: controller)),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, child) {
            return IconButton(
              icon: const Icon(Icons.send),
              onPressed: controller.text != '' && !isLlmTyping
                  ? () {
                      submit(controller.text);
                      controller.clear();
                    }
                  : null,
            );
          },
        ),
      ],
    );
  }
}
