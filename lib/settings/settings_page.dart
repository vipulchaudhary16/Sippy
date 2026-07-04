import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'app_settings.dart';

class SettingsPage extends StatefulWidget {
  final AppSettings initial;
  final Future<void> Function(AppSettings) onSave;
  const SettingsPage({super.key, required this.initial, required this.onSave});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _interval =
      TextEditingController(text: widget.initial.intervalMinutes.toString());
  late final _snooze =
      TextEditingController(text: widget.initial.snoozeMinutes.toString());
  late final _goal =
      TextEditingController(text: widget.initial.dailyGoal.toString());
  late double _volume = widget.initial.volume;
  late bool _muted = widget.initial.muted;
  late final List<String> _music = List.of(widget.initial.musicPaths);

  int _parse(TextEditingController c, int fallback) =>
      int.tryParse(c.text) ?? fallback;

  Future<void> _addMusic() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.audio, allowMultiple: true);
    if (result != null) {
      setState(() =>
          _music.addAll(result.files.map((f) => f.path).whereType<String>()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sippy — Settings')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        TextField(
          key: const Key('interval-field'),
          controller: _interval,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Interval (minutes)'),
        ),
        TextField(
          key: const Key('snooze-field'),
          controller: _snooze,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Snooze (minutes)'),
        ),
        TextField(
          key: const Key('goal-field'),
          controller: _goal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Daily goal (glasses)'),
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Volume'),
          Expanded(
            child: Slider(
              value: _volume,
              onChanged: (v) => setState(() => _volume = v),
            ),
          ),
        ]),
        SwitchListTile(
          title: const Text('Mute'),
          value: _muted,
          onChanged: (v) => setState(() => _muted = v),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Music'),
          const Spacer(),
          TextButton(onPressed: _addMusic, child: const Text('Add files')),
        ]),
        for (final path in _music)
          ListTile(
            dense: true,
            title: Text(path, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => setState(() => _music.remove(path)),
            ),
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('save-settings'),
          onPressed: () => widget.onSave(AppSettings(
            intervalMinutes: _parse(_interval, widget.initial.intervalMinutes),
            snoozeMinutes: _parse(_snooze, widget.initial.snoozeMinutes),
            dailyGoal: _parse(_goal, widget.initial.dailyGoal),
            volume: _volume,
            muted: _muted,
            musicPaths: _music,
          )),
          child: const Text('Save'),
        ),
      ]),
    );
  }
}
