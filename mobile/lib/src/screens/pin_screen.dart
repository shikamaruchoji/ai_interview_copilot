import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/section_card.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pin = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      await context.read<AppState>().loginWithPin(_pin.text.trim());
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SectionCard(
              title: '4-digit PIN',
              subtitle:
                  'Creates or unlocks a profile on this phone only. Resume, job description, and voice sample stay on-device.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '••••',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_err != null) ...[
                    Text(_err!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
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
