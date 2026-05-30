import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginMode = true;
  bool isLoading = false;
  bool isSendingOtp = false;
  bool otpSent = false;
  bool _obscurePassword = true;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _ageFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _otpFocus = FocusNode();

  final String serverUrl = "$kBaseUrl/api/auth";

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    _ageFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _otpFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    emailController.dispose();
    passwordController.dispose();
    otpController.dispose();
    _nameFocus.dispose();
    _ageFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  Future<void> _sendOtp() async {
    if (!isLoginMode) {
      if (nameController.text.trim().isEmpty || ageController.text.trim().isEmpty) {
        _showSnack("Name and Age are required for Sign Up!", Colors.red);
        return;
      }
      if (passwordController.text.trim().length < 8) {
        _showSnack("Password must be at least 8 characters.", Colors.red);
        return;
      }
    }
    
    if (emailController.text.trim().isEmpty) {
      _showSnack("Please enter your Email to receive the OTP", Colors.red);
      return;
    }
    if (!_isValidEmail(emailController.text.trim())) {
      _showSnack("Please enter a valid email address.", Colors.red);
      return;
    }

    setState(() => isSendingOtp = true);
    try {
      if (isLoginMode) {
        await AuthService.requestLoginOtp(emailController.text.trim());
        _showSnack("OTP sent to your email for login.", Colors.green);
      } else {
        await AuthService.register(
          nameController.text.trim(),
          ageController.text.trim(),
          emailController.text.trim(),
          passwordController.text.trim(),
        );
        _showSnack("Account created! OTP sent to your email to verify.", Colors.green);
      }
      setState(() => otpSent = true);
    } catch (e) {
      _showSnack("Error: ${e.toString().replaceAll('Exception: ', '')}", Colors.red);
    } finally {
      if (mounted) setState(() => isSendingOtp = false);
    }
  }

  Future<void> authenticate() async {
    if (emailController.text.trim().isEmpty) {
      _showSnack("Please fill in your Email!", Colors.red);
      return;
    }
    if (!_isValidEmail(emailController.text.trim())) {
      _showSnack("Please enter a valid email address.", Colors.red);
      return;
    }

    bool useOtp = otpController.text.trim().isNotEmpty;
    
    if (!useOtp && passwordController.text.trim().isEmpty) {
       _showSnack("Please enter your Password or an OTP!", Colors.red);
       return;
    }

    if (!isLoginMode && !useOtp) {
       _showSnack("You must send and enter an OTP to verify your new account.", Colors.red);
       return;
    }

    setState(() => isLoading = true);
    try {
      Map<String, dynamic>? user;
      
      if (useOtp) {
        user = await AuthService.verifyOtp(emailController.text.trim(), otpController.text.trim());
      } else {
        user = await AuthService.login(
          emailController.text.trim(),
          passwordController.text.trim(),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', user['name'] ?? "Unknown");
      await prefs.setString('user_age', user['age'] ?? "18");
      await prefs.setString('user_email', user['email'] ?? "");
      await prefs.setBool('is_admin', user['isAdmin'] == true);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              userName: user['name'] ?? "Unknown",
              userAge: user['age'] ?? "18",
              userEmail: user['email'] ?? "",
              isAdmin: user['isAdmin'] == true,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnack("Error: ${e.toString().replaceAll('Exception: ', '')}", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  OutlineInputBorder _border(bool focused) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: focused ? BorderSide(color: Theme.of(context).primaryColor, width: 2.5) : BorderSide.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                    height: 115,
                    width: 115,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Ridify",
                  style: TextStyle(
                    fontSize: 34, 
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 40),

                if (!isLoginMode) ...[
                  _inputField(hint: "Full Name", icon: Icons.person_outline, controller: nameController, focusNode: _nameFocus),
                  const SizedBox(height: 16),
                  _inputField(hint: "Age", icon: Icons.cake_outlined, isNumber: true, controller: ageController, focusNode: _ageFocus),
                  const SizedBox(height: 16),
                ],

                _inputField(hint: "Email", icon: Icons.email_outlined, controller: emailController, focusNode: _emailFocus),
                const SizedBox(height: 16),

                _passwordField(),
                const SizedBox(height: 16),

                _otpField(),
                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: isLoading ? null : authenticate,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isLoginMode ? "Log In" : "Create Account",
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLoginMode ? "Don't have an account? " : "Already have an account? ",
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isLoginMode = !isLoginMode;
                          otpSent = false;
                          otpController.clear();
                        });
                      },
                      child: Text(
                        isLoginMode ? "Sign up" : "Log in",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
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

  Widget _passwordField() {
    return TextField(
      controller: passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscurePassword,
      keyboardType: TextInputType.visiblePassword,
      maxLength: kMaxFieldLength,
      decoration: InputDecoration(
        counterText: "",
        hintText: "Password",
        hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: _border(false),
        enabledBorder: _border(false),
        focusedBorder: _border(true),
      ),
    );
  }

  Widget _otpField() {
    return TextField(
      controller: otpController,
      focusNode: _otpFocus,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: InputDecoration(
        counterText: "",
        hintText: isLoginMode ? "OTP Code (Optional)" : "OTP Code (Required)",
        hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
        prefixIcon: const Icon(Icons.security, color: Colors.grey),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6.0, top: 6.0, bottom: 6.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: otpSent ? Colors.grey : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(80, 0),
            ),
            onPressed: isSendingOtp ? null : _sendOtp,
            child: isSendingOtp 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(otpSent ? "Resend" : "Send OTP", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: _border(false),
        enabledBorder: _border(false),
        focusedBorder: _border(true),
      ),
    );
  }

  Widget _inputField({required String hint, required IconData icon, bool isNumber = false, TextEditingController? controller, required FocusNode focusNode}) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLength: kMaxFieldLength,
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: _border(false),
        enabledBorder: _border(false),
        focusedBorder: _border(true),
      ),
    );
  }
}
