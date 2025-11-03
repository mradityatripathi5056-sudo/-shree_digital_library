import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const ShreeDigitalLibraryApp());
}

class ShreeDigitalLibraryApp extends StatelessWidget {
  const ShreeDigitalLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shree Digital Library',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF0F1722),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Member {
  String name;
  DateTime joined;
  DateTime monthEnds;
  bool feesPaid;

  Member({
    required this.name,
    required this.joined,
    required this.monthEnds,
    required this.feesPaid,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'joined': joined.toIso8601String(),
        'monthEnds': monthEnds.toIso8601String(),
        'feesPaid': feesPaid ? 1 : 0,
      };

  factory Member.fromMap(Map<String, dynamic> m) => Member(
        name: m['name'] as String,
        joined: DateTime.parse(m['joined'] as String),
        monthEnds: DateTime.parse(m['monthEnds'] as String),
        feesPaid: (m['feesPaid'] as int) == 1,
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Member> _members = [];
  final TextEditingController _nameController = TextEditingController();
  late SharedPreferences _prefs;
  final DateFormat _fmt = DateFormat.yMMMd();

  static const String adminKeyCode = 'Shree@Nitesh';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadMembersFromPrefs();
    // You can also store an admin boolean, here we ask for code every session for simplicity
  }

  void _loadMembersFromPrefs() {
    final keys = _prefs.getKeys();
    final memberKeys = keys.where((k) => k.startsWith('member_')).toList();
    _members.clear();
    for (final key in memberKeys) {
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        final map = Map<String, dynamic>.from(
          (Map.castFrom<dynamic, dynamic, String, dynamic>(Map<String, dynamic>.from(
              (Map<String, dynamic>.from(Uri.splitQueryString(raw)))))
          ),
        );
        // fallback: we store using json-like format: name|joined|monthEnds|fees
      } catch (_) {}
    }

    // Simpler storage: use index-based string encoding (name|joinedIso|monthIso|feesInt)
    int i = 0;
    while (true) {
      final k = 'member_$i';
      final val = _prefs.getString(k);
      if (val == null) break;
      final parts = val.split('|');
      if (parts.length >= 4) {
        final name = parts[0];
        final joined = DateTime.tryParse(parts[1]) ?? DateTime.now();
        final monthEnds = DateTime.tryParse(parts[2]) ?? joined.add(const Duration(days: 30));
        final feesPaid = parts[3] == '1';
        _members.add(Member(name: name, joined: joined, monthEnds: monthEnds, feesPaid: feesPaid));
      }
      i++;
    }
    setState(() {});
  }

  Future<void> _saveMembersToPrefs() async {
    // Clear previous keys
    final keys = _prefs.getKeys().where((k) => k.startsWith('member_')).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
    for (var i = 0; i < _members.length; i++) {
      final m = _members[i];
      final encoded = '${m.name}|${m.joined.toIso8601String()}|${m.monthEnds.toIso8601String()}|${m.feesPaid ? '1' : '0'}';
      await _prefs.setString('member_$i', encoded);
    }
  }

  void _addMember(String name) {
    if (name.trim().isEmpty) return;
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month, now.day).add(const Duration(days: 30));
    final newMember = Member(name: name.trim(), joined: now, monthEnds: endOfMonth, feesPaid: false);
    setState(() {
      _members.add(newMember);
    });
    _saveMembersToPrefs();
    _nameController.clear();
  }

  void _toggleFeesPaid(int index) async {
    if (!_isAdmin) {
      _askAdminLogin();
      return;
    }
    setState(() {
      _members[index].feesPaid = !_members[index].feesPaid;
    });
    await _saveMembersToPrefs();
  }

  Future<void> _askAdminLogin() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter admin code to enable fees actions'),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Admin code'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok != true) return;
    if (controller.text == adminKeyCode) {
      setState(() {
        _isAdmin = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin enabled')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid admin code')));
    }
  }

  Widget _buildMemberTile(int idx) {
    final m = _members[idx];
    final overdue = DateTime.now().isAfter(m.monthEnds);
    return Card(
      color: const Color(0xFF111827),
      child: ListTile(
        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Joined: ${_fmt.format(m.joined)}'),
            Text('Month completes: ${_fmt.format(m.monthEnds)}'),
            Text('Fees: ${m.feesPaid ? "Paid" : "Not paid"}${overdue && !m.feesPaid ? " (Overdue)" : ""}'),
          ],
        ),
        trailing: IconButton(
          icon: Icon(m.feesPaid ? Icons.check_circle : Icons.money_off, color: m.feesPaid ? Colors.green : Colors.red),
          onPressed: () => _toggleFeesPaid(idx),
        ),
      ),
    );
  }

  Future<void> _clearAll() async {
    await _prefs.clear();
    setState(() {
      _members.clear();
      _isAdmin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shree Digital Library'),
        actions: [
          IconButton(
            icon: Icon(_isAdmin ? Icons.admin_panel_settings : Icons.lock),
            onPressed: _askAdminLogin,
            tooltip: 'Admin login',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Confirm'),
                  content: const Text('Clear all local data?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                    TextButton(onPressed: () {
                      Navigator.pop(c);
                      _clearAll();
                    }, child: const Text('Clear')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('Made by Aditya & Anshik', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter member name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _addMember,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addMember(_nameController.text),
                  child: const Text('Add'),
                )
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _members.isEmpty
                  ? const Center(child: Text('No members yet. Add one above.'))
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (c, i) => _buildMemberTile(i),
                    ),
            )
          ],
        ),
      ),
    );
  }
}
