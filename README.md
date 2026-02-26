# AL Runtime Compiler

Generate valid Business Central `.app` files at runtime — entirely from AL code, without `alc.exe`.

Built entirely with [Claude Code](https://claude.com/claude-code).

## What is this?

This is a proof-of-concept BC extension that constructs fully valid `.app` packages (NAVX header + ZIP + metadata) at runtime using only native AL codeunits and data types. No external compiler, no DevOps pipeline, no PowerShell — just AL code running inside Business Central.

The project packages table extensions and page extensions into fully valid NAVX .app files. Generated apps can be downloaded or published directly to the same BC environment using `ExtensionManagement.UploadExtension`.

## Why?

The standard BC development workflow requires the AL compiler (`alc.exe`) to produce `.app` files. This project proves that the `.app` format can be constructed programmatically at runtime, opening possibilities for:

- Dynamic extension generation based on user configuration
- Self-modifying BC environments
- Runtime code generation without external tooling
- Understanding the NAVX `.app` format internals

Inspired by Erik Hougaard's [Simple Object Designer](https://youtu.be/wOOGFP-6XEk), which demonstrated that runtime compilation in BC is possible. This project replicates and explores that capability from scratch.

## Architecture

The project is organized into three layers, each with a clear responsibility. Total: 16 AL files across 3 layers.

```
src/
├── Compiler/              # Layer 1: Generic .app packaging (5 codeunits)
│   ├── AppBuilder.Codeunit.al (50100)
│   │     Orchestrates the full build pipeline. Accumulates source files,
│   │     SymRef fragments, and entitlement entries, then produces a valid
│   │     .app blob with NAVX header. Integration events: OnBeforeBuildApp,
│   │     OnCollectAdditionalFiles, OnAfterBuildApp.
│   ├── ContentGenerator.Codeunit.al (50101)
│   │     Generates all metadata files: NavxManifest.xml, [Content_Types].xml,
│   │     SymbolReference.json, DocComments.xml, navigation.xml,
│   │     MediaIdListing.xml, entitlement XML. Handles encoding (BOM/no-BOM)
│   │     and line endings per NAVX spec.
│   ├── BinaryWriter.Codeunit.al (50102)
│   │     Writes the 40-byte NAVX binary header. Handles GUID-to-little-endian
│   │     integer conversion.
│   ├── EnvironmentResolver.Codeunit.al (50103)
│   │     Reads BC runtime info: auto-detects application version, runtime
│   │     version, target platform (Cloud/OnPremises), and builds dependency
│   │     XML from installed app metadata.
│   └── AppPublisher.Codeunit.al (50110)
│         Downloads .app via browser (DownloadFromStream) and publishes via
│         ExtensionManagement.UploadExtension. Queries deployment status.
│
├── ObjectBuilder/         # Layer 2: AL object source generation (3 codeunits + 2 enums)
│   ├── Codeunit/
│   │   ├── ALCodeWriter.Codeunit.al (50104)
│   │   │     Structured AL syntax builder that produces well-formatted AL
│   │   │     source code using TextBuilder with indent tracking and LF-only
│   │   │     line endings. Supports objects, blocks, fields, page fields,
│   │   │     properties.
│   │   ├── TableExtBuilder.Codeunit.al (50105)
│   │   │     Generates table extension AL source code and SymbolReference
│   │   │     JSON fragments. Supports multiple field types.
│   │   └── PageExtBuilder.Codeunit.al (50106)
│   │         Generates page extension AL source code and SymbolReference
│   │         JSON. Supports configurable placement (addafter/addbefore)
│   │         with field-level anchors.
│   └── Enum/
│       ├── FieldDataType.Enum.al (50107)
│       │     Text, Code, Integer, Decimal, Boolean, Date, DateTime, Option
│       └── PlacementType.Enum.al (50108)
│             addafter (value 0), addbefore (value 1). Only field-level
│             anchors from the Page Control Field virtual table.
│
├── PoC/                   # Layer 3: Proof-of-concept UI (1 codeunit + 1 table + 3 pages)
│   ├── Codeunit/
│   │   └── AppBuildRunner.Codeunit.al (50114)
│   │         Orchestrates the app build workflow. Delegates to ObjectBuilder
│   │         and Compiler layers. Validates wizard steps (1-3), handles
│   │         generation, download, publish. Has OpenDeploymentStatus
│   │         notification callback.
│   ├── Table/
│   │   └── AppBuilderBuffer.Table.al (50113)
│   │         Temporary table for wizard state. Fields: App Name, Publisher,
│   │         Version (Major/Minor/Build/Revision), Target Table/Page (with
│   │         resolved names and App Package IDs), Field definition (Id, Name,
│   │         Data Type, Length, Option String), Placement (Type, Anchor
│   │         Control), Object IDs (Table Ext, Page Ext). OnValidate triggers
│   │         resolve table/page names from AllObjWithCaption and Page Metadata.
│   └── Page/
│       ├── AppBuilderWizard.Page.al (50111)
│       │     4-step NavigatePage wizard:
│       │     - Step 1 (Extension Identity): App Name, Publisher, Version
│       │     - Step 2 (Target Selection): Target Table (lookup from Table
│       │       Objects), Target Page (custom OnLookup filtering Page Metadata
│       │       by SourceTable), Advanced: Object IDs
│       │     - Step 3 (Field & Placement): Field ID, Field Name, Field Data
│       │       Type (conditional: Field Length for Text/Code, Option String
│       │       for Option), Placement Type, Anchor Control (custom OnLookup
│       │       filtering Page Control Field by page)
│       │     - Step 4 (Review & Build): Read-only review of all inputs,
│       │       actions: Download App (auto-generates then downloads),
│       │       Publish App (auto-generates then publishes with Notification
│       │       for deployment status), Extension Deployment Status
│       │     Back/Next actions use Visible (hide when not applicable), not
│       │     Enabled
│       ├── PageLookup.Page.al (50116)
│       │     List page for Page Metadata (ID, Name, Caption, SourceTable).
│       └── PageControlLookup.Page.al (50117)
│             List page for Page Control Field (Sequence, ControlName),
│             caption "Select Anchor Control".
│
└── PermissionSet.al (50112)
      Grants execute on all codeunits, RIMD on buffer tabledata, execute
      on all pages.
```

### Layer 1: Compiler

The generic `.app` packager. Knows nothing about specific AL object types — it just packages files into the NAVX format. Key responsibilities:

- **NAVX header**: 40-byte binary header (`NAVX` magic + package GUID + ZIP size)
- **Metadata files**: NavxManifest.xml, SymbolReference.json, DocComments.xml, [Content_Types].xml, navigation.xml, MediaIdListing.xml, entitlement XML
- **Environment resolution**: Auto-detects BC version, runtime version, and target platform
- **Integration events**: `OnBeforeBuildApp`, `OnCollectAdditionalFiles`, `OnAfterBuildApp` for extensibility

### Layer 2: ObjectBuilder

Generates AL source code and SymbolReference JSON fragments for specific object types. Currently supports:

- **Table extensions**: Field definitions with configurable data type, length, and option strings
- **Page extensions**: Field controls with configurable placement (addafter/addbefore with field-level anchors)

Uses a fluent builder pattern: TableExtBuilder and PageExtBuilder use SetTarget/SetObjectId/AddField/SetPlacement methods.

### Layer 3: PoC

A 4-step NavigatePage wizard that ties everything together. Configure an app name, pick a target table/page, define a field, and generate a working `.app` — all from the BC web client.

## The NAVX .app Format

A `.app` file is simply a **40-byte binary header** followed by a **standard ZIP archive**:

```
┌──────────────────────────────────────────┐
│ NAVX Header (40 bytes)                   │
│  ├─ Magic: "NAVX" (4 bytes)             │
│  ├─ Header size: 40 (uint32 LE)         │
│  ├─ Version: 2 (uint32 LE)              │
│  ├─ Package GUID (16 bytes)             │
│  ├─ ZIP size (uint32 LE)                │
│  ├─ Flags: 0 (uint32 LE)                │
│  └─ Magic: "NAVX" (4 bytes)             │
├──────────────────────────────────────────┤
│ ZIP Archive                              │
│  ├─ NavxManifest.xml                    │
│  ├─ [Content_Types].xml                 │
│  ├─ SymbolReference.json                │
│  ├─ DocComments.xml                     │
│  ├─ navigation.xml                      │
│  ├─ MediaIdListing.xml                  │
│  ├─ entitlement/{appid}.xml             │
│  └─ src/**/*.al                         │
└──────────────────────────────────────────┘
```

All integers are little-endian uint32. The header GUID is a **package GUID** (random per build), NOT the App Id from manifest.

### Encoding Rules

These are critical — BC will reject the app if encoding is wrong:

| File | BOM | Line endings |
|------|-----|-------------|
| NavxManifest.xml | No BOM | LF |
| DocComments.xml | No BOM | LF |
| AL source files (.al) | No BOM | LF |
| [Content_Types].xml | UTF-8 BOM | Single line |
| SymbolReference.json | UTF-8 BOM | Single line |
| navigation.xml | UTF-8 BOM | CRLF |
| MediaIdListing.xml | UTF-8 BOM | CRLF |
| entitlement/*.xml | UTF-8 BOM | CRLF |

## Key Design Decisions

- **Layer separation**: Compiler knows nothing about specific object types. ObjectBuilder generates source + symref. PoC ties it together.
- **Integration events**: App Builder exposes OnBeforeBuildApp, OnCollectAdditionalFiles, OnAfterBuildApp for extensibility.
- **Fluent builder pattern**: TableExtBuilder and PageExtBuilder use SetTarget/SetObjectId/AddField/SetPlacement pattern.
- **Environment auto-detection**: EnvironmentResolver reads Base Application version at runtime, maps to runtime version (major - 11), detects SaaS vs OnPrem.
- **SaaS-only publish**: Uses ExtensionManagement.UploadExtension which handles unsigned extensions on SaaS. Not available on-prem/Docker.

## Requirements

- Business Central 27.0 or later (runtime 16.0+)
- **Cloud (SaaS) environment** — the publish feature uses `ExtensionManagement.UploadExtension`, which is only available on SaaS. On-premises and Docker containers do not support runtime extension upload. You can still download the generated `.app` file, but that defeats the purpose.
- Object ID range: 50100-50199

## Getting Started

1. Clone this repo
2. Open in VS Code with the AL Language extension
3. Download symbols from your BC environment (BC 27.0+)
4. Publish to your BC sandbox
5. Search for **App Builder Wizard** in the BC web client
6. Walk through the 4-step wizard:
   - Step 1: Name your extension (App Name, Publisher, Version)
   - Step 2: Pick a target table and page
   - Step 3: Define a field (ID, Name, Data Type, Placement)
   - Step 4: Review and build (Download or Publish)

## Limitations

This is a proof-of-concept. Current limitations:

- Only generates table extensions and page extensions (single field each per build)
- No support for codeunits, reports, enums, or other object types in generated apps
- No code signing (generated apps are unsigned)
- SaaS-only for publish — `ExtensionManagement.UploadExtension` is not available on-premises or Docker
- Anchor control lookup shows only field-level controls (not structural controls like Areas, Groups, Repeaters)
- No validation of generated AL source against BC metadata
- Single field per extension (the ObjectBuilder layer supports multiple fields, but the PoC wizard only configures one)

## License

MIT
