import 'package:flutter/material.dart';
import 'dart:async';
import '../services/nominatim_service.dart';

class AddressSearchWidget extends StatefulWidget {
  final String hintText;
  final IconData prefixIcon;
  final Color iconColor;
  final Function(String name, double lat, double lon) onSelected;
  final TextEditingController controller;
  final VoidCallback? onMapTap;

  const AddressSearchWidget({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    required this.iconColor,
    required this.onSelected,
    required this.controller,
    this.onMapTap,
  });

  @override
  State<AddressSearchWidget> createState() => _AddressSearchWidgetState();
}

class _AddressSearchWidgetState extends State<AddressSearchWidget> {
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
      });
      _removeOverlay();
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final suggestions = await NominatimService.searchAddress(query);
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
      });
      if (_suggestions.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _searchAddress(value);
    });
  }

  void _showOverlay() {
    if (!mounted) return;
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  return ListTile(
                    title: Text(
                      item['display_name'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    onTap: () {
                      widget.controller.text = item['display_name'];
                      widget.onSelected(
                        item['display_name'],
                        item['lat'],
                        item['lon'],
                      );
                      setState(() {
                        _suggestions = [];
                      });
                      _removeOverlay();
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        onChanged: _onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          prefixIcon: Icon(widget.prefixIcon, color: widget.iconColor),
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
          border: InputBorder.none,
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : widget.onMapTap != null
                  ? IconButton(
                      icon: Icon(Icons.map_outlined, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6)),
                      onPressed: widget.onMapTap,
                    )
                  : null,
        ),
      ),
    );
  }
}
