import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pocket_plan/models/transaction_model.dart';

class ExportService {
  // ─────────────────────────────────────────
  // EXPORT TO CSV
  // ─────────────────────────────────────────
  static Future<void> exportToCSV(List<TransactionModel> transactions) async {
    final List<List<dynamic>> rows = [];

    // Header row
    rows.add([
      'Date',
      'Type',
      'Category',
      'Budget Bucket',
      'Description',
      'Amount (RM)',
    ]);

    // Data rows
    for (final tx in transactions) {
      rows.add([
        '${tx.date.day}/${tx.date.month}/${tx.date.year}',
        tx.type == TransactionType.expense ? 'Expense' : 'Income',
        tx.category,
        _bucketLabel(tx.budgetCategory),
        tx.description,
        tx.type == TransactionType.expense
            ? '-${tx.amount.toStringAsFixed(2)}'
            : '+${tx.amount.toStringAsFixed(2)}',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/pocketplan_transactions_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'PocketPlan Transactions Export',
      text: 'My transaction history from PocketPlan',
    );
  }

  // ─────────────────────────────────────────
  // EXPORT TO PDF
  // ─────────────────────────────────────────
  static Future<void> exportToPDF(
    List<TransactionModel> transactions,
    double monthlyAllowance,
  ) async {
    final pdf = pw.Document();

    // Calculate totals
    final totalExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);
    final totalIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (s, t) => s + t.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFF6C63FF),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PocketPlan',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Transaction Report — Generated ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Summary
          pw.Row(
            children: [
              _pdfSummaryCard(
                'Monthly Allowance',
                'RM ${monthlyAllowance.toStringAsFixed(2)}',
                PdfColors.purple100,
              ),
              pw.SizedBox(width: 10),
              _pdfSummaryCard(
                'Total Expenses',
                'RM ${totalExpense.toStringAsFixed(2)}',
                PdfColors.red100,
              ),
              pw.SizedBox(width: 10),
              _pdfSummaryCard(
                'Total Income',
                'RM ${totalIncome.toStringAsFixed(2)}',
                PdfColors.green100,
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Transactions table
          pw.Text(
            'Transaction History',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Table header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Date', isHeader: true),
                  _pdfCell('Type', isHeader: true),
                  _pdfCell('Category', isHeader: true),
                  _pdfCell('Description', isHeader: true),
                  _pdfCell('Amount', isHeader: true),
                ],
              ),
              // Data rows
              ...transactions.map((tx) {
                final isExpense = tx.type == TransactionType.expense;
                return pw.TableRow(
                  children: [
                    _pdfCell('${tx.date.day}/${tx.date.month}/${tx.date.year}'),
                    _pdfCell(
                      isExpense ? 'Expense' : 'Income',
                      color: isExpense ? PdfColors.red : PdfColors.green,
                    ),
                    _pdfCell(tx.category),
                    _pdfCell(tx.description.isNotEmpty ? tx.description : '-'),
                    _pdfCell(
                      '${isExpense ? '-' : '+'}RM ${tx.amount.toStringAsFixed(2)}',
                      color: isExpense ? PdfColors.red : PdfColors.green,
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Generated by PocketPlan — UTeM FYP 2025/26',
            style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/pocketplan_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'PocketPlan Transaction Report',
      text: 'My financial report from PocketPlan',
    );
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
  static pw.Widget _pdfSummaryCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static String _bucketLabel(BudgetCategory category) {
    switch (category) {
      case BudgetCategory.commitment:
        return 'Commitments (50%)';
      case BudgetCategory.spending:
        return 'Spending (30%)';
      case BudgetCategory.savings:
        return 'Savings (20%)';
    }
  }
}
