import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/vitals_model.dart';
import 'nearby_hospitals_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PatientVitalsScreen extends StatefulWidget {
  final LatLng patientLocation;

  const PatientVitalsScreen({super.key, required this.patientLocation});

  @override
  State<PatientVitalsScreen> createState() => _PatientVitalsScreenState();
}

class _PatientVitalsScreenState extends State<PatientVitalsScreen> {
  // ── Vitals controllers ──
  final _hrController      = TextEditingController();
  final _bpController      = TextEditingController();
  final _spo2Controller    = TextEditingController();
  final _notesController   = TextEditingController();
  String _consciousness    = 'Alert';

  // ── Recording ──
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _recordingDone = false;
  String? _audioPath;
  int _recordingSeconds = 0;
  Timer? _recordTimer;

  final List<String> _consciousnessOptions = ['Alert', 'Verbal', 'Pain', 'Unresponsive'];

  @override
  void dispose() {
    _hrController.dispose();
    _bpController.dispose();
    _spo2Controller.dispose();
    _notesController.dispose();
    _recorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  // ── Start recording ──────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _showSnack('Microphone permission denied', Colors.red);
      return;
    }

    final dir = await getTemporaryDirectory();
    _audioPath = '${dir.path}/patient_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: _audioPath!,
    );

    _recordingSeconds = 0;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
      if (_recordingSeconds >= 120) _stopRecording(); // max 2 min
    });

    setState(() {
      _isRecording = true;
      _recordingDone = false;
    });
  }

  // ── Stop recording ───────────────────────────────────────────────────────
  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordingDone = true;
    });
  }

  String get _recordingLabel {
    final m = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Proceed to hospital list ─────────────────────────────────────────────
  void _proceed() {
    final vitals = VitalsModel(
      heartRate: _hrController.text.trim().isEmpty ? null : int.tryParse(_hrController.text.trim()),
      bloodPressure: _bpController.text.trim().isEmpty ? null : _bpController.text.trim(),
      spo2: _spo2Controller.text.trim().isEmpty ? null : int.tryParse(_spo2Controller.text.trim()),
      consciousness: _consciousness,
      conditionNotes: _notesController.text.trim(),
      audioFilePath: _audioPath,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NearbyHospitalsScreen(
          initialLocation: widget.patientLocation,
          vitals: vitals,
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ── Color for AVPU ──
  Color _avpuColor(String val) {
    switch (val) {
      case 'Alert': return Colors.green;
      case 'Verbal': return Colors.orange;
      case 'Pain': return Colors.deepOrange;
      case 'Unresponsive': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Vitals & Voice Note'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              _sectionCard(
                icon: Icons.monitor_heart,
                title: 'Vital Signs',
                color: const Color(0xFFE53935),
                children: [
                  _vitalRow(
                    icon: Icons.favorite,
                    label: 'Heart Rate (bpm)',
                    controller: _hrController,
                    hint: 'e.g. 72',
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _vitalRow(
                    icon: Icons.compress,
                    label: 'Blood Pressure (mmHg)',
                    controller: _bpController,
                    hint: 'e.g. 120/80',
                    keyboard: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  _vitalRow(
                    icon: Icons.water_drop,
                    label: 'SpO₂ (%)',
                    controller: _spo2Controller,
                    hint: 'e.g. 97',
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  // Consciousness selector
                  const Text(
                    'Consciousness (AVPU)',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _consciousnessOptions.map((opt) {
                      final selected = _consciousness == opt;
                      return ChoiceChip(
                        label: Text(opt),
                        selected: selected,
                        selectedColor: _avpuColor(opt),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() => _consciousness = opt),
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Condition Notes ──
              _sectionCard(
                icon: Icons.notes,
                title: 'Condition Notes',
                color: const Color(0xFF1976D2),
                children: [
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Chest pain, shortness of breath, suspected MI...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Voice Note ──
              _sectionCard(
                icon: Icons.mic,
                title: 'Voice Note',
                color: const Color(0xFF388E3C),
                children: [
                  // Status pill
                  if (_isRecording)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record,
                              color: Colors.red, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Recording  $_recordingLabel',
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  if (_recordingDone && _audioPath != null)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xFF388E3C), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Recorded (${_recordingSeconds}s) — ready to send',
                            style: const TextStyle(
                                color: Color(0xFF388E3C),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                          label: Text(_isRecording
                              ? 'Stop Recording'
                              : _recordingDone
                                  ? 'Re-record'
                                  : 'Start Voice Note'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording
                                ? Colors.red
                                : const Color(0xFF388E3C),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              _isRecording ? _stopRecording : _startRecording,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Record up to 2 minutes. Hospital will hear this note.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Submit button ──
              ElevatedButton.icon(
                icon: const Icon(Icons.local_hospital, color: Colors.white),
                label: const Text(
                  'Submit & Find Hospital →',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _proceed,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NearbyHospitalsScreen(
                      initialLocation: widget.patientLocation,
                    ),
                  ),
                ),
                child: const Text('Skip — Proceed without vitals',
                    style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 15),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboard,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFE53935)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboard,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
