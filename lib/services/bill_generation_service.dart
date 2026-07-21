import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:aaysha_stores/config/constants.dart';
import 'package:printing/printing.dart';
import 'package:aaysha_stores/utils/logger.dart';
import 'package:aaysha_stores/utils/storage_path.dart';

/// Service for generating PDF bills
class BillGenerationService {
  static final BillGenerationService _instance = BillGenerationService._internal();

  factory BillGenerationService() {
    return _instance;
  }

  BillGenerationService._internal();

  /// Generate bill PDF
  Future<File?> generateBillPDF({
    required String billNumber,
    required DateTime billDate,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required String paymentMethod,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        shopName ?? 'Aaysha Stores',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (shopAddress != null)
                        pw.Text(
                          shopAddress,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if (shopPhone != null)
                        pw.Text(
                          'Phone: $shopPhone',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),

                // Bill Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Bill #: $billNumber', style: const pw.TextStyle(fontSize: 11)),
                        pw.Text(
                          'Date: ${billDate.toString().split(' ')[0]}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.Text(
                          'Time: ${billDate.hour}:${billDate.minute.toString().padLeft(2, '0')}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Payment: $paymentMethod',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),

                // Items Table Header
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.Divider(),

                // Items
                ...items.map((item) {
                  final itemTotal = (item['quantity'] as int) * (item['price'] as num);
                  return pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          item['name'] as String,
                          style: const pw.TextStyle(fontSize: 9),
                          maxLines: 2,
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          (item['quantity'] as int).toString(),
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '${AppConstants.currencySymbol} ${(item['price'] as num).toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '${AppConstants.currencySymbol} ${itemTotal.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }),

                pw.Divider(),
                pw.SizedBox(height: 10),

                // Totals
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                        if (discount > 0) pw.Text('Discount:', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Total:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(width: 20),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('${AppConstants.currencySymbol} ${subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                        if (discount > 0) pw.Text('${AppConstants.currencySymbol} ${discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('${AppConstants.currencySymbol} ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),
                pw.Divider(),

                // Footer
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Thank you for your purchase!', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Visit us again', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      return await _savePDF(pdf, 'Bill_$billNumber');
    } catch (e) {
      AppLogger.error('Error generating bill PDF', e);
      return null;
    }
  }

  /// Save PDF to file
  Future<File?> _savePDF(pw.Document pdf, String fileName) async {
    try {
      final directory = await StoragePathHelper.resolveExportDirectory();
      final filePath = '${directory.path}/$fileName.pdf';
      final file = File(filePath);

      await file.writeAsBytes(await pdf.save());
      AppLogger.success('Bill PDF saved: $filePath');
      return file;
    } catch (e) {
      AppLogger.error('Error saving PDF', e);
      return null;
    }
  }

  /// Print bill
  Future<void> printBill(pw.Document pdf) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
      );
      AppLogger.success('Bill sent to printer');
    } catch (e) {
      AppLogger.error('Error printing bill', e);
    }
  }

  /// Share bill via WhatsApp
  Future<void> shareBillViaWhatsApp({
    required String billNumber,
    required double totalAmount,
  }) async {
    try {
      final message = '''
Aaysha Stores Receipt
Bill #: $billNumber
Amount: ${AppConstants.currencySymbol} ${totalAmount.toStringAsFixed(2)}
Date: ${DateTime.now()}

Thank you for your purchase!
''';

      // In real implementation, integrate with flutter_contact or share_plus
      AppLogger.info('Share message: $message');
    } catch (e) {
      AppLogger.error('Error sharing bill', e);
    }
  }

  /// Get saved bills directory
  Future<Directory> getBillsDirectory() async {
    final baseDir = await StoragePathHelper.resolveExportDirectory();
    final billsDir = Directory('${baseDir.path}/Aaysha_Bills');

    if (!await billsDir.exists()) {
      await billsDir.create(recursive: true);
    }

    return billsDir;
  }

  /// Get all saved bills
  Future<List<File>> getSavedBills() async {
    try {
      final dir = await getBillsDirectory();
      return dir.listSync().whereType<File>().toList();
    } catch (e) {
      AppLogger.error('Error getting saved bills', e);
      return [];
    }
  }
}
