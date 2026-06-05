import 'dart:math';

import '../core/models.dart';
import 'analytics_service.dart';

class BehaviorInsight {
  const BehaviorInsight({
    required this.id,
    required this.evidenceKey,
    required this.title,
    required this.body,
    required this.kind,
    required this.type,
    required this.why,
    required this.nextAction,
    this.evidenceSummary,
    this.confidence,
    this.searchQuery,
    this.suggestions = const [],
    this.habitsNoticed = const [],
    this.priority = 0,
    this.isPinned = false,
  });

  final String id;
  final String evidenceKey;
  final String title;
  final String body;
  final InsightKind kind;
  final InsightType type;
  final String why;
  final String nextAction;
  final String? evidenceSummary;
  final String? confidence;
  final String? searchQuery;
  final List<String> suggestions;
  final List<String> habitsNoticed;
  final int priority;
  final bool isPinned;

  BehaviorInsight copyWith({bool? isPinned}) {
    return BehaviorInsight(
      id: id,
      evidenceKey: evidenceKey,
      title: title,
      body: body,
      kind: kind,
      type: type,
      why: why,
      nextAction: nextAction,
      evidenceSummary: evidenceSummary,
      confidence: confidence,
      searchQuery: searchQuery,
      suggestions: suggestions,
      habitsNoticed: habitsNoticed,
      priority: priority,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

enum InsightKind { pattern, progress, context, privacy, money }

enum InsightType {
  timeOfDay,
  weekday,
  stressLinked,
  repeatedSameDay,
  reducedFrequency,
  increasedQuantity,
  triggerContext,
  targetContinuity,
  moneyIncreased,
  moneyConcentration,
  moneyReduced,
  moneyWeekend,
  moneySetup,
  gettingStarted,
  privacy,
  steady,
}

class InsightEngine {
  static List<BehaviorInsight> generate(
    AppState state,
    AnalyticsSnapshot analytics,
  ) {
    final entries = _activeEntries(state);
    if (entries.length < 3) {
      return [
        BehaviorInsight(
          id: 'getting_started',
          evidenceKey: 'logs:${entries.length}',
          title: 'Patterns will appear gradually',
          body:
              'A few logs are enough to begin showing time, mood, money, and context shifts without judging the day.',
          kind: InsightKind.context,
          type: InsightType.gettingStarted,
          why:
              'Stillpoint waits for a small local sample before calling anything a pattern.',
          nextAction:
              'Add one log when it feels easy, even if details are incomplete.',
          evidenceSummary: '${entries.length} local log(s) available',
          confidence: 'Building evidence',
          suggestions: const [
            'Use optional context only when it helps you remember the moment.',
            'Set money per unit for trackers where cost matters.',
            'Leave anything blank when it does not feel useful.',
          ],
          habitsNoticed: const ['Waiting for a few local logs'],
          priority: 10,
        ),
        const BehaviorInsight(
          id: 'privacy_local_first',
          evidenceKey: 'privacy:v1',
          title: 'Private by default',
          body:
              'Your tracker is local-first, with optional reminders and exports kept under your control.',
          kind: InsightKind.privacy,
          type: InsightType.privacy,
          why:
              'The app stores your tracker data on this device and only opens searches or exports when you choose them.',
          nextAction: 'Turn on biometric or PIN lock if this device is shared.',
          evidenceSummary: 'All logs stay on this device',
          confidence: 'App setting',
          suggestions: [
            'Keep notification content hidden if privacy matters in public.',
            'Use exports only when you decide they are useful.',
            'Review privacy settings after setup.',
          ],
          habitsNoticed: ['All logs stay on this device'],
          priority: 9,
        ),
      ];
    }

    final insights = <BehaviorInsight>[
      ?_timeOfDayInsight(state, entries),
      ?_weekdayInsight(state, entries),
      ?_stressInsight(state, entries),
      ?_sameDayInsight(state, entries),
      ?_frequencyInsight(state, entries),
      ?_increasedQuantityInsight(state, entries),
      ?_triggerInsight(state, analytics),
      ?_targetContinuityInsight(state, analytics),
      ..._moneyInsights(state, analytics, entries),
    ];

    if (insights.isEmpty) {
      insights.add(
        BehaviorInsight(
          id: 'steady_patterns',
          evidenceKey: 'steady:${entries.length}:${analytics.weekTotal}',
          title: 'Your data looks steady',
          body:
              'No strong shift stands out yet. Keeping the pattern visible is still useful.',
          kind: InsightKind.context,
          type: InsightType.steady,
          why:
              'Recent logs do not show a clear time, weekday, stress, quantity, or money change beyond the thresholds used here.',
          nextAction:
              'Keep logging lightly and add context only when a moment feels meaningful.',
          evidenceSummary: '${entries.length} logs reviewed locally',
          confidence: _confidenceFor(entries.length),
          suggestions: const [
            'Look for timing changes rather than perfect days.',
            'Use custom trackers for patterns that do not fit the presets.',
            'Pin this if a steady week is something you want to remember.',
          ],
          habitsNoticed: _topHabitNames(state),
          priority: 1,
        ),
      );
    }

    insights.sort((a, b) => b.priority.compareTo(a.priority));
    return insights;
  }

  static List<BehaviorInsight> applyPreferences(
    List<BehaviorInsight> insights,
    List<InsightPreference> preferences,
  ) {
    final byId = {
      for (final preference in preferences) preference.id: preference,
    };
    final visible = <BehaviorInsight>[];

    for (final insight in insights) {
      final preference = byId[insight.id];
      final pinned = preference?.pinned ?? false;
      final dismissedForThisEvidence =
          preference?.dismissed == true &&
          preference?.evidenceKey == insight.evidenceKey;
      if (dismissedForThisEvidence && !pinned) continue;
      visible.add(insight.copyWith(isPinned: pinned));
    }

    visible.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.priority.compareTo(a.priority);
    });
    return visible.take(6).toList(growable: false);
  }
}

BehaviorInsight? _timeOfDayInsight(AppState state, List<UsageEntry> entries) {
  if (entries.length < 4) return null;
  final windows = [
    _WindowMetric(
      key: 'late_night',
      label: 'Late night',
      rangeLabel: '12 AM-5 AM',
      matches: (entry) => entry.loggedAt.hour < 5,
    ),
    _WindowMetric(
      key: 'morning',
      label: 'Mornings',
      rangeLabel: '5 AM-12 PM',
      matches: (entry) => entry.loggedAt.hour >= 5 && entry.loggedAt.hour < 12,
    ),
    _WindowMetric(
      key: 'afternoon',
      label: 'Afternoons',
      rangeLabel: '12 PM-6 PM',
      matches: (entry) => entry.loggedAt.hour >= 12 && entry.loggedAt.hour < 18,
    ),
    _WindowMetric(
      key: 'evening',
      label: 'Evenings',
      rangeLabel: '6 PM-12 AM',
      matches: (entry) => entry.loggedAt.hour >= 18,
    ),
  ];

  for (final window in windows) {
    window.add(entries.where(window.matches));
  }
  final top = windows.reduce((a, b) => a.logs >= b.logs ? a : b);
  if (top.logs < 2 || top.logs / entries.length < .35) return null;

  return BehaviorInsight(
    id: 'time_of_day_${top.key}',
    evidenceKey:
        '${top.key}:${top.logs}:${top.quantity.toStringAsFixed(1)}:${entries.length}',
    title: '${top.label} show up often',
    body:
        '${top.logs} recent logs happened around ${top.rangeLabel.toLowerCase()}. This may be a useful window to make softer.',
    kind: InsightKind.pattern,
    type: InsightType.timeOfDay,
    why:
        'More of your local logs cluster in this part of the day than in other time windows.',
    nextAction:
        'Before the next ${top.label.toLowerCase()} window, choose one small barrier or support that feels realistic.',
    evidenceSummary:
        '${top.logs} of ${entries.length} logs, ${_formatQuantity(top.quantity)} total quantity',
    confidence: _confidenceFor(top.logs),
    searchQuery: '${top.label} cravings harm reduction routine delay support',
    suggestions: [
      'Try a 10 minute delay before the first use in that window.',
      'Move supplies or apps one step farther away before the window starts.',
      'Log one extra context detail next time to see what is underneath.',
    ],
    habitsNoticed: _topHabitNames(state),
    priority: 80,
  );
}

BehaviorInsight? _weekdayInsight(AppState state, List<UsageEntry> entries) {
  if (entries.length < 5) return null;
  final counts = <int, ({int logs, double quantity})>{};
  for (final entry in entries) {
    final previous = counts[entry.loggedAt.weekday] ?? (logs: 0, quantity: 0.0);
    counts[entry.loggedAt.weekday] = (
      logs: previous.logs + 1,
      quantity: previous.quantity + entry.quantity,
    );
  }
  if (counts.isEmpty) return null;

  final top = counts.entries.reduce(
    (a, b) => a.value.logs >= b.value.logs ? a : b,
  );
  if (top.value.logs < 2 || top.value.logs / entries.length < .25) return null;
  final dayName = _weekdayName(top.key);

  return BehaviorInsight(
    id: 'weekday_${top.key}',
    evidenceKey:
        '${top.key}:${top.value.logs}:${top.value.quantity.toStringAsFixed(1)}',
    title: '$dayName has been more active',
    body:
        '$dayName carries more logged moments than other weekdays in your recent data.',
    kind: InsightKind.pattern,
    type: InsightType.weekday,
    why:
        'When logs are grouped by weekday, this day has the clearest concentration.',
    nextAction:
        'Treat $dayName as a planning cue: set up one supportive condition before it arrives.',
    evidenceSummary:
        '${top.value.logs} logs on $dayName, ${_formatQuantity(top.value.quantity)} total quantity',
    confidence: _confidenceFor(top.value.logs),
    searchQuery: '$dayName substance cravings harm reduction planning',
    suggestions: [
      'Check whether schedule, social plans, sleep, or money changes on $dayName.',
      'Put a lower-friction alternative in place before the usual time.',
      'Compare next $dayName with a quieter weekday rather than with a perfect day.',
    ],
    habitsNoticed: _topHabitNames(state),
    priority: 72,
  );
}

BehaviorInsight? _stressInsight(AppState state, List<UsageEntry> entries) {
  final stressedEntries = entries
      .where((entry) => (entry.stress ?? 0) >= 4)
      .toList(growable: false);
  final steadyEntries = entries
      .where((entry) => (entry.stress ?? 6) <= 2)
      .toList(growable: false);
  if (stressedEntries.length < 2 || steadyEntries.length < 2) return null;

  final stressedAvg = _averageQuantity(stressedEntries);
  final steadyAvg = _averageQuantity(steadyEntries);
  if (stressedAvg <= steadyAvg * 1.2) return null;

  return BehaviorInsight(
    id: 'stress_linked_quantity',
    evidenceKey:
        '${stressedEntries.length}:${steadyEntries.length}:${stressedAvg.toStringAsFixed(1)}:${steadyAvg.toStringAsFixed(1)}',
    title: 'Stress may be linked with quantity',
    body:
        'Higher-stress logs are carrying more quantity than steadier logs in your data.',
    kind: InsightKind.pattern,
    type: InsightType.stressLinked,
    why:
        'Logs marked strong or intense stress average ${_formatQuantity(stressedAvg)}, compared with ${_formatQuantity(steadyAvg)} during quieter stress entries.',
    nextAction:
        'Before a high-stress log, try one settling step and then decide what comes next.',
    evidenceSummary:
        '${stressedEntries.length} high-stress logs compared with ${steadyEntries.length} quieter logs',
    confidence: _confidenceFor(stressedEntries.length + steadyEntries.length),
    searchQuery: 'stress cravings harm reduction coping before use',
    suggestions: const [
      'Use the breathing card before logging during high stress.',
      'Lower stimulation first; decide after the body settles.',
      'Add stress context for a few more logs to confirm the pattern.',
    ],
    habitsNoticed: _topHabitNames(state),
    priority: 86,
  );
}

BehaviorInsight? _sameDayInsight(AppState state, List<UsageEntry> entries) {
  final byDay = <DateTime, List<UsageEntry>>{};
  for (final entry in entries) {
    byDay.putIfAbsent(_dayStart(entry.loggedAt), () => []).add(entry);
  }
  final repeatedDays = byDay.entries
      .where((entry) => entry.value.length >= 2)
      .toList(growable: false);
  if (repeatedDays.isEmpty) return null;
  final maxLogs = repeatedDays.fold<int>(
    0,
    (value, entry) => max(value, entry.value.length),
  );
  if (repeatedDays.length < 2 && maxLogs < 3) return null;

  return BehaviorInsight(
    id: 'repeated_same_day',
    evidenceKey: '${repeatedDays.length}:$maxLogs:${entries.length}',
    title: 'Some days include repeat logs',
    body:
        'A few days have more than one logged moment. That can point to timing, access, or a trigger loop.',
    kind: InsightKind.pattern,
    type: InsightType.repeatedSameDay,
    why:
        'Stillpoint found ${repeatedDays.length} day(s) with repeated logs, with up to $maxLogs logs on one day.',
    nextAction:
        'For the next repeat-log day, note what happened between the first and second log.',
    evidenceSummary:
        '${repeatedDays.length} repeated day(s), up to $maxLogs logs in one day',
    confidence: _confidenceFor(repeatedDays.length + maxLogs),
    searchQuery: 'repeated same day cravings redosing harm reduction',
    suggestions: const [
      'Add one note after the first log about setting, access, or emotion.',
      'Try a delay or location change before the second log.',
      'Look for whether repeat days share sleep, work, or social pressure.',
    ],
    habitsNoticed: _topHabitNames(state),
    priority: 78,
  );
}

BehaviorInsight? _frequencyInsight(AppState state, List<UsageEntry> entries) {
  final now = DateTime.now();
  final today = _dayStart(now);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final previousWeekStart = weekStart.subtract(const Duration(days: 7));
  final weekLogs = _between(entries, weekStart, now).length;
  final previousLogs = _between(entries, previousWeekStart, weekStart).length;
  if (previousLogs < 3 || weekLogs > previousLogs * .75) return null;

  return BehaviorInsight(
    id: 'reduced_frequency_week',
    evidenceKey: '$weekLogs:$previousLogs',
    title: 'Fewer logged moments this week',
    body:
        'This week has fewer logged moments than last week. That shift is worth noticing without forcing a story onto it.',
    kind: InsightKind.progress,
    type: InsightType.reducedFrequency,
    why:
        'There are $weekLogs logs this week compared with $previousLogs in the previous week.',
    nextAction:
        'Notice one condition that made the lower-frequency week easier to repeat.',
    evidenceSummary: '$weekLogs this week vs $previousLogs last week',
    confidence: _confidenceFor(previousLogs),
    searchQuery: 'reduced substance use frequency support maintaining change',
    suggestions: const [
      'Name the condition that helped, even if it was small.',
      'Keep the next goal gentle enough to repeat.',
      'Avoid turning one hard day into a reset.',
    ],
    habitsNoticed: _topHabitNames(state),
    priority: 88,
  );
}

BehaviorInsight? _increasedQuantityInsight(
  AppState state,
  List<UsageEntry> entries,
) {
  final now = DateTime.now();
  final today = _dayStart(now);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final previousWeekStart = weekStart.subtract(const Duration(days: 7));
  final weekEntries = _between(entries, weekStart, now).toList(growable: false);
  final previousEntries = _between(
    entries,
    previousWeekStart,
    weekStart,
  ).toList(growable: false);
  if (weekEntries.length < 2 || previousEntries.length < 2) return null;

  final currentAvg = _averageQuantity(weekEntries);
  final previousAvg = _averageQuantity(previousEntries);
  if (previousAvg <= 0 || currentAvg < previousAvg * 1.2) return null;

  return BehaviorInsight(
    id: 'increased_quantity_per_log',
    evidenceKey:
        '${currentAvg.toStringAsFixed(1)}:${previousAvg.toStringAsFixed(1)}',
    title: 'Quantity per log has increased',
    body:
        'Recent logs are averaging more quantity than the previous week. This is information, not a verdict.',
    kind: InsightKind.pattern,
    type: InsightType.increasedQuantity,
    why:
        'This week averages ${_formatQuantity(currentAvg)} per log, compared with ${_formatQuantity(previousAvg)} last week.',
    nextAction:
        'Before the next log, choose a smaller preset first and decide again after a pause.',
    evidenceSummary:
        '${weekEntries.length} logs this week compared with ${previousEntries.length} last week',
    confidence: _confidenceFor(weekEntries.length + previousEntries.length),
    searchQuery: 'increased quantity per use harm reduction safer dosing',
    suggestions: const [
      'Use the small preset once to test how it feels.',
      'Notice whether quantity rose with stress, sleep loss, or redosing.',
      'Keep logging unit cost if money is also part of the pattern.',
    ],
    habitsNoticed: _topHabitNames(state),
    priority: 90,
  );
}

BehaviorInsight? _triggerInsight(AppState state, AnalyticsSnapshot analytics) {
  if (analytics.triggers.isEmpty) return null;
  final top = analytics.triggers.first;
  if (top.logs < 2) return null;

  return BehaviorInsight(
    id: 'trigger_${_slug(top.name)}',
    evidenceKey: '${top.name}:${top.logs}:${top.quantity.toStringAsFixed(1)}',
    title: '${top.name} appears often',
    body:
        'This context is linked with ${top.logs} recent logs. Treat it as information, not a verdict.',
    kind: InsightKind.context,
    type: InsightType.triggerContext,
    why:
        'Among logged context chips, ${top.name} currently has the strongest link by quantity.',
    nextAction:
        'Prepare one small barrier for ${top.name.toLowerCase()} moments.',
    evidenceSummary:
        '${top.logs} logs, ${_formatQuantity(top.quantity)} total quantity',
    confidence: _confidenceFor(top.logs),
    searchQuery: '${top.name} cravings harm reduction coping support',
    suggestions: [
      'Log the next ${top.name.toLowerCase()} moment with mood or stress.',
      'Try changing location before deciding what comes next.',
      'Keep one replacement action visible and easy.',
    ],
    habitsNoticed: [top.name],
    priority: 70,
  );
}

BehaviorInsight? _targetContinuityInsight(
  AppState state,
  AnalyticsSnapshot analytics,
) {
  if (analytics.currentTargetDays <= 0) return null;
  return BehaviorInsight(
    id: 'target_continuity',
    evidenceKey: 'days:${analytics.currentTargetDays}',
    title: 'Target continuity is building',
    body:
        '${analytics.currentTargetDays} recent day${analytics.currentTargetDays == 1 ? '' : 's'} stayed within your flexible target.',
    kind: InsightKind.progress,
    type: InsightType.targetContinuity,
    why:
        'Your active reduction targets are being compared against recent daily totals.',
    nextAction:
        'Keep the target gentle enough to repeat, then notice what made those days work.',
    evidenceSummary:
        '${analytics.currentTargetDays} day${analytics.currentTargetDays == 1 ? '' : 's'} within target',
    confidence: _confidenceFor(analytics.currentTargetDays),
    searchQuery: 'maintaining reduced substance use flexible goals support',
    suggestions: const [
      'Notice the conditions around the days that worked.',
      'Keep targets flexible rather than perfect.',
      'Use one hard day as context, not as a reset.',
    ],
    habitsNoticed: _topHabitNames(state),
    priority: 75,
  );
}

List<BehaviorInsight> _moneyInsights(
  AppState state,
  AnalyticsSnapshot analytics,
  List<UsageEntry> entries,
) {
  final insights = <BehaviorInsight>[];
  if (analytics.habitsWithCost == 0) {
    insights.add(
      const BehaviorInsight(
        id: 'money_setup',
        evidenceKey: 'no_costs',
        title: 'Money tracking is optional',
        body:
            'Add a cost per unit to any tracker to see money patterns alongside timing and context.',
        kind: InsightKind.context,
        type: InsightType.moneySetup,
        why:
            'No active tracker has a unit cost yet, so money insights stay hidden.',
        nextAction:
            'Open a tracker and set cost per unit when money is relevant.',
        evidenceSummary: 'No tracker costs set yet',
        confidence: 'Optional setup',
        suggestions: [
          'Use rough estimates; exact accounting is not required.',
          'Leave cost blank for patterns where money is not useful.',
          'Update unit costs when prices change.',
        ],
        habitsNoticed: ['No tracker costs set yet'],
        priority: 20,
      ),
    );
    return insights;
  }

  if (analytics.previousWeekEstimatedCost > 0 &&
      analytics.weekEstimatedCost > analytics.previousWeekEstimatedCost * 1.2) {
    insights.add(
      BehaviorInsight(
        id: 'money_increased_week',
        evidenceKey:
            '${analytics.weekEstimatedCost.toStringAsFixed(2)}:${analytics.previousWeekEstimatedCost.toStringAsFixed(2)}',
        title: 'Spending has increased this week',
        body:
            'Estimated cost is higher than last week. This can be a planning signal, not a shame signal.',
        kind: InsightKind.money,
        type: InsightType.moneyIncreased,
        why:
            'This week is ${_formatMoney(analytics.weekEstimatedCost)}, compared with ${_formatMoney(analytics.previousWeekEstimatedCost)} last week.',
        nextAction: 'Pick one lower-cost window to test before the week ends.',
        evidenceSummary:
            '${_formatMoney(analytics.weekEstimatedCost)} this week vs ${_formatMoney(analytics.previousWeekEstimatedCost)} last week',
        confidence: _confidenceFor(entries.length),
        searchQuery:
            'substance spending reduction harm reduction budgeting support',
        suggestions: const [
          'Notice which time window or context raised cost.',
          'Set or update unit costs if the estimate feels off.',
          'Choose one moment where spending less would feel kind, not punitive.',
        ],
        habitsNoticed: _costedHabitNames(state),
        priority: 84,
      ),
    );
  }

  final topCost = _topCostForWeek(state, entries);
  if (topCost != null && analytics.weekEstimatedCost > 0) {
    final share = topCost.amount / analytics.weekEstimatedCost;
    if (share >= .6 && topCost.amount >= 1) {
      insights.add(
        BehaviorInsight(
          id: 'money_concentration_${topCost.habit.id}',
          evidenceKey:
              '${topCost.habit.id}:${topCost.amount.toStringAsFixed(2)}:${analytics.weekEstimatedCost.toStringAsFixed(2)}',
          title: 'Most cost is coming from ${topCost.habit.name}',
          body:
              '${topCost.habit.name} accounts for most estimated cost this week. A small change there may matter more than chasing every tracker.',
          kind: InsightKind.money,
          type: InsightType.moneyConcentration,
          why:
              '${_formatMoney(topCost.amount)} of ${_formatMoney(analytics.weekEstimatedCost)} is linked with ${topCost.habit.name}.',
          nextAction:
              'Try one lower-cost preset or one pause window for ${topCost.habit.name}.',
          evidenceSummary: '${(share * 100).toStringAsFixed(0)}% of week cost',
          confidence: _confidenceFor(topCost.logs),
          searchQuery:
              '${topCost.habit.name} harm reduction reduce spending support',
          suggestions: const [
            'Focus on the biggest cost source first.',
            'Update the unit cost if the estimate feels stale.',
            'Compare change by week, not by a single hard day.',
          ],
          habitsNoticed: [topCost.habit.name],
          priority: 82,
        ),
      );
    }
  }

  if (analytics.previousWeekEstimatedCost > 0 &&
      analytics.weekEstimatedCost < analytics.previousWeekEstimatedCost * .8) {
    insights.add(
      BehaviorInsight(
        id: 'money_reduced_week',
        evidenceKey:
            '${analytics.weekEstimatedCost.toStringAsFixed(2)}:${analytics.previousWeekEstimatedCost.toStringAsFixed(2)}',
        title: 'You spent less than last week',
        body:
            'Estimated cost is lower this week. That may point to a condition worth repeating.',
        kind: InsightKind.money,
        type: InsightType.moneyReduced,
        why:
            'This week is ${_formatMoney(analytics.weekEstimatedCost)}, down from ${_formatMoney(analytics.previousWeekEstimatedCost)} last week.',
        nextAction:
            'Name one thing that helped the lower-cost week and keep it easy to repeat.',
        evidenceSummary:
            '${_formatMoney(analytics.weekEstimatedCost)} this week vs ${_formatMoney(analytics.previousWeekEstimatedCost)} last week',
        confidence: _confidenceFor(entries.length),
        searchQuery: 'maintain reduced spending substance use support',
        suggestions: const [
          'Notice whether timing, access, or social context changed.',
          'Keep the next money goal small and repeatable.',
          'Use this as a reflection, not a scoreboard.',
        ],
        habitsNoticed: _costedHabitNames(state),
        priority: 83,
      ),
    );
  }

  final weekend = _weekendCostPattern(state, entries);
  if (weekend != null) {
    insights.add(
      BehaviorInsight(
        id: 'money_weekend_rise',
        evidenceKey:
            '${weekend.weekendAverage.toStringAsFixed(2)}:${weekend.weekdayAverage.toStringAsFixed(2)}',
        title: 'Cost tends to rise on weekends',
        body:
            'Estimated daily cost is higher on weekends in the logs with cost data.',
        kind: InsightKind.money,
        type: InsightType.moneyWeekend,
        why:
            'Weekend days average ${_formatMoney(weekend.weekendAverage)}, compared with ${_formatMoney(weekend.weekdayAverage)} on weekdays.',
        nextAction:
            'Before the weekend starts, choose one spending boundary that feels supportive.',
        evidenceSummary:
            '${weekend.weekendDays} weekend day(s) and ${weekend.weekdayDays} weekday(s) with cost data',
        confidence: _confidenceFor(weekend.weekendDays + weekend.weekdayDays),
        searchQuery: 'weekend substance spending harm reduction planning',
        suggestions: const [
          'Look for social, after-work, or celebration links.',
          'Set an amount or supply boundary before the higher-cost window.',
          'Keep the wording kind: planning is not punishment.',
        ],
        habitsNoticed: _costedHabitNames(state),
        priority: 76,
      ),
    );
  }

  return insights;
}

List<UsageEntry> _activeEntries(AppState state) {
  final activeIds = state.activeHabits.map((habit) => habit.id).toSet();
  return state.entries
      .where((entry) => activeIds.contains(entry.habitId))
      .toList(growable: false)
    ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
}

List<String> _topHabitNames(AppState state) {
  final counts = <String, int>{};
  final habitsById = {for (final habit in state.activeHabits) habit.id: habit};
  for (final entry in state.entries) {
    final habit = habitsById[entry.habitId];
    if (habit == null) continue;
    counts.update(habit.name, (value) => value + 1, ifAbsent: () => 1);
  }
  final names = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return names.take(3).map((entry) => entry.key).toList(growable: false);
}

List<String> _costedHabitNames(AppState state) {
  return state.activeHabits
      .where((habit) => (habit.costPerUnit ?? 0) > 0)
      .take(3)
      .map((habit) => habit.name)
      .toList(growable: false);
}

Iterable<UsageEntry> _between(
  List<UsageEntry> entries,
  DateTime start,
  DateTime end,
) {
  return entries.where(
    (entry) => !entry.loggedAt.isBefore(start) && entry.loggedAt.isBefore(end),
  );
}

DateTime _dayStart(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

double _averageQuantity(List<UsageEntry> entries) {
  if (entries.isEmpty) return 0;
  return entries.fold<double>(0, (total, entry) => total + entry.quantity) /
      entries.length;
}

String _confidenceFor(int evidenceCount) {
  if (evidenceCount >= 12) return 'Stronger local signal';
  if (evidenceCount >= 6) return 'Moderate local signal';
  return 'Early local signal';
}

String _formatQuantity(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

String _formatMoney(double value) => '\$${value.toStringAsFixed(2)}';

String _weekdayName(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => 'This weekday',
  };
}

String _slug(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

class _WindowMetric {
  _WindowMetric({
    required this.key,
    required this.label,
    required this.rangeLabel,
    required this.matches,
  });

  final String key;
  final String label;
  final String rangeLabel;
  final bool Function(UsageEntry entry) matches;

  int logs = 0;
  double quantity = 0;

  void add(Iterable<UsageEntry> entries) {
    for (final entry in entries) {
      logs += 1;
      quantity += entry.quantity;
    }
  }
}

({Habit habit, double amount, int logs})? _topCostForWeek(
  AppState state,
  List<UsageEntry> entries,
) {
  final now = DateTime.now();
  final today = _dayStart(now);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final habitsById = {for (final habit in state.activeHabits) habit.id: habit};
  final totals = <String, ({double amount, int logs})>{};
  for (final entry in _between(entries, weekStart, now)) {
    final habit = habitsById[entry.habitId];
    if (habit == null) continue;
    final cost = entry.estimatedCostFor(habit);
    if (cost == null || cost <= 0) continue;
    final previous = totals[habit.id] ?? (amount: 0.0, logs: 0);
    totals[habit.id] = (
      amount: previous.amount + cost,
      logs: previous.logs + 1,
    );
  }
  if (totals.isEmpty) return null;

  final top = totals.entries.reduce(
    (a, b) => a.value.amount >= b.value.amount ? a : b,
  );
  final habit = habitsById[top.key];
  if (habit == null) return null;
  return (habit: habit, amount: top.value.amount, logs: top.value.logs);
}

({
  double weekendAverage,
  double weekdayAverage,
  int weekendDays,
  int weekdayDays,
})?
_weekendCostPattern(AppState state, List<UsageEntry> entries) {
  final habitsById = {for (final habit in state.activeHabits) habit.id: habit};
  final totalsByDay = <DateTime, double>{};
  for (final entry in entries) {
    final habit = habitsById[entry.habitId];
    final cost = habit == null ? null : entry.estimatedCostFor(habit);
    if (cost == null || cost <= 0) continue;
    totalsByDay.update(
      _dayStart(entry.loggedAt),
      (value) => value + cost,
      ifAbsent: () => cost,
    );
  }
  if (totalsByDay.length < 4) return null;

  final weekendCosts = <double>[];
  final weekdayCosts = <double>[];
  for (final item in totalsByDay.entries) {
    if (item.key.weekday == DateTime.saturday ||
        item.key.weekday == DateTime.sunday) {
      weekendCosts.add(item.value);
    } else {
      weekdayCosts.add(item.value);
    }
  }
  if (weekendCosts.length < 2 || weekdayCosts.length < 2) return null;

  final weekendAverage =
      weekendCosts.fold<double>(0, (total, value) => total + value) /
      weekendCosts.length;
  final weekdayAverage =
      weekdayCosts.fold<double>(0, (total, value) => total + value) /
      weekdayCosts.length;
  if (weekdayAverage <= 0 || weekendAverage < weekdayAverage * 1.25) {
    return null;
  }

  return (
    weekendAverage: weekendAverage,
    weekdayAverage: weekdayAverage,
    weekendDays: weekendCosts.length,
    weekdayDays: weekdayCosts.length,
  );
}
