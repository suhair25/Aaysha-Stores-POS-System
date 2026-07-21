import 'dart:io';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:aaysha_stores/config/constants.dart';
import 'package:intl/intl.dart';
import 'package:aaysha_stores/models/sale_model.dart';
import 'package:aaysha_stores/utils/storage_path.dart';

class ReceiptService {
  static Future<Uint8List> generateSalePdf(SaleModel sale) async {
    final pdf = pw.Document();
    final df = DateFormat('yyyy-MM-dd HH:mm');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pw.PageTheme().pageFormat,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Aaysha Stores',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Sale ID: ${sale.id}'),
          pw.Text('Date: ${df.format(sale.saleDate.toLocal())}'),
          pw.SizedBox(height: 12),

          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Qty', 'Price', 'Total'],
            data: sale.items.map((i) {
              final total = (i.sellingPrice * i.quantity) - i.discount;
              final itemName = i.productName ?? i.productId;
              return [
                itemName,
                i.quantity.toString(),
                i.sellingPrice.toStringAsFixed(2),
                total.toStringAsFixed(2),
              ];
            }).toList(),
          ),

          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Subtotal: ${AppConstants.currencySymbol} ${sale.totalAmount.toStringAsFixed(2)}',
                ),
                pw.Text(
                  'Discount: ${AppConstants.currencySymbol} ${sale.discount.toStringAsFixed(2)}',
                ),
                pw.Text(
                  'Net: ${AppConstants.currencySymbol} ${sale.netTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Payment: ${sale.paymentMethod.name}'),
              ],
            ),
          ),

          pw.SizedBox(height: 20),
          pw.Text(
            'Thank you for shopping with us!',
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<File?> saveSalePdf(SaleModel sale) async {
    try {
      final bytes = await generateSalePdf(sale);
      final baseDir = await StoragePathHelper.resolveExportDirectory();
      final billsDir = Directory('${baseDir.path}/Aaysha_Bills');
      if (!await billsDir.exists()) {
        await billsDir.create(recursive: true);
      }
      final file = File('${billsDir.path}/Bill_${sale.id}.pdf');
      await file.writeAsBytes(bytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<void> previewSalePdf(SaleModel sale) async {
    final bytes = await generateSalePdf(sale);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  static Future<void> printSalePdf(SaleModel sale) async {
    final bytes = await generateSalePdf(sale);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  static Future<void> shareSalePdf(SaleModel sale) async {
    final bytes = await generateSalePdf(sale);
    await Printing.sharePdf(bytes: bytes, filename: 'sale_${sale.id}.pdf');
  }
}
