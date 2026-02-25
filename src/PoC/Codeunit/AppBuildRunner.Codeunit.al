/// <summary>
/// Orchestrates the app build workflow for the Dashboard page.
/// Extracts all business logic from the page into a single runner codeunit,
/// keeping the page as a thin UI layer. Maintains the generated .app blob
/// internally and provides methods for generation, download, publish, and preview.
/// </summary>
codeunit 50114 "App Build Runner"
{
    Access = Internal;

    var
        AppBlob: Codeunit "Temp Blob";
        IsAppGenerated: Boolean;
        AppNameRequiredErr: Label 'App Name is required.';
        PublisherRequiredErr: Label 'Publisher is required.';
        SelectTableErr: Label 'Please select a target table.';
        SelectPageErr: Label 'Please select a target page.';
        FieldIdRequiredErr: Label 'Field ID is required.';
        FieldNameRequiredErr: Label 'Field Name is required.';
        TableExtIdRequiredErr: Label 'Table Extension Object ID is required.';
        PageExtIdRequiredErr: Label 'Page Extension Object ID is required.';
        AppGeneratedMsg: Label 'App generated successfully.';
        AppNotGeneratedErr: Label 'Generate an app first.';
        PublishInitiatedMsg: Label 'Extension upload initiated. Check Extension Deployment Status for progress.';
        PublishFailedMsg: Label 'Publish failed: %1', Comment = '%1 = Error message';
        PreviewSeparatorTxt: Label '\\---\\', Locked = true;

    /// <summary>
    /// Validates inputs, generates object sources via the ObjectBuilder layer,
    /// and packages them into a complete .app file via the Compiler layer.
    /// </summary>
    /// <param name="Rec">The Compiler Setup record containing all build parameters.</param>
    procedure GenerateApp(var Rec: Record "App Builder Buffer")
    var
        TableExtBldr: Codeunit "Table Ext. Builder";
        PageExtBldr: Codeunit "Page Ext. Builder";
        AppBuilder: Codeunit "App Builder";
        EnvResolver: Codeunit "Environment Resolver";
        TableExtSource: Codeunit "Temp Blob";
        PageExtSource: Codeunit "Temp Blob";
        TableExtSymRef: JsonObject;
        PageExtSymRef: JsonObject;
    begin
        ValidateInput(Rec);

        // Layer 2: Generate object sources
        TableExtBldr.SetTarget(Rec."Target Table No.", Rec."Target Table Name", Rec."Target Table App Package Id");
        TableExtBldr.SetObjectId(Rec."Table Ext. Object Id");
        TableExtBldr.AddField(Rec."Field Id", Rec."Field Name", Rec."Field Data Type", Rec."Field Length", Rec."Option String");
        TableExtBldr.GenerateSource(TableExtSource);
        TableExtSymRef := TableExtBldr.GenerateSymbolReference();

        PageExtBldr.SetTarget(Rec."Target Page No.", Rec."Target Page Name", Rec."Target Page App Package Id");
        PageExtBldr.SetObjectId(Rec."Page Ext. Object Id");
        PageExtBldr.SetPlacement(Rec."Placement Type", Rec."Anchor Control");

        PageExtBldr.AddField(Rec."Field Name", 'Rec."' + Rec."Field Name" + '"');
        PageExtBldr.GenerateSource(PageExtSource);
        PageExtSymRef := PageExtBldr.GenerateSymbolReference();

        // Layer 1: Package into .app
        AppBuilder.SetAppMetadata(Rec."App Name", Rec.Publisher,
            Rec."Version Major", Rec."Version Minor", Rec."Version Build", Rec."Version Revision");

        AppBuilder.AddSourceFile(TableExtBldr.GetSourceFilePath(), TableExtSource);
        AppBuilder.AddSourceFile(PageExtBldr.GetSourceFilePath(), PageExtSource);

        AppBuilder.AddSymbolReferenceFragment('TableExtensions', TableExtSymRef);
        AppBuilder.AddSymbolReferenceFragment('PageExtensions', PageExtSymRef);

        AppBuilder.AddEntitlementEntry(
            TableExtBldr.GetEntitlementTypeCode(), TableExtBldr.GetObjectId());
        AppBuilder.AddEntitlementEntry(
            PageExtBldr.GetEntitlementTypeCode(), PageExtBldr.GetObjectId());

        AppBuilder.SetDependencyXml(
            EnvResolver.BuildDependencyXml(Rec."Target Table App Package Id"));

        Clear(AppBlob);
        AppBuilder.Build(AppBlob);
        IsAppGenerated := true;

        Message(AppGeneratedMsg);
    end;

    /// <summary>
    /// Downloads the previously generated .app file to the user's browser.
    /// </summary>
    /// <param name="Rec">The Compiler Setup record containing version info for the filename.</param>
    procedure DownloadApp(var Rec: Record "App Builder Buffer")
    var
        Publisher: Codeunit "App Publisher";
        AppVersion: Text;
    begin
        CheckAppGenerated();
        AppVersion := Format(Rec."Version Major") + '.' + Format(Rec."Version Minor") + '.'
            + Format(Rec."Version Build") + '.' + Format(Rec."Version Revision");
        Publisher.DownloadApp(AppBlob, Rec."App Name", AppVersion);
    end;

    /// <summary>
    /// Publishes the previously generated .app to the current BC environment
    /// via ExtensionManagement.UploadExtension.
    /// </summary>
    /// <param name="Rec">The Compiler Setup record to update with deployment status.</param>
    procedure PublishApp(var Rec: Record "App Builder Buffer")
    var
        Publisher: Codeunit "App Publisher";
    begin
        CheckAppGenerated();
        Rec.Status := Rec.Status::InProgress;
        Rec."Status Message" := '';
        Rec.Modify();

        if Publisher.PublishApp(AppBlob) then begin
            Rec.Status := Rec.Status::InProgress;
            Rec.Modify();
            Message(PublishInitiatedMsg);
        end else begin
            Rec.Status := Rec.Status::Failed;
            Rec."Status Message" := CopyStr(GetLastErrorText(), 1, 250);
            Rec.Modify();
            Message(PublishFailedMsg, Rec."Status Message");
        end;
    end;

    /// <summary>
    /// Queries the deployment status from the App Publisher and updates the record.
    /// </summary>
    /// <param name="Rec">The Compiler Setup record to update with current status.</param>
    procedure RefreshStatus(var Rec: Record "App Builder Buffer")
    var
        Publisher: Codeunit "App Publisher";
        StatusValue: Integer;
        ErrorMsg: Text;
    begin
        Publisher.GetDeploymentStatus(StatusValue, ErrorMsg);
        // Standard values: 0=Unknown,1=InProgress,2=Failed,3=Completed,4=NotFound
        // Our Option:      0=None,   1=Unknown,   2=InProgress,3=Failed,4=Completed,5=NotFound
        Rec.Status := StatusValue + 1;
        Rec."Status Message" := CopyStr(ErrorMsg, 1, 250);
        Rec.Modify();
    end;

    /// <summary>
    /// Generates a preview of the AL source code that would be produced,
    /// without packaging into an .app file.
    /// </summary>
    /// <param name="Rec">The Compiler Setup record containing all build parameters.</param>
    /// <returns>Combined table extension and page extension source code separated by a divider.</returns>
    procedure PreviewCode(var Rec: Record "App Builder Buffer"): Text
    var
        TableExtBldr: Codeunit "Table Ext. Builder";
        PageExtBldr: Codeunit "Page Ext. Builder";
    begin
        ValidateInput(Rec);

        TableExtBldr.SetTarget(Rec."Target Table No.", Rec."Target Table Name", Rec."Target Table App Package Id");
        TableExtBldr.SetObjectId(Rec."Table Ext. Object Id");
        TableExtBldr.AddField(Rec."Field Id", Rec."Field Name", Rec."Field Data Type", Rec."Field Length", Rec."Option String");

        PageExtBldr.SetTarget(Rec."Target Page No.", Rec."Target Page Name", Rec."Target Page App Package Id");
        PageExtBldr.SetObjectId(Rec."Page Ext. Object Id");
        PageExtBldr.SetPlacement(Rec."Placement Type", Rec."Anchor Control");

        PageExtBldr.AddField(Rec."Field Name", 'Rec."' + Rec."Field Name" + '"');

        exit(TableExtBldr.PreviewSource() + PreviewSeparatorTxt + PageExtBldr.PreviewSource());
    end;

    /// <summary>
    /// Returns whether an .app file has been generated in the current session.
    /// Used by the Dashboard page to enable/disable Download and Publish actions.
    /// </summary>
    /// <returns>True if GenerateApp has been called successfully.</returns>
    procedure GetIsAppGenerated(): Boolean
    begin
        exit(IsAppGenerated);
    end;

    local procedure ValidateInput(var Rec: Record "App Builder Buffer")
    begin
        if Rec."App Name" = '' then
            Error(AppNameRequiredErr);
        if Rec.Publisher = '' then
            Error(PublisherRequiredErr);
        if Rec."Target Table No." <= 0 then
            Error(SelectTableErr);
        if Rec."Target Page No." <= 0 then
            Error(SelectPageErr);
        if Rec."Field Id" <= 0 then
            Error(FieldIdRequiredErr);
        if Rec."Field Name" = '' then
            Error(FieldNameRequiredErr);
        if Rec."Table Ext. Object Id" <= 0 then
            Error(TableExtIdRequiredErr);
        if Rec."Page Ext. Object Id" <= 0 then
            Error(PageExtIdRequiredErr);
    end;

    local procedure CheckAppGenerated()
    begin
        if not IsAppGenerated then
            Error(AppNotGeneratedErr);
    end;

    local procedure SanitizeName(InputName: Text): Text
    var
        Result: TextBuilder;
        i: Integer;
        c: Char;
    begin
        for i := 1 to StrLen(InputName) do begin
            c := InputName[i];
            case true of
                (c >= 'A') and (c <= 'Z'),
                (c >= 'a') and (c <= 'z'),
                (c >= '0') and (c <= '9'):
                    Result.Append(Format(c));
            end;
        end;
        exit(Result.ToText());
    end;
}
