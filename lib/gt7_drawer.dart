import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GT7Drawer extends StatelessWidget {
  final TextEditingController ipController;
  final bool isListening;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final int packetCount;
  final String status;

  const GT7Drawer({
    super.key,
    required this.ipController,
    required this.isListening,
    required this.onStart,
    required this.onStop,
    required this.packetCount,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Drawer(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: Text(
                      "Menu",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Divider(),
                TextField(
                  controller: ipController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: "PlayStation IP",
                    hintText: "192.168.0.12",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isListening ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isListening ? onStop : onStart,
                  child: Text(isListening ? "stop" : "start"),
                ),
                const SizedBox(height: 8),
                Text(
                  "Received Packets: $packetCount",
                  style: const TextStyle(fontSize: 16),
                ),
                const Divider(),
                Text(
                  "Status: $status",
                  style: TextStyle(
                    fontSize: 14,
                    color: status.startsWith("ERROR")
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
