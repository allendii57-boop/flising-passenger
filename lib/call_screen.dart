import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'agora_config.dart';
import 'dart:async';

// ─────────────────────────────────────────────────────────────────────────────
// USAGE (Passenger side — in passenger_main_screen.dart ACCEPTED block):
//
//   IconButton(
//     icon: const Icon(Icons.call, color: Colors.greenAccent),
//     onPressed: () {
//       Navigator.push(context, MaterialPageRoute(
//         builder: (_) => CallScreen(
//           rideId: _currentRideId!,
//           callerType: 'passenger',
//           otherPersonName: _driverName ?? 'Driver',
//           otherPersonPhoto: _driverPhoto,
//         ),
//       ));
//     },
//   ),
// ─────────────────────────────────────────────────────────────────────────────

class CallScreen extends StatefulWidget {
  final String rideId;
  final String callerType; // 'passenger' or 'driver'
  final String otherPersonName;
  final String? otherPersonPhoto;

  const CallScreen({
    super.key,
    required this.rideId,
    required this.callerType,
    required this.otherPersonName,
    this.otherPersonPhoto,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  bool _isConnecting = true;
  bool _otherPersonJoined = false;

  int _callDurationSeconds = 0;
  Timer? _callTimer;
  StreamSubscription<DatabaseEvent>? _callSignalListener;

  final Color flisingOrange = const Color(0xFFE9692C);
  final Color darkSurface = const Color(0xFF1C1C1E);

  late DatabaseReference _callRef;

  @override
  void initState() {
    super.initState();
    _callRef = FirebaseDatabase.instance.ref('rides/${widget.rideId}/call');
    _initCall();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callSignalListener?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  // ── INIT ──────────────────────────────────────────────
  Future<void> _initCall() async {
    // 1. Request mic permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for calls'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    // 2. Signal the call via Firebase
    await _callRef.set({
      'status': 'CALLING',
      'callerType': widget.callerType,
      'channel': widget.rideId,
      'timestamp': ServerValue.timestamp,
    });

    // 3. Listen for other person joining or declining
    _callSignalListener = _callRef.onValue.listen((event) {
      if (!event.snapshot.exists || !mounted) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final status = data['status'] as String? ?? '';

      if (status == 'DECLINED' || status == 'ENDED') {
        _endCall(byRemote: true);
      }
    });

    // 4. Init Agora engine
    await _setupAgora();
  }

  Future<void> _setupAgora() async {
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: agoraAppId));

      // Voice call only
      await _engine!.setChannelProfile(
          ChannelProfileType.channelProfileCommunication);
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableAudio();
      await _engine!.setEnableSpeakerphone(_isSpeakerOn);

      // Event handlers
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (mounted) {
            setState(() {
              _isConnecting = false;
              _isConnected = true;
            });
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (mounted) {
            setState(() => _otherPersonJoined = true);
            _startCallTimer();
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          _endCall(byRemote: true);
        },
        onLeaveChannel: (connection, stats) {
          if (mounted) setState(() => _isConnected = false);
        },
        onError: (err, msg) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Call error: $msg'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ));

      // Join channel — rideId is the channel name
      await _engine!.joinChannel(
        token: '',
        channelId: widget.rideId,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  // ── TIMER ─────────────────────────────────────────────
  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── CONTROLS ──────────────────────────────────────────
  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _engine?.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    _engine?.setEnableSpeakerphone(_isSpeakerOn);
  }

  Future<void> _endCall({bool byRemote = false}) async {
    _callTimer?.cancel();
    _callSignalListener?.cancel();

    // Update Firebase signal
    await _callRef.update({'status': 'ENDED'});

    await _engine?.leaveChannel();
    await _engine?.release();

    if (mounted) Navigator.pop(context);
  }

  // ── BUILD ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: darkSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Flising Call',
                    style: TextStyle(
                      color: flisingOrange,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            const Spacer(),

            // ── Avatar
            CircleAvatar(
              radius: 64,
              backgroundColor: flisingOrange.withOpacity(0.15),
              backgroundImage: widget.otherPersonPhoto != null
                  ? NetworkImage(widget.otherPersonPhoto!)
                  : null,
              child: widget.otherPersonPhoto == null
                  ? Icon(Icons.person, size: 64, color: flisingOrange)
                  : null,
            ),
            const SizedBox(height: 24),

            // ── Name
            Text(
              widget.otherPersonName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // ── Call status
            Text(
              _isConnecting
                  ? 'Calling...'
                  : _otherPersonJoined
                      ? _formatDuration(_callDurationSeconds)
                      : 'Waiting for answer...',
              style: TextStyle(
                color: _otherPersonJoined ? Colors.greenAccent : Colors.white54,
                fontSize: 16,
              ),
            ),

            // ── Connecting indicator
            if (_isConnecting) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: flisingOrange,
                ),
              ),
            ],

            const Spacer(),

            // ── Control buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _controlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    color: _isMuted ? Colors.white : darkSurface,
                    iconColor: _isMuted ? Colors.black : Colors.white,
                    onTap: _toggleMute,
                  ),

                  // End call
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_end,
                          color: Colors.white, size: 32),
                    ),
                  ),

                  // Speaker
                  _controlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                    color: _isSpeakerOn ? flisingOrange : darkSurface,
                    iconColor: Colors.white,
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
