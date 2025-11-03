// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const ShreeDigitalLibraryApp());
}

class ShreeDigitalLibraryApp extends StatelessWidget {
  const ShreeDigitalLibraryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..loadFromPrefs(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Shree Digital Library',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.amber,
          scaffoldBackgroundColor: Colors.black,
          cardColor: const Color(0xFF111111),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

/* ------------------------
   Models & AppState
   ------------------------ */
class Student {
  final String id;
  final String name;
  final String joinDate; // ISO string
  bool feesPaid;
  bool monthComplete;

  Student({
    required this.id,
    required this.name,
    required this.joinDate,
    this.feesPaid = false,
    this.monthComplete = false,
  });

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as String,
        name: j['name'] as String,
        joinDate: j['joinDate'] as String,
        feesPaid: j['feesPaid'] as bool,
        monthComplete: j['monthComplete'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'joinDate': joinDate,
        'feesPaid': feesPaid,
        'monthComplete': monthComplete,
      };
}

class AppState extends ChangeNotifier {
  final List<Student> students = [];
  bool isAdmin = false;

  static const _storageKey = 'shree_students_v1';
  static const adminKey = 'shree_admin';

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        students.clear();
        students.addAll(list.map((e) => Student.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(students.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  void addStudent(String name, DateTime joinDate) {
    final s = Student(
      id: const Uuid().v4(),
      name: name,
      joinDate: joinDate.toIso8601String(),
    );
    students.add(s);
    saveToPrefs();
    notifyListeners();
  }

  void toggleFees(String id) {
    final s = students.firstWhere((e) => e.id == id);
    s.feesPaid = !s.feesPaid;
    saveToPrefs();
    notifyListeners();
  }

  void toggleMonthComplete(String id) {
    final s = students.firstWhere((e) => e.id == id);
    s.monthComplete = !s.monthComplete;
    saveToPrefs();
    notifyListeners();
  }

  void removeStudent(String id) {
    students.removeWhere((e) => e.id == id);
    saveToPrefs();
    notifyListeners();
  }

  // Admin login check
  bool loginAdmin(String password) {
    // password provided by you: Shree@Nitesh
    if (password == 'Shree@Nitesh') {
      isAdmin = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logoutAdmin() {
    isAdmin = false;
    notifyListeners();
  }
}

/* ------------------------
   Screens & Widgets
   ------------------------ */
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  String formatDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat.yMMMEd().format(dt);
  }

  String monthsUntilNow(String iso) {
    final joined = DateTime.parse(iso);
    final now = DateTime.now();
    final months = (now.year - joined.year) * 12 + (now.month - joined.month);
    return months.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shree Digital Library'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(child: Text('Made by Aditya & Anshik', style: TextStyle(fontSize: 13, color: Colors.amber[200]))),
          ),
          IconButton(
            icon: Icon(state.isAdmin ? Icons.admin_panel_settings : Icons.login),
            tooltip: state.isAdmin ? 'Admin Panel' : 'Admin Login',
            onPressed: () {
              if (state.isAdmin) {
                // show admin menu
                _showAdminPanel(context);
              } else {
                _showAdminLogin(context);
              }
            },
          ),
        ],
      ),
      body: state.students.isEmpty
          ? const Center(child: Text('No students found.\n(Admins can add students.)', textAlign: TextAlign.center))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: state.students.length,
              itemBuilder: (context, i) {
                final s = state.students[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    title: Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text('Joined: ${formatDate(s.joinDate)}'),
                        const SizedBox(height: 3),
                        Text('Months since join: ${monthsUntilNow(s.joinDate)}'),
                        const SizedBox(height: 3),
                        Text('Fees paid: ${s.feesPaid ? "Yes" : "No"}'),
                        const SizedBox(height: 3),
                        Text('Month complete: ${s.monthComplete ? "Yes" : "No"}'),
                      ],
                    ),
                    trailing: state.isAdmin
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'fees') state.toggleFees(s.id);
                              if (v == 'month') state.toggleMonthComplete(s.id);
                              if (v == 'remove') state.removeStudent(s.id);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'fees', child: Text(s.feesPaid ? 'Mark fees unpaid' : 'Mark fees paid')),
                              PopupMenuItem(value: 'month', child: Text(s.monthComplete ? 'Mark month not complete' : 'Mark month complete')),
                              const PopupMenuItem(value: 'remove', child: Text('Remove')),
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: state.isAdmin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add),
              label: const Text('Add Student'),
              onPressed: () => _showAddStudent(context),
            )
          : null,
    );
  }

  void _showAdminPanel(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Container(
          color: Colors.black,
          padding: const EdgeInsets.all(16),
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin Panel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddStudent(context);
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add Student'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  state.logoutAdmin();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout Admin'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAdminLogin(BuildContext context) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Admin Login'),
          content: TextField(
            controller: passCtrl,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Enter admin code'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final ok = Provider.of<AppState>(context, listen: false).loginAdmin(passCtrl.text.trim());
                Navigator.pop(context);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong code')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin logged in')));
                }
              },
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  }

  void _showAddStudent(BuildContext context) {
    final nameCtrl = TextEditingController();
    DateTime joinDate = DateTime.now();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Add Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Join: ${DateFormat.yMd().format(joinDate)}')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: joinDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                      if (picked != null) {
                        joinDate = picked;
                        Navigator.pop(context);
                        _showAddStudent(context); // reopen to refresh date
                      }
                    },
                    child: const Text('Pick date'),
                  )
                ],
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Provider.of<AppState>(context, listen: false).addStudent(name, joinDate);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
