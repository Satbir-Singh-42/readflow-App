import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Speed Reading (RSVP) Mode Widget - Displays one word at a time
class SpeedReadingWidget extends StatelessWidget {
  final TtsService ttsService;
  final VoidCallback onClose;

  const SpeedReadingWidget({
    super.key,
    required this.ttsService,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bgDark,
      child: SafeArea(
        child: Column(
          children: [
            // Header with controls
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textPrimary),
                  ),
                  const Spacer(),
                  // WPM indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${ttsService.wordsPerMinute} WPM',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Progress
                  Text(
                    '${ttsService.speedReadProgress}%',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

            // Main word display
            Expanded(
              child: Center(
                child: ListenableBuilder(
                  listenable: ttsService,
                  builder: (context, _) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final fontSize = screenWidth < 360
                        ? 36.0
                        : (screenWidth < 400 ? 42.0 : 48.0);
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 50),
                      child: Text(
                        ttsService.currentSpeedWord,
                        key: ValueKey(ttsService.currentSpeedWord),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Progress bar
            ListenableBuilder(
              listenable: ttsService,
              builder: (context, _) {
                return LinearProgressIndicator(
                  value: ttsService.speedReadProgress / 100,
                  backgroundColor: AppTheme.bgHighlight,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                );
              },
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Slower
                  IconButton(
                    onPressed: () {
                      ttsService
                          .setWordsPerMinute(ttsService.wordsPerMinute - 50);
                    },
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppTheme.textSecondary, size: 32),
                  ),
                  const SizedBox(width: 16),

                  // Play/Pause
                  ListenableBuilder(
                    listenable: ttsService,
                    builder: (context, _) {
                      return IconButton(
                        onPressed: () {
                          if (ttsService.isSpeedReadingActive) {
                            ttsService.pauseSpeedReading();
                          } else {
                            ttsService.resumeSpeedReading();
                          }
                        },
                        icon: Icon(
                          ttsService.isSpeedReadingActive
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: AppTheme.primary,
                          size: 64,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),

                  // Faster
                  IconButton(
                    onPressed: () {
                      ttsService
                          .setWordsPerMinute(ttsService.wordsPerMinute + 50);
                    },
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppTheme.textSecondary, size: 32),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sleep Timer Selection Dialog
class SleepTimerDialog extends StatelessWidget {
  final TtsService ttsService;

  const SleepTimerDialog({super.key, required this.ttsService});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.bedtime_rounded, color: AppTheme.primary),
          SizedBox(width: 8),
          Text('Sleep Timer', style: TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ttsService.hasSleepTimer)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${ttsService.sleepMinutesRemaining} min remaining',
                    style: const TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ttsService.cancelSleepTimer();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel',
                        style: TextStyle(color: AppTheme.error)),
                  ),
                ],
              ),
            ),
          ...ttsService.sleepTimerOptions.map((minutes) => ListTile(
                leading: const Icon(Icons.access_time,
                    color: AppTheme.textSecondary),
                title: Text(
                  minutes < 60
                      ? '$minutes minutes'
                      : '${minutes ~/ 60} hour${minutes >= 120 ? 's' : ''}',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  ttsService.startSleepTimer(minutes);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sleep timer set for $minutes minutes'),
                      backgroundColor: AppTheme.primary,
                    ),
                  );
                },
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }
}

/// Floating Sleep Timer Indicator
class SleepTimerIndicator extends StatelessWidget {
  final TtsService ttsService;
  final VoidCallback onTap;

  const SleepTimerIndicator({
    super.key,
    required this.ttsService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ttsService,
      builder: (context, _) {
        if (!ttsService.hasSleepTimer) return const SizedBox.shrink();

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bedtime_rounded,
                    color: AppTheme.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${ttsService.sleepMinutesRemaining}m',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
