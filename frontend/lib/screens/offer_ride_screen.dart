import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../widgets/address_search_widget.dart';
import '../core/constants.dart';
import 'map_picker_screen.dart';

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

  String routePreference = 'flexible';
  List<Map<String, dynamic>> routePath = [];
  double totalDistance = 0.0;

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

  Future<void> fetchRoute() async {
    if (pickupLat == null || destLat == null) return;
    try {
      final distance = const Distance();
      final straightLineDistance = distance.as(LengthUnit.Kilometer, LatLng(pickupLat!, pickupLng!), LatLng(destLat!, destLng!));
      final overview = straightLineDistance > 50 ? 'simplified' : 'full';
      final url = "https://router.project-osrm.org/route/v1/driving/$pickupLng,$pickupLat;$destLng,$destLat?geometries=geojson&overview=$overview";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          setState(() {
            totalDistance = route['distance'] / 1000.0; // in km
            final coordinates = route['geometry']['coordinates'];
            routePath = (coordinates as List).map<Map<String, dynamic>>((c) => {"lng": c[0], "lat": c[1]}).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch route: $e");
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(primary: Colors.white, onPrimary: Colors.black, surface: Color(0xFF1E1E1E))
                : const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(primary: Colors.white, onPrimary: Colors.black, surface: Color(0xFF1E1E1E))
                : const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
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
          content: Text("Please select valid locations from the dropdown and fill all fields!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (totalDistance < 1.5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ride must be at least 1.5 km long."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isPosting = true);

    DateTime dateToUse = _selectedDate ?? DateTime.now();
    TimeOfDay timeToUse = _selectedTime ?? TimeOfDay.now();

    String timeString = "${dateToUse.day}/${dateToUse.month}/${dateToUse.year} at ${timeToUse.format(context)}";

    final dt = DateTime(dateToUse.year, dateToUse.month, dateToUse.day, timeToUse.hour, timeToUse.minute);
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
          "routePath": routePath,
          "totalDistance": totalDistance,
          "routePreference": routePreference
        }),
      );

      if (response.statusCode == 201 && mounted) {
        Navigator.pop(context, 'ride_posted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ride offered successfully!"), backgroundColor: Colors.green),
        );
      } else if (mounted) {
        String errorMsg = "Server rejected the ride.";
        try {
          final errData = jsonDecode(response.body);
          if (errData['error'] != null) errorMsg = errData['error'];
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to connect: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  Widget _buildPreferenceCard(String title, String description, String value, IconData icon) {
    bool isSelected = routePreference == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => routePreference = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? (isDark ? const Color(0xFF2C2C2C) : Colors.black) : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: isSelected ? Colors.white : Theme.of(context).iconTheme.color?.withValues(alpha: 0.6), size: 24),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateText = _selectedDate == null ? "dd/mm/yyyy" : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}";
    String timeText = _selectedTime == null ? "--:--" : _selectedTime!.format(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Offer a Ride",
          style: TextStyle(color: Theme.of(context).appBarTheme.titleTextStyle?.color ?? Colors.white, fontWeight: FontWeight.bold),
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                children: [
                  AddressSearchWidget(
                    controller: pickupController,
                    hintText: "Your Pickup Location",
                    prefixIcon: Icons.location_on_outlined,
                    iconColor: Colors.green,
                    onMapTap: () async {
                      final initial = (pickupLat != null && pickupLng != null)
                          ? LatLng(pickupLat!, pickupLng!)
                          : null;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MapPickerScreen(initialPosition: initial)),
                      );
                      if (result != null && mounted) {
                        setState(() {
                          pickupController.text = result['name'];
                          pickupLat = result['lat'];
                          pickupLng = result['lng'];
                        });
                        fetchRoute();
                      }
                    },
                    onSelected: (name, lat, lon) {
                      setState(() {
                        pickupLat = lat;
                        pickupLng = lon;
                      });
                      fetchRoute();
                    },
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  AddressSearchWidget(
                    controller: destinationController,
                    hintText: "Your Destination",
                    prefixIcon: Icons.flag_outlined,
                    iconColor: Colors.red,
                    onMapTap: () async {
                      final initial = (destLat != null && destLng != null)
                          ? LatLng(destLat!, destLng!)
                          : (pickupLat != null && pickupLng != null)
                              ? LatLng(pickupLat!, pickupLng!)
                              : null;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MapPickerScreen(initialPosition: initial)),
                      );
                      if (result != null && mounted) {
                        setState(() {
                          destinationController.text = result['name'];
                          destLat = result['lat'];
                          destLng = result['lng'];
                        });
                        fetchRoute();
                      }
                    },
                    onSelected: (name, lat, lon) {
                      setState(() {
                        destLat = lat;
                        destLng = lon;
                      });
                      fetchRoute();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text("Route Flexibility", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Choose how flexible you want your route to be", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreferenceCard("Flexible", "Pickup & drop anywhere", "flexible", Icons.route_outlined),
                _buildPreferenceCard("Shared Start", "Same pickup, flexible drop", "shared_start", Icons.call_split),
                _buildPreferenceCard("Nonstop", "Exact pickup and drop only", "nonstop", Icons.straight),
              ],
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
                IconData icon = type == 'Bike' ? Icons.motorcycle : type == 'Sedan' ? Icons.directions_car : Icons.airport_shuttle;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onVehicleChanged(type),
                    child: Container(
                      height: 85,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black) : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(icon, color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                          const SizedBox(height: 5),
                          Text(
                            type,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
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

            const Text(
              "Schedule",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 20, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6)),
                          const SizedBox(width: 10),
                          Text(
                            dateText,
                            style: TextStyle(
                              color: _selectedDate == null ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5) : Theme.of(context).textTheme.bodyLarge?.color,
                              fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.bold,
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
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 20, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6)),
                          const SizedBox(width: 10),
                          Text(
                            timeText,
                            style: TextStyle(
                              color: _selectedTime == null ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5) : Theme.of(context).textTheme.bodyLarge?.color,
                              fontWeight: _selectedTime == null ? FontWeight.normal : FontWeight.bold,
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Seats Available", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Max: ${getMaxSeats()}", style: const TextStyle(color: Colors.grey)),
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
                      color: selectedSeats == seats ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black) : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: selectedSeats == seats ? Colors.white : Colors.transparent,
                        width: 2.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "$seats",
                        style: TextStyle(
                          color: selectedSeats == seats ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
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
            const Text("Price", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                prefixText: "₹ ",
                prefixStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                hintText: "Enter base price",
                hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Theme.of(context).primaryColor)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: isPosting ? null : postRideOffer,
                child: isPosting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Offer Ride", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
