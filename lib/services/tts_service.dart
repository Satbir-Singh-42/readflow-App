import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused }

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  TtsState _state = TtsState.stopped;
  List<dynamic> _voices = [];
  int _currentVoiceIndex = 0;
  double _speed = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;
  String _currentWord = '';
  Function(int start, int end)? onWordHighlight;
  Function()? onComplete;

  // Sleep Timer
  Timer? _sleepTimer;
  int _sleepMinutesRemaining = 0;

  // Speed Reading (RSVP)
  bool _isSpeedReadingMode = false;
  int _wordsPerMinute = 300;
  List<String> _speedReadWords = [];
  int _currentWordIndex = 0;
  Timer? _speedReadTimer;
  String _currentSpeedWord = '';

  TtsState get state => _state;
  List<dynamic> get voices => _voices;
  int get currentVoiceIndex => _currentVoiceIndex;
  double get speed => _speed;
  double get pitch => _pitch;
  double get volume => _volume;
  String get currentWord => _currentWord;
  bool get isPlaying => _state == TtsState.playing;
  bool get isPaused => _state == TtsState.paused;

  // Sleep Timer getters
  int get sleepMinutesRemaining => _sleepMinutesRemaining;
  bool get hasSleepTimer => _sleepMinutesRemaining > 0;

  // Speed Reading getters
  bool get isSpeedReadingMode => _isSpeedReadingMode;
  int get wordsPerMinute => _wordsPerMinute;
  String get currentSpeedWord => _currentSpeedWord;
  int get speedReadProgress => _speedReadWords.isEmpty
      ? 0
      : ((_currentWordIndex / _speedReadWords.length) * 100).round();

  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speed);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(_volume);

    _voices = await _tts.getVoices ?? [];

    _tts.setStartHandler(() {
      _state = TtsState.playing;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      _state = TtsState.stopped;
      onComplete?.call();
      notifyListeners();
    });

    _tts.setPauseHandler(() {
      _state = TtsState.paused;
      notifyListeners();
    });

    _tts.setCancelHandler(() {
      _state = TtsState.stopped;
      notifyListeners();
    });

    _tts.setProgressHandler((text, start, end, word) {
      _currentWord = word;
      onWordHighlight?.call(start, end);
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      _state = TtsState.stopped;
      notifyListeners();
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (_state == TtsState.playing) await stop();
    await _tts.speak(text);
  }

  Future<void> pause() async {
    if (_state == TtsState.playing) {
      await _tts.pause();
    }
  }

  Future<void> resume() async {
    if (_state == TtsState.paused) {
      await _tts.speak(_currentWord);
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _state = TtsState.stopped;
    _currentWord = '';
    cancelSleepTimer();
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.25, 3.0);
    await _tts.setSpeechRate(_speed);
    notifyListeners();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
    notifyListeners();
  }

  Future<void> setVoice(int index) async {
    if (index < 0 || index >= _voices.length) return;
    _currentVoiceIndex = index;
    final voice = _voices[index];
    await _tts.setVoice({'name': voice['name'], 'locale': voice['locale']});
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    await _tts.setLanguage(lang);
    notifyListeners();
  }

  // ============ SLEEP TIMER ============

  /// Start sleep timer - auto-stop TTS after [minutes]
  void startSleepTimer(int minutes) {
    cancelSleepTimer();
    _sleepMinutesRemaining = minutes;
    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _sleepMinutesRemaining--;
      notifyListeners();

      if (_sleepMinutesRemaining <= 0) {
        stop();
        stopSpeedReading();
        cancelSleepTimer();
      }
    });
  }

  /// Cancel active sleep timer
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepMinutesRemaining = 0;
    notifyListeners();
  }

  // ============ SPEED READING (RSVP) ============

  /// Set words per minute for speed reading
  void setWordsPerMinute(int wpm) {
    _wordsPerMinute = wpm.clamp(100, 1000);
    notifyListeners();
  }

  /// Start speed reading mode with given text
  void startSpeedReading(String text) {
    if (text.isEmpty) return;

    _isSpeedReadingMode = true;
    _speedReadWords = text.split(RegExp(r'\s+'));
    _currentWordIndex = 0;
    _currentSpeedWord = _speedReadWords.isNotEmpty ? _speedReadWords[0] : '';
    notifyListeners();

    final interval = Duration(milliseconds: (60000 / _wordsPerMinute).round());

    _speedReadTimer = Timer.periodic(interval, (timer) {
      if (_currentWordIndex < _speedReadWords.length - 1) {
        _currentWordIndex++;
        _currentSpeedWord = _speedReadWords[_currentWordIndex];
        notifyListeners();
      } else {
        stopSpeedReading();
        onComplete?.call();
      }
    });
  }

  /// Pause speed reading
  void pauseSpeedReading() {
    _speedReadTimer?.cancel();
    _speedReadTimer = null;
    notifyListeners();
  }

  /// Resume speed reading from current position
  void resumeSpeedReading() {
    if (!_isSpeedReadingMode || _speedReadWords.isEmpty) return;

    final interval = Duration(milliseconds: (60000 / _wordsPerMinute).round());

    _speedReadTimer = Timer.periodic(interval, (timer) {
      if (_currentWordIndex < _speedReadWords.length - 1) {
        _currentWordIndex++;
        _currentSpeedWord = _speedReadWords[_currentWordIndex];
        notifyListeners();
      } else {
        stopSpeedReading();
        onComplete?.call();
      }
    });
  }

  /// Stop speed reading mode
  void stopSpeedReading() {
    _speedReadTimer?.cancel();
    _speedReadTimer = null;
    _isSpeedReadingMode = false;
    _speedReadWords = [];
    _currentWordIndex = 0;
    _currentSpeedWord = '';
    notifyListeners();
  }

  /// Check if speed reading is actively running
  bool get isSpeedReadingActive => _speedReadTimer != null;

  List<Map<String, dynamic>> get availableLanguages => [
        {'code': 'en-US', 'label': 'English (US)'},
        {'code': 'en-GB', 'label': 'English (UK)'},
        {'code': 'hi-IN', 'label': 'Hindi'},
        {'code': 'es-ES', 'label': 'Spanish'},
        {'code': 'fr-FR', 'label': 'French'},
        {'code': 'de-DE', 'label': 'German'},
        {'code': 'zh-CN', 'label': 'Chinese'},
        {'code': 'ja-JP', 'label': 'Japanese'},
        {'code': 'ar-SA', 'label': 'Arabic'},
        {'code': 'pt-BR', 'label': 'Portuguese'},
      ];

  /// Available sleep timer durations in minutes
  List<int> get sleepTimerOptions => [5, 10, 15, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _tts.stop();
    _sleepTimer?.cancel();
    _speedReadTimer?.cancel();
    super.dispose();
  }
}
