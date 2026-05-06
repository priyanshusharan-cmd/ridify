import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/address_search_widget.dart';
import '../core/constants.dart';

class OfferRideScreen extends StatefulWidget {
  final String userName;
  const OfferRideScreen({super.key, required this.userName});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  double? pickupLat;
  double? pickupLng;
  double? destLat;
  double? destLng;

  String selectedVehicle = 'Sedan';
  int selectedSeats = 1;
  bool isPosting = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final String serverUrl = "$kBaseUrl/api/rides";

  int getMaxSeats() {
    if (selectedVehicle == 'Bike') return 1;
    if (selectedVehicle == 'Sedan') return 4;
    return 6; // SUV
  }

  void _onVehicleChanged(String vehicle) {
    setState(() {
      selectedVehicle = vehicle;
      selectedSeats = 1;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: Colors.black)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: Colors.black)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> postRideOffer() async {
    if (pickupController.text.isEmpty ||
        destinationController.text.isEmpty ||
        priceController.text.isEmpty ||
        pickupLat == null ||
        destLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select valid locations from the dropdown and fill all fields!",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isPosting = true);

    DateTime dateToUse = _selectedDate ?? DateTime.now();
    TimeOfDay timeToUse = _selectedTime ?? TimeOfDay.now();

    String timeString =
        "${dateToUse.day}/${dateToUse.month}/${dateToUse.year} at ${timeToUse.format(context)}";

    final dt = DateTime(
      dateToUse.year,
      dateToUse.month,
      dateToUse.day,
      timeToUse.hour,
      timeToUse.minute,
    );

    // Expires 15 minutes AFTER the scheduled departure time
    int expiresAtEpoch = dt.millisecondsSinceEpoch + (15 * 60 * 1000);

    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "riderName": widget.userName,
          "pickupLocation": pickupController.text,
          "pickupLat": pickupLat,
          "pickupLng": pickupLng,
          "destination": destinationController.text,
          "destLat": destLat,
          "destLng": destLng,
          "departureTime": timeString,
          "expiresAt": expiresAtEpoch,
          "fare": int.parse(priceController.text),
          "status": "available",
          "vehicleType": selectedVehicle,
          "totalSeats": selectedSeats,
          "availableSeats": selectedSeats,
        }),
      );

      if (response.statusCode == 201 && mounted) {
        // ── Navigation Result ─────────────────────────────────────────────────
        // Pop with 'ride_posted' so the HomeScreen can detect this specific
        // success and trigger the Victory Lap — no Socket.IO, no broadcast.
        // Only the person who just tapped "Offer Ride" will see the animation.
        Navigator.pop(context, 'ride_posted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ride offered successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateText = _selectedDate == null
        ? "dd/mm/yyyy"
        : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}";
    String timeText = _selectedTime == null
        ? "--:--"
        : _selectedTime!.format(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Offer a Ride",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  AddressSearchWidget(
                    controller: pickupController,
                    hintText: "Your Pickup Location",
                    prefixIcon: Icons.location_on_outlined,
                    iconColor: Colors.green,
                    onSelected: (name, lat, lon) {
                      setState(() {
                        pickupLat = lat;
                        pickupLng = lon;
                      });
                    },
                  ),
                  const Divider(height: 1, color: Colors.black12),
                  AddressSearchWidget(
                    controller: destinationController,
                    hintText: "Your Destination",
                    prefixIcon: Icons.flag_outlined,
                    iconColor: Colors.red,
                    onSelected: (name, lat, lon) {
                      setState(() {
                        destLat = lat;
                        destLng = lon;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Vehicle Selection
            const Text(
              "Vehicle Type",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: ['Bike', 'Sedan', 'SUV'].map((type) {
                bool isSelected = selectedVehicle == type;
                IconData icon = type == 'Bike'
                    ? Icons.motorcycle
                    : type == 'Sedan'
                    ? Icons.directions_car
                    : Icons.airport_shuttle;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onVehicleChanged(type),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            icon,
                            color: isSelected ? Colors.white : Colors.black54,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            type,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            dateText,
                            style: TextStyle(
                              color: _selectedDate == null
                                  ? Colors.black54
                                  : Colors.black,
                              fontWeight: _selectedDate == null
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickTime(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 20,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            timeText,
                            style: TextStyle(
                              color: _selectedTime == null
                                  ? Colors.black54
                                  : Colors.black,
                              fontWeight: _selectedTime == null
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Dynamic Seats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Seats Available",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Max: ${getMaxSeats()}",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(getMaxSeats(), (index) {
                int seats = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => selectedSeats = seats),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: selectedSeats == seats
                          ? Colors.black
                          : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Center(
                      child: Text(
                        "$seats",
                        style: TextStyle(
                          color: selectedSeats == seats
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 30),
            const Text(
              "Price per Seat",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: "₹ ",
                hintText: "Enter price",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: isPosting ? null : postRideOffer,
                child: isPosting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Offer Ride",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
