import 'models.dart';

class HabitCategoryProfile {
  const HabitCategoryProfile({
    required this.defaultUnit,
    required this.loggingHint,
    required this.contextChips,
    required this.aliases,
    required this.searchTerms,
    this.defaultUnitCost,
  });

  final String defaultUnit;
  final String loggingHint;
  final List<String> contextChips;
  final List<String> aliases;
  final List<String> searchTerms;
  final double? defaultUnitCost;
}

class HabitLibrary {
  static const _defaultContextChips = [
    'Stress',
    'Social',
    'Sleep',
    'Boredom',
    'Work',
    'Evening',
    'Pain',
    'Celebration',
  ];

  static const _fallbackProfile = HabitCategoryProfile(
    defaultUnit: 'units',
    loggingHint:
        'Use the log as a note to your future self. If safety feels uncertain, pause and reach out for real-time help.',
    contextChips: _defaultContextChips,
    aliases: ['habit', 'pattern', 'custom'],
    searchTerms: ['behavior pattern', 'harm reduction support'],
  );

  static const _profiles = <HabitCategory, HabitCategoryProfile>{
    HabitCategory.cigarettes: HabitCategoryProfile(
      defaultUnit: 'cigarettes',
      defaultUnitCost: .5,
      loggingHint:
          'Nicotine urges can rise and settle quickly. A short delay, water, and moving away from supplies can make the next choice less automatic.',
      contextChips: ['Stress', 'Habit', 'After meal', 'Driving'],
      aliases: ['cigs', 'cig', 'smokes', 'smoking', 'tobacco', 'nicotine'],
      searchTerms: ['smoking harm reduction', 'quit smoking support'],
    ),
    HabitCategory.vaping: HabitCategoryProfile(
      defaultUnit: 'sessions',
      defaultUnitCost: 1,
      loggingHint:
          'Try noticing whether vaping is tied to stress, habit loops, or a place. A brief delay can help separate craving from routine.',
      contextChips: ['Stress', 'Habit', 'After meal', 'Driving'],
      aliases: ['vape', 'vapes', 'e-cig', 'ecig', 'nicotine'],
      searchTerms: ['vaping harm reduction', 'quit vaping support'],
    ),
    HabitCategory.alcohol: HabitCategoryProfile(
      defaultUnit: 'drinks',
      defaultUnitCost: 8,
      loggingHint:
          'Avoid driving or mixing alcohol with opioids, sedatives, or pills. If heavy daily drinking is present, medical support matters before stopping suddenly.',
      contextChips: ['Social', 'Alone', 'After work', 'Celebration'],
      aliases: ['booze', 'beer', 'wine', 'liquor', 'drinking', 'drinks'],
      searchTerms: ['alcohol harm reduction', 'reduce drinking support'],
    ),
    HabitCategory.cannabis: HabitCategoryProfile(
      defaultUnit: 'uses',
      defaultUnitCost: 6,
      loggingHint:
          'Dose, potency, and timing can change the experience. Give effects time before more, avoid driving, and note sleep or anxiety links gently.',
      contextChips: ['Sleep', 'Anxiety', 'Boredom', 'Social'],
      aliases: [
        'weed',
        'pot',
        'marijuana',
        'thc',
        'edible',
        'edibles',
        'joint',
      ],
      searchTerms: ['cannabis harm reduction', 'THC safer use'],
    ),
    HabitCategory.cocaine: HabitCategoryProfile(
      defaultUnit: 'uses',
      loggingHint:
          'Redosing and sleep loss can raise strain. Pause before more, avoid mixing, and seek urgent help for chest pain, severe agitation, or overheating.',
      contextChips: ['Redose', 'Sleep loss', 'Work pressure', 'Focus'],
      aliases: ['coke', 'stimulant', 'powder'],
      searchTerms: ['stimulant harm reduction', 'cocaine safer use'],
    ),
    HabitCategory.methamphetamine: HabitCategoryProfile(
      defaultUnit: 'uses',
      loggingHint:
          'Sleep loss, redosing, and overheating can raise risk. Food, water, rest, and a trusted person nearby can matter before more.',
      contextChips: ['Redose', 'Sleep loss', 'Work pressure', 'Focus'],
      aliases: ['meth', 'crystal', 'ice', 'stimulant'],
      searchTerms: ['methamphetamine harm reduction', 'stimulant safer use'],
    ),
    HabitCategory.caffeine: HabitCategoryProfile(
      defaultUnit: 'servings',
      defaultUnitCost: 4.5,
      loggingHint:
          'Late caffeine can borrow from sleep. Notice timing, anxiety, and jitters before adding another serving.',
      contextChips: ['Focus', 'Sleep loss', 'Work pressure', 'Habit'],
      aliases: ['coffee', 'energy drink', 'tea', 'espresso', 'cola'],
      searchTerms: ['caffeine sleep anxiety support'],
    ),
    HabitCategory.opioids: HabitCategoryProfile(
      defaultUnit: 'doses',
      loggingHint:
          'Avoid mixing with alcohol, benzodiazepines, or other sedatives. If opioids may be involved, naloxone and another person nearby can save time in an emergency.',
      contextChips: ['Pain', 'Alone', 'Sleep', 'Mixing risk'],
      aliases: ['opioid', 'opiate', 'pain pills', 'oxy', 'heroin', 'fentanyl'],
      searchTerms: ['opioid harm reduction', 'naloxone overdose prevention'],
    ),
    HabitCategory.benzodiazepines: HabitCategoryProfile(
      defaultUnit: 'doses',
      loggingHint:
          'Mixing sedatives with alcohol or opioids can slow breathing. If this is prescribed, a clinician or pharmacist is the safest place to adjust dose.',
      contextChips: ['Anxiety', 'Sleep', 'Alone', 'Mixing risk'],
      aliases: ['benzos', 'xanax', 'valium', 'klonopin', 'sedative'],
      searchTerms: ['benzodiazepine harm reduction', 'sedative safety'],
    ),
    HabitCategory.sedatives: HabitCategoryProfile(
      defaultUnit: 'doses',
      loggingHint:
          'Sedatives can stack with alcohol, opioids, and sleep medicines. Note timing and mixing risk before deciding on more.',
      contextChips: ['Sleep', 'Anxiety', 'Alone', 'Mixing risk'],
      aliases: ['sleeping pills', 'sleep meds', 'tranquilizers'],
      searchTerms: ['sedative harm reduction', 'sleep medicine safety'],
    ),
    HabitCategory.pills: HabitCategoryProfile(
      defaultUnit: 'pills',
      loggingHint:
          'Check the label and dose when pills are involved. Mixing, unknown strength, or using differently than prescribed deserves extra caution.',
      contextChips: ['Pain', 'Anxiety', 'Sleep', 'Mixing risk'],
      aliases: ['meds', 'tablets', 'capsules', 'prescription'],
      searchTerms: ['prescription drug safety', 'pill harm reduction'],
    ),
    HabitCategory.prescriptionMisuse: HabitCategoryProfile(
      defaultUnit: 'doses',
      loggingHint:
          'Prescribed medicines can still carry interaction risk. If control feels reduced, bring the pattern to a clinician or pharmacist without waiting for perfection.',
      contextChips: ['Pain', 'Anxiety', 'Sleep', 'Mixing risk'],
      aliases: ['med misuse', 'prescription', 'rx', 'pills'],
      searchTerms: ['prescription misuse support', 'medication safety'],
    ),
    HabitCategory.gambling: HabitCategoryProfile(
      defaultUnit: 'sessions',
      loggingHint:
          'A cooling-off window and a money barrier can help when chasing losses or urgency is high.',
      contextChips: ['Stress', 'Boredom', 'Chasing loss', 'Payday'],
      aliases: ['betting', 'bets', 'casino', 'sportsbook', 'lottery'],
      searchTerms: ['gambling support', 'problem gambling help'],
    ),
    HabitCategory.doomscrolling: HabitCategoryProfile(
      defaultUnit: 'minutes',
      loggingHint:
          'Feeds are built to keep going. A timer, distance from the device, and getting out of bed can protect sleep and attention.',
      contextChips: ['Boredom', 'Anxiety', 'News', 'Bedtime'],
      aliases: ['scrolling', 'phone', 'social media', 'feeds', 'reels'],
      searchTerms: ['doomscrolling support', 'digital wellbeing'],
    ),
    HabitCategory.pornography: HabitCategoryProfile(
      defaultUnit: 'sessions',
      loggingHint:
          'Notice privacy, stress, and timing without turning it into a verdict. Changing location can soften an automatic loop.',
      contextChips: ['Stress', 'Alone', 'Boredom', 'Bedtime'],
      aliases: ['porn', 'adult content', 'sexual content'],
      searchTerms: ['compulsive sexual behavior support'],
    ),
  };

  static HabitCategoryProfile profileFor(HabitCategory category) {
    return _profiles[category] ??
        HabitCategoryProfile(
          defaultUnit: category.defaultUnit,
          loggingHint: _fallbackProfile.loggingHint,
          contextChips: _defaultContextChips,
          aliases: const [],
          searchTerms: [category.label.toLowerCase(), 'harm reduction support'],
        );
  }

  static List<String> contextChipsFor(HabitCategory category) {
    return profileFor(category).contextChips;
  }

  static String loggingHintFor(HabitCategory category) {
    return profileFor(category).loggingHint;
  }

  static double? defaultUnitCostFor(HabitCategory category) {
    return profileFor(category).defaultUnitCost;
  }

  static List<String> searchTermsFor(Habit habit) {
    final profile = profileFor(habit.category);
    return [
      habit.name,
      habit.category.label,
      habit.unit,
      ...profile.aliases,
      ...profile.searchTerms,
    ];
  }

  static bool matchesHabit(Habit habit, String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return true;
    return searchTermsFor(
      habit,
    ).any((term) => _normalize(term).contains(normalized));
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll('-', ' ');
  }
}
