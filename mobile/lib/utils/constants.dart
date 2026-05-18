class ApiConstants {
  static const String baseUrl = "http://10.191.129.178:8000/api/v1"; 
  // static const String baseUrl = "http://localhost:8000/api/v1"; // For iOS / Web
  
  static const String login = "$baseUrl/auth/login";
  static const String register = "$baseUrl/auth/register";
  static const String startSession = "$baseUrl/attendance/start-session";
  static const String verifyAttendance = "$baseUrl/attendance/verify";
}

class AppConstants {
  static const String appName = "Smart Attendance";
}
