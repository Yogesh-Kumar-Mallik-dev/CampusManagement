import 'package:flutter/widgets.dart';
import '../facade/campus_facade.dart';
import '../services/api_service.dart';
import '../services/offline_storage_service.dart';
import '../services/storage_interface.dart';

/// CampusDI provides an IoC service locator and dependency injection container.
class CampusDI {
  static final CampusDI _instance = CampusDI._internal();
  static CampusDI get instance => _instance;

  CampusDI._internal();

  final Map<Type, dynamic> _singletons = {};
  final Map<Type, dynamic Function()> _factories = {};

  /// Registers a singleton instance of type [T].
  void registerSingleton<T>(T instance) {
    _singletons[T] = instance;
    _factories.remove(T);
  }

  /// Registers a lazy singleton factory for type [T].
  void registerLazySingleton<T>(T Function() factory) {
    _factories[T] = factory;
    _singletons.remove(T);
  }

  /// Checks if a service of type [T] is registered.
  bool isRegistered<T>() {
    return _singletons.containsKey(T) || _factories.containsKey(T);
  }

  /// Retrieves an instance of type [T].
  T get<T>() {
    if (_singletons.containsKey(T)) {
      return _singletons[T] as T;
    }
    if (_factories.containsKey(T)) {
      final instance = _factories[T]!() as T;
      _singletons[T] = instance;
      _factories.remove(T);
      return instance;
    }
    throw StateError(
      'CampusDI: No instance or factory registered for type $T. '
      'Make sure CampusDI.setup() or registerSingleton<$T>() has been invoked.',
    );
  }

  /// Clears all registered singletons and factories.
  void reset() {
    _singletons.clear();
    _factories.clear();
  }

  /// Convenience setup method initializing default bindings with optional test overrides.
  static CampusDI setup({
    ICampusApi? api,
    ICampusStorage? storage,
    ICampusFacade? facade,
    String defaultBaseUrl = 'http://localhost:8080',
  }) {
    final di = CampusDI.instance;
    di.reset();

    final effectiveApi = api ?? ApiService(baseUrl: defaultBaseUrl);
    di.registerSingleton<ICampusApi>(effectiveApi);

    final effectiveStorage =
        storage ?? OfflineStorageService(api: effectiveApi);
    di.registerSingleton<ICampusStorage>(effectiveStorage);
    // Also register concrete OfflineStorageService if needed for backward-compatibility
    if (effectiveStorage is OfflineStorageService) {
      di.registerSingleton<OfflineStorageService>(effectiveStorage);
    }

    final effectiveFacade = facade ??
        CampusFacade(
          storage: effectiveStorage,
          api: effectiveApi,
        );
    di.registerSingleton<ICampusFacade>(effectiveFacade);

    return di;
  }
}

/// CampusScope is an InheritedWidget that provides DI and Facade access down the widget hierarchy.
class CampusScope extends InheritedWidget {
  final CampusDI container;
  final ICampusFacade facade;
  final ICampusStorage storage;
  final ICampusApi api;

  CampusScope({
    super.key,
    required super.child,
    CampusDI? container,
    ICampusFacade? facade,
    ICampusStorage? storage,
    ICampusApi? api,
  })  : container = container ?? CampusDI.instance,
        facade = facade ?? (container ?? CampusDI.instance).get<ICampusFacade>(),
        storage = storage ?? (container ?? CampusDI.instance).get<ICampusStorage>(),
        api = api ?? (container ?? CampusDI.instance).get<ICampusApi>();

  static CampusScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CampusScope>();
    if (scope == null) {
      throw StateError(
        'CampusScope.of() called with a context that does not contain a CampusScope. '
        'Wrap your app or widget tree in a CampusScope widget.',
      );
    }
    return scope;
  }

  static ICampusFacade facadeOf(BuildContext context) => of(context).facade;
  static ICampusStorage storageOf(BuildContext context) => of(context).storage;
  static ICampusApi apiOf(BuildContext context) => of(context).api;

  @override
  bool updateShouldNotify(CampusScope oldWidget) {
    return container != oldWidget.container ||
        facade != oldWidget.facade ||
        storage != oldWidget.storage ||
        api != oldWidget.api;
  }
}
