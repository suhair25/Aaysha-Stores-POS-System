import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/providers/product_provider.dart';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:aaysha_stores/config/constants.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _lowStockController = TextEditingController(text: '10');
  DateTime? _expiryDate;
  String? _imagePath;

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _supplierController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProductProvider>();
    // Auto-generate barcode if none provided
    String? barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();
    if (barcode == null || barcode.isEmpty) {
      try {
        barcode = await provider.generateUniqueBarcode();
      } catch (_) {
        barcode = DateTime.now().millisecondsSinceEpoch.toString().substring(0, 12);
      }
    }

    final product = ProductModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      barcode: barcode,
      category: _categoryController.text.trim(),
      costPrice: double.tryParse(_costPriceController.text.trim()) ?? 0.0,
      sellingPrice: double.tryParse(_sellingPriceController.text.trim()) ?? 0.0,
      quantity: int.tryParse(_quantityController.text.trim()) ?? 0,
      supplierName: _supplierController.text.trim(),
      expiryDate: _expiryDate,
      lowStockThreshold: int.tryParse(_lowStockController.text.trim()) ?? 10,
      createdAt: DateTime.now(),
      productImageUrl: _imagePath,
    );

    final success = await provider.addProduct(product);
    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    setState(() {
      _imagePath = file.path;
    });
  }

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter product name' : null,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                border: Border.all(color: Colors.grey[300]!, width: 1),
                              ),
                              child: _imagePath != null
                                  ? Image.file(
                                      File(_imagePath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image, size: 32, color: Colors.grey[400]),
                                              const SizedBox(height: 4),
                                              Text('Image Error', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_not_supported, size: 40, color: Colors.grey[400]),
                                          const SizedBox(height: 4),
                                          Text(
                                            'No image',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Product Image',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.photo_library, size: 18),
                                  label: const Text('Pick Image'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                if (_imagePath != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _imagePath = null;
                                        });
                                      },
                                      icon: const Icon(Icons.delete_outline, size: 16),
                                      label: const Text('Remove'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Barcode (optional)',
                      suffixIcon: SizedBox(
                        width: 96,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              tooltip: 'Scan barcode',
                              onPressed: () async {
                                final result = await Navigator.of(context).pushNamed<String>(AppRoutes.barcodeScanner);
                                if (!mounted || result == null || result.isEmpty) return;
                                setState(() {
                                  _barcodeController.text = result;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.qr_code),
                              tooltip: 'Generate barcode',
                              onPressed: () async {
                                final result = await Navigator.of(context).pushNamed<String>(AppRoutes.barcodeGenerator);
                                if (!mounted || result == null || result.isEmpty) return;
                                setState(() {
                                  _barcodeController.text = result;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter category' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costPriceController,
                          decoration: const InputDecoration(labelText: 'Cost Price'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Enter cost price';
                            if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sellingPriceController,
                          decoration: const InputDecoration(labelText: 'Selling Price'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Enter selling price';
                            if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(labelText: 'Quantity'),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Enter quantity';
                            if (int.tryParse(value.trim()) == null) return 'Enter a valid quantity';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lowStockController,
                          decoration: const InputDecoration(labelText: 'Low stock threshold'),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Enter threshold';
                            if (int.tryParse(value.trim()) == null) return 'Enter a valid number';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _supplierController,
                    decoration: const InputDecoration(labelText: 'Supplier Name'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiry Date (optional)'),
                    subtitle: Text(_expiryDate != null ? _expiryDate!.toLocal().toString().split(' ')[0] : 'Not selected'),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: _selectExpiryDate,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (provider.errorMessage != null)
                    Text(provider.errorMessage!, style: const TextStyle(color: Colors.red)),
                  ElevatedButton(
                    onPressed: provider.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: provider.isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Product'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
