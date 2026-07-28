import '../../core/service_status.dart';

abstract class PurchaseService {
  ServiceCapability get capability;

  Future<List<String>> loadProducts();
}

class StubPurchaseService implements PurchaseService {
  const StubPurchaseService();

  @override
  ServiceCapability get capability => const ServiceCapability(
        state: ServiceState.unavailable,
        message: '付费能力不在 P0 范围内，只保留接口占位。',
      );

  @override
  Future<List<String>> loadProducts() async => const [];
}
