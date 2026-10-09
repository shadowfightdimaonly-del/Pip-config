import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const PipConfigApp());

class PipConfigApp extends StatelessWidget {
  const PipConfigApp({super.key});
  static const background = Color(0xFF09070D);
  static const surface = Color(0xFF15111C);
  static const surface2 = Color(0xFF1D1727);
  static const purple = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PipConfig',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: background,
          colorScheme: ColorScheme.fromSeed(seedColor: purple, brightness: Brightness.dark),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        home: const HomeScreen(),
      );
}

class ConfigEntry {
  const ConfigEntry({required this.name, required this.value});
  final String name;
  final String value;

  String get formatLabel => ConfigInspector.labelFor(value);
  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  factory ConfigEntry.fromJson(Map<String, dynamic> json) => ConfigEntry(
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? (json['name'] as String).trim()
            : 'Импортированный конфиг',
        value: json['value'] as String? ?? '',
      );
}

/// Распознавание формата для интерфейса, не проверка совместимости движка.
class ConfigInspector {
  static String labelFor(String raw) {
    final value = raw.trim();
    final lower = value.toLowerCase();
    if (lower.startsWith('vless://')) return 'VLESS';
    if (lower.startsWith('vmess://')) return 'VMess';
    if (lower.startsWith('trojan://')) return 'Trojan';
    if (lower.startsWith('ss://')) return 'Shadowsocks';
    if (lower.startsWith('socks://') || lower.startsWith('socks5://')) return 'SOCKS proxy';
    if (lower.startsWith('http://') || lower.startsWith('https://')) return 'HTTP(S) link';
    if (lower.contains('[interface]') && lower.contains('[peer]')) return 'WireGuard';
    if (RegExp(r'(^|\n)\s*(client|remote\s+\S+|dev\s+tun)(\s|$)', caseSensitive: false).hasMatch(value)) {
      return 'OpenVPN';
    }
    return 'Неизвестный формат';
  }

  static String? validate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Вставь ссылку или текст конфигурации.';
    final label = labelFor(value);
    if (label == 'Неизвестный формат') {
      return 'Формат не распознан. Конфиг не сохранён.';
    }
    if (label == 'WireGuard') {
      if (!RegExp(r'(?im)^\s*PrivateKey\s*=').hasMatch(value) ||
          !RegExp(r'(?im)^\s*PublicKey\s*=').hasMatch(value)) {
        return 'WireGuard-конфиг неполный: не найдены PrivateKey и/или PublicKey.';
      }
    } else if (label == 'OpenVPN') {
      if (!RegExp(r'(?im)^\s*remote\s+\S+').hasMatch(value)) return 'В OpenVPN-конфиге не найдена строка remote.';
    } else if (label == 'HTTP(S) link') {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.host.isEmpty) return 'Ссылка выглядит неполной: не найден адрес.';
    } else {
      final separator = value.indexOf('://');
      if (separator < 0 || value.substring(separator + 3).trim().isEmpty) {
        return 'После префикса протокола нет данных.';
      }
    }
    return null;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<ConfigEntry> _configs = [];
  int? _selectedIndex;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('configs') ?? [];
    final loaded = <ConfigEntry>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          final entry = ConfigEntry.fromJson(decoded);
          if (entry.value.trim().isNotEmpty) loaded.add(entry);
          continue;
        }
      } catch (_) {
        // Совместимость со старым форматом «название|конфиг».
      }
      final split = item.indexOf('|');
      final entry = split < 0
          ? ConfigEntry(name: 'Импортированный конфиг', value: item)
          : ConfigEntry(name: item.substring(0, split), value: item.substring(split + 1));
      if (entry.value.trim().isNotEmpty) loaded.add(entry);
    }
    if (!mounted) return;
    setState(() {
      _configs..clear()..addAll(loaded);
      _loading = false;
    });
    await _saveConfigs(); // Переводим старые записи на безопасное JSON-хранение.
  }

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('configs', _configs.map((c) => jsonEncode(c.toJson())).toList());
  }

  Future<void> _addConfig() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    String? validationMessage;

    final result = await showDialog<ConfigEntry>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          title: const Text('Добавить конфиг'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название', hintText: 'Например, Netherlands'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  minLines: 4,
                  maxLines: 7,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Ссылка или конфигурация',
                    hintText: 'vless://…, vmess://… или текст конфига',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => refreshDialog(() => validationMessage = null),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final clip = await Clipboard.getData('text/plain');
                      final text = clip?.text?.trim() ?? '';
                      if (text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В буфере обмена нет текста.')));
                        return;
                      }
                      valueController.text = text;
                      refreshDialog(() => validationMessage = null);
                    },
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: const Text('Вставить из буфера'),
                  ),
                ),
                if (validationMessage != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(validationMessage!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  ),
                ],
                const Text(
                  'Это только базовая проверка формата. Она не проверяет сервер и не запускает подключение.',
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                final value = valueController.text.trim();
                final issue = ConfigInspector.validate(value);
                if (issue != null) {
                  refreshDialog(() => validationMessage = issue);
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  ConfigEntry(
                    name: nameController.text.trim().isEmpty ? ConfigInspector.labelFor(value) : nameController.text.trim(),
                    value: value,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    valueController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _configs.add(result);
      _selectedIndex = _configs.length - 1;
    });
    await _saveConfigs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«${result.name}» сохранён локально.')));
  }

  Future<void> _removeConfig(int index) async {
    final removed = _configs[index];
    setState(() {
      _configs.removeAt(index);
      if (_selectedIndex == index) {
        _selectedIndex = null;
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
    await _saveConfigs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«${removed.name}» удалён.')));
  }

  void _showNotReady(String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title пока не реализовано.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: PipConfigApp.background,
          title: const Text('PipConfig', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [IconButton(tooltip: 'Настройки', onPressed: () => _showNotReady('Настройки'), icon: const Icon(Icons.settings_outlined))],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Подключения', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        _configs.isEmpty ? 'Пока здесь пусто' : '${_configs.length} конфиг${_configs.length == 1 ? '' : 'а'}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _configs.isEmpty
                            ? _EmptyState(onAdd: _addConfig, onQr: () => _showNotReady('Импорт QR-кода'))
                            : ListView.separated(
                                itemCount: _configs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final config = _configs[index];
                                  return Dismissible(
                                    key: ValueKey('${config.name}-${config.value.hashCode}'),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) => _removeConfig(index),
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
                                      child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    ),
                                    child: _ConfigCard(
                                      config: config,
                                      selected: index == _selectedIndex,
                                      onTap: () => setState(() => _selectedIndex = index),
                                      onConnect: () => _showNotReady('Подключение'),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _addConfig,
                        icon: const Icon(Icons.add),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Добавить конфиг', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: PipConfigApp.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _showNotReady('Импорт QR-кода'),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Импортировать QR-код')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.config, required this.selected, required this.onTap, required this.onConnect});
  final ConfigEntry config;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? PipConfigApp.surface2 : PipConfigApp.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? PipConfigApp.purple.withValues(alpha: .65) : Colors.white10),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: PipConfigApp.purple.withValues(alpha: .14), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.public, color: PipConfigApp.purple),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(config.formatLabel, style: const TextStyle(color: PipConfigApp.purple, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(config.value.replaceAll('\n', ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(tooltip: 'Подключиться', onPressed: onConnect, icon: const Icon(Icons.play_arrow_rounded), color: PipConfigApp.purple),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onQr});
  final VoidCallback onAdd;
  final VoidCallback onQr;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(color: PipConfigApp.purple.withValues(alpha: .12), shape: BoxShape.circle),
                child: const Icon(Icons.tune_rounded, size: 40, color: PipConfigApp.purple),
              ),
              const SizedBox(height: 18),
              const Text('Добавь первый конфиг', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'PipConfig хранит конфиги на устройстве.\nДвижок подключения подключим отдельным этапом.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.45),
              ),
              const SizedBox(height: 18),
              TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Добавить по ссылке')),
              TextButton.icon(onPressed: onQr, icon: const Icon(Icons.qr_code_2), label: const Text('Добавить через QR')),
            ],
          ),
        ),
      );
}
