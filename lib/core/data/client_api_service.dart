import 'package:dio/dio.dart';

import '../../features/home/data/models/home_models.dart';
import '../../features/notifications/data/models/notification_model.dart';
import '../../features/orders/data/models/order_models.dart';
import '../../features/profile/data/models/user_profile.dart';

class ClientApiService {
  const ClientApiService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/mobile/client';

  Future<List<ProjectSummary>> getProjects() async {
    final res = await _dio.get('$_base/projects');
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => ProjectSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProjectDetail> getProjectDetail(String projectId) async {
    final res = await _dio.get('$_base/projects/$projectId');
    return ProjectDetail.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<List<Order>> getProjectOrders(
    String projectId, {
    String type = 'active',
  }) async {
    final res = await _dio.get(
      '$_base/projects/$projectId/orders',
      queryParameters: {'type': type},
    );
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Order>> getOrders({String type = 'active'}) async {
    final res = await _dio.get(
      '$_base/orders',
      queryParameters: {'type': type},
    );
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> getOrder(String orderId) async {
    final res = await _dio.get('$_base/orders/$orderId');
    return Order.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<List<ProjectProduct>> getProjectProducts(String projectId) async {
    final res = await _dio.get('$_base/projects/$projectId/products');
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => ProjectProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> createOrder({
    required String projectId,
    required String productName,
    required String productGrade,
    required String quantity,
    String? date,
    String? time,
    String? deliveryAddress,
  }) async {
    final res = await _dio.post(
      '$_base/orders',
      data: {
        'projectId': projectId,
        'productName': productName,
        'productGrade': productGrade,
        'quantity': quantity,
        if (date != null) 'date': date,
        if (time != null) 'time': time,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      },
    );
    final responseData =
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return responseData['orderId'] as String;
  }

  Future<UserProfile> getProfile() async {
    final res = await _dio.get('$_base/profile');
    return UserProfile.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<List<AppNotification>> getNotifications() async {
    final res = await _dio.get('$_base/notifications');
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _dio.put('$_base/notifications/$notificationId/read');
  }

  Future<List<Comment>> getComments(String orderId) async {
    final res = await _dio.get('$_base/orders/$orderId/comments');
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addComment(String orderId, String message) async {
    await _dio.post(
      '$_base/orders/$orderId/comments',
      data: {'message': message},
    );
  }

  Future<void> registerFcmToken(String token, String platform) async {
    await _dio.put(
      '$_base/fcm-token',
      data: {'token': token, 'platform': platform},
    );
  }
}
