---
name: mfc-ui-modernization
description: Improves and reviews MFC/Win32 UI in the Playasa/SPlayer codebase. Use when enhancing MFC dialogs, controls, toolbars, skins, themes, high-DPI behavior, accessibility, owner-draw painting, resources, or user-facing desktop UI without replacing the existing MFC architecture.
---

# MFC UI Modernization

## Purpose

Use this skill for focused UI improvements in the Playasa/SPlayer MFC desktop app. The goal is to improve polish, usability, high-DPI behavior, theming, and maintainability while preserving the existing Win32/MFC/DirectShow architecture.

## Project Context

- Main UI code lives under `src/Source/apps/mplayerc/`.
- Important UI areas include `MainFrm.*`, `ChildView.*`, `PlayerToolBar.*`, `PlayerToolTopBar.*`, `PlayerFloatToolBar.*`, `SVPSliderCtrl.*`, `VolumeCtrl.*`, `SUIButton.*`, `SkinPreviewDlg.*`, `UserInterface/Dialogs/`, `UserInterface/Renderer/`, and `Model/ThemePkg.*`.
- Resources and dialogs may be in `.rc`, `resource.h`, bitmap/icon assets, and project filters.
- Build and output layout must follow `.spec/rfc/completed/rfc-0011-windows-repository-layout.md`.
- Do not introduce a new UI framework unless the user explicitly asks for a separate migration RFC.

## Workflow

1. Identify the exact UI surface: dialog, toolbar, custom control, menu, skin asset, theme color, layout, or resource.
2. Read the local implementation and nearby similar controls before editing.
3. Prefer small, reversible changes: layout constants, helper functions, paint logic, theme lookup, DPI scaling, resource cleanup, or focused class extraction.
4. Preserve MFC message-map patterns, resource IDs, Unicode behavior, and existing COM/player lifecycle assumptions.
5. Add or update comments only where painting/layout/theme behavior is not obvious.
6. Validate with the smallest useful build first, then broader app build if shared UI infrastructure changed.

## UI Enhancement Checklist

- Layout scales from constants or DPI-aware helpers instead of raw repeated magic numbers.
- Colors, fonts, and icons come from existing theme/skin mechanisms when available.
- Custom painting handles background erase, disabled state, hover/pressed/focused states, and double buffering where relevant.
- Text is not clipped at common DPI settings and supports longer localized strings.
- Keyboard navigation, focus cues, accelerators, and default buttons remain usable.
- Changes do not block media playback, DirectShow graph lifecycle, or main-frame message routing.
- Resource IDs are unique and project files include any new `.rc`, bitmap, icon, or source entries.

## Preferred Patterns

- Prefer pure helper functions for geometry, color selection, and state mapping.
- Prefer local constants with descriptive names over inline string or numeric literals.
- Prefer extending existing theme classes before adding new global UI state.
- Prefer owner-draw fixes inside the relevant control class rather than scattering paint logic through parent dialogs.
- For large dialogs, improve one coherent section at a time instead of redesigning the whole surface.

## Avoid

- Replacing MFC with Qt, WinUI, WPF, webviews, or React as part of a small UI polish task.
- Rewriting resource files by hand without checking existing ID conventions.
- Adding dependencies for simple drawing/layout changes.
- Changing playback, updater, network, or parser behavior while working on UI polish.
- Hiding rendering bugs with broad invalidation loops or timers; fix paint invalidation and state ownership at the source.

## Verification

For narrow UI edits, build the owning project or `mplayerc_vs2005.vcxproj` configuration that contains the changed files. For shared UI controls, theme code, resources, or project-file changes, run the full `src/splayer.sln` build when practical.

When runtime verification is needed, launch `out/bin/Win32/Release Unicode/splayer.exe` or the relevant built configuration and smoke-test the changed surface manually.
