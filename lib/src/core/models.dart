import 'dart:math';

enum HabitCategory {
  cigarettes,
  vaping,
  alcohol,
  drugs,
  pills,
  recreationalSubstances,
  caffeine,
  gambling,
  doomscrolling,
  pornography,
  prescriptionMisuse,
  custom;

  String get label => switch (this) {
    HabitCategory.cigarettes => 'Cigarettes',
    HabitCategory.vaping => 'Vaping',
    HabitCategory.alcohol => 'Alcohol',
    HabitCategory.drugs => 'Drugs',
    HabitCategory.pills => 'Pills',
    HabitCategory.recreationalSubstances => 'Recreational substances',
    HabitCategory.caffeine => 'Caffeine',
    HabitCategory.gambling => 'Gambling',
    HabitCategory.doomscrolling => 'Doomscrolling',
    HabitCategory.pornography => 'Pornography',
    HabitCategory.prescriptionMisuse => 'Prescription misuse',
    HabitCategory.custom => 'Custom',
  };

  String get defaultUnit => switch (this) {
    HabitCategory.cigarettes => 'cigarettes',
    HabitCategory.vaping => 'sessions',
    HabitCategory.alcohol => 'drinks',
    HabitCategory.drugs => 'uses',
    HabitCategory.pills => 'pills',
    HabitCategory.recreationalSubstances => 'uses',
    HabitCategory.caffeine => 'servings',
    HabitCategory.gambling => 'sessions',
    HabitCategory.doomscrolling => 'minutes',
    HabitCategory.pornography => 'sessions',
    HabitCategory.prescriptionMisuse => 'doses',
    HabitCategory.custom => 'units',
  };

  static HabitCategory fromName(String value) {
    return HabitCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => HabitCategory.custom,
    );
  }
}

enum ReductionMode {
  monitor,
  stabilize,
  reduce,
  quit;

  String get label => switch (this) {
    ReductionMode.monitor => 'Monitor',
    ReductionMode.stabilize => 'Stabilize',
    ReductionMode.reduce => 'Reduce gradually',
    ReductionMode.quit => 'Step away',
  };

  String get calmDescription => switch (this) {
    ReductionMode.monitor => 'Track patterns without a target.',
    ReductionMode.stabilize => 'Keep usage steadier while observing cues.',
    ReductionMode.reduce => 'Use flexible targets that adapt over time.',
    ReductionMode.quit => 'Support longer pauses without resetting progress.',
  };

  static ReductionMode fromName(String value) {
    return ReductionMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ReductionMode.monitor,
    );
  }
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.colorValue,
    required this.createdAt,
    this.reductionMode = ReductionMode.monitor,
    this.dailyTarget,
    this.archived = false,
  });

  final String id;
  final String name;
  final HabitCategory category;
  final String unit;
  final int colorValue;
  final DateTime createdAt;
  final ReductionMode reductionMode;
  final double? dailyTarget;
  final bool archived;

  Habit copyWith({
    String? id,
    String? name,
    HabitCategory? category,
    String? unit,
    int? colorValue,
    DateTime? createdAt,
    ReductionMode? reductionMode,
    double? dailyTarget,
    bool clearDailyTarget = false,
    bool? archived,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      reductionMode: reductionMode ?? this.reductionMode,
      dailyTarget: clearDailyTarget ? null : dailyTarget ?? this.dailyTarget,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'unit': unit,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'reductionMode': reductionMode.name,
      'dailyTarget': dailyTarget,
      'archived': archived,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as String,
      name: map['name'] as String,
      category: HabitCategory.fromName(map['category'] as String? ?? ''),
      unit: map['unit'] as String? ?? 'units',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF6A8F7A,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      reductionMode: ReductionMode.fromName(
        map['reductionMode'] as String? ?? '',
      ),
      dailyTarget: (map['dailyTarget'] as num?)?.toDouble(),
      archived: map['archived'] as bool? ?? false,
    );
  }
}

class UsageEntry {
  const UsageEntry({
    required this.id,
    required this.habitId,
    required this.loggedAt,
    required this.quantity,
    this.mood,
    this.craving,
    this.stress,
    this.trigger,
    this.note,
  });

  final String id;
  final String habitId;
  final DateTime loggedAt;
  final double quantity;
  final int? mood;
  final int? craving;
  final int? stress;
  final String? trigger;
  final String? note;

  UsageEntry copyWith({
    String? id,
    String? habitId,
    DateTime? loggedAt,
    double? quantity,
    int? mood,
    int? craving,
    int? stress,
    String? trigger,
    String? note,
  }) {
    return UsageEntry(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      loggedAt: loggedAt ?? this.loggedAt,
      quantity: quantity ?? this.quantity,
      mood: mood ?? this.mood,
      craving: craving ?? this.craving,
      stress: stress ?? this.stress,
      trigger: trigger ?? this.trigger,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'loggedAt': loggedAt.toIso8601String(),
      'quantity': quantity,
      'mood': mood,
      'craving': craving,
      'stress': stress,
      'trigger': trigger,
      'note': note,
    };
  }

  factory UsageEntry.fromMap(Map<String, dynamic> map) {
    return UsageEntry(
      id: map['id'] as String,
      habitId: map['habitId'] as String,
      loggedAt:
          DateTime.tryParse(map['loggedAt'] as String? ?? '') ?? DateTime.now(),
      quantity: max(0, (map['quantity'] as num?)?.toDouble() ?? 0),
      mood: (map['mood'] as num?)?.toInt(),
      craving: (map['craving'] as num?)?.toInt(),
      stress: (map['stress'] as num?)?.toInt(),
      trigger: map['trigger'] as String?,
      note: map['note'] as String?,
    );
  }
}

class AppSettings {
  const AppSettings({
    this.useSystemTheme = true,
    this.darkMode = false,
    this.biometricLock = false,
    this.pinLock = false,
    this.pinHash,
    this.offlineMode = true,
    this.hiddenNotifications = true,
    this.softReminders = true,
    this.quietHours = true,
    this.quietStartHour = 22,
    this.quietEndHour = 8,
    this.reduceMotion = false,
  });

  final bool useSystemTheme;
  final bool darkMode;
  final bool biometricLock;
  final bool pinLock;
  final String? pinHash;
  final bool offlineMode;
  final bool hiddenNotifications;
  final bool softReminders;
  final bool quietHours;
  final int quietStartHour;
  final int quietEndHour;
  final bool reduceMotion;

  AppSettings copyWith({
    bool? useSystemTheme,
    bool? darkMode,
    bool? biometricLock,
    bool? pinLock,
    String? pinHash,
    bool clearPinHash = false,
    bool? offlineMode,
    bool? hiddenNotifications,
    bool? softReminders,
    bool? quietHours,
    int? quietStartHour,
    int? quietEndHour,
    bool? reduceMotion,
  }) {
    return AppSettings(
      useSystemTheme: useSystemTheme ?? this.useSystemTheme,
      darkMode: darkMode ?? this.darkMode,
      biometricLock: biometricLock ?? this.biometricLock,
      pinLock: pinLock ?? this.pinLock,
      pinHash: clearPinHash ? null : pinHash ?? this.pinHash,
      offlineMode: offlineMode ?? this.offlineMode,
      hiddenNotifications: hiddenNotifications ?? this.hiddenNotifications,
      softReminders: softReminders ?? this.softReminders,
      quietHours: quietHours ?? this.quietHours,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'useSystemTheme': useSystemTheme,
      'darkMode': darkMode,
      'biometricLock': biometricLock,
      'pinLock': pinLock,
      'pinHash': pinHash,
      'offlineMode': offlineMode,
      'hiddenNotifications': hiddenNotifications,
      'softReminders': softReminders,
      'quietHours': quietHours,
      'quietStartHour': quietStartHour,
      'quietEndHour': quietEndHour,
      'reduceMotion': reduceMotion,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      useSystemTheme: map['useSystemTheme'] as bool? ?? true,
      darkMode: map['darkMode'] as bool? ?? false,
      biometricLock: map['biometricLock'] as bool? ?? false,
      pinLock: map['pinLock'] as bool? ?? false,
      pinHash: map['pinHash'] as String?,
      offlineMode: map['offlineMode'] as bool? ?? true,
      hiddenNotifications: map['hiddenNotifications'] as bool? ?? true,
      softReminders: map['softReminders'] as bool? ?? true,
      quietHours: map['quietHours'] as bool? ?? true,
      quietStartHour: (map['quietStartHour'] as num?)?.toInt() ?? 22,
      quietEndHour: (map['quietEndHour'] as num?)?.toInt() ?? 8,
      reduceMotion: map['reduceMotion'] as bool? ?? false,
    );
  }
}

class AppState {
  const AppState({
    required this.habits,
    required this.entries,
    required this.settings,
  });

  final List<Habit> habits;
  final List<UsageEntry> entries;
  final AppSettings settings;

  List<Habit> get activeHabits =>
      habits.where((habit) => !habit.archived).toList(growable: false);

  UsageEntry? get lastEntry {
    if (entries.isEmpty) return null;
    final sorted = [...entries]
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return sorted.first;
  }

  AppState copyWith({
    List<Habit>? habits,
    List<UsageEntry>? entries,
    AppSettings? settings,
  }) {
    return AppState(
      habits: habits ?? this.habits,
      entries: entries ?? this.entries,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'habits': habits.map((habit) => habit.toMap()).toList(),
      'entries': entries.map((entry) => entry.toMap()).toList(),
      'settings': settings.toMap(),
    };
  }

  factory AppState.fromMap(Map<String, dynamic> map) {
    return AppState(
      habits: (map['habits'] as List<dynamic>? ?? const [])
          .map((item) => Habit.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      entries: (map['entries'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                UsageEntry.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      settings: AppSettings.fromMap(
        Map<String, dynamic>.from(map['settings'] as Map? ?? const {}),
      ),
    ).withDefaultHabits();
  }

  factory AppState.initial() {
    final now = DateTime.now();
    return AppState(
      habits: defaultHabitPresets(now),
      entries: const [],
      settings: const AppSettings(),
    );
  }

  AppState withDefaultHabits() {
    final existingIds = habits.map((habit) => habit.id).toSet();
    final missing = defaultHabitPresets(
      DateTime.now(),
    ).where((habit) => !existingIds.contains(habit.id));
    if (missing.isEmpty) return this;
    return copyWith(habits: [...habits, ...missing]);
  }

  static List<Habit> defaultHabitPresets(DateTime createdAt) {
    final presets = [
      (HabitCategory.cigarettes, 'Cigarettes', 0xFF6A8F7A),
      (HabitCategory.vaping, 'Vaping', 0xFF4F8DAA),
      (HabitCategory.alcohol, 'Alcohol', 0xFFC77D57),
      (HabitCategory.drugs, 'Drugs', 0xFF707C64),
      (HabitCategory.pills, 'Pills', 0xFF5B7F95),
      (HabitCategory.caffeine, 'Caffeine', 0xFFB88A44),
      (HabitCategory.doomscrolling, 'Doomscrolling', 0xFF7E8A97),
      (HabitCategory.gambling, 'Gambling', 0xFF8C6A93),
      (HabitCategory.pornography, 'Pornography', 0xFF9D7668),
      (
        HabitCategory.recreationalSubstances,
        'Recreational substances',
        0xFF60735B,
      ),
      (HabitCategory.prescriptionMisuse, 'Prescription misuse', 0xFF536E8B),
    ];

    return [
      for (final preset in presets)
        Habit(
          id: 'preset_${preset.$1.name}',
          name: preset.$2,
          category: preset.$1,
          unit: preset.$1.defaultUnit,
          colorValue: preset.$3,
          createdAt: createdAt,
        ),
    ];
  }
}

String moodLabel(int? value) {
  return switch (value) {
    null => 'Not set',
    <= 1 => 'Heavy',
    2 => 'Low',
    3 => 'Steady',
    4 => 'Clear',
    _ => 'Light',
  };
}

String intensityLabel(int? value) {
  return switch (value) {
    null => 'Not set',
    <= 1 => 'Quiet',
    2 => 'Mild',
    3 => 'Moderate',
    4 => 'Strong',
    _ => 'Intense',
  };
}
