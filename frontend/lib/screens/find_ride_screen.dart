import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/address_search_widget.dart';
import '../core/constants.dart';
import 'map_picker_screen.dart';

class FindRideScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  const FindRideScreen({super.key, required this.userName, required this.userEmail});

  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  String selectedVehicle = 'Any';
  int selectedSeats = 1;
  double walkableRadius = 1000; // Default 1km
  bool isSearching = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  double? pickupLat;
  double? pickupLng;
  double? destLat;
  double? destLng;

  final String serverUrl = "$kBaseUrl/api/rides/search";

  @override
  void initState() {
    super.initState();
    _autofillLocation();
  }

  Future<void> _autofillLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (mounted) {
          setState(() {
            pickupLat = position.latitude;
            pickupLng = position.longitude;
          });
        }

        final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json');
        final response = await http.get(url, headers: {'User-Agent': 'ridify_app/1.0'});
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['display_name'] != null && mounted) {
            setState(() {
              pickupController.text = data['display_name'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Autofill Error: $e");
    }
  }

  int getMaxSeats() {
    if (selectedVehicle == 'Bike') return 1;
    if (selectedVehicle == 'Sedan') return 4;
    return 6; // SUV or Any
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

  Future<void> startSearch() async {
    if (pickupController.text.trim().isEmpty ||
        destinationController.text.trim().isEmpty || pickupLat == null || destLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select valid locations for both Pickup and Destination!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isSearching = true);

    try {
      DateTime dateToSearch = _selectedDate ?? DateTime.now();
      String dateStr = "${dateToSearch.day}/${dateToSearch.month}/${dateToSearch.year}";

      String timeQueryStr = "";
      if (_selectedTime != null) {
        final searchDt = DateTime(
          dateToSearch.year,
          dateToSearch.month,
          dateToSearch.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        timeQueryStr = "&searchTimeEpoch=${searchDt.millisecondsSinceEpoch}";
      }

      final Uri searchUri = Uri.parse(
        "$serverUrl?pickup=${Uri.encodeComponent(pickupController.text)}&destination=${Uri.encodeComponent(destinationController.text)}&seats=$selectedSeats&vehicle=$selectedVehicle&date=$dateStr$timeQueryStr&lat=$pickupLat&lng=$pickupLng&destLat=$destLat&destLng=$destLng&radius=${walkableRadius.toInt()}&userEmail=${Uri.encodeComponent(widget.userEmail)}",
      );

      final response = await http.get(searchUri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        List<dynamic> allRides = jsonDecode(response.body);
        List<dynamic> validRides = allRides
            .where((ride) => ride['riderEmail'] != widget.userEmail)
            .toList();

        if (mounted) {
          if (validRides.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("No rides found matching your route and criteria."),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            _showResultsBottomSheet(validRides);
          }
        }
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Search timed out. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Network Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network error. Check your connection."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  bool _isSendingRequest = false;

  Future<void> sendRideRequest(dynamic ride, String driverName) async {
    if (_isSendingRequest) return;
    _isSendingRequest = true;
    try {
      final response = await http.patch(
        Uri.parse("$kBaseUrl/api/rides/request/${ride['_id']}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "riderName": widget.userName,
          "riderEmail": widget.userEmail,
          "seats": selectedSeats,
          "computedFare": ride['computedFare'],
          "computedDistance": ride['computedDistance'],
          "startIndex": ride['startIndex'],
          "endIndex": ride['endIndex'],
          "pickupLat": pickupLat,
          "pickupLng": pickupLng,
          "destLat": destLat,
          "destLng": destLng,
          "pickupLocation": pickupController.text,
          "destination": destinationController.text
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && mounted) {
        Navigator.pop(context); // close bottom sheet
        Navigator.pop(context); // close find ride screen, back to home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ride Requested!"),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (mounted) {
        final err = jsonDecode(response.body)['error'] ?? "Request failed";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request timed out. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Request Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not send request. Check your connection."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isSendingRequest = false;
    }
  }

  void _showResultsBottomSheet(List<dynamic> rides) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Available Rides (${rides.length})",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      final ride = rides[index];
                      final computedFare = ride['computedFare'] ?? ride['fare'];
                      final computedDistance = ride['computedDistance'] != null ? ride['computedDistance'].toStringAsFixed(1) : "?";
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                        color: Theme.of(context).cardColor,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(15),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            ride['riderName'] ?? "Driver",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Dist: $computedDistance km • ${ride['vehicleType'] ?? 'Car'} • ${ride['routePreference'] == 'nonstop' ? 'Nonstop' : 'Flexible'}",
                              ),
                              Text(
                                "Departs: ${ride['departureTime'] ?? "Now"}",
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "₹$computedFare",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                                  minimumSize: const Size(60, 30),
                                ),
                                onPressed: () => sendRideRequest(
                                  ride,
                                  ride['riderName'] ?? "Driver",
                                ),
                                child: const Text(
                                  "Book",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Find a Ride",
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
                      }
                    },
                    onSelected: (name, lat, lon) {
                      setState(() {
                         pickupLat = lat;
                         pickupLng = lon;
                      });
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
                      }
                    },
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

            const Text(
              "Search Radius",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("100m", style: TextStyle(color: Colors.grey)),
                Expanded(
                  child: Slider(
                    value: walkableRadius,
                    min: 100,
                    max: 2000,
                    divisions: 19,
                    activeColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    inactiveColor: Theme.of(context).dividerColor,
                    label: "${(walkableRadius / 1000).toStringAsFixed(1)} km",
                    onChanged: (val) {
                      setState(() {
                        walkableRadius = val;
                      });
                    },
                  ),
                ),
                const Text("2km", style: TextStyle(color: Colors.grey)),
              ],
            ),
            Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.grey),
                  children: [
                    const TextSpan(text: "Searching within "),
                    TextSpan(text: "${(walkableRadius / 1000).toStringAsFixed(1)} km"),
                    const TextSpan(text: " of your radius"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Preferred Vehicle",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: ['Any', 'Bike', 'Sedan', 'SUV'].map((type) {
                bool isSelected = selectedVehicle == type;
                IconData icon = type == 'Any'
                    ? Icons.all_inclusive
                    : type == 'Bike'
                    ? Icons.motorcycle
                    : type == 'Sedan'
                    ? Icons.directions_car
                    : Icons.airport_shuttle;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onVehicleChanged(type),
                    child: Container(
                      height: 85,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            icon,
                            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            type,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            dateText,
                            style: TextStyle(
                              color: _selectedDate == null
                                  ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)
                                  : Theme.of(context).textTheme.bodyLarge?.color,
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
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 20,
                            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            timeText,
                            style: TextStyle(
                              color: _selectedTime == null
                                  ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)
                                  : Theme.of(context).textTheme.bodyLarge?.color,
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Seats Needed",
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
                          ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black)
                          : Theme.of(context).cardColor,
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
                          color: selectedSeats == seats
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: isSearching ? null : startSearch,
                child: isSearching
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Search Rides",
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
