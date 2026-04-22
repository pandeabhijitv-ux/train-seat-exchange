import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/seat_entry.dart';

class ApiService {
  final Dio _dio;

  ApiService() : _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectionTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  // ========== OTP Methods ==========
  
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await _dio.post(
        ApiConfig.sendOtp,
        data: {'phone': phone},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyOtp,
        data: {
          'phone': phone,
          'otp': otp,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> registerUser({
    required String phone,
    required String name,
  }) async {
    try {
      final response = await _dio.post(
        '/user/register',
        data: {
          'phone': phone,
          'name': name,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getUserProfile(String phone) async {
    try {
      final response = await _dio.get('/user/profile/$phone');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ========== PNR Verification ==========
  
  Future<Map<String, dynamic>> verifyPNR(String pnr) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyPnr,
        data: {'pnr': pnr},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ========== User Limits ==========
  
  Future<Map<String, dynamic>> getUserLimits(String phone) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.getUserLimits}/$phone',
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ========== Entry Methods ==========
  
  Future<Map<String, dynamic>> createEntry({required SeatEntry entry}) async {
    try {
      final data = entry.toJson();
      
      final response = await _dio.post(
        ApiConfig.createEntry,
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> searchEntries({
    required String trainNumber,
    required String trainDate,
    String? bogie,
    String? requesterPhone,
    String? currentBogie,
    String? currentSeat,
    String? desiredBogie,
    String? desiredSeat,
  }) async {
    try {
      final data = {
        'train_number': trainNumber,
        'train_date': trainDate,
        if (bogie != null) 'bogie': bogie,
        if (requesterPhone != null) 'requester_phone': requesterPhone,
        if (currentBogie != null) 'current_bogie': currentBogie,
        if (currentSeat != null) 'current_seat': currentSeat,
        if (desiredBogie != null) 'desired_bogie': desiredBogie,
        if (desiredSeat != null) 'desired_seat': desiredSeat,
      };
      
      final response = await _dio.post(
        ApiConfig.searchEntry,
        data: data,
      );
      
      final List<dynamic> responseData = response.data;
      return responseData;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getMyActiveEntries(String phone) async {
    try {
      final response = await _dio.get('${ApiConfig.myActiveEntries}/$phone');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ========== Error Handling ==========
  
  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'];
      }
      return 'Server error: ${error.response!.statusCode}';
    } else if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please check your internet.';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      return 'Server taking too long to respond.';
    } else {
      return 'Network error. Please try again.';
    }
  }
}
