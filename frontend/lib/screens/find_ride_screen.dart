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
  List<dynamic>? _searchResults;

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
            setState(() {
              _searchResults = validRides;
            });
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isResults = child.key == const ValueKey('results_view');
          final slideIn = Tween<Offset>(
            begin: isResults ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

          return SlideTransition(position: slideIn, child: child);
        },
        child: _searchResults != null
            ? AvailableRidesScreen(
                key: const ValueKey('results_view'),
                initialRides: _searchResults!,
                userName: widget.userName,
                userEmail: widget.userEmail,
                selectedSeats: selectedSeats,
                pickupLat: pickupLat!,
                pickupLng: pickupLng!,
                destLat: destLat!,
                destLng: destLng!,
                pickupLocation: pickupController.text,
                destination: destinationController.text,
                onBack: () => setState(() => _searchResults = null),
              )
            : SingleChildScrollView(
                key: const ValueKey('search_form'),
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
                    ? Icons.grid_view
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
      ),
    );
  }
}

class AvailableRidesScreen extends StatefulWidget {
  final List<dynamic> initialRides;
  final String userName;
  final String userEmail;
  final int selectedSeats;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final String pickupLocation;
  final String destination;
  final VoidCallback? onBack;

  const AvailableRidesScreen({
    super.key,
    required this.initialRides,
    required this.userName,
    required this.userEmail,
    required this.selectedSeats,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.pickupLocation,
    required this.destination,
    this.onBack,
  });

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  late List<dynamic> allRides;
  late List<dynamic> displayedRides;
  String selectedFilter = 'Any'; // Any, Sedan, Bike, SUV
  String sortOption = 'low_to_high'; // low_to_high, high_to_low

  String? _sendingRideId;

  @override
  void initState() {
    super.initState();
    allRides = List.from(widget.initialRides);
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    setState(() {
      displayedRides = allRides.where((ride) {
        if (selectedFilter == 'Any') return true;
        final vehicleType = ride['vehicleType']?.toString().toLowerCase() ?? '';
        return vehicleType.contains(selectedFilter.toLowerCase());
      }).toList();

      displayedRides.sort((a, b) {
        final fareA = (a['computedFare'] ?? a['fare'] ?? 0) as num;
        final fareB = (b['computedFare'] ?? b['fare'] ?? 0) as num;
        if (sortOption == 'low_to_high') {
          return fareA.compareTo(fareB);
        } else {
          return fareB.compareTo(fareA);
        }
      });
    });
  }

  void _showSortOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sort Options",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.arrow_upward, color: isDark ? Colors.white : Colors.black),
                title: const Text("Price: Low to High"),
                trailing: sortOption == 'low_to_high' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    sortOption = 'low_to_high';
                  });
                  _applyFiltersAndSort();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.arrow_downward, color: isDark ? Colors.white : Colors.black),
                title: const Text("Price: High to Low"),
                trailing: sortOption == 'high_to_low' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    sortOption = 'high_to_low';
                  });
                  _applyFiltersAndSort();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> sendRideRequest(dynamic ride, String driverName) async {
    if (_sendingRideId != null) return;
    setState(() => _sendingRideId = ride['_id']);
    try {
      final response = await http.patch(
        Uri.parse("$kBaseUrl/api/rides/request/${ride['_id']}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "riderName": widget.userName,
          "riderEmail": widget.userEmail,
          "seats": widget.selectedSeats,
          "computedFare": ride['computedFare'],
          "computedDistance": ride['computedDistance'],
          "startIndex": ride['startIndex'],
          "endIndex": ride['endIndex'],
          "pickupLat": widget.pickupLat,
          "pickupLng": widget.pickupLng,
          "destLat": widget.destLat,
          "destLng": widget.destLng,
          "pickupLocation": widget.pickupLocation,
          "destination": widget.destination
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && mounted) {
        // Successfully requested ride
        if (widget.onBack != null) {
          // It's rendered inside FindRideScreen via AnimatedSwitcher
          Navigator.pop(context); // Close the FindRideScreen wrapper entirely
        } else {
          Navigator.pop(context); // Pop Available Rides Screen
          Navigator.pop(context); // Pop Find Ride Screen, back to home
        }
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
      if (mounted) {
        setState(() => _sendingRideId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleColor = isDark ? Colors.white54 : Colors.grey[600];

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack ?? () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Icon(Icons.arrow_back, color: primaryTextColor, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Available Rides",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    Text(
                      "Choose a ride that fits your journey",
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Header Card with Locations
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.transparent),
              boxShadow: isDark
                  ? []
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.pickupLocation,
                        style: TextStyle(color: primaryTextColor, fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 9, top: 4, bottom: 4),
                  child: Container(width: 2, height: 16, color: Theme.of(context).dividerColor),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.flag_outlined, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.destination,
                        style: TextStyle(color: primaryTextColor, fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Any', 'Sedan', 'Bike', 'SUV'].map((filter) {
                        bool isSelected = selectedFilter == filter;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedFilter = filter;
                            });
                            _applyFiltersAndSort();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black)
                                  : cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (filter == 'Any') ...[
                                  Icon(Icons.grid_view, size: 16, color: isSelected ? (isDark ? Colors.black : Colors.white) : primaryTextColor),
                                  const SizedBox(width: 6),
                                ] else if (filter == 'Sedan') ...[
                                  Icon(Icons.directions_car, size: 16, color: isSelected ? (isDark ? Colors.black : Colors.white) : primaryTextColor),
                                  const SizedBox(width: 6),
                                ] else if (filter == 'Bike') ...[
                                  Icon(Icons.motorcycle, size: 16, color: isSelected ? (isDark ? Colors.black : Colors.white) : primaryTextColor),
                                  const SizedBox(width: 6),
                                ] else if (filter == 'SUV') ...[
                                  Icon(Icons.airport_shuttle, size: 16, color: isSelected ? (isDark ? Colors.black : Colors.white) : primaryTextColor),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected ? (isDark ? Colors.black : Colors.white) : primaryTextColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showSortOptions,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Icon(Icons.filter_list, color: primaryTextColor, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List of Rides
          Expanded(
            child: displayedRides.isEmpty
                ? Center(
                    child: Text(
                      "No rides available for this filter.",
                      style: TextStyle(color: subtitleColor, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: displayedRides.length,
                    itemBuilder: (context, index) {
                      final ride = displayedRides[index];
                      return _buildRideCard(ride, isDark, cardColor, primaryTextColor, subtitleColor);
                    },
                  ),
          ),
        ],
      );
  }

  Widget _buildRideCard(dynamic ride, bool isDark, Color cardColor, Color? primaryTextColor, Color? subtitleColor) {
    final computedFare = ride['computedFare'] ?? ride['fare'];
    final computedDistance = ride['computedDistance'] != null ? ride['computedDistance'].toStringAsFixed(1) : "?";
    final driverName = ride['riderName'] ?? "Driver";
    final vehicle = ride['vehicleType'] ?? 'Sedan';
    final routePref = ride['routePreference'] == 'nonstop' ? 'Nonstop' : 'Flexible Route';
    final departs = ride['departureTime'] ?? "Now";
    final totalSeats = ride['totalSeats'] ?? 4;
    final seatsLeft = totalSeats - (ride['boardedPassengers'] as List? ?? []).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.black,
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$vehicle • $routePref",
                      style: TextStyle(color: primaryTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₹$computedFare",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor),
                  ),
                  Text(
                    "Per Seat",
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: subtitleColor),
                        const SizedBox(width: 8),
                        Text(
                          "Departs at $departs",
                          style: TextStyle(color: subtitleColor, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ride['pickupLocation'] ?? widget.pickupLocation,
                            style: TextStyle(color: primaryTextColor, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 3, top: 4, bottom: 4),
                      child: Container(width: 2, height: 12, color: Theme.of(context).dividerColor),
                    ),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ride['destination'] ?? widget.destination,
                            style: TextStyle(color: primaryTextColor, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.airline_seat_recline_normal, size: 14, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        "$seatsLeft Seats Left",
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.add_road, size: 14, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        "$computedDistance km",
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      minimumSize: const Size(100, 40),
                    ),
                    onPressed: () => sendRideRequest(ride, driverName),
                    child: _sendingRideId == ride['_id'] 
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.black : Colors.white))
                        : const Text("Book", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
