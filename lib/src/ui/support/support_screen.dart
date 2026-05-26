import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../widgets/adaptive_scaffold.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Support')),
        SliverToBoxAdapter(
          child: ScreenPadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SlowModeHeader(),
                SizedBox(height: 16),
                BreathingTimer(),
                SizedBox(height: 16),
                UrgeDelayCard(),
                SizedBox(height: 16),
                GroundingPrompts(),
                SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SlowModeHeader extends StatelessWidget {
  const _SlowModeHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.primaryContainer.withValues(alpha: .62),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.self_improvement_rounded,
              size: 32,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 14),
            Text(
              'A quieter screen for intense moments.',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No score, no reset, no pressure. Just enough structure to wait out the wave.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(
                  alpha: .76,
                ),
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
    final phase = _phase;
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Breathing'),
          const SizedBox(height: 16),
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
                  width: 172 * wave,
                  height: 172 * wave,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: .14),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: .36),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(phase, style: theme.textTheme.titleLarge),
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
    final running = _remaining > 0;
    return CalmCard(
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
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _start(120),
                child: const Text('2 min'),
              ),
              FilledButton.tonal(
                onPressed: () => _start(300),
                child: const Text('5 min'),
              ),
              FilledButton.tonal(
                onPressed: () => _start(600),
                child: const Text('10 min'),
              ),
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
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: prompts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final prompt = prompts[index];
            return CalmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(prompt.$1),
                  const Spacer(),
                  Text(
                    prompt.$2,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
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
        ),
      ],
    );
  }
}
