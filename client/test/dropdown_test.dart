import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/widgets/app_dropdown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDropdown Standard Component Tests', () {
    testWidgets('Renders selected item label and custom hint when null', (WidgetTester tester) async {
      String? selectedVal;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppDropdown<String>(
            key: const Key('test-dropdown'),
            labelText: 'Campus Branch',
            hint: 'Choose your branch',
            value: selectedVal,
            items: const [
              AppDropdownItem(value: 'cs', label: 'Computer Science'),
              AppDropdownItem(value: 'ec', label: 'Electronics & Comm'),
              AppDropdownItem(value: 'me', label: 'Mechanical Eng'),
            ],
            onChanged: (val) {
              selectedVal = val;
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Campus Branch'), findsOneWidget);
      expect(find.text('Choose your branch'), findsOneWidget);
    });

    testWidgets('Tapping dropdown trigger opens menu and triggers onChanged', (WidgetTester tester) async {
      String? selectedVal = 'cs';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppDropdown<String>(
                key: const Key('test-dropdown'),
                labelText: 'Campus Branch',
                value: selectedVal,
                items: const [
                  AppDropdownItem(value: 'cs', label: 'Computer Science'),
                  AppDropdownItem(value: 'ec', label: 'Electronics & Comm'),
                  AppDropdownItem(value: 'me', label: 'Mechanical Eng'),
                ],
                onChanged: (val) {
                  setState(() => selectedVal = val);
                },
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Computer Science'), findsOneWidget);

      // Tap dropdown to open menu
      await tester.tap(find.byKey(const Key('test-dropdown')));
      await tester.pumpAndSettle();

      // Verify all items are rendered in the popup
      expect(find.text('Computer Science'), findsWidgets);
      expect(find.text('Electronics & Comm'), findsOneWidget);
      expect(find.text('Mechanical Eng'), findsOneWidget);

      // Select Electronics
      await tester.tap(find.text('Electronics & Comm'));
      await tester.pumpAndSettle();

      expect(selectedVal, 'ec');
      expect(find.text('Electronics & Comm'), findsOneWidget);
    });

    testWidgets('Tapping labelText opens the dropdown menu via key delegation', (WidgetTester tester) async {
      String? selectedVal = 'cs';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppDropdown<String>(
                labelText: 'Campus Branch',
                value: selectedVal,
                items: const [
                  AppDropdownItem(value: 'cs', label: 'Computer Science'),
                  AppDropdownItem(value: 'ec', label: 'Electronics & Comm'),
                ],
                onChanged: (val) {
                  setState(() => selectedVal = val);
                },
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap on the label text specifically
      await tester.tap(find.text('Campus Branch'));
      await tester.pumpAndSettle();

      // Menu should be open
      expect(find.text('Electronics & Comm'), findsOneWidget);

      await tester.tap(find.text('Electronics & Comm'));
      await tester.pumpAndSettle();

      expect(selectedVal, 'ec');
    });

    testWidgets('Nullable items with value: null cleanly trigger onChanged(null)', (WidgetTester tester) async {
      String? selectedVal = 'prof_1';
      bool nullSelected = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppDropdown<String?>(
                key: const Key('test-null-dropdown'),
                labelText: 'Head of Department',
                value: selectedVal,
                items: const [
                  AppDropdownItem<String?>(value: null, label: 'No HOD assigned yet'),
                  AppDropdownItem<String?>(value: 'prof_1', label: 'Dr. Sharma'),
                  AppDropdownItem<String?>(value: 'prof_2', label: 'Dr. Verma'),
                ],
                onChanged: (val) {
                  setState(() {
                    selectedVal = val;
                    if (val == null) nullSelected = true;
                  });
                },
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Sharma'), findsOneWidget);

      // Open dropdown
      await tester.tap(find.byKey(const Key('test-null-dropdown')));
      await tester.pumpAndSettle();

      expect(find.text('No HOD assigned yet'), findsOneWidget);

      // Tap the null value option
      await tester.tap(find.text('No HOD assigned yet'));
      await tester.pumpAndSettle();

      expect(selectedVal, isNull);
      expect(nullSelected, isTrue);
    });

    testWidgets('Disabled items cannot be selected', (WidgetTester tester) async {
      String? selectedVal = 'cs';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppDropdown<String>(
                key: const Key('test-disabled-dropdown'),
                labelText: 'Program',
                value: selectedVal,
                items: const [
                  AppDropdownItem(value: 'cs', label: 'Computer Science'),
                  AppDropdownItem(value: 'arch', label: 'Architecture (Full)', enabled: false),
                ],
                onChanged: (val) {
                  setState(() => selectedVal = val);
                },
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('test-disabled-dropdown')));
      await tester.pumpAndSettle();

      expect(find.text('Architecture (Full)'), findsOneWidget);

      // Tap disabled option
      await tester.tap(find.text('Architecture (Full)'));
      await tester.pumpAndSettle();

      // Selected value should remain 'cs'
      expect(selectedVal, 'cs');
    });
  });
}
