class WorkOrderSummary {
  String monthYear;
  int totalWorkOrders = 0;
  double sanctionLoad = 0;
  int loanCount = 0;
  int cashCount = 0;
  double totalAmount = 0;

  // New fields
  double amountReceived = 0;
  double outstanding = 0;

  // Store work order IDs per month
  List<String> workOrderIds = [];

  WorkOrderSummary(this.monthYear);
}
