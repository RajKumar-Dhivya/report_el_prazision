import 'package:flutter/material.dart';
import 'workorder_summary.dart';

class MonthlyDetailPage extends StatelessWidget {
  final WorkOrderSummary summary;

  const MonthlyDetailPage({super.key, required this.summary});

  Widget row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value.toString()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Details - ${summary.monthYear}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row("Total Work Orders", summary.totalWorkOrders),
            row("Sanction Load", summary.sanctionLoad),
            row("Loan Count", summary.loanCount),
            row("Cash Count", summary.cashCount),
            row("Total Amount", summary.totalAmount),
            row("Amount Received", summary.amountReceived),
            row("Outstanding", summary.outstanding),
            row("Margin", "${summary.margin}%"),
            const Divider(),
            const Text("Work Order IDs"),
            ...summary.workOrderIds.map((e) => Text(e)),
          ],
        ),
      ),
    );
  }
}
