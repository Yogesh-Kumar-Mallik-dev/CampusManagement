# UI & Design System

This document outlines the **Material 3 Design System**, **Institutional Color Palette**, **Theme Architecture**, and **SVG Asset Guidelines** for the CampusManagement Flutter client.

---

## 1. Visual Identity & Color Palette

The interface adopts a high-contrast institutional aesthetic inspired by GitHub Primer and academic collegiate branding.

### 1.1 Brand Colors

| Token | Hex Value | Role & Usage |
| :--- | :--- | :--- |
| **Wine Red** (Primary) | `#7A1C30` | Primary actions, app bar headers, faculty broadcast badges, identity titles. |
| **Wine Red Subtle** | `#FDF2F4` / `#2D1217` | Subtle pill badges, tag backgrounds, active navigation indicator. |
| **GitHub Green** (Accent) | `#238636` | Verification confirmations, success badges, student scan launchers. |
| **GitHub Green Subtle** | `#EBF6ED` / `#112316` | Present attendance indicators, verified receipt banners. |

### 1.2 Neutral Scales & Constant Border Geometry

To prevent **layout shift (CLS)** when hovering, focusing, or activating elements, all surface cards, list tiles, and input containers maintain a **constant 1.0px border**.

| Token | Light Theme | Dark Theme |
| :--- | :--- | :--- |
| **Canvas Background** | `#F6F8FA` | `#0D1117` |
| **Surface Card** | `#FFFFFF` | `#161B22` |
| **Border / Divider** | `#D0D7DE` | `#30363D` |
| **Primary Text** | `#1F2328` | `#F0F6FC` |
| **Secondary Text** | `#656D76` | `#8B949E` |
| **Muted Monospace** | `#8C959F` | `#6E7681` |

---

## 2. Animated Theme Transitions (`animated_theme_switcher`)

Rather than abruptly flipping theme brightness, CampusManagement integrates `animated_theme_switcher` to create a smooth, circular clip or cross-fade transition between light and dark modes.

### 2.1 Implementation Pattern
Toggles wrap actions inside `ThemeSwitcher.withTheme`:

```dart
ThemeSwitcher.withTheme(
  builder: (context, switcher) => IconButton(
    icon: AppSvgIcon(
      svgString: isDark ? AppSvgIcon.sun : AppSvgIcon.moon,
      size: 18,
      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    ),
    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
    onPressed: () {
      final newTheme = isDark ? AppTheme.lightTheme : AppTheme.darkTheme;
      switcher.changeTheme(theme: newTheme);
    },
  ),
);
```

---

## 3. High-Definition SVG App Logo (`AppLogo`)

The institutional logo (`logo.svg`) is rendered at vector precision:
- **Light Theme**: Renders with rich default brand fills (`#7A1C30` with dark accents).
- **Dark Theme**: Passes through a specialized color matrix or filter inversion:
  ```dart
  ColorFilter.matrix([
    -1,  0,  0, 0, 255, // Invert R
     0, -1,  0, 0, 255, // Invert G
     0,  0, -1, 0, 255, // Invert B
     0,  0,  0, 1,   0, // Preserve Alpha
  ])
  ```
- **Zero Blurriness**: Rendered via vector SVG pipelines rather than rasterized PNG approximations.

---

## 4. Non-Scrollable Viewport Architecture (Login Screen)

Institutional sign-in screens must feel solid, focused, and app-like without awkward scroll bounce or accidental vertical scrolling on laptops and tablets.

- The login viewport wraps the card inside a `FittedBox(fit: BoxFit.scaleDown)`.
- If the screen height is compressed (such as on mobile landscape or split-screen mode), the entire sign-in dialog scales down proportionally to fit the viewport cleanly with **no vertical scrollbars**.
- Verified by automated widget tests:
  ```dart
  expect(
    find.descendant(of: find.byType(LoginScreen), matching: find.byType(SingleChildScrollView)),
    findsNothing,
  );
  ```

---

## 5. Strict Zero-Emoji Vector Icon System (`AppSvgIcon`)

In accordance with institutional UI guidelines, **no Unicode emojis are used in the interface**. All icons are rendered via lightweight, inline SVG strings (`AppSvgIcon`).

### 5.1 Standard Vector Glyphs

| Glyph Name | Constant | Semantic Role |
| :--- | :--- | :--- |
| `qrCode` | `AppSvgIcon.qrCode` | Optical broadcast, rolling QR, scan launcher |
| `attendance` | `AppSvgIcon.attendance` | Attendance rosters, presence status, verification checks |
| `timetable` | `AppSvgIcon.timetable` | Weekly schedule, classroom timetable slots |
| `notice` | `AppSvgIcon.notice` | Targeted administrative broadcasts |
| `shield` | `AppSvgIcon.shield` | Anti-screenshot protection alert, RBAC authority |
| `check` | `AppSvgIcon.check` | Verified attendance badge, completed state |
| `close` | `AppSvgIcon.close` | Session conclusion, modal dismissal |
| `sun` / `moon`| `AppSvgIcon.sun` | Smooth light/dark theme switcher |

---

## 6. Academic Management UI Components & Visual Patterns

The academic administration console (`DepartmentManagementScreen`) provides unified oversight of departments, shared sections, course syllabi, lab batches, and faculty teaching workloads.

### 6.1 Multi-Tab Institutional Hub
The console is structured into four dedicated primary tabs:
1. **Departments**: Overview of academic divisions, department codes, and appointed HODs with drill-down detail views.
2. **Programs & Sections**: Degree programs, cross-program shared lecture sections, student rosters, lab batch partitions, and mobility tools.
3. **Subjects & Syllabus**: Decoupled subject catalog with odd/even term codes, credit weights, and Board of Studies (BoS) syllabus revision histories.
4. **Faculty Workload**: Teaching hour distributions, weekly load progress meters, and overload ceiling warnings.

### 6.2 Specialized Dialogs & Modals
All administrative mutations occur through responsive, validated modal dialogs:
- **Create Department Modal**: Provides reactive search and selection for faculty Head of Department (HOD) appointments.
- **Create Shared Section Modal**: Dynamic multi-select chip selector to assign one or multiple academic degree programs (`prog_ids`) to a single cohort.
- **Section Detail Inspector**: Displays enrolled student roster, interactive lab batch manager, student transfer modal, and cohort merge dialog.
- **Auto-Partition Lab Batches Modal**: Number-stepper selector allowing deterministic round-robin distribution of enrolled students into $N$ balanced practical lab batches.
- **Syllabus Revision Modal**: Full-featured markdown syllabus editor with mandatory Board of Studies (BoS) revision code, approver identity, and justification change notes.
- **Faculty Allocation Dialog**: Subject selector, section picker, component toggle (*Theory* / *Practical* / *Tutorial*), optional lab batch selector, and weekly hours input.

### 6.3 Institutional Workload Indicators & Badges
To prevent faculty burnout and enforce institutional regulations:
- Each faculty card renders an animated `LinearProgressIndicator` showing assigned weekly contact hours against the standard **16-hour limit**.
- **Normal Workload ($\le 16$ hrs)**: Visualized using GitHub Green subtle pills (`#238636`) and clear breakdown chips (Theory vs Practical).
- **Overloaded Workload ($> 16$ hrs)**: Renders a high-contrast danger badge (`#CF222E`) with a warning vector glyph and explicit excess hour counts.

### 6.4 Zero-Emoji Compliance
All academic management screens adhere strictly to the zero-emoji design rule. Academic navigation and actions utilize vector glyphs exclusively:
- Department: `AppSvgIcon.school`
- Subjects / Syllabus: `AppSvgIcon.bookOpen`
- Student Rosters: `AppSvgIcon.userGroup`
- Contact Hours: `AppSvgIcon.clock`
- Student Mobility: `AppSvgIcon.swapHorizontal`
- Cohort Consolidation: `AppSvgIcon.merge`
- Add / Action: `AppSvgIcon.plus`

---

## 7. Desktop-Grade Dropdown Architecture (`AppDropdown`)

Traditional Flutter `DropdownButton` and `DropdownButtonFormField` components use a legacy Android modal design that positions the menu centered directly *over* the anchor trigger, obscuring the clicked button and overflowing screen bounds on desktop and web interfaces.

CampusManagement replaces this with [`AppDropdown<T>`](file:///home/yogesh/Projects/CampusManagement/client/lib/widgets/app_dropdown.dart) and global theme rules:

### 7.1 Dropdown Invariants
1. **Strict Sub-Anchor Placement**: Dropdown menus strictly open **underneath** the trigger (`PopupMenuPosition.under` with an `Offset(0, 4)` gap). The anchor button or combobox field always remains visible above the opened menu.
2. **Width Alignment**: The dropdown menu's width is dynamically constrained to match the anchor field's exact layout width via `LayoutBuilder`.
3. **Bounded Scroll Height**: Menus are capped at `maxHeight: 280` with smooth internal scrollbars to prevent lists from spanning screen borders.
4. **Theme & Hover States**: Rendered with constant 1.0px borders (`AppColors.lightBorder` / `AppColors.darkBorder`), themed surface fills (`#FFFFFF` / `#161B22`), mouse hover highlights, and active selection checkmarks (`AppSvgIcon.check`).
5. **AppBar Persona Dropdown**: The header persona switcher drops down underneath the user pill, displaying avatars, campus handles, archetype badges, and checkmarks without obscuring navigation.
