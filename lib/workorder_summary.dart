
class WorkOrderSummary {
  String monthYear;
  int totalWorkOrders = 0;
  double sanctionLoad = 0;
  int loanCount = 0;
  int cashCount = 0;
  double totalAmount = 0;
  double amountReceived = 0;
  double outstanding = 0;
  double profit = 0;
  List<String> workOrderIds = [];

  WorkOrderSummary(this.monthYear);
}
