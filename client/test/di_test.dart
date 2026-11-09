import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/di/service_locator.dart';
import 'package:campus_client/facade/campus_facade.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/services/storage_interface.dart';

class MockCampusApi implements ICampusApi {
  @override
  String get baseUrl => 'http://mock-campus.test';

  @override
  Future<bool> checkHealth() async => true;

  @override
  Future<UserModel> login(String identifier, String password) async {
    return UserModel(
      id: 'mock-user-1',
      campusHandle: 'mock_tester',
      firstName: 'Mock',
      lastName: 'Tester',
      email: 'mock@campus.edu',
      archetype: 'student',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CampusDI IoC Container Tests', () {
    setUp(() {
      CampusDI.instance.reset();
    });

    test('CampusDI.setup registers default singletons', () {
      final di = CampusDI.setup();

      expect(di.isRegistered<ICampusApi>(), isTrue);
      expect(di.isRegistered<ICampusStorage>(), isTrue);
      expect(di.isRegistered<OfflineStorageService>(), isTrue);
      expect(di.isRegistered<ICampusFacade>(), isTrue);

      final api = di.get<ICampusApi>();
      final storage = di.get<ICampusStorage>();
      final facade = di.get<ICampusFacade>();

      expect(api, isA<ApiService>());
      expect(storage, isA<OfflineStorageService>());
      expect(facade, isA<CampusFacade>());
      expect(facade.api, equals(api));
      expect(facade.storage, equals(storage));
    });

    test('CampusDI allows injecting custom/mock implementations', () {
      final mockApi = MockCampusApi();
      final mockStorage = OfflineStorageService(api: mockApi);
      final customFacade = CampusFacade(storage: mockStorage, api: mockApi);

      final di = CampusDI.setup(
        api: mockApi,
        storage: mockStorage,
        facade: customFacade,
      );

      expect(di.get<ICampusApi>(), equals(mockApi));
      expect(di.get<ICampusStorage>(), equals(mockStorage));
      expect(di.get<ICampusFacade>(), equals(customFacade));
    });

    test('CampusDI supports lazy singleton resolution and caching', () {
      final di = CampusDI.instance;
      int factoryInvocationCount = 0;

      di.registerLazySingleton<String>(() {
        factoryInvocationCount++;
        return 'lazy_payload_$factoryInvocationCount';
      });

      expect(factoryInvocationCount, equals(0));

      final firstResolution = di.get<String>();
      expect(firstResolution, equals('lazy_payload_1'));
      expect(factoryInvocationCount, equals(1));

      final secondResolution = di.get<String>();
      expect(secondResolution, equals('lazy_payload_1'));
      expect(factoryInvocationCount, equals(1));
    });

    test('CampusDI throws StateError when resolving unregistered type', () {
      final di = CampusDI.instance;
      expect(() => di.get<DateTime>(), throwsA(isA<StateError>()));
    });

    test('CampusDI.reset clears all registrations', () {
      final di = CampusDI.setup();
      expect(di.isRegistered<ICampusFacade>(), isTrue);

      di.reset();
      expect(di.isRegistered<ICampusFacade>(), isFalse);
      expect(di.isRegistered<ICampusStorage>(), isFalse);
    });
  });

  group('CampusScope InheritedWidget Tests', () {
    testWidgets('CampusScope injects dependencies down the widget tree',
        (tester) async {
      final mockApi = MockCampusApi();
      final storage = OfflineStorageService(api: mockApi);
      final facade = CampusFacade(storage: storage, api: mockApi);

      ICampusFacade? retrievedFacade;
      ICampusStorage? retrievedStorage;
      ICampusApi? retrievedApi;

      await tester.pumpWidget(
        CampusScope(
          facade: facade,
          storage: storage,
          api: mockApi,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                retrievedFacade = CampusScope.facadeOf(context);
                retrievedStorage = CampusScope.storageOf(context);
                retrievedApi = CampusScope.apiOf(context);
                return const Text('DI Scope Child');
              },
            ),
          ),
        ),
      );

      expect(find.text('DI Scope Child'), findsOneWidget);
      expect(retrievedFacade, equals(facade));
      expect(retrievedStorage, equals(storage));
      expect(retrievedApi, equals(mockApi));
    });

    testWidgets('CampusScope.of throws StateError when missing from ancestor tree',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                () => CampusScope.of(context),
                throwsA(isA<StateError>()),
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    test('CampusDI registers and lazily resolves singleton factory', () {
      final di = CampusDI.instance;
      di.reset();

      int factoryCallCount = 0;
      di.registerLazySingleton<String>(() {
        factoryCallCount++;
        return 'lazy_test_instance';
      });

      expect(di.isRegistered<String>(), isTrue);
      expect(factoryCallCount, equals(0));

      final firstCall = di.get<String>();
      expect(firstCall, equals('lazy_test_instance'));
      expect(factoryCallCount, equals(1));

      final secondCall = di.get<String>();
      expect(secondCall, equals('lazy_test_instance'));
      expect(factoryCallCount, equals(1)); // Should be cached, not called again
    });

    test('CampusScope.updateShouldNotify accurately detects dependency changes', () {
      final di = CampusDI.setup();
      final facade = di.get<ICampusFacade>();
      final storage = di.get<ICampusStorage>();
      final api = di.get<ICampusApi>();

      final scope1 = CampusScope(
        container: di,
        facade: facade,
        storage: storage,
        api: api,
        child: const SizedBox(),
      );

      final scopeIdentical = CampusScope(
        container: di,
        facade: facade,
        storage: storage,
        api: api,
        child: const SizedBox(),
      );

      final scopeDifferentApi = CampusScope(
        container: di,
        facade: facade,
        storage: storage,
        api: MockCampusApi(),
        child: const SizedBox(),
      );

      expect(scope1.updateShouldNotify(scopeIdentical), isFalse);
      expect(scope1.updateShouldNotify(scopeDifferentApi), isTrue);
    });
  });
}
