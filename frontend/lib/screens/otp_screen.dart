import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;
  bool isResending = false;

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _verifyOtp() async {
    if (otpController.text.trim().length < 6) {
      _showSnack("Please enter the 6-digit OTP", Colors.red);
      return;
    }

    setState(() => isLoading = true);
    try {
      final user = await AuthService.verifyOtp(widget.email, otpController.text.trim());
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', user['name'] ?? "Unknown");
      await prefs.setString('user_age', user['age'] ?? "18");
      await prefs.setString('user_email', user['email'] ?? "");
      await prefs.setBool('is_admin', user['isAdmin'] == true);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              userName: user['name'] ?? "Unknown",
              userAge: user['age'] ?? "18",
              userEmail: user['email'] ?? "",
              isAdmin: user['isAdmin'] == true,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnack("Verification failed: ${e.toString().replaceAll('Exception: ', '')}", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => isResending = true);
    try {
      await AuthService.resendOtp(widget.email);
      _showSnack("A new OTP has been sent to your email.", Colors.green);
    } catch (e) {
      _showSnack("Failed to resend: ${e.toString().replaceAll('Exception: ', '')}", Colors.red);
    } finally {
      if (mounted) setState(() => isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  "Verify Your Email",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "We've sent a 6-digit code to\n${widget.email}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "000000",
                    hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 8),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: isLoading ? null : _verifyOtp,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Verify & Continue",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                TextButton(
                  onPressed: isResending ? null : _resendOtp,
                  child: isResending 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Didn't receive a code? Resend", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
