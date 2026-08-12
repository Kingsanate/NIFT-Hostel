import 'dart:async';
import 'package:flutter/material.dart';
import '../../main.dart'; // For AppConfig
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../chat_palette.dart';

class MessageInput extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool enabled;

  const MessageInput({super.key, required this.onSend, this.enabled = true});

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  // Speech to Text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';
  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_sync);
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (error) => _stopListening(),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_isListening && _ctrl.text.trim().isNotEmpty) {
            _send();
          }
          _stopListening();
        }
      },
    );
    if (mounted) setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    _ctrl.clear();
    _lastRecognizedWords = '';
    
    await _speechToText.listen(
      onResult: (result) {
        if (!mounted || !_isListening) return; // Prevent ghost typing
        
        setState(() {
          _lastRecognizedWords = result.recognizedWords;
          _ctrl.text = _lastRecognizedWords;
        });

        // Reset the 3-second auto-send timer
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(seconds: 3), () {
          if (_isListening && _ctrl.text.trim().isNotEmpty) {
            _stopListening();
            _send();
          }
        });
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
    
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    if (_isListening) {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      _silenceTimer?.cancel();
      await _speechToText.stop();
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _ctrl.removeListener(_sync);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _sync() {
    final next = _ctrl.text.trim().isNotEmpty;
    if (next != _hasText) setState(() => _hasText = next);
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _ctrl.clear();
    _lastRecognizedWords = ''; // Prevent late speech results from repopulating the field
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ChatPalette.background.withValues(alpha: 0),
              ChatPalette.background,
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 860),
            child: _InputBox(
              ctrl: _ctrl,
              focus: _focus,
              enabled: widget.enabled,
              hasText: _hasText,
              onSend: _send,
              isListening: _isListening,
              speechEnabled: _speechEnabled,
              onToggleMic: _toggleListening,
            ),
          ),
          SizedBox(height: 8),
          Text('${AppConfig.appName.split(' ').first} Chat can make mistakes. Verify important information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: ChatPalette.dim.withValues(alpha: 0.7),
                  fontSize: 11)),
        ]),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool enabled;
  final bool hasText;
  final VoidCallback onSend;
  final bool isListening;
  final bool speechEnabled;
  final VoidCallback onToggleMic;

  const _InputBox({
    required this.ctrl,
    required this.focus,
    required this.enabled,
    required this.hasText,
    required this.onSend,
    required this.isListening,
    required this.speechEnabled,
    required this.onToggleMic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ChatPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: focus.hasFocus || isListening
              ? ChatPalette.accent.withValues(alpha: 0.5)
              : ChatPalette.border,
        ),
        boxShadow: [
          BoxShadow(
            color: isListening 
                ? ChatPalette.accent.withValues(alpha: 0.15) 
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: TextField(
                  controller: ctrl,
                  focusNode: focus,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 7,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 15,
                    height: 1.45,
                  ),
                  decoration: InputDecoration(
                    hintText: isListening ? 'Listening...' : 'Ask anything about ${AppConfig.appName}…',
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintStyle: TextStyle(
                      color: isListening ? ChatPalette.accent : ChatPalette.dim, 
                      fontSize: 15
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            
            // Microphone Button
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Tooltip(
                message: isListening ? 'Stop listening' : 'Voice input',
                child: InkWell(
                  onTap: (enabled && speechEnabled) ? onToggleMic : null,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isListening ? ChatPalette.accent.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 18,
                      color: isListening 
                          ? ChatPalette.accent 
                          : ((enabled && speechEnabled) ? ChatPalette.muted : ChatPalette.dim),
                    ).animate(target: isListening ? 1 : 0).scaleXY(begin: 1.0, end: 1.15, duration: 150.ms),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: _SendBtn(canSend: hasText && enabled, onSend: onSend),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendBtn extends StatelessWidget {
  final bool canSend;
  final VoidCallback onSend;
  const _SendBtn({required this.canSend, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canSend ? onSend : null,
      child: AnimatedContainer(
        duration: 200.ms,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: canSend ? ChatPalette.accentDeep : ChatPalette.surface,
          shape: BoxShape.circle,
          boxShadow: canSend
              ? [
                  BoxShadow(
                    color: ChatPalette.accentDeep.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          size: 18,
          color: canSend ? Colors.white : ChatPalette.dim,
        ),
      ),
    );
  }
}
