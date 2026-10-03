/// Stable payload carried on local notifications so taps open the right place.
/// Format: TYPE|id|optionalReminderId
class NotificationPayload {
  NotificationPayload({
    required this.type,
    required this.id,
    this.reminderId,
  });

  final String type;
  final String id;
  final String? reminderId;

  static const task = 'TASK';
  static const bill = 'BILL';
  static const billOcc = 'BILL_OCC';
  static const subscription = 'SUBSCRIPTION';
  static const document = 'DOCUMENT';
  static const practical = 'PRACTICAL';
  static const event = 'EVENT';
  static const habit = 'HABIT';
  static const routine = 'ROUTINE';
  static const reminder = 'REMINDER';
  static const goal = 'GOAL';
  static const project = 'PROJECT';
  static const budget = 'BUDGET';
  static const overdue = 'OVERDUE';

  String encode() {
    final parts = [type, id];
    if (reminderId != null && reminderId!.isNotEmpty) parts.add(reminderId!);
    return parts.join('|');
  }

  static NotificationPayload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length < 2) return null;
    return NotificationPayload(
      type: parts[0],
      id: parts[1],
      reminderId: parts.length > 2 ? parts[2] : null,
    );
  }
}
