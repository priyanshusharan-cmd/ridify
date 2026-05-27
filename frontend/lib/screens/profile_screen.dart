import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';
import '../core/constants.dart';
import '../core/socket_service.dart';
import '../core/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userAge;
  final String userEmail;

  const ProfileScreen({
    super.key,
    this.userName = "Unknown",
    this.userAge = "18",
    this.userEmail = "email@example.com",
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String fullName;
  late String age;
  late String email;

  @override
  void initState() {
    super.initState();
    fullName = widget.userName;
    age = widget.userAge;
    email = widget.userEmail;
  }

  // ── LOGOUT ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    // Clear JWT tokens from secure storage
    await AuthService.logout(); // calls TokenService.clearTokens()
    
    // Clear SharedPreferences session data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Dispose socket connection
    SocketService().dispose();
    
    HomeScreen.resetStartupAnimation();
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ── DELETE OWN ACCOUNT ────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    try {
      await AuthService.deleteAccount(email);
      await AuthService.logout();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      SocketService().dispose();
      HomeScreen.resetStartupAnimation();
      
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account successfully deleted"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // ── ADMIN: WIPE ALL USERS ─────────────────────────────────────────────────
  Future<void> _adminWipeAllUsers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '⚠️ Delete ALL Users',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: const Text(
          'This permanently deletes every user account and all associated ride data.\n\nYou will be logged out immediately after.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Delete All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await AuthService.adminDeleteAllUsers(email);
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Auto-logout
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Delete Account",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to delete your account? It deletes all your data and history with us.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    String title,
    String currentValue,
    Function(String) onSave,
  ) {
    TextEditingController controller = TextEditingController(
      text: currentValue,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $title"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "Enter $title"),
          keyboardType: title == "Age"
              ? TextInputType.number
              : TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
            ),
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String getInitials(String name) {
    List<String> parts = name.trim().split(" ");
    if (parts.isEmpty) return "?";
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = kAdminEmails.contains(email.toLowerCase());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── FIXED HEADER — does NOT scroll ──────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "My Profile",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  PopupMenuButton<ThemeMode>(
                    icon: Icon(
                      Icons.dark_mode_outlined,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onSelected: (ThemeMode mode) {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .setThemeMode(mode);
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<ThemeMode>>[
                      const PopupMenuItem<ThemeMode>(
                        value: ThemeMode.light,
                        child: Text('Light Mode'),
                      ),
                      const PopupMenuItem<ThemeMode>(
                        value: ThemeMode.dark,
                        child: Text('Dark Mode'),
                      ),
                      const PopupMenuItem<ThemeMode>(
                        value: ThemeMode.system,
                        child: Text('Use Device Settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE CONTENT ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 12,
                  bottom: 100,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      child: Text(
                        getInitials(fullName),
                        style: TextStyle(
                          color: isDark ? Colors.black : Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      fullName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 40),

                    _editableTile(
                      Icons.person_outline,
                      "Name",
                      fullName,
                      (val) => setState(() => fullName = val),
                    ),
                    _editableTile(
                      Icons.cake_outlined,
                      "Age",
                      age,
                      (val) => setState(() => age = val),
                    ),
                    _editableTile(
                      Icons.email_outlined,
                      "Email",
                      email,
                      (val) => setState(() => email = val),
                    ),

                    const SizedBox(height: 40),

                    // ── LOGOUT ──────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          "Logout",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // ── DELETE OWN ACCOUNT ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: _showDeleteConfirmationDialog,
                        icon: const Icon(Icons.delete_forever, color: Colors.white),
                        label: const Text(
                          "Delete Account",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // ── ADMIN-ONLY: WIPE ALL USERS ────────────────────────
                    if (isAdmin) ...[
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.deepOrange),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: _adminWipeAllUsers,
                          icon: const Icon(Icons.delete_sweep,
                              color: Colors.deepOrange),
                          label: const Text(
                            "Admin: Wipe All Users",
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editableTile(
    IconData icon,
    String title,
    String value,
    Function(String) onSave,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white70 : Colors.black54, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
            onPressed: () => _showEditDialog(title, value, onSave),
          ),
        ],
      ),
    );
  }
}
