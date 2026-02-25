/// <summary>
/// Handles downloading and publishing of generated .app blobs.
/// Provides browser download via DownloadFromStream and server-side
/// publish via ExtensionManagement.UploadExtension.
/// Queries deployment status via Extension Management Cloud-compatible API.
/// </summary>
codeunit 50110 "App Publisher"
{
    Access = Public;

    /// <summary>
    /// Downloads the generated .app file to the user's browser.
    /// Constructs a filename from the app name and version, then triggers browser download.
    /// </summary>
    /// <param name="AppBlob">The Temp Blob containing the .app file content.</param>
    /// <param name="AppName">The application name (used in the download filename).</param>
    /// <param name="AppVersion">The application version string (used in the download filename).</param>
    procedure DownloadApp(var AppBlob: Codeunit "Temp Blob"; AppName: Text; AppVersion: Text)
    var
        InStr: InStream;
        FileName: Text;
    begin
        if not AppBlob.HasValue() then
            Error(AppBlobEmptyErr);

        AppBlob.CreateInStream(InStr);
        FileName := BuildFileName(AppName, AppVersion);
        DownloadFromStream(InStr, DownloadDialogTitleLbl, '', AppFileFilterLbl, FileName);
    end;

    /// <summary>
    /// Publishes the generated .app to the current BC environment
    /// using ExtensionManagement.UploadExtension.
    /// </summary>
    /// <param name="AppBlob">The Temp Blob containing the .app file content.</param>
    /// <returns>True if the upload was initiated without error; false otherwise.</returns>
    procedure PublishApp(var AppBlob: Codeunit "Temp Blob"): Boolean
    var
        InStr: InStream;
    begin
        if not AppBlob.HasValue() then
            Error(AppBlobEmptyErr);

        AppBlob.CreateInStream(InStr);
        if not TryUploadExtension(InStr) then
            exit(false);

        exit(true);
    end;

    /// <summary>
    /// Retrieves the current deployment status via the Extension Management API.
    /// Uses GetAllExtensionDeploymentStatusEntries (Cloud-compatible) to read the
    /// most recent operation record from the temporary Extension Deployment Status table.
    /// Returns the raw status option value matching the standard: 0=Unknown, 1=InProgress, 2=Failed, 3=Completed, 4=NotFound.
    /// </summary>
    /// <param name="StatusValue">Returns the raw status option value from Extension Deployment Status.</param>
    /// <param name="ErrorMsg">Returns the description if the status is Failed or NotFound.</param>
    procedure GetDeploymentStatus(var StatusValue: Integer; var ErrorMsg: Text)
    var
        ExtensionMgt: Codeunit "Extension Management";
        TempDeployStatus: Record "Extension Deployment Status" temporary;
    begin
        ExtensionMgt.GetAllExtensionDeploymentStatusEntries(TempDeployStatus);
        TempDeployStatus.SetCurrentKey("Started On");
        TempDeployStatus.Ascending(false);
        if not TempDeployStatus.FindFirst() then begin
            StatusValue := 0; // Unknown
            exit;
        end;

        StatusValue := TempDeployStatus.Status;
        if TempDeployStatus.Status in [TempDeployStatus.Status::Failed, TempDeployStatus.Status::NotFound] then
            ErrorMsg := TempDeployStatus.Description;
    end;

    [TryFunction]
    local procedure TryUploadExtension(InStr: InStream)
    var
        ExtensionMgt: Codeunit "Extension Management";
    begin
        ExtensionMgt.UploadExtension(InStr, GlobalLanguage());
    end;

    local procedure BuildFileName(AppName: Text; AppVersion: Text): Text
    var
        SafeName: Text;
    begin
        SafeName := DelChr(AppName, '=', '/\:*?"<>|');
        if SafeName = '' then
            SafeName := 'Extension';
        exit(SafeName + '_' + AppVersion + '.app');
    end;

    var
        AppBlobEmptyErr: Label 'The app blob is empty. Generate an app before downloading or publishing.';
        DownloadDialogTitleLbl: Label 'Download Extension';
        AppFileFilterLbl: Label 'App Files (*.app)|*.app';
}