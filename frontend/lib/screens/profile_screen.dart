import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_panel_screen.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';

import '../core/socket_service.dart';
import '../core/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userAge;
  final String userEmail;
  final bool isAdmin;
  final String verificationStatus;

  const ProfileScreen({
    super.key,
    this.userName = "Unknown",
    this.userAge = "18",
    this.userEmail = "email@example.com",
    this.isAdmin = false,
    this.verificationStatus = 'none',
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String fullName;
  late String age;
  late String email;
  String _verificationStatus = 'none';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    fullName = widget.userName;
    age = widget.userAge;
    email = widget.userEmail;
    _verificationStatus = widget.verificationStatus;
    _fetchVerificationStatus();
  }

  Future<void> _fetchVerificationStatus() async {
    try {
      final data = await AuthService.getVerificationStatus(email);
      if (mounted) setState(() => _verificationStatus = data['verificationStatus'] ?? 'none');
    } catch (_) {}
  }

  Future<void> _startVerification() async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1200);
    if (photo == null) return;
    
    setState(() => _isUploading = true);
    try {
      // 1. Read image bytes and convert to base64
      final bytes = await photo.readAsBytes();
      final base64Data = base64Encode(bytes);
      final filename = email.replaceAll('@', '_at_').replaceAll('.', '_dot_');
      
      // 2. Upload ID by sending base64 to backend
      await AuthService.uploadIdForVerification(email, base64Data, filename);
      
      if (mounted) {
        setState(() => _verificationStatus = 'pending');
        // Save to SharedPreferences so it persists
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('verification_status', 'pending');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
            onPressed: () async {
              final val = controller.text.trim();
              Navigator.pop(context);
              try {
                final updated = await AuthService.updateProfile(
                  email,
                  name: title == 'Name' ? val : null,
                  age: title == 'Age' ? val : null,
                );
                onSave(val);
                // Persist the updated name to SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                if (title == 'Name') await prefs.setString('user_name', updated['name'] ?? val);
                if (title == 'Age') await prefs.setString('user_age', updated['age'] ?? val);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    TextEditingController currentController = TextEditingController();
    TextEditingController newController = TextEditingController();
    bool isSaving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Change Password"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      hintText: "Current Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrent ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureCurrent = !obscureCurrent;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: newController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      hintText: "New Password (min 8 chars)",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureNew = !obscureNew;
                          });
                        },
                      ),
                    ),
                  ),
                ],
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
                  onPressed: isSaving ? null : () async {
                    if (currentController.text.trim().isEmpty || newController.text.trim().isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Both fields are required."), backgroundColor: Colors.red));
                       return;
                    }
                    if (newController.text.trim().length < 8) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New password must be at least 8 characters."), backgroundColor: Colors.red));
                       return;
                    }
                    setState(() => isSaving = true);
                    try {
                      await AuthService.changePassword(currentController.text.trim(), newController.text.trim());
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password changed successfully."), backgroundColor: Colors.green));
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
                    } finally {
                      if (context.mounted) setState(() => isSaving = false);
                    }
                  },
                  child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Save", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
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
    final bool isAdmin = widget.isAdmin;
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
                  bottom: 24,
                ),
                child: Column(
                  children: [
                    Stack(
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
                        if (_verificationStatus == 'verified')
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.verified, color: Colors.green, size: 20),
                            ),
                          ),
                      ],
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
                    if (_verificationStatus == 'none')
                      GestureDetector(
                        onTap: _isUploading ? null : _startVerification,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _isUploading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text("Verify your account", style: TextStyle(color: Colors.grey, fontSize: 13, decoration: TextDecoration.underline)),
                        ),
                      )
                    else if (_verificationStatus == 'pending')
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text("Waiting for approval", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      )
                    else if (_verificationStatus == 'verified')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text("Verified", style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
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
                    _passwordTile(),

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

                    // ── ADMIN-ONLY SECTION ─────────────────────────────────
                    if (isAdmin) ...[
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2C2C2C)
                                : Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                            );
                          },
                          icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
                          label: const Text(
                            "Admin Panel",
                            style: TextStyle(
                              color: Colors.white,
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

  Widget _passwordTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: isDark ? Colors.white70 : Colors.black54, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Password",
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12),
                ),
                Text(
                  "••••••••",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 2,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
            onPressed: _showChangePasswordDialog,
          ),
        ],
      ),
    );
  }
}
