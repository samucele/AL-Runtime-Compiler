# AL Runtime Compiler

Generate valid Business Central `.app` files at runtime — entirely from AL code, without `alc.exe`.

## What is this?

This is a proof-of-concept BC extension that constructs fully valid `.app` packages (NAVX header + ZIP + metadata) at runtime using only native AL APIs. No external compiler, no DevOps pipeline, no PowerShell — just AL code running inside Business Central.

The generated apps can be downloaded or published directly to the same BC environment via the Extension Management API.

## Why?

The standard BC development workflow requires the AL compiler (`alc.exe`) to produce `.app` files. This project proves that the `.app` format can be constructed programmatically at runtime, opening possibilities for:

- Dynamic extension generation based on user configuration
- Self-modifying BC environments
- Runtime code generation without external tooling
- Understanding the NAVX `.app` format internals

## Architecture

The project is organized into three layers, each with a clear responsibility:

```
src/
├── Compiler/              # Layer 1: Generic .app packaging
│   ├── AppBuilder         # Orchestrates the full build pipeline
│   ├── BinaryWriter       # Writes the 40-byte NAVX binary header
│   ├── ContentGenerator   # Generates all metadata files (manifest, symref, etc.)
│   ├── EnvironmentResolver# Reads BC runtime info (version, platform, dependencies)
│   └── AppPublisher       # Download + publish via Extension Management API
│
├── ObjectBuilder/         # Layer 2: AL object source generation
│   ├── Codeunit/
│   │   ├── ALCodeWriter       # Structured AL source code writer
│   │   ├── TableExtBuilder    # Generates table extension source + symbol reference
│   │   └── PageExtBuilder     # Generates page extension source + symbol reference
│   └── Enum/
│       ├── FieldDataType      # Supported field types (Text, Integer, Decimal, etc.)
│       └── PlacementType      # Page placement options (addlast, addfirst, addafter, addbefore)
│
├── PoC/                   # Layer 3: Proof-of-concept UI
│   ├── Codeunit/
│   │   └── AppBuildRunner     # Business logic for the dashboard
│   ├── Page/
│   │   └── AppBuilderDashboard# Card page UI for configuring and building apps
│   └── Table/
│       └── AppBuilderBuffer   # Temporary table for user input state
│
└── PermissionSet.al       # Permission set for all objects
```

### Layer 1: Compiler

The generic `.app` packager. Knows nothing about specific AL object types — it just packages files into the NAVX format. Key responsibilities:

- **NAVX header**: 40-byte binary header (`NAVX` magic + package GUID + ZIP size)
- **Metadata files**: NavxManifest.xml, SymbolReference.json, DocComments.xml, Content_Types.xml, navigation.xml, MediaIdListing.xml, entitlement XML
- **Environment resolution**: Auto-detects BC version, runtime version, and target platform
- **Integration events**: `OnBeforeBuildApp`, `OnCollectAdditionalFiles`, `OnAfterBuildApp` for extensibility

### Layer 2: ObjectBuilder

Generates AL source code and SymbolReference JSON fragments for specific object types. Currently supports:

- **Table extensions**: Field definitions with configurable data type, length, and option strings
- **Page extensions**: Field controls with configurable placement (addlast/addfirst/addafter/addbefore)

### Layer 3: PoC

A dashboard page that ties everything together. Configure an app name, pick a target table/page, define a field, and generate a working `.app` — all from the BC web client.

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
│  ├─ Flags: 0 (uint32 LE)               │
│  └─ Magic: "NAVX" (4 bytes)            │
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

## Requirements

- Business Central 26.0 or later (runtime 15.0+)
- Cloud (SaaS) or On-Premises environment
- Object ID range: 50100–50199

## Getting Started

1. Clone this repo
2. Open in VS Code with the AL Language extension
3. Download symbols from your BC environment
4. Publish to your BC sandbox
5. Search for **App Builder Dashboard** in the BC web client
6. Configure your extension and click **Generate App**

## Limitations

This is a proof-of-concept. Current limitations:

- Only generates table extensions and page extensions (single field each)
- No support for codeunits, reports, enums, or other object types in generated apps
- No code signing (generated apps require `-skipVerification` for container deployment)
- No validation of generated AL source against BC metadata
- Field lookup is basic — no filtering by field type compatibility

## License

MIT
