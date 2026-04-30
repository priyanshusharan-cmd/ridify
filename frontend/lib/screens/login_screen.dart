import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginMode = true;
  bool isLoading = false;
  bool _obscurePassword = true;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final String serverUrl = "$kBaseUrl/api/auth";

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Validates email format: must have local part, @, and a TLD (e.g. .com)
  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  Future<void> authenticate() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _showSnack("Please fill in your Email and Password!", Colors.red);
      return;
    }

    // Strict email format validation before making any HTTP call
    if (!_isValidEmail(emailController.text.trim())) {
      _showSnack("Please enter a valid email address.", Colors.red);
      return;
    }

    if (passwordController.text.trim().length < 8) {
      _showSnack("Password must be at least 8 characters.", Colors.red);
      return;
    }
    if (!isLoginMode) {
      if (nameController.text.trim().isEmpty ||
          ageController.text.trim().isEmpty) {
        _showSnack("Name and Age are required for Sign Up!", Colors.red);
        return;
      }
    }

    setState(() => isLoading = true);
    try {
      final url = isLoginMode ? "$serverUrl/login" : "$serverUrl/register";
      final body = isLoginMode
          ? {
              "email": emailController.text.trim(),
              "password": passwordController.text.trim(),
            }
          : {
              "name": nameController.text.trim(),
              "age": ageController.text.trim(),
              "email": emailController.text.trim(),
              "password": passwordController.text.trim(),
            };

      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = data['user'];

        // Persist session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', user['name'] ?? "Unknown");
        await prefs.setString('user_age', user['age'] ?? "18");
        await prefs.setString('user_email', user['email'] ?? "");

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                userName: user['name'] ?? "Unknown",
                userAge: user['age'] ?? "18",
                userEmail: user['email'] ?? "",
              ),
            ),
          );
        }
      } else {
        final err =
            jsonDecode(response.body)['error'] ?? "Authentication failed";
        _showSnack(err, Colors.red);
      }
    } catch (e) {
      _showSnack("Error: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // No actions — trash icon removed per admin-only design
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icon.png',
                    height: 70,
                    width: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Ridify",
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                // ── SIGNUP-ONLY FIELDS ──────────────────────────────
                if (!isLoginMode) ...[
                  _inputField(
                    hint: "Full Name",
                    icon: Icons.person_outline,
                    controller: nameController,
                  ),
                  const SizedBox(height: 16),
                  _inputField(
                    hint: "Age",
                    icon: Icons.cake_outlined,
                    isNumber: true,
                    controller: ageController,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── EMAIL ────────────────────────────────────────────
                _inputField(
                  hint: "Email",
                  icon: Icons.email_outlined,
                  controller: emailController,
                ),
                const SizedBox(height: 16),

                // ── PASSWORD (with eye toggle) ───────────────────────
                _passwordField(),
                const SizedBox(height: 16),

                const SizedBox(height: 9),

                // ── SUBMIT ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: isLoading ? null : authenticate,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isLoginMode ? "Log In" : "Create Account",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLoginMode
                          ? "Don't have an account? "
                          : "Already have an account? ",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isLoginMode = !isLoginMode;
                        });
                      },
                      child: Text(
                        isLoginMode ? "Sign up" : "Log in",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── PASSWORD FIELD with eye toggle ────────────────────────────────────────
  Widget _passwordField() {
    return TextField(
      controller: passwordController,
      obscureText: _obscurePassword,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(
        hintText: "Password",
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ── GENERIC INPUT FIELD ───────────────────────────────────────────────────
  Widget _inputField({
    required String hint,
    required IconData icon,
    bool isNumber = false,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
