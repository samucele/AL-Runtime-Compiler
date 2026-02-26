/// <summary>
/// Generic .app packager. Accumulates source files, SymbolReference fragments, and
/// entitlement entries, then produces a valid .app blob with NAVX header.
/// Has zero knowledge of specific AL object types -- it just packages files.
/// </summary>
codeunit 50100 "App Builder"
{
    Access = Public;

    var
        ContentGen: Codeunit "Content Generator";
        BinaryWriter: Codeunit "Binary Writer";
        EnvResolver: Codeunit "Environment Resolver";
        SourceFilePaths: List of [Text];
        SourceFileContents: List of [Text];
        SymRefFragments: JsonObject;
        EntitlementTypeCodes: List of [Integer];
        EntitlementObjectIds: List of [Integer];
        AppName: Text[100];
        AppPublisher: Text[100];
        VersionMajor: Integer;
        VersionMinor: Integer;
        VersionBuild: Integer;
        VersionRevision: Integer;
        ApplicationVersionOverride: Text;
        RuntimeVersionOverride: Text;
        TargetPlatformOverride: Text;
        DependencyXmlOverride: Text;
        IsMetadataSet: Boolean;
        MetadataNotSetErr: Label 'Call SetAppMetadata() before Build().', Locked = true;
        NoSourceFilesErr: Label 'Add at least one source file before calling Build().', Locked = true;

    // --- App Metadata ---

    /// <summary>
    /// Sets app identity. Must be called before Build().
    /// </summary>
    /// <param name="Name">The display name of the app (max 100 chars).</param>
    /// <param name="Publisher">The publisher name (max 100 chars).</param>
    /// <param name="Major">Major version number.</param>
    /// <param name="Minor">Minor version number.</param>
    /// <param name="Build">Build version number.</param>
    /// <param name="Revision">Revision version number.</param>
    procedure SetAppMetadata(Name: Text[100]; Publisher: Text[100];
        Major: Integer; Minor: Integer; Build: Integer; Revision: Integer)
    begin
        AppName := Name;
        AppPublisher := Publisher;
        VersionMajor := Major;
        VersionMinor := Minor;
        VersionBuild := Build;
        VersionRevision := Revision;
        IsMetadataSet := true;
    end;

    // --- Source Files ---

    /// <summary>
    /// Adds an AL source file to the .app package.
    /// The caller is responsible for encoding (UTF-8, no BOM for AL source).
    /// </summary>
    /// <param name="ZipPath">The path inside the ZIP (e.g., 'src/TableExtension/Customer.TableExt.al').</param>
    /// <param name="SourceBlob">The blob containing the file content.</param>
    procedure AddSourceFile(ZipPath: Text; var SourceBlob: Codeunit "Temp Blob")
    var
        InStr: InStream;
        TB: TextBuilder;
        Line: Text;
        Lf: Text[1];
        LineCount: Integer;
    begin
        Lf := GetLf();
        SourceBlob.CreateInStream(InStr, TextEncoding::UTF8);
        LineCount := 0;
        while not InStr.EOS() do begin
            InStr.ReadText(Line);
            if LineCount > 0 then
                TB.Append(Lf);
            TB.Append(Line);
            LineCount += 1;
        end;

        SourceFilePaths.Add(ZipPath);
        SourceFileContents.Add(TB.ToText());
    end;

    // --- Symbol Reference ---

    /// <summary>
    /// Adds a SymbolReference fragment to the specified array.
    /// ArrayName maps to the JSON array in SymbolReference.json
    /// (e.g., 'TableExtensions', 'PageExtensions', 'Codeunits').
    /// Fragment is a single JSON object to append to that array.
    /// </summary>
    /// <param name="ArrayName">The target array name in the SymbolReference.</param>
    /// <param name="Fragment">A JSON object fragment to add to the array.</param>
    procedure AddSymbolReferenceFragment(ArrayName: Text; Fragment: JsonObject)
    var
        ExistingToken: JsonToken;
        ExistingArray: JsonArray;
    begin
        if SymRefFragments.Get(ArrayName, ExistingToken) then begin
            ExistingArray := ExistingToken.AsArray();
            ExistingArray.Add(Fragment);
            SymRefFragments.Replace(ArrayName, ExistingArray);
        end else begin
            Clear(ExistingArray);
            ExistingArray.Add(Fragment);
            SymRefFragments.Add(ArrayName, ExistingArray);
        end;
    end;

    // --- Entitlement / Permissions ---

    /// <summary>
    /// Registers an object for the entitlement XML.
    /// </summary>
    /// <param name="TypeCode">The BC entitlement type code (9=TableExt, 8=PageExt, 5=Codeunit, etc.).</param>
    /// <param name="ObjectId">The AL object ID.</param>
    procedure AddEntitlementEntry(TypeCode: Integer; ObjectId: Integer)
    begin
        EntitlementTypeCodes.Add(TypeCode);
        EntitlementObjectIds.Add(ObjectId);
    end;

    // --- Environment / Dependencies ---

    /// <summary>
    /// Sets dependency XML directly. If not called, Build() uses empty dependencies.
    /// </summary>
    /// <param name="Xml">The full Dependencies XML element.</param>
    procedure SetDependencyXml(Xml: Text)
    begin
        DependencyXmlOverride := Xml;
    end;

    /// <summary>
    /// Override: sets application version (bypasses EnvironmentResolver).
    /// </summary>
    /// <param name="Version">The application version string (e.g., '27.0.0.0').</param>
    procedure SetApplicationVersion(Version: Text)
    begin
        ApplicationVersionOverride := Version;
    end;

    /// <summary>
    /// Override: sets runtime version (bypasses EnvironmentResolver).
    /// </summary>
    /// <param name="Version">The runtime version string (e.g., '17.0').</param>
    procedure SetRuntimeVersion(Version: Text)
    begin
        RuntimeVersionOverride := Version;
    end;

    /// <summary>
    /// Override: sets target platform (bypasses EnvironmentResolver).
    /// </summary>
    /// <param name="Platform">'Cloud' or 'OnPremises'.</param>
    procedure SetTargetPlatform(Platform: Text)
    begin
        TargetPlatformOverride := Platform;
    end;

    // --- Build ---

    /// <summary>
    /// Builds the complete .app file.
    /// Validates state, resolves any unset runtime values, generates metadata,
    /// packages ZIP, prepends NAVX header.
    /// </summary>
    /// <param name="ResultBlob">Output blob containing the complete .app file.</param>
    procedure Build(var ResultBlob: Codeunit "Temp Blob")
    var
        DataCompression: Codeunit "Data Compression";
        ZipBlob: Codeunit "Temp Blob";
        EntryBlob: Codeunit "Temp Blob";
        AppOutStream: OutStream;
        ZipOutStream: OutStream;
        ZipInStream: InStream;
        EntryInStream: InStream;
        AppId: Guid;
        PackageGuid: Guid;
        AppVersion: Text;
        ApplicationVersion: Text;
        RuntimeVersion: Text;
        TargetPlatform: Text;
        DependencyXml: Text;
        MinObjectId: Integer;
        MaxObjectId: Integer;
        ZipSize: Integer;
        EventContext: JsonObject;
        IsHandled: Boolean;
        i: Integer;
        FilePath: Text;
        FileContent: Text;
    begin
        // 1. Validate
        if not IsMetadataSet then
            Error(MetadataNotSetErr);
        if SourceFilePaths.Count() = 0 then
            Error(NoSourceFilesErr);

        // 2. Generate identifiers
        AppId := CreateGuid();
        PackageGuid := CreateGuid();
        AppVersion := FormatVersion();

        // 3. Resolve environment (use overrides or EnvironmentResolver)
        ApplicationVersion := ResolveApplicationVersion();
        RuntimeVersion := ResolveRuntimeVersion();
        TargetPlatform := ResolveTargetPlatform();
        DependencyXml := ResolveDependencyXml();

        // 4. Compute ID range from entitlement entries
        ComputeIdRange(MinObjectId, MaxObjectId);

        // 5. EVENT: OnBeforeBuildApp
        EventContext := AssembleEventContext(AppId, AppVersion, ApplicationVersion, RuntimeVersion, TargetPlatform);
        OnBeforeBuildApp(EventContext, IsHandled);
        if IsHandled then
            exit;

        // 6. Create ZIP archive
        DataCompression.CreateZipArchive();

        // 7. Generate + add metadata files
        Clear(EntryBlob);
        ContentGen.GenerateManifest(AppId, AppName, AppPublisher, AppVersion,
            ApplicationVersion, RuntimeVersion, TargetPlatform,
            MinObjectId, MaxObjectId, DependencyXml, EntryBlob);
        AddBlobToZip(DataCompression, 'NavxManifest.xml', EntryBlob);

        Clear(EntryBlob);
        ContentGen.GenerateContentTypes(EntryBlob);
        AddBlobToZip(DataCompression, '[Content_Types].xml', EntryBlob);

        Clear(EntryBlob);
        ContentGen.GenerateDocComments(AppId, AppName, AppPublisher, AppVersion, EntryBlob);
        AddBlobToZip(DataCompression, 'DocComments.xml', EntryBlob);

        Clear(EntryBlob);
        ContentGen.GenerateNavigation(EntryBlob);
        AddBlobToZip(DataCompression, 'navigation.xml', EntryBlob);

        Clear(EntryBlob);
        ContentGen.GenerateMediaIdListing(EntryBlob);
        AddBlobToZip(DataCompression, 'MediaIdListing.xml', EntryBlob);

        // 8. Add all collected source files
        for i := 1 to SourceFilePaths.Count() do begin
            SourceFilePaths.Get(i, FilePath);
            SourceFileContents.Get(i, FileContent);

            Clear(EntryBlob);
            WriteTextToBlob(FileContent, EntryBlob);
            AddBlobToZip(DataCompression, FilePath, EntryBlob);
        end;

        // 9. EVENT: OnCollectAdditionalFiles
        OnCollectAdditionalFiles(DataCompression, SymRefFragments, EventContext);

        // 10. Assemble and add SymbolReference.json
        Clear(EntryBlob);
        ContentGen.GenerateSymbolReference(AppId, AppName, AppPublisher, AppVersion,
            RuntimeVersion, SymRefFragments, EntryBlob);
        AddBlobToZip(DataCompression, 'SymbolReference.json', EntryBlob);

        // 11. Add entitlement
        Clear(EntryBlob);
        ContentGen.GenerateEntitlement(AppId, EntitlementTypeCodes, EntitlementObjectIds, EntryBlob);
        AddBlobToZip(DataCompression, ContentGen.GetEntitlementPath(AppId), EntryBlob);

        // 12. Save ZIP, measure size
        ZipBlob.CreateOutStream(ZipOutStream);
        DataCompression.SaveZipArchive(ZipOutStream);
        DataCompression.CloseZipArchive();
        ZipSize := ZipBlob.Length();

        // 13. Assemble final .app = NAVX header + ZIP
        ResultBlob.CreateOutStream(AppOutStream);
        BinaryWriter.WriteNavxHeader(AppOutStream, PackageGuid, ZipSize);
        ZipBlob.CreateInStream(ZipInStream);
        CopyStream(AppOutStream, ZipInStream);

        // 14. EVENT: OnAfterBuildApp
        OnAfterBuildApp(ResultBlob, EventContext);
    end;

    /// <summary>
    /// Resets all internal state for a fresh build cycle.
    /// </summary>
    procedure Reset()
    begin
        Clear(SourceFilePaths);
        Clear(SourceFileContents);
        Clear(SymRefFragments);
        Clear(EntitlementTypeCodes);
        Clear(EntitlementObjectIds);
        Clear(AppName);
        Clear(AppPublisher);
        Clear(VersionMajor);
        Clear(VersionMinor);
        Clear(VersionBuild);
        Clear(VersionRevision);
        Clear(ApplicationVersionOverride);
        Clear(RuntimeVersionOverride);
        Clear(TargetPlatformOverride);
        Clear(DependencyXmlOverride);
        IsMetadataSet := false;
    end;

    // --- Integration Events ---

    /// <summary>
    /// Raised before the .app build begins. Allows subscribers to modify context or cancel the build.
    /// </summary>
    /// <param name="Context">JSON context with app metadata and resolved environment values.</param>
    /// <param name="IsHandled">Set to true to cancel the build.</param>
    [IntegrationEvent(false, false)]
    local procedure OnBeforeBuildApp(Context: JsonObject; var IsHandled: Boolean)
    begin
    end;

    /// <summary>
    /// Raised after source files are added but before SymbolReference and entitlement.
    /// Allows subscribers to add additional files to the ZIP and additional SymRef fragments.
    /// </summary>
    /// <param name="DataCompression">The ZIP archive being built -- add entries directly.</param>
    /// <param name="SymRefFragments">The SymRef fragment collection -- add additional fragments.</param>
    /// <param name="Context">JSON context with app metadata.</param>
    [IntegrationEvent(false, false)]
    local procedure OnCollectAdditionalFiles(
        var DataCompression: Codeunit "Data Compression";
        var SymRefFragments: JsonObject;
        Context: JsonObject)
    begin
    end;

    /// <summary>
    /// Raised after the .app file is fully assembled.
    /// Allows subscribers to inspect or modify the final blob.
    /// </summary>
    /// <param name="AppBlob">The complete .app blob.</param>
    /// <param name="Context">JSON context with app metadata.</param>
    [IntegrationEvent(false, false)]
    local procedure OnAfterBuildApp(var AppBlob: Codeunit "Temp Blob"; Context: JsonObject)
    begin
    end;

    // --- Internal Helpers ---

    local procedure FormatVersion(): Text
    begin
        exit(StrSubstNo('%1.%2.%3.%4', VersionMajor, VersionMinor, VersionBuild, VersionRevision));
    end;

    local procedure ResolveApplicationVersion(): Text
    begin
        if ApplicationVersionOverride <> '' then
            exit(ApplicationVersionOverride);
        exit(EnvResolver.GetApplicationVersion());
    end;

    local procedure ResolveRuntimeVersion(): Text
    begin
        if RuntimeVersionOverride <> '' then
            exit(RuntimeVersionOverride);
        exit(EnvResolver.GetRuntimeVersion());
    end;

    local procedure ResolveTargetPlatform(): Text
    begin
        if TargetPlatformOverride <> '' then
            exit(TargetPlatformOverride);
        exit(EnvResolver.GetTargetPlatform());
    end;

    local procedure ResolveDependencyXml(): Text
    begin
        if DependencyXmlOverride <> '' then
            exit(DependencyXmlOverride);
        exit('<Dependencies />');
    end;

    local procedure ComputeIdRange(var MinObjectId: Integer; var MaxObjectId: Integer)
    var
        ObjectId: Integer;
        i: Integer;
    begin
        if EntitlementObjectIds.Count() = 0 then begin
            MinObjectId := 50100;
            MaxObjectId := 50199;
            exit;
        end;

        EntitlementObjectIds.Get(1, MinObjectId);
        MaxObjectId := MinObjectId;

        for i := 2 to EntitlementObjectIds.Count() do begin
            EntitlementObjectIds.Get(i, ObjectId);
            if ObjectId < MinObjectId then
                MinObjectId := ObjectId;
            if ObjectId > MaxObjectId then
                MaxObjectId := ObjectId;
        end;
    end;

    local procedure AssembleEventContext(AppId: Guid; AppVersion: Text;
        ApplicationVersion: Text; RuntimeVersion: Text; TargetPlatform: Text): JsonObject
    var
        Context: JsonObject;
    begin
        Context.Add('AppId', Format(AppId, 0, 9));
        Context.Add('AppName', AppName);
        Context.Add('Publisher', AppPublisher);
        Context.Add('AppVersion', AppVersion);
        Context.Add('ApplicationVersion', ApplicationVersion);
        Context.Add('RuntimeVersion', RuntimeVersion);
        Context.Add('TargetPlatform', TargetPlatform);
        Context.Add('SourceFileCount', SourceFilePaths.Count());
        Context.Add('EntitlementCount', EntitlementTypeCodes.Count());
        exit(Context);
    end;

    local procedure AddBlobToZip(var DataCompression: Codeunit "Data Compression"; EntryPath: Text; var TempBlob: Codeunit "Temp Blob")
    var
        InStr: InStream;
    begin
        TempBlob.CreateInStream(InStr);
        DataCompression.AddEntry(InStr, EntryPath);
    end;

    local procedure WriteTextToBlob(Content: Text; var TempBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
    begin
        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Content);
    end;

    local procedure GetLf(): Text[1]
    var
        Lf: Text[1];
    begin
        Lf := ' ';
        Lf[1] := 10;
        exit(Lf);
    end;
}