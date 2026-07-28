enum ServiceState { available, placeholder, unavailable }

class ServiceCapability {
  const ServiceCapability({required this.state, required this.message});

  final ServiceState state;
  final String message;

  bool get isAvailable => state == ServiceState.available;
  bool get isPlaceholder => state == ServiceState.placeholder;

  String get userMessage => switch (state) {
    ServiceState.available => '功能可用。',
    ServiceState.placeholder => '当前设备上的此功能受限，可以继续使用其他学习方式。',
    ServiceState.unavailable => '当前设备暂时无法使用此功能，请稍后重试或改用其他学习方式。',
  };
}

class ServiceDescriptor {
  const ServiceDescriptor({
    required this.name,
    required this.description,
    required this.capability,
  });

  final String name;
  final String description;
  final ServiceCapability capability;
}
