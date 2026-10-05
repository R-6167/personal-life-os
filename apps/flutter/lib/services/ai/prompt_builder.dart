import '../personal_context_engine.dart';

/// Builds grounded prompts from [PersonalSituation] + user message.
class AiPromptBuilder {
  static String situationBlock(PersonalSituation s) {
    final buf = StringBuffer();
    buf.writeln('PERSONAL CONTEXT (ground truth — do not invent beyond this):');
    buf.writeln('Time: ${s.at.toIso8601String()}');
    buf.writeln(
        'Open tasks: ${s.openTaskCount} · overdue: ${s.overdueCount} · due today: ${s.dueTodayCount}');
    buf.writeln(
        'Habits: ${s.habitCount} · bills open: ${s.openBillCount} · projects: ${s.projectCount}');
    buf.writeln(
        'Free minutes today: ${s.availableMinutesToday} · busy: ${s.busyMinutesToday}');
    buf.writeln('Capacity: ${s.capacityLabel}');
    if (s.pressure.isNotEmpty) {
      buf.writeln('Pressure:');
      for (final p in s.pressure.take(5)) {
        buf.writeln('- ${p.label}');
      }
    }
    if (s.priorityLines.isNotEmpty) {
      buf.writeln('Priority:');
      for (final line in s.priorityLines.take(4)) {
        buf.writeln('- $line');
      }
    }
    if (s.opportunities.isNotEmpty) {
      buf.writeln('Opportunities (fit free time):');
      for (final o in s.opportunities.take(5)) {
        buf.writeln('- ${o.title} (${o.reason})');
      }
    }
    if (s.contextLines.isNotEmpty) {
      buf.writeln('Recent context:');
      for (final c in s.contextLines.take(4)) {
        buf.writeln('- $c');
      }
    }
    return buf.toString();
  }

  static String userMessageWithContext(PersonalSituation s, String userMessage) {
    return '${situationBlock(s)}\n\nUSER:\n$userMessage';
  }
}
