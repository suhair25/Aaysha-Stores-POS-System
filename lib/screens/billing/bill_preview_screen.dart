import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class BillPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String saleId;

  const BillPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.saleId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        maxPageWidth: 800,
      ),
    );
  }
}
