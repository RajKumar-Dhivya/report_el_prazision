import 'package:flutter/material.dart';
import 'API CALL/google_sheets_api.dart';
import 'workorder_summary.dart';
import 'monthly_detail_page.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  Map<String, WorkOrderSummary> summaryMap = {};
  List<dynamic> receivedPayments = [];
  List<dynamic> workOrders = [];
  List<dynamic> customers = [];

  bool loading = true;

  double parseKW(dynamic value) {
    if (value == null) return 0;
    final text = value.toString().toLowerCase();
    final numeric = text.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(numeric) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    try {
      workOrders = await GoogleSheetsApi.getSheet("Work Orders");
      receivedPayments =
          await GoogleSheetsApi.getSheet("Received Payments");
      customers = await GoogleSheetsApi.getSheet("Customer");

      processWorkOrders(workOrders);
      calculateReceivedPayments();
    } catch (e) {
      debugPrint("Error: $e");
    }

    setState(() => loading = false);
  }

  void processWorkOrders(List rows) {
    summaryMap.clear();

    for (var row in rows) {
      if (row == null ||
          row.values.every(
              (v) => v == null || v.toString().trim().isEmpty)) {
        continue;
      }

      String recordedDate = row["Recorded Date"];
      String paymentMode = row["Payment Mode"];
      double sanctionLoad = parseKW(row["Sanction Load/KW"]);
      double totalAmount =
          double.tryParse(row["Total Amount"].toString()) ?? 0;

      DateTime dt = DateTime.parse(recordedDate);
      String monthYear = "${_monthName(dt.month)} ${dt.year}";

      summaryMap.putIfAbsent(
          monthYear, () => WorkOrderSummary(monthYear));
      var s = summaryMap[monthYear]!;

      s.totalWorkOrders++;
      s.sanctionLoad += sanctionLoad;
      s.totalAmount += totalAmount;

      if (paymentMode.toLowerCase() == "loan") {
        s.loanCount++;
      } else if (paymentMode.toLowerCase() == "cash") {
        s.cashCount++;
      }

      s.workOrderIds.add(row["ID"].toString());
    }
  }

  void calculateReceivedPayments() {
    for (var payment in receivedPayments) {
      String woID = payment["Work Order ID"].toString();
      double amount =
          double.tryParse(payment["Received Payment"].toString()) ?? 0;

      for (var s in summaryMap.values) {
        if (s.workOrderIds.contains(woID)) {
          s.amountReceived += amount;
        }
      }
    }

    for (var s in summaryMap.values) {
      s.outstanding = s.totalAmount - s.amountReceived;
    }
  }

  String _monthName(int m) {
    const months = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[m];
  }

  DataCell cell(dynamic v) =>
    DataCell(
      Center(
        child: SelectableText(
          v.toString(),
          showCursor: true,
        ),
      ),
    );


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset("assets/company_logo.png"),
        ),
        title: const Text("Work Order Summary"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;

                return Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: screenWidth),
                      child: Scrollbar(
                        controller: _vertical,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _vertical,
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            border: TableBorder.all(color: Colors.grey),
                            headingRowColor:
                                MaterialStateProperty.all(
                                    Colors.grey.shade200),
                            columns: const [
                              DataColumn(label: Text("Month")),
                              DataColumn(label: Text("Total WO")),
                              DataColumn(label: Text("Load (kW)")),
                              DataColumn(label: Text("Loan")),
                              DataColumn(label: Text("Cash")),
                              DataColumn(label: Text("Amount")),
                              DataColumn(label: Text("Received")),
                              DataColumn(label: Text("Outstanding")),
                            ],
                            rows: summaryMap.values.map((s) {
                              return DataRow(cells: [
                                DataCell(
                                  TextButton(
                                    child: Text(s.monthYear),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              MonthlyDetailPage(
                                            summary: s,
                                            workOrders: workOrders,
                                            customers: customers,
                                            payments:
                                                receivedPayments,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                cell(s.totalWorkOrders),
                                cell(s.sanctionLoad),
                                cell(s.loanCount),
                                cell(s.cashCount),
                                cell("₹${s.totalAmount}"),
                                cell("₹${s.amountReceived}"),
                                cell("₹${s.outstanding}"),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
