import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:barcode/barcode.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/utils/logger.dart';

/// LabelService generates printable PDF labels for products
class LabelService {
  static final LabelService _instance = LabelService._internal();
  factory LabelService() => _instance;
  LabelService._internal();

  /// Generate a PDF label for a product and return the PDF bytes.
  /// If [copies] > 1, the PDF will contain multiple labels (one per page).
  Future<Uint8List> generateLabelPdf(ProductModel product, {int copies = 1}) async {
    final pdf = pw.Document();

    // Create barcode SVG using code128 (works for numeric/alphanumeric)
    final bc = Barcode.code128();
    final svg = bc.toSvg(product.barcode ?? product.id, width: 200, height: 60, drawText: false);

    for (var i = 0; i < copies; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(200 * PdfPageFormat.mm, 80 * PdfPageFormat.mm),
          build: (context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Product image (if available)
                  if (product.productImageUrl != null && product.productImageUrl!.isNotEmpty)
                    pw.Container(
                      width: 80,
                      height: 80,
                      child: pw.Image(
                        pw.MemoryImage(_loadImageBytes(product.productImageUrl!)),
                        fit: pw.BoxFit.cover,
                      ),
                    )
                  else
                    pw.Container(width: 80, height: 80, color: PdfColors.grey300),
                  pw.SizedBox(width: 8),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(product.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text(product.supplierName, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 6),
                      pw.Text(product.sellingPrice.toStringAsFixed(2), style: pw.TextStyle(fontSize: 14, color: PdfColors.black)),
                      pw.SizedBox(height: 8),
                      // Barcode SVG
                      pw.SvgImage(svg: svg),
                      pw.SizedBox(height: 4),
                      pw.Text(product.barcode ?? product.id, style: pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    AppLogger.success('Label PDF generated for product ${product.id}');
    return bytes;
  }

  /// Generate labels for multiple products in a single PDF
  Future<Uint8List> generateLabelsForProducts(List<ProductModel> products, {int copiesPerProduct = 1}) async {
    final pdf = pw.Document();
    final bc = Barcode.code128();

    for (final product in products) {
      final svg = bc.toSvg(product.barcode ?? product.id, width: 200, height: 60, drawText: false);
      for (var i = 0; i < copiesPerProduct; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(200 * PdfPageFormat.mm, 80 * PdfPageFormat.mm),
            build: (context) {
              return pw.Container(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (product.productImageUrl != null && product.productImageUrl!.isNotEmpty)
                      pw.Container(
                        width: 80,
                        height: 80,
                        child: pw.Image(pw.MemoryImage(_loadImageBytes(product.productImageUrl!)), fit: pw.BoxFit.cover),
                      )
                    else
                      pw.Container(width: 80, height: 80, color: PdfColors.grey300),
                    pw.SizedBox(width: 8),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(product.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.Text(product.supplierName, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 6),
                        pw.Text(product.sellingPrice.toStringAsFixed(2), style: pw.TextStyle(fontSize: 14, color: PdfColors.black)),
                        pw.SizedBox(height: 8),
                        pw.SvgImage(svg: svg),
                        pw.SizedBox(height: 4),
                        pw.Text(product.barcode ?? product.id, style: pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    }

    final bytes = await pdf.save();
    AppLogger.success('Bulk label PDF generated for ${products.length} products');
    return bytes;
  }

  /// Save PDF bytes to documents directory and return file path
  Future<String> savePdfToFile(Uint8List bytes, String filename) async {
    try {
      if (bytes.isEmpty) throw Exception('Empty PDF bytes');

      final baseDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${baseDir.path}/AayshaExports');
      if (!await exportDir.exists()) await exportDir.create(recursive: true);
      final file = File('${exportDir.path}/$filename');
      await file.writeAsBytes(bytes);

      // On Android attempt to also save to external storage app directory when available
      if (Platform.isAndroid) {
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            final extDir = Directory('${ext.path}/AayshaExports');
            if (!await extDir.exists()) await extDir.create(recursive: true);
            final extFile = File('${extDir.path}/$filename');
            await extFile.writeAsBytes(bytes);
            AppLogger.success('Also saved PDF to ${extFile.path}');
          }
        } catch (e) {
          AppLogger.warning('Failed to save PDF to external storage', e);
        }
      }

      AppLogger.success('Saved PDF to ${file.path}');
      return file.path;
    } catch (e) {
      AppLogger.error('Failed to save PDF', e);
      rethrow;
    }
  }

  // Helper to load image bytes from local file or network URL.
  // For network URLs, Printing's network image loader is recommended, but keep simple for now.
  Uint8List _loadImageBytes(String path) {
    try {
      if (path.startsWith('http')) {
        // printing package can fetch network images when drawing but MemoryImage here requires bytes.
        // As a fallback, return empty bytes and PDF will show placeholder.
        return Uint8List(0);
      }
      final file = File(path);
      if (file.existsSync()) return file.readAsBytesSync();
    } catch (e) {
      AppLogger.error('Failed to load image bytes for label', e);
    }
    return Uint8List(0);
  }
}
