String formatAddress(String? address) {
  if (address == null || address.isEmpty) return "Unknown";
  List<String> parts = address.split(', ');
  if (parts.length > 2) {
    return "${parts[0]}, ${parts[1]}";
  }
  return address;
}
