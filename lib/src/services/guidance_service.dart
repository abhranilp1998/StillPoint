import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';

class SupportResource {
  const SupportResource({
    required this.title,
    required this.source,
    required this.url,
  });

  final String title;
  final String source;
  final String url;
}

class RiskProfile {
  const RiskProfile({
    required this.title,
    required this.riskSummary,
    required this.cooldown,
    required this.immediateSteps,
    required this.resources,
  });

  final String title;
  final String riskSummary;
  final String cooldown;
  final List<String> immediateSteps;
  final List<SupportResource> resources;
}

class GuidanceService {
  static RiskProfile profileFor(HabitCategory category) {
    return switch (category) {
      HabitCategory.cigarettes => _nicotineProfile(
        title: 'Nicotine and smoking',
      ),
      HabitCategory.vaping => _nicotineProfile(title: 'Nicotine and vaping'),
      HabitCategory.alcohol => const RiskProfile(
        title: 'Alcohol risk notes',
        riskSummary:
            'Drinking less can lower risk. Higher alcohol use is linked with injury risk, poor sleep, liver strain, some cancers, and higher danger when mixed with other drugs.',
        cooldown:
            'Try a 20 minute pause, water, food if appropriate, and a location change before deciding what comes next.',
        immediateSteps: [
          'Avoid driving, swimming, machinery, or mixing with opioids, sedatives, or pills.',
          'If breathing, consciousness, or safety feels uncertain, seek urgent help.',
          'If daily heavy use is present, talk with a clinician before stopping suddenly.',
        ],
        resources: [
          SupportResource(
            title: 'Alcohol and your health',
            source: 'CDC',
            url: 'https://www.cdc.gov/alcohol/about-alcohol-use/index.html',
          ),
          SupportResource(
            title: 'Check your drinking',
            source: 'CDC',
            url: 'https://www.cdc.gov/alcohol/checkyourdrinking/index.html',
          ),
          SupportResource(
            title: 'Find treatment and support',
            source: 'SAMHSA',
            url: 'https://www.samhsa.gov/find-help',
          ),
        ],
      ),
      HabitCategory.drugs ||
      HabitCategory.recreationalSubstances => const RiskProfile(
        title: 'Drug use risk notes',
        riskSummary:
            'Drug effects vary by substance, dose, setting, and mixing. Higher-risk patterns include using alone, unknown potency, repeated redosing, impaired breathing, panic, chest pain, or mixing depressants.',
        cooldown:
            'Use a 15 minute delay, move to a safer setting, drink water if safe, and contact a trusted person before redosing.',
        immediateSteps: [
          'Avoid mixing substances; alcohol, opioids, benzodiazepines, and other sedatives can compound breathing risk.',
          'If overdose is possible, call emergency services and use naloxone if opioids may be involved.',
          'Use this app as awareness, not as medical clearance.',
        ],
        resources: [
          SupportResource(
            title: 'Commonly used drugs and effects',
            source: 'NIDA',
            url:
                'https://nida.nih.gov/research-topics/commonly-used-drugs-charts',
          ),
          SupportResource(
            title: 'Find help and treatment',
            source: 'SAMHSA',
            url: 'https://www.samhsa.gov/find-help',
          ),
          SupportResource(
            title: 'Substance use treatment',
            source: 'SAMHSA',
            url: 'https://www.samhsa.gov/substance-use/treatment',
          ),
        ],
      ),
      HabitCategory.pills ||
      HabitCategory.prescriptionMisuse => const RiskProfile(
        title: 'Pills and prescription misuse',
        riskSummary:
            'Pills can carry serious interaction and overdose risks, especially opioids, sedatives, stimulants, or medication used differently than prescribed.',
        cooldown:
            'Pause for 15 minutes, check the actual label/dose, avoid alcohol or other sedatives, and consider contacting a clinician or pharmacist.',
        immediateSteps: [
          'Do not mix opioids with benzodiazepines, alcohol, or other sedatives.',
          'If breathing slows, someone cannot stay awake, or overdose is possible, seek emergency help.',
          'If medication is prescribed, use the prescriber or pharmacist as the safest next support.',
        ],
        resources: [
          SupportResource(
            title: 'Prescription opioids',
            source: 'NIDA',
            url:
                'https://nida.nih.gov/publications/drugfacts/prescription-opioids',
          ),
          SupportResource(
            title: 'Opioids and benzodiazepines',
            source: 'NIDA',
            url:
                'https://nida.nih.gov/drugs-abuse/opioids/benzodiazepines-opioids',
          ),
          SupportResource(
            title: 'Find treatment and support',
            source: 'SAMHSA',
            url: 'https://www.samhsa.gov/find-help',
          ),
        ],
      ),
      HabitCategory.caffeine => const RiskProfile(
        title: 'Caffeine risk notes',
        riskSummary:
            'Caffeine sensitivity varies. Higher intake can contribute to sleep disruption, anxiety, jitters, stomach upset, and fast heartbeat.',
        cooldown:
            'Try a 30 minute delay after each serving and avoid late-day caffeine when sleep is the pattern you want to protect.',
        immediateSteps: [
          'Track total caffeine from coffee, tea, energy drinks, soda, and pills.',
          'Hydrate and eat if caffeine is making you shaky.',
          'Ask a clinician about caffeine if pregnant, sensitive, or taking interacting medication.',
        ],
        resources: [
          SupportResource(
            title: 'How much caffeine is too much?',
            source: 'FDA',
            url:
                'https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much',
          ),
          SupportResource(
            title: 'Caffeine overview',
            source: 'Mayo Clinic',
            url:
                'https://www.mayoclinic.org/healthy-lifestyle/nutrition-and-healthy-eating/in-depth/caffeine/art-20045678',
          ),
        ],
      ),
      HabitCategory.gambling => const RiskProfile(
        title: 'Gambling risk notes',
        riskSummary:
            'Risk can rise when chasing losses, hiding activity, borrowing money, or feeling unable to stop once started.',
        cooldown:
            'Use a 24 hour cooling-off period before deposits, bets, or app reopens. Add a spending barrier while the urge is active.',
        immediateSteps: [
          'Move money or cards away from easy access before urges peak.',
          'Use account limits, self-exclusion, or app/site blockers when available.',
          'If debt or safety pressure is rising, contact a trusted person or gambling support line.',
        ],
        resources: [
          SupportResource(
            title: 'Problem gambling helpline',
            source: 'NCPG',
            url: 'https://www.ncpgambling.org/help-treatment/',
          ),
          SupportResource(
            title: 'State gambling support',
            source: 'NCPG',
            url: 'https://www.ncpgambling.org/help-treatment/help-by-state/',
          ),
        ],
      ),
      HabitCategory.doomscrolling => const RiskProfile(
        title: 'Doomscrolling risk notes',
        riskSummary:
            'Long scrolling windows can crowd out sleep, attention, movement, and emotional recovery, especially late at night.',
        cooldown:
            'Try a 10 minute phone-down period. Put the device across the room and choose one replacement action.',
        immediateSteps: [
          'Turn off push alerts for the current window.',
          'Use a timer and stop at the timer, not at the end of the feed.',
          'Keep scrolling out of bed when sleep is already under pressure.',
        ],
        resources: [
          SupportResource(
            title: 'Digital wellbeing tools',
            source: 'Google',
            url: 'https://wellbeing.google/',
          ),
          SupportResource(
            title: 'Sleep and screen habits',
            source: 'Sleep Foundation',
            url:
                'https://www.sleepfoundation.org/how-sleep-works/how-electronics-affect-sleep',
          ),
        ],
      ),
      HabitCategory.pornography => const RiskProfile(
        title: 'Pornography pattern notes',
        riskSummary:
            'Porn use becomes more concerning when it feels hard to control, causes distress, disrupts relationships/work, or is used as the main escape from stress or loneliness.',
        cooldown:
            'Try a 15 minute delay, leave the private browsing context, and choose a replacement activity that changes location.',
        immediateSteps: [
          'Make the behavior less private during high-risk windows.',
          'Use blockers or device boundaries if late-night patterns repeat.',
          'Consider a mental health professional if control feels reduced or distress is rising.',
        ],
        resources: [
          SupportResource(
            title: 'Compulsive sexual behavior',
            source: 'Mayo Clinic',
            url:
                'https://www.mayoclinic.org/diseases-conditions/compulsive-sexual-behavior/symptoms-causes/syc-20360434',
          ),
          SupportResource(
            title: 'Treatment and coping',
            source: 'Mayo Clinic',
            url:
                'https://www.mayoclinic.org/diseases-conditions/compulsive-sexual-behavior/diagnosis-treatment/drc-20360453',
          ),
        ],
      ),
      HabitCategory.custom => const RiskProfile(
        title: 'Pattern risk notes',
        riskSummary:
            'A repeated pattern deserves attention when it narrows choice, affects sleep, money, safety, relationships, or makes you feel less in control.',
        cooldown:
            'Try a 10 minute delay and note what changed before deciding what comes next.',
        immediateSteps: [
          'Change location, reduce access, and contact a trusted person if safety feels uncertain.',
          'Use the log as information, not a score.',
        ],
        resources: [
          SupportResource(
            title: 'Find support',
            source: 'SAMHSA',
            url: 'https://www.samhsa.gov/find-support',
          ),
        ],
      ),
    };
  }

  static Uri searchUriFor({
    required Habit habit,
    required List<UsageEntry> entries,
  }) {
    final triggerCounts = <String, int>{};
    for (final entry in entries.where((entry) => entry.trigger != null)) {
      triggerCounts.update(
        entry.trigger!,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final topTrigger = triggerCounts.entries.isEmpty
        ? null
        : triggerCounts.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;

    final commonHour = _commonHour(entries);
    final pattern = [
      habit.name,
      ?topTrigger,
      if (commonHour case final hour?) _windowLabel(hour),
    ].join(' ');

    final query = '$pattern evidence based reduce cravings cooldown support';
    return Uri.https('www.google.com', '/search', {'q': query});
  }

  static Future<bool> openUri(String url) {
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static Future<bool> openSearch({
    required Habit habit,
    required List<UsageEntry> entries,
  }) {
    return launchUrl(
      searchUriFor(habit: habit, entries: entries),
      mode: LaunchMode.externalApplication,
    );
  }

  static RiskProfile _nicotineProfile({required String title}) {
    return RiskProfile(
      title: '$title risk notes',
      riskSummary:
          'Nicotine is highly addictive. Smoking has well-established health risks; vaping can still expose the lungs to harmful substances and nicotine withdrawal can intensify cravings.',
      cooldown:
          'Try a 10 minute urge delay. Keep hands busy, change location, breathe slowly, and decide again after the wave settles.',
      immediateSteps: const [
        'Use a safer substitute for hands or mouth during the urge window.',
        'Avoid places or supplies that make the next use automatic.',
        'Quitlines and clinicians can help with nicotine replacement or medication options.',
      ],
      resources: const [
        SupportResource(
          title: 'Tips for quitting',
          source: 'CDC',
          url:
              'https://www.cdc.gov/tobacco/campaign/tips/quit-smoking/tips-for-quitting/index.html',
        ),
        SupportResource(
          title: 'How to quit smoking',
          source: 'CDC',
          url: 'https://www.cdc.gov/tobacco/about/how-to-quit.html',
        ),
        SupportResource(
          title: 'Vaping and quitting',
          source: 'CDC',
          url: 'https://www.cdc.gov/tobacco/e-cigarettes/quitting.html',
        ),
      ],
    );
  }

  static int? _commonHour(List<UsageEntry> entries) {
    if (entries.isEmpty) return null;
    final counts = <int, int>{};
    for (final entry in entries) {
      counts.update(
        entry.loggedAt.hour,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String _windowLabel(int hour) {
    final end = (hour + 3) % 24;
    String format(int value) {
      if (value == 0) return 'midnight';
      if (value < 12) return '$value AM';
      if (value == 12) return 'noon';
      return '${value - 12} PM';
    }

    return '${format(hour)} to ${format(end)}';
  }
}

extension EntryStats on List<UsageEntry> {
  double get totalQuantity =>
      fold<double>(0, (total, entry) => total + max(0, entry.quantity));
}
