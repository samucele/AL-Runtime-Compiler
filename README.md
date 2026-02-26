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

The project is organized into three layers, each with a clear responsibility, plus a dedicated test project.

```
app/                               # Main extension
└── src/
    ├── Compiler/                  # Layer 1: Generic .app packaging
    │   ├── AppBuilder             (50100) Build pipeline orchestrator
    │   ├── ContentGenerator       (50101) Metadata file generation
    │   ├── BinaryWriter           (50102) NAVX binary header
    │   ├── EnvironmentResolver    (50103) BC runtime info detection
    │   └── AppPublisher           (50110) Download + publish via UploadExtension
    │
    ├── ObjectBuilder/             # Layer 2: AL source generation
    │   ├── Codeunit/
    │   │   ├── ALCodeWriter       (50104) Structured AL syntax builder
    │   │   ├── TableExtBuilder    (50105) Table extension source + symref
    │   │   └── PageExtBuilder     (50106) Page extension source + symref
    │   └── Enum/
    │       ├── FieldDataType      (50107) Text, Code, Integer, Decimal, etc.
    │       └── PlacementType      (50108) addafter, addbefore
    │
    ├── PoC/                       # Layer 3: Proof-of-concept UI
    │   ├── AppBuildRunner         (50114) Wizard workflow orchestrator
    │   ├── AppBuilderBuffer       (50113) Temporary table for wizard state
    │   ├── AppBuilderWizard       (50111) 4-step NavigatePage wizard
    │   ├── PageLookup             (50116) Page Metadata lookup
    │   └── PageControlLookup      (50117) Anchor control lookup
    │
    └── PermissionSet              (50112) Execute on all objects

test/                              # Test extension (depends on main app)
└── src/                           # ID range 50150-50199
    ├── UnitTests              (50150) ALCodeWriter + BinaryWriter
    ├── IntegrationTests       (50160) TableExtBuilder + PageExtBuilder
    ├── ScenarioTests          (50170) Full pipeline + wizard validation
    └── EdgeCaseTests          (50180) Errors + boundaries + all types
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

## Testing

The project includes a comprehensive test suite with 83 tests across 4 test codeunits, all passing.

### Test Structure

Test project located in `test/` folder, uses ID range 50150-50199, depends on main app + Library Assert.

**Codeunit 50150 "ARC Unit Tests"** — 24 tests
- ALCodeWriter: Object/block/field/property formatting, indentation, reset
- BinaryWriter: HexToSignedInt32, GuidToLEIntegers

**Codeunit 50160 "ARC Integration Tests"** — 21 tests
- TableExtBuilder: Text/Integer/Code/Option fields, SymRef JSON, source file path, entitlement code, multiple fields, reset
- PageExtBuilder: addafter/addbefore, quoted anchors, SymRef JSON with ControlChanges, multiple fields

**Codeunit 50170 "ARC Scenario Tests"** — 12 tests
- Full AppBuilder pipeline (SetMetadata → AddSource → Build → verify blob)
- NAVX header magic bytes verification
- PreviewCode
- ValidateStep progression
- Multi-field and option field scenarios

**Codeunit 50180 "ARC Edge Case Tests"** — 26 tests
- Validation errors (missing target/objectId/fields)
- Boundary values (min/max int32, zero, -1)
- All 8 field data types
- Default lengths

### Running Tests

```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'admin' -AsPlainText -Force))

# Run individual test suites
Run-TestsInBcContainer -containerName [container] -credential $cred -testCodeunit 50150  # Unit
Run-TestsInBcContainer -containerName [container] -credential $cred -testCodeunit 50160  # Integration
Run-TestsInBcContainer -containerName [container] -credential $cred -testCodeunit 50170  # Scenario
Run-TestsInBcContainer -containerName [container] -credential $cred -testCodeunit 50180  # Edge Case
```

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
