import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aaysha_stores/config/app_theme.dart';
import 'package:aaysha_stores/enums/expense_category.dart';
import 'package:aaysha_stores/models/expense_model.dart';
import 'package:aaysha_stores/providers/expense_provider.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/services/export_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().loadExpenses();
    });
  }

  void _showAddExpenseDialog() {
    final categoryController = ValueNotifier<ExpenseCategory>(ExpenseCategory.other);
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final dateController = ValueNotifier<DateTime>(DateTime.now());
    final expenseProvider = context.read<ExpenseProvider>();
    final nav = Navigator.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Expense'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<ExpenseCategory>(
                valueListenable: categoryController,
                builder: (context, category, _) => DropdownButtonFormField<ExpenseCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ExpenseCategory.values
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat.displayName)))
                      .toList(),
                  onChanged: (cat) {
                    if (cat != null) categoryController.value = cat;
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount (LKR)', prefixText: AppConstants.currencySymbol),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<DateTime>(
                valueListenable: dateController,
                builder: (context, date, _) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(date.toLocal().toString().split(' ')[0]),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) dateController.value = picked;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0 || descriptionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields')));
                return;
              }

              final expense = ExpenseModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                category: categoryController.value,
                amount: amount,
                description: descriptionController.text.trim(),
                expenseDate: dateController.value,
                addedBy: 'user',
                createdAt: DateTime.now(),
              );

              if (!mounted) return;
              final ok = await expenseProvider.addExpense(expense);
              if (ok && mounted) {
                nav.pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses'), actions: [
        IconButton(
          tooltip: 'Export expenses',
          icon: const Icon(Icons.file_download_outlined),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              final raw = provider.expenses.map((e) => e.toJson()).toList();
              final path = await ExportService().exportExpensesToExcel(raw);
              if (!mounted) return;
              messenger.showSnackBar(SnackBar(content: Text('Expenses exported: $path')));
            } catch (e) {
              if (!mounted) return;
              messenger.showSnackBar(const SnackBar(content: Text('Failed to export expenses')));
            }
          },
        ),
      ]),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.expenses.isEmpty
              ? const Center(child: Text('No expenses recorded yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: provider.expenses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final expense = provider.expenses[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(expense.category.icon),
                        ),
                        title: Text(expense.category.displayName),
                        subtitle: Text(expense.description),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${expense.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(expense.expenseDate.toLocal().toString().split(' ')[0], style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        onLongPress: () async {
                          final expProvider = context.read<ExpenseProvider>();
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete expense?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                              ],
                            ),
                          );

                          if (confirm == true && mounted) {
                            await expProvider.deleteExpense(expense.id);
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
