import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../widgets/adaptive_scaffold.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(pinned: true, title: Text('Support')),
          SliverToBoxAdapter(
            child: ScreenPadding(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SlowModeHeader(),
                  SizedBox(height: 14),
                  BreathingTimer(),
                  SizedBox(height: 14),
                  UrgeDelayCard(),
                  SizedBox(height: 14),
                  GroundingPrompts(),
                  SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlowModeHeader extends StatelessWidget {
  const _SlowModeHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final accent = isDark ? scheme.tertiary : const Color(0xFF9E4A24);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  scheme.surfaceContainerHigh,
                  Color.alphaBlend(
                    scheme.tertiary.withValues(alpha: .16),
                    scheme.surfaceContainer,
                  ),
                ]
              : const [Color(0xFFF4DED2), Color(0xFFEED1C0)],
        ),
        border: Border.all(
          color: isDark
              ? scheme.tertiary.withValues(alpha: .22)
              : const Color(0xFFDAB9A8),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.self_improvement_rounded,
                  size: 26,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'A quieter screen for intense moments',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No score, no reset, no pressure. Just enough structure to wait out the wave.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BreathingTimer extends StatefulWidget {
  const BreathingTimer({super.key});

  @override
  State<BreathingTimer> createState() => _BreathingTimerState();
}

class _BreathingTimerState extends State<BreathingTimer> {
  bool _running = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phase = _phase;
    return CalmCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Breathing',
            trailing: Text(
              _seconds == 0 ? '12 sec cycle' : _formatElapsed(_seconds),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _running ? 1 : 0),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                final wave = .78 + sin((_seconds + value) / 4 * pi) * .12;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOut,
                  width: 164 * wave,
                  height: 164 * wave,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: .12),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: .36),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .08),
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      phase,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _running ? _stop : _start,
                  icon: Icon(
                    _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(_running ? 'Pause' : 'Begin'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Reset',
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _phase {
    final cycle = _seconds % 12;
    if (!_running && _seconds == 0) return 'Ready';
    if (cycle < 4) return 'Inhale';
    if (cycle < 6) return 'Hold';
    if (cycle < 10) return 'Exhale';
    return 'Rest';
  }

  String _formatElapsed(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  void _start() {
    setState(() => _running = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _seconds = 0;
    });
  }
}

class UrgeDelayCard extends StatefulWidget {
  const UrgeDelayCard({super.key});

  @override
  State<UrgeDelayCard> createState() => _UrgeDelayCardState();
}

class _UrgeDelayCardState extends State<UrgeDelayCard> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final running = _remaining > 0;
    return CalmCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Delay timer'),
          const SizedBox(height: 8),
          Text(
            running
                ? _formatRemaining(_remaining)
                : 'Choose a short pause and check again after it ends.',
            style: running
                ? theme.textTheme.headlineLarge
                : theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DelayButton(label: '2 min', onPressed: () => _start(120)),
              _DelayButton(label: '5 min', onPressed: () => _start(300)),
              _DelayButton(label: '10 min', onPressed: () => _start(600)),
              if (running)
                OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _start(int seconds) {
    _timer?.cancel();
    setState(() => _remaining = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _clear();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _clear() {
    _timer?.cancel();
    if (mounted) setState(() => _remaining = 0);
  }

  String _formatRemaining(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }
}

class _DelayButton extends StatelessWidget {
  const _DelayButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primaryContainer.withValues(alpha: .72),
        foregroundColor: scheme.onPrimaryContainer,
        minimumSize: const Size(92, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class GroundingPrompts extends StatelessWidget {
  const GroundingPrompts({super.key});

  @override
  Widget build(BuildContext context) {
    final prompts = [
      (Icons.water_drop_outlined, 'Drink water', 'A small physical reset.'),
      (Icons.directions_walk_rounded, 'Step outside', 'Two minutes is enough.'),
      (
        Icons.pan_tool_alt_outlined,
        'Name five things',
        'Use the room around you.',
      ),
      (
        Icons.bedtime_outlined,
        'Lower stimulation',
        'Dim the screen and slow input.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Grounding'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 620 ? 4 : 2;
            return GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prompts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 154,
              ),
              itemBuilder: (context, index) {
                final prompt = prompts[index];
                return CalmCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        prompt.$1,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const Spacer(),
                      Text(
                        prompt.$2,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prompt.$3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
