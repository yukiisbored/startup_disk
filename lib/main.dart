import 'dart:async';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:rinf/rinf.dart';
import 'package:system_theme/system_theme.dart';

import 'src/bindings/bindings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeRust(assignRustSignal);

  SystemTheme.fallbackColor = Colors.blue;
  await SystemTheme.accentColor.load();

  runApp(const StartupDiskApp());

  doWhenWindowReady(() {
    const initialSize = Size(800, 450);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

void reboot(int id) {
  Reboot(value: id).sendSignalToRust();
}

void setDefault(int id) {
  SetDefault(value: id).sendSignalToRust();
}

class StartupDiskApp extends StatelessWidget {
  const StartupDiskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Startup Disk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: SystemTheme.accentColor.accent),
        useMaterial3: true,
      ),
      home: WindowBorder(
        color: Theme.of(context).colorScheme.primary,
        child: StartupDiskPane(),
      ),
    );
  }
}

class StartupDiskPane extends StatefulWidget {
  const StartupDiskPane({super.key});

  @override
  State<StartupDiskPane> createState() => _StartupDiskPaneState();
}

class _StartupDiskPaneState extends State<StartupDiskPane> {
  StreamSubscription<RustSignalPack<GetBootEntriesResult>>? _subscription;
  List<BootEntry>? _entries;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _subscription = GetBootEntriesResult.rustSignalStream.listen((pack) {
      if (!mounted) return;
      setState(() {
        _entries = pack.message.entries;
        if (_selectedId == null || !_entries!.any((e) => e.id == _selectedId)) {
          final current = _entries!.firstWhere(
            (e) => e.selected,
            orElse: () => _entries!.isNotEmpty
                ? _entries!.first
                : const BootEntry(
                    id: 0,
                    description: '',
                    current: false,
                    selected: false,
                    next: false,
                  ),
          );
          _selectedId = _entries!.isEmpty ? null : current.id;
        }
      });
    });
    const GetBootEntries().sendSignalToRust();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _refresh() => const GetBootEntries().sendSignalToRust();

  BootEntry? get _selectedEntry {
    if (_entries == null || _selectedId == null) return null;
    for (final entry in _entries!) {
      if (entry.id == _selectedId) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            const _WindowTitleBar(),
            _Header(onRefresh: _refresh),
            const Divider(height: 1),
            Expanded(
              child: entries == null
                  ? const Center(child: CircularProgressIndicator())
                  : entries.isEmpty
                  ? const _EmptyState()
                  : _EntriesView(
                      entries: entries,
                      selectedId: _selectedId,
                      onSelect: (id) => setState(() => _selectedId = id),
                    ),
            ),
            if (entries != null && entries.isNotEmpty)
              _ActionBar(selected: _selectedEntry),
          ],
        ),
      ),
    );
  }
}

class _WindowTitleBar extends StatelessWidget {
  const _WindowTitleBar();

  @override
  Widget build(BuildContext context) {
    return WindowTitleBarBox(
      child: ColoredBox(
        color: const Color(0xFFE5E5EA),
        child: Row(
          children: [
            Expanded(child: MoveWindow()),
            const _WindowButtons(),
          ],
        ),
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: Colors.black87,
      mouseOver: Colors.black12,
      mouseDown: Colors.black26,
      iconMouseOver: Colors.black87,
      iconMouseDown: Colors.black87,
    );
    final closeColors = WindowButtonColors(
      iconNormal: Colors.black87,
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );
    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeColors),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  'Startup Disk',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select the system you want to use to start up your computer',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _EntriesView extends StatelessWidget {
  const _EntriesView({
    required this.entries,
    required this.selectedId,
    required this.onSelect,
  });

  final List<BootEntry> entries;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final entry in entries)
            _DiskTile(
              entry: entry,
              isSelected: entry.id == selectedId,
              onTap: () => onSelect(entry.id),
            ),
        ],
      ),
    );
  }
}

class _DiskTile extends StatelessWidget {
  const _DiskTile({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  final BootEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 160,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Stack(
                  clipBehavior: .none,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? primary : Colors.black12,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        entry.current ? Icons.computer : Icons.storage,
                        size: 64,
                        color: Colors.black87,
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: primary,
                            shape: .circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  entry.description.isEmpty
                      ? 'Boot${entry.id.toRadixString(16).toUpperCase().padLeft(4, '0')}'
                      : entry.description,
                  maxLines: 2,
                  overflow: .ellipsis,
                  textAlign: .center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                _StatusChips(entry: entry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.entry});

  final BootEntry entry;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (entry.current)
        const _Chip(label: 'Current', color: Color(0xFF34C759)),
      if (entry.selected)
        const _Chip(label: 'Default', color: Color(0xFF007AFF)),
      if (entry.next) const _Chip(label: 'Next', color: Color(0xFFFF9500)),
    ];
    if (chips.isEmpty) return const SizedBox(height: 22);
    return Wrap(alignment: .center, spacing: 4, runSpacing: 4, children: chips);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.selected});

  final BootEntry? selected;

  @override
  Widget build(BuildContext context) {
    final entry = selected;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black12)),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry == null
                  ? 'No startup disk selected.'
                  : 'You have selected "${entry.description}" as your startup disk.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: entry == null ? null : () => setDefault(entry.id),
            child: const Text('Set as Default'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: entry == null ? null : () => reboot(entry.id),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Restart with This Disk…'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: Colors.black38,
          ),
          const SizedBox(height: 12),
          Text(
            'No boot entries found.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'EFI variables may be unavailable on this system.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
