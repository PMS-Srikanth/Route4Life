import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Launches Google Maps for real turn-by-turn navigation (with live traffic).
/// Falls back to the Google Maps website if the native app isn't installed.
class NavigationService {
  /// Open Google Maps navigation to [dest].
  ///
  /// If [origin] is provided (e.g. patient pickup location), the route is drawn
  /// from that fixed point → [dest], regardless of the driver's current GPS.
  /// If [origin] is null, Google Maps uses the device's current location.
  static Future<void> navigateTo(
    LatLng dest, {
    LatLng? origin,
    String? label,
  }) async {
    final dlat = dest.latitude;
    final dlng = dest.longitude;

    if (origin != null) {
      final olat = origin.latitude;
      final olng = origin.longitude;

      // 1️⃣ comgooglemaps:// — native URI that explicitly sets start address
      //    saddr = origin, daddr = destination — Maps respects these always
      final nativeUri = Uri.parse(
        'comgooglemaps://?saddr=$olat,$olng&daddr=$dlat,$dlng&directionsmode=driving',
      );
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri);
        return;
      }

      // 2️⃣ Fallback: maps.google.com with saddr/daddr (works in browser too)
      final webUri = Uri.parse(
        'https://maps.google.com/maps'
        '?saddr=$olat,$olng'
        '&daddr=$dlat,$dlng'
        '&dirflg=d',
      );
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      // No explicit origin — use google.navigation deep-link (current GPS → dest)
      final navUri = Uri.parse('google.navigation:q=$dlat,$dlng&mode=d');
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri);
        return;
      }

      // Fallback web URL
      final webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$dlat,$dlng'
        '&travelmode=driving',
      );
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens Google Maps showing [location] as a labeled pin.
  static Future<void> showOnMap(LatLng location, {String label = 'Location'}) async {
    final lat = location.latitude;
    final lng = location.longitude;
    final encodedLabel = Uri.encodeComponent(label);

    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedLabel)');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    final webUri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
