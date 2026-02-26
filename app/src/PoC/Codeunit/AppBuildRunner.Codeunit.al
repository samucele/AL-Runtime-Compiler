/// <summary>
/// Orchestrates the app build workflow for the App Builder Wizard.
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
        AnchorControlRequiredErr: Label 'Please select an anchor control.';
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
    /// <param name="Rec">The App Builder Buffer record.</param>
    /// <returns>True if the upload was initiated successfully.</returns>
    procedure PublishApp(var Rec: Record "App Builder Buffer"): Boolean
    var
        Publisher: Codeunit "App Publisher";
    begin
        CheckAppGenerated();
        exit(Publisher.PublishApp(AppBlob));
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
    /// Used by the Wizard page to enable/disable Download and Publish actions.
    /// </summary>
    /// <returns>True if GenerateApp has been called successfully.</returns>
    procedure GetIsAppGenerated(): Boolean
    begin
        exit(IsAppGenerated);
    end;

    /// <summary>
    /// Validates a single wizard step. Called by the wizard page on Next.
    /// </summary>
    /// <param name="StepNo">The step number to validate (1-3).</param>
    /// <param name="Rec">The App Builder Buffer record with current inputs.</param>
    procedure ValidateStep(StepNo: Integer; var Rec: Record "App Builder Buffer")
    begin
        case StepNo of
            1:
                begin
                    if Rec."App Name" = '' then
                        Error(AppNameRequiredErr);
                    if Rec.Publisher = '' then
                        Error(PublisherRequiredErr);
                end;
            2:
                begin
                    if Rec."Target Table No." <= 0 then
                        Error(SelectTableErr);
                    if Rec."Target Page No." <= 0 then
                        Error(SelectPageErr);
                end;
            3:
                begin
                    if Rec."Field Name" = '' then
                        Error(FieldNameRequiredErr);
                    if Rec."Anchor Control" = '' then
                        Error(AnchorControlRequiredErr);
                end;
        end;
    end;

    /// <summary>
    /// Opens the Extension Deployment Status page. Used as a Notification action callback.
    /// </summary>
    /// <param name="Notif">The notification that triggered this action.</param>
    procedure OpenDeploymentStatus(var Notif: Notification)
    begin
        Page.Run(Page::"Extension Deployment Status");
    end;

    local procedure ValidateInput(var Rec: Record "App Builder Buffer")
    begin
        ValidateStep(1, Rec);
        ValidateStep(2, Rec);
        ValidateStep(3, Rec);
        if Rec."Field Id" <= 0 then
            Error(FieldIdRequiredErr);
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

}
