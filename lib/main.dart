import 'package:flutter/material.dart';
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
          colorScheme: ColorScheme.fromSeed(
            seedColor: purple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      );
}

class ConfigEntry {
  const ConfigEntry({required this.name, required this.value});
  final String name;
  final String value;
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
    setState(() {
      _configs
        ..clear()
        ..addAll(raw.map((item) {
          final split = item.indexOf('|');
          if (split < 0) return ConfigEntry(name: 'Импортированный конфиг', value: item);
          return ConfigEntry(name: item.substring(0, split), value: item.substring(split + 1));
        }));
      _loading = false;
    });
  }

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'configs',
      _configs.map((c) => '${c.name}|${c.value}').toList(),
    );
  }

  Future<void> _addConfig() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final result = await showDialog<ConfigEntry>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить конфиг'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Название',
                hintText: 'Например, Netherlands',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ссылка или конфигурация',
                hintText: 'Вставь данные подключения',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final value = valueController.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(
                context,
                ConfigEntry(
                  name: nameController.text.trim().isEmpty
                      ? 'Новый конфиг'
                      : nameController.text.trim(),
                  value: value,
                ),
              );
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    nameController.dispose();
    valueController.dispose();

    if (result == null) return;
    setState(() {
      _configs.add(result);
      _selectedIndex = _configs.length - 1;
    });
    await _saveConfigs();
  }

  Future<void> _removeConfig(int index) async {
    setState(() {
      _configs.removeAt(index);
      if (_selectedIndex == index) {
        _selectedIndex = null;
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
    await _saveConfigs();
  }

  void _showNotReady(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title будет подключено на следующем этапе.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PipConfigApp.background,
        title: const Text('PipConfig', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            onPressed: () => _showNotReady('Настройки'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
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
                          ? _EmptyState(onAdd: _addConfig, onQr: () => _showNotReady('Импорт QR'))
                          : ListView.separated(
                              itemCount: _configs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final config = _configs[index];
                                final selected = index == _selectedIndex;
                                return Dismissible(
                                  key: ValueKey('${config.name}-$index'),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) => _removeConfig(index),
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: .18),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  ),
                                  child: _ConfigCard(
                                    config: config,
                                    selected: selected,
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
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        child: Text('Импортировать QR-код'),
                      ),
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
                decoration: BoxDecoration(
                  color: PipConfigApp.purple.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.public, color: PipConfigApp.purple),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      config.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Подключиться',
                onPressed: onConnect,
                icon: const Icon(Icons.play_arrow_rounded),
                color: PipConfigApp.purple,
              ),
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
                decoration: BoxDecoration(
                  color: PipConfigApp.purple.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune_rounded, size: 40, color: PipConfigApp.purple),
              ),
              const SizedBox(height: 18),
              const Text('Добавь первый конфиг', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'PipConfig пока хранит конфигурации локально.\nДвижок подключения подключим следующим этапом.',
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
