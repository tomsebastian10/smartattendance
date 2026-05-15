import 'package:mobile_scanner/mobile_scanner.dart';

class QrService {
  // Mobile scanner is used directly in the UI component.
  // This service can handle validation logic or token parsing if needed.
  
  bool isValidToken(String token) {
    // Basic format check: e.g., 12 characters (as defined in backend)
    return token.length == 12;
  }
}
