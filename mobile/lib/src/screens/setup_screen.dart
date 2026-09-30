import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/section_card.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _job = TextEditingController();
  final _geminiKey = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final k = await context.read<AppState>().getGeminiApiKey();
    if (k != null && mounted) _geminiKey.text = k;
  }

  @override
  void dispose() {
    _job.dispose();
    _geminiKey.dispose();
    super.dispose();
  }

  Future<void> _saveGeminiKey() async {
    final s = context.read<AppState>();
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await s.setGeminiApiKey(_geminiKey.text.trim());
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickResume() async {
    final s = context.read<AppState>();
    final p = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'txt'],
    );
    if (p == null || p.files.single.path == null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await s.saveResumeFromFile(File(p.files.single.path!));
      await s.refreshSetupStatus();
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveJobText() async {
    final s = context.read<AppState>();
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await s.saveJobFromText(_job.text);
      await s.refreshSetupStatus();
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickJobFile() async {
    final s = context.read<AppState>();
    final p = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'txt'],
    );
    if (p == null || p.files.single.path == null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await s.saveJobFromFile(File(p.files.single.path!));
      await s.refreshSetupStatus();
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => context.read<AppState>().logout(),
            child: const Text('Logout'),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_err != null) ...[
              Text(_err!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
            ],
            SectionCard(
              title: 'Progress',
              subtitle:
                  'When Resume and Job description are done, Interview Mode opens. Tap Start Interview there.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProgressRow(ok: s.hasResume, label: 'Resume imported'),
                  _ProgressRow(ok: s.hasJob, label: 'Job description saved'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Gemini API key (optional)',
              subtitle:
                  'Get a free key at Google AI Studio (aistudio.google.com/apikey). Stored encrypted on this device. Without it, the app uses a short offline template.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _geminiKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'AIza…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _busy ? null : _saveGeminiKey,
                    child: const Text('Save API key'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Resume',
              subtitle: s.hasResume ? 'Imported' : 'PDF / DOCX / TXT',
              child: ElevatedButton(
                onPressed: _busy ? null : _pickResume,
                child: const Text('Choose resume file'),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Job description',
              subtitle: s.hasJob ? 'Saved' : 'Paste text or choose a file',
              child: Column(
                children: [
                  TextField(
                    controller: _job,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(hintText: 'Paste job description here…'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy ? null : _saveJobText,
                          child: const Text('Save text'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy ? null : _pickJobFile,
                          child: const Text('Choose file'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20, color: ok ? Colors.greenAccent : Colors.white38),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
