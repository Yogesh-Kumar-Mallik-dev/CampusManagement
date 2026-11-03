# Enterprise Design Rules & Aesthetic Guidelines

## 1. Brand Identity & Color Hierarchy
* **Primary Color (Wine Red):** `#7A1C30` (Pantone 209 C / Deep Burgundy).
  - Used for institutional headers, brand landmarks, primary navigation rails, and core identity badges.
  - Dark Shade: `#581120`, Light/Hover Shade: `#96243D`, Subtle Surface Tint: `#FDF2F4`.
* **Accent Color (GitHub Green):** `#238636` (GitHub Actions Green).
  - Used for call-to-action buttons, active statuses, present attendance marks, successful sync pills, and affirmative action states.
  - Hover Shade: `#2EA44F`, Subtle Tint: `#E6F7EC`, Text Accent: `#1A7F37`.
* **Neutral Surface System (ERP Precision):**
  - Light Background: `#F8FAFC` (Clean Slate).
  - Light Surface: `#FFFFFF` with crisp 1px borders (`#E2E8F0` / `#CBD5E1`).
  - Dark Background: `#0D1117` (GitHub Dark).
  - Dark Surface: `#161B22` with borders (`#30363D`).

---

## 2. Strict Iconography Rules (Zero Emoji Policy)
* **NO Consumer Emojis:** Do NOT use consumer emojis (e.g., 🏛️, 🚀, 📅, 📱, ❌, ✅, ⚠️, 🧑‍🏫, etc.) anywhere in the UI, headers, tables, dialogs, or snackbars.
* **Vector SVG Iconography:** All icons must be clean, geometric SVG vector icons conforming to enterprise ERP standards (referencing Lucide, Octicons, and SAP Fiori).
* Icons must maintain a consistent 1.5px–2px stroke width and accept contextual foreground colors (`colorScheme.onSurface`, `primary`, or `githubGreen`).

---

## 3. Real-World ERP Reference & Layout Density
* **Layout Structure:**
  - High data density inspired by **Workday**, **SAP S/4HANA**, **Canvas LMS**, and **GitHub Enterprise**.
  - No decorative gradients or cartoonish shadows.
  - Subtle 1px structural dividing lines instead of heavy drop shadows.
  - Crisp border radii: `6px` to `10px` for buttons, cards, and inputs.
* **Status Badges & Monospaced Data:**
  - IDs, Roll Numbers, Timetable Hours, and Room Numbers use tabular numbers (`tnum`) or monospaced font features for precision scanning.
  - Status indicators follow standard enterprise pill design: `[● Active]`, `[● Present]`, `[● High Priority]`.

---

## 4. Theme Modes
* The application must support a refined, modern **Light Mode** as the primary enterprise view, alongside a high-contrast **Dark Mode**.
* Light mode must provide sufficient contrast ratio (WCAG AA compliant: minimum 4.5:1 for normal text).
