/// <summary>
/// Generates all metadata files required for a valid .app package.
/// Fully parameterized -- no hardcoded app identity or environment values.
/// Handles encoding (BOM/no-BOM) and line endings per the NAVX format specification.
/// </summary>
codeunit 50101 "Content Generator"
{
    Access = Public;

    var
        CrLf: Text[2];

    /// <summary>
    /// Generates NavxManifest.xml (UTF-8, NO BOM, LF line endings).
    /// </summary>
    /// <param name="AppId">The unique app identifier GUID.</param>
    /// <param name="AppName">The display name of the app.</param>
    /// <param name="Publisher">The publisher name.</param>
    /// <param name="AppVersion">The app version string (e.g., '1.0.0.0').</param>
    /// <param name="ApplicationVersion">The BC application version (e.g., '27.0.0.0').</param>
    /// <param name="RuntimeVersion">The AL runtime version (e.g., '17.0').</param>
    /// <param name="TargetPlatform">The target platform ('Cloud' or 'OnPremises').</param>
    /// <param name="MinObjectId">The minimum object ID in the ID range.</param>
    /// <param name="MaxObjectId">The maximum object ID in the ID range.</param>
    /// <param name="DependencyXml">The dependency XML fragment (e.g., '<Dependencies />' or full dependency block).</param>
    /// <param name="TempBlob">Output blob containing the generated XML.</param>
    procedure GenerateManifest(AppId: Guid; AppName: Text; Publisher: Text; AppVersion: Text;
        ApplicationVersion: Text; RuntimeVersion: Text; TargetPlatform: Text;
        MinObjectId: Integer; MaxObjectId: Integer; DependencyXml: Text;
        var TempBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
        TB: TextBuilder;
        Lf: Text[1];
        AppIdText: Text;
        BuildTimestamp: Text;
    begin
        Lf := GetLf();
        AppIdText := FormatGuidNoBraces(AppId);
        BuildTimestamp := Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>.0000000Z');

        TB.Append('<Package xmlns="http://schemas.microsoft.com/navx/2015/manifest">');
        TB.Append(Lf);
        TB.Append('  <App Id="');
        TB.Append(AppIdText);
        TB.Append('" Name="');
        TB.Append(AppName);
        TB.Append('" Publisher="');
        TB.Append(Publisher);
        TB.Append('" Brief="');
        TB.Append(AppName);
        TB.Append('" Description="');
        TB.Append(AppName);
        TB.Append('" Version="');
        TB.Append(AppVersion);
        TB.Append('" CompatibilityId="0.0.0.0"');
        TB.Append(' PrivacyStatement="" EULA="" Help="" HelpBaseUrl="" Url="" Logo=""');
        TB.Append(' Platform="1.0.0.0"');
        TB.Append(' Application="');
        TB.Append(ApplicationVersion);
        TB.Append('" Runtime="');
        TB.Append(RuntimeVersion);
        TB.Append('" Target="');
        TB.Append(TargetPlatform);
        TB.Append('" ShowMyCode="True" />');
        TB.Append(Lf);
        TB.Append('  <IdRanges>');
        TB.Append(Lf);
        TB.Append('    <IdRange MinObjectId="');
        TB.Append(Format(MinObjectId));
        TB.Append('" MaxObjectId="');
        TB.Append(Format(MaxObjectId));
        TB.Append('" />');
        TB.Append(Lf);
        TB.Append('  </IdRanges>');
        TB.Append(Lf);
        TB.Append('  ');
        TB.Append(DependencyXml);
        TB.Append(Lf);
        TB.Append('  <InternalsVisibleTo />');
        TB.Append(Lf);
        TB.Append('  <ScreenShots />');
        TB.Append(Lf);
        TB.Append('  <SupportedLocales />');
        TB.Append(Lf);
        TB.Append('  <Features>');
        TB.Append(Lf);
        TB.Append('    <Feature>NOIMPLICITWITH</Feature>');
        TB.Append(Lf);
        TB.Append('    <Feature>NOPROMOTEDACTIONPROPERTIES</Feature>');
        TB.Append(Lf);
        TB.Append('  </Features>');
        TB.Append(Lf);
        TB.Append('  <PreprocessorSymbols />');
        TB.Append(Lf);
        TB.Append('  <SuppressWarnings />');
        TB.Append(Lf);
        TB.Append('  <ResourceExposurePolicy AllowDebugging="true" AllowDownloadingSource="true"');
        TB.Append(' IncludeSourceInSymbolFile="true" ApplyToDevExtension="false" />');
        TB.Append(Lf);
        TB.Append('  <KeyVaultUrls />');
        TB.Append(Lf);
        TB.Append('  <Source />');
        TB.Append(Lf);
        TB.Append('  <Build By="AL Runtime Compiler,1.0.0" Timestamp="');
        TB.Append(BuildTimestamp);
        TB.Append('" CompilerVersion="');
        TB.Append(RuntimeVersion);
        TB.Append('.0.0" />');
        TB.Append(Lf);
        TB.Append('  <AlternateIds />');
        TB.Append(Lf);
        TB.Append('</Package>');

        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(TB.ToText());
    end;

    /// <summary>
    /// Generates [Content_Types].xml (UTF-8, WITH BOM, single line).
    /// This file is static -- it declares the content types for xml, al, and json files.
    /// </summary>
    /// <param name="TempBlob">Output blob containing the generated XML.</param>
    procedure GenerateContentTypes(var TempBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
        TB: TextBuilder;
    begin
        TB.Append('<?xml version="1.0" encoding="utf-8"?>');
        TB.Append('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
        TB.Append('<Default Extension="xml" ContentType="" />');
        TB.Append('<Default Extension="al" ContentType="" />');
        TB.Append('<Default Extension="json" ContentType="" />');
        TB.Append('</Types>');

        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        WriteBom(OutStr);
        OutStr.WriteText(TB.ToText());
    end;

    /// <summary>
    /// Generates SymbolReference.json (UTF-8, WITH BOM).
    /// Builds the root JSON structure with all standard arrays, then merges fragments
    /// from the provided JsonObject. Keys in SymRefFragments map to array names
    /// (e.g., 'TableExtensions', 'PageExtensions'). Values are JsonArrays of fragment objects.
    /// Arrays not present in fragments remain empty.
    /// </summary>
    /// <param name="AppId">The unique app identifier GUID.</param>
    /// <param name="AppName">The display name of the app.</param>
    /// <param name="Publisher">The publisher name.</param>
    /// <param name="AppVersion">The app version string.</param>
    /// <param name="RuntimeVersion">The AL runtime version.</param>
    /// <param name="SymRefFragments">JsonObject where keys are array names and values are JsonArrays of fragments.</param>
    /// <param name="TempBlob">Output blob containing the generated JSON.</param>
    procedure GenerateSymbolReference(AppId: Guid; AppName: Text; Publisher: Text;
        AppVersion: Text; RuntimeVersion: Text;
        SymRefFragments: JsonObject;
        var TempBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
        Root: JsonObject;
        Namespaces: JsonArray;
        Ns: JsonObject;
    begin
        // Build the Namespaces[0] object with all standard arrays
        Ns := BuildNamespaceObject(SymRefFragments);

        Namespaces.Add(Ns);

        // Build root object
        Root.Add('RuntimeVersion', RuntimeVersion);
        Root.Add('Namespaces', Namespaces);
        AddArrayToObject(Root, 'Codeunits', SymRefFragments);
        AddArrayToObject(Root, 'Reports', SymRefFragments);
        AddArrayToObject(Root, 'XmlPorts', SymRefFragments);
        AddArrayToObject(Root, 'Queries', SymRefFragments);
        AddArrayToObject(Root, 'ControlAddIns', SymRefFragments);
        AddArrayToObject(Root, 'EnumTypes', SymRefFragments);
        AddArrayToObject(Root, 'DotNetPackages', SymRefFragments);
        AddArrayToObject(Root, 'Interfaces', SymRefFragments);
        AddArrayToObject(Root, 'PermissionSets', SymRefFragments);
        AddArrayToObject(Root, 'PermissionSetExtensions', SymRefFragments);
        AddArrayToObject(Root, 'ReportExtensions', SymRefFragments);
        AddArrayToObject(Root, 'TableExtensions', SymRefFragments);
        AddArrayToObject(Root, 'PageExtensions', SymRefFragments);
        AddEmptyArray(Root, 'InternalsVisibleToModules');
        Root.Add('AppId', FormatGuidNoBraces(AppId));
        Root.Add('Name', AppName);
        Root.Add('Publisher', Publisher);
        Root.Add('Version', AppVersion);

        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        WriteBom(OutStr);
        Root.WriteTo(OutStr);
    end;

    /// <summary>
    /// Generates DocComments.xml (UTF-8, NO BOM, LF line endings).
    /// </summary>
    /// <param name="AppId">The unique app identifier GUID.</param>
    /// <param name="AppName">The display name of the app.</param>
    /// <param name="Publisher">The publisher name.</param>
    /// <param name="AppVersion">The app version string.</param>
    /// <param name="TempBlob">Output blob containing the generated XML.</param>
    procedure GenerateDocComments(AppId: Guid; AppName: Text; Publisher: Text;
        AppVersion: Text; var TempBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
        TB: TextBuilder;
        Lf: Text[1];
    begin
        Lf := GetLf();

        TB.Append('<?xml version="1.0"?>');
        TB.Append(Lf);
        TB.Append('<doc>');
        TB.Append(Lf);
        TB.Append('    <application>');
        TB.Append(Lf);
        TB.Append('        <id>');
        TB.Append(FormatGuidNoBraces(AppId));
        TB.Append('</id>');
        TB.Append(Lf);
        TB.Append('        <name>');
        TB.Append(AppName);
        TB.Append('</name>');
        TB.Append(Lf);
        TB.Append('        <publisher>');
        TB.Append(Publisher);
        TB.Append('</publisher>');
        TB.Append(Lf);
        TB.Append('        <version>');
        TB.Append(AppVersion);
        TB.Append('</version>');
        TB.Append(Lf);
        TB.Append('    </application>');
        TB.Append(Lf);
        TB.Append('    <members />');
        TB.Append(Lf);
        TB.Append('</doc>');
        TB.Append(Lf);

        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(TB.ToText());
    end;

    /// <summary>
    /// Generates navigation.xml (UTF-8, WITH BOM, CRLF line endings).
    /// This file is static -- extensions have empty navigation.
    /// </summary>
    /// <param name="TempBlob">Output blob containing the generated XML.</param>
    procedure GenerateNavigation(var TempBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
        TB: TextBuilder;
    begin
        InitCrLf();

        TB.Append('<?xml version="1.0" encoding="utf-8"?>');
        TB.Append(CrLf);
        TB.Append('<NavigationDefinition xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
        TB.Append(' xmlns:xsd="http://www.w3.org/2001/XMLSchema"');
        TB.Append(' xmlns="urn:schemas-microsoft-com:dynamics:NAV:MetaObjects">');
        TB.Append(CrLf);
        TB.Append('  <ActionContainers ActionContainerType="Departments" />');
        TB.Append(CrLf);
        TB.Append('</NavigationDefinition>');

        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        WriteBom(OutStr);
        OutStr.WriteText(TB.ToText());
    end;

    /// <summary>
    /// Generates MediaIdListing.xml (UTF-8, WITH BOM, CRLF line endings).
    /// This file is static -- extensions have empty media listings.
    /// </summary>
    /// <param name="TempBlob">Output blob containing the generated XML.</param>
    procedure GenerateMediaIdListing(var TempBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
        TB: TextBuilder;
    begin
        InitCrLf();

        TB.Append('<MediaIdListing xmlns="http://schemas.microsoft.com/navx/2016/mediaidlisting">');
        TB.Append(CrLf);
        TB.Append('  <MediaSetIds />');
        TB.Append(CrLf);
        TB.Append('</MediaIdListing>');

        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        WriteBom(OutStr);
        OutStr.WriteText(TB.ToText());
    end;

    /// <summary>
    /// Generates the entitlement XML file (UTF-8, WITH BOM, CRLF line endings).
    /// Iterates parallel lists of TypeCodes and ObjectIds to generate Permission entries.
    /// Type 9 = TableExtension, Type 8 = PageExtension, Type 5 = Codeunit, etc.
    /// Value 16 = Execute permission.
    /// </summary>
    /// <param name="AppId">The unique app identifier GUID.</param>
    /// <param name="TypeCodes">List of BC entitlement type codes.</param>
    /// <param name="ObjectIds">List of AL object IDs (parallel with TypeCodes).</param>
    /// <param name="TempBlob">Output blob containing the generated XML.</param>
    procedure GenerateEntitlement(AppId: Guid;
        TypeCodes: List of [Integer]; ObjectIds: List of [Integer];
        var TempBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
        TB: TextBuilder;
        i: Integer;
        TypeCode: Integer;
        ObjectId: Integer;
    begin
        InitCrLf();

        TB.Append('<?xml version="1.0" encoding="utf-8"?>');
        TB.Append(CrLf);
        TB.Append('<Entitlement MetadataVersion="130000" Name="');
        TB.Append(FormatGuidNoBraces(AppId));
        TB.Append('" Type="Implicit" xmlns="urn:schemas-microsoft-com:dynamics:NAV:MetaObjects">');
        TB.Append(CrLf);
        TB.Append('  <ObjectEntitlements>');
        TB.Append(CrLf);

        for i := 1 to TypeCodes.Count() do begin
            TypeCodes.Get(i, TypeCode);
            ObjectIds.Get(i, ObjectId);
            TB.Append('    <Permission Type="');
            TB.Append(Format(TypeCode));
            TB.Append('" ID="');
            TB.Append(Format(ObjectId));
            TB.Append('" Value="16" />');
            TB.Append(CrLf);
        end;

        TB.Append('  </ObjectEntitlements>');
        TB.Append(CrLf);
        TB.Append('</Entitlement>');

        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        WriteBom(OutStr);
        OutStr.WriteText(TB.ToText());
    end;

    /// <summary>
    /// Returns the ZIP path for the entitlement file.
    /// Format: 'entitlement/{guid-lowercase-no-braces}.xml'
    /// </summary>
    /// <param name="AppId">The unique app identifier GUID.</param>
    /// <returns>The entitlement file path within the ZIP archive.</returns>
    procedure GetEntitlementPath(AppId: Guid): Text
    begin
        exit('entitlement/' + FormatGuidNoBraces(AppId) + '.xml');
    end;

    /// <summary>
    /// Removes non-alphanumeric characters from a name to produce a safe identifier.
    /// Used for file paths and internal names.
    /// </summary>
    /// <param name="Name">The name to sanitize.</param>
    /// <returns>The sanitized name containing only A-Z, a-z, 0-9.</returns>
    procedure SanitizeName(Name: Text): Text
    var
        Result: TextBuilder;
        i: Integer;
        c: Char;
    begin
        for i := 1 to StrLen(Name) do begin
            c := Name[i];
            case true of
                (c >= 'A') and (c <= 'Z'),
                (c >= 'a') and (c <= 'z'),
                (c >= '0') and (c <= '9'):
                    Result.Append(Format(c));
            end;
        end;
        exit(Result.ToText());
    end;

    /// <summary>
    /// Formats a target object reference for SymbolReference JSON.
    /// Format: '#guid-no-dashes-lowercase#ObjectName'
    /// </summary>
    /// <param name="AppPackageId">The app package ID owning the target object.</param>
    /// <param name="ObjectName">The name of the target object.</param>
    /// <returns>The formatted target object reference string.</returns>
    procedure FormatTargetObject(AppPackageId: Guid; ObjectName: Text): Text
    var
        GuidStr: Text;
    begin
        GuidStr := LowerCase(DelChr(Format(AppPackageId, 0, 9), '=', '{}-'));
        exit('#' + GuidStr + '#' + ObjectName);
    end;

    local procedure BuildNamespaceObject(SymRefFragments: JsonObject): JsonObject
    var
        Ns: JsonObject;
    begin
        AddArrayToObject(Ns, 'Namespaces', SymRefFragments);
        AddArrayToObject(Ns, 'Codeunits', SymRefFragments);
        AddArrayToObject(Ns, 'Pages', SymRefFragments);
        AddArrayToObject(Ns, 'Reports', SymRefFragments);
        AddArrayToObject(Ns, 'XmlPorts', SymRefFragments);
        AddArrayToObject(Ns, 'Queries', SymRefFragments);
        AddArrayToObject(Ns, 'ControlAddIns', SymRefFragments);
        AddArrayToObject(Ns, 'EnumTypes', SymRefFragments);
        AddArrayToObject(Ns, 'DotNetPackages', SymRefFragments);
        AddArrayToObject(Ns, 'Interfaces', SymRefFragments);
        AddArrayToObject(Ns, 'PermissionSets', SymRefFragments);
        AddArrayToObject(Ns, 'PermissionSetExtensions', SymRefFragments);
        AddArrayToObject(Ns, 'ReportExtensions', SymRefFragments);
        AddArrayToObject(Ns, 'TableExtensions', SymRefFragments);
        AddArrayToObject(Ns, 'PageExtensions', SymRefFragments);
        Ns.Add('Name', '');
        exit(Ns);
    end;

    local procedure AddArrayToObject(var TargetObj: JsonObject; ArrayName: Text; SymRefFragments: JsonObject)
    var
        FragmentToken: JsonToken;
        FragmentArray: JsonArray;
    begin
        // If the fragments collection contains this array name, use those fragments.
        // Otherwise, add an empty array.
        if SymRefFragments.Get(ArrayName, FragmentToken) then begin
            FragmentArray := FragmentToken.AsArray();
            TargetObj.Add(ArrayName, FragmentArray);
        end else
            AddEmptyArray(TargetObj, ArrayName);
    end;

    local procedure AddEmptyArray(var TargetObj: JsonObject; ArrayName: Text)
    var
        EmptyArr: JsonArray;
    begin
        TargetObj.Add(ArrayName, EmptyArr);
    end;

    local procedure WriteBom(var OutStr: OutStream)
    var
        BomStr: Text[1];
    begin
        // UTF-8 BOM: EF BB BF -- encoded by writing U+FEFF as UTF-8
        BomStr := ' ';
        BomStr[1] := 65279; // U+FEFF
        OutStr.WriteText(BomStr);
    end;

    local procedure GetLf(): Text[1]
    var
        Lf: Text[1];
    begin
        Lf := ' ';
        Lf[1] := 10;
        exit(Lf);
    end;

    local procedure InitCrLf()
    begin
        CrLf := '  ';
        CrLf[1] := 13;
        CrLf[2] := 10;
    end;

    local procedure FormatGuidNoBraces(InputGuid: Guid): Text
    begin
        exit(LowerCase(DelChr(Format(InputGuid, 0, 9), '=', '{}')));
    end;
}