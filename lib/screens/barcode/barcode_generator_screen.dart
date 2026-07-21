import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:aaysha_stores/config/constants.dart';

class BarcodeGeneratorScreen extends StatefulWidget {
  const BarcodeGeneratorScreen({super.key});

  @override
  State<BarcodeGeneratorScreen> createState() => _BarcodeGeneratorScreenState();
}

class _BarcodeGeneratorScreenState extends State<BarcodeGeneratorScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  bool get _isValidBarcode {
    final text = _barcodeController.text.trim();
    return RegExp(RegexPatterns.barcode).hasMatch(text);
  }

  void _generateRandomBarcode() {
    const length = 12;
    final random = Random.secure();
    final generated = List.generate(length, (_) => random.nextInt(10)).join();
    _barcodeController.text = generated;
    setState(() {
      _errorText = null;
    });
  }

  Future<void> _copyBarcode() async {
    if (!_isValidBarcode) {
      setState(() {
        _errorText = 'Barcode must be 8-13 digits.';
      });
      return;
    }
    await Clipboard.setData(ClipboardData(text: _barcodeController.text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barcode copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Barcode'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode value',
                hintText: 'Enter 8-13 digits',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) {
                setState(() {
                  _errorText = null;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateRandomBarcode,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyBarcode,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final value = _barcodeController.text.trim();
                      if (!RegExp(RegexPatterns.barcode).hasMatch(value)) {
                        setState(() {
                          _errorText = 'Barcode must be 8-13 digits.';
                        });
                        return;
                      }
                      Navigator.of(context).pop(value);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Use'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: _isValidBarcode
                    ? BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: _barcodeController.text.trim(),
                        width: double.infinity,
                        height: 140,
                        drawText: true,
                      )
                    : const Text(
                        'Enter a valid numeric barcode to preview the label.',
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
