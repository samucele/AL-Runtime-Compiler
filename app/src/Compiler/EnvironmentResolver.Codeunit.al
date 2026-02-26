/// <summary>
/// Reads BC metadata APIs at runtime to resolve environment-specific values
/// such as application version, runtime version, target platform, and dependencies.
/// Called by App Builder when override values are not set.
/// Also available for ObjectBuilder consumers who need dependency info.
/// </summary>
codeunit 50103 "Environment Resolver"
{
    Access = Public;

    /// <summary>
    /// Gets the currently installed Base Application version by reading module info at runtime.
    /// Returns the version in 'Major.Minor.Build.Revision' format (e.g., '27.0.0.0').
    /// </summary>
    /// <returns>The Base Application version string.</returns>
    procedure GetApplicationVersion(): Text
    var
        ModInfo: ModuleInfo;
    begin
        NavApp.GetModuleInfo(GetBaseAppId(), ModInfo);
        exit(Format(ModInfo.AppVersion().Major()) + '.0.0.0');
    end;

    /// <summary>
    /// Maps the current Base Application major version to the corresponding AL runtime version.
    /// Based on the established mapping: runtime = major - 11 (e.g., 27->16.0, 26->15.0).
    /// </summary>
    /// <returns>The AL runtime version string (e.g., '16.0').</returns>
    procedure GetRuntimeVersion(): Text
    var
        ModInfo: ModuleInfo;
        MajorVersion: Integer;
    begin
        NavApp.GetModuleInfo(GetBaseAppId(), ModInfo);
        MajorVersion := ModInfo.AppVersion().Major();
        exit(MapMajorToRuntime(MajorVersion));
    end;

    /// <summary>
    /// Determines the target platform based on whether the current environment is SaaS.
    /// Returns 'Cloud' for SaaS environments and 'OnPremises' for on-premises installations.
    /// </summary>
    /// <returns>'Cloud' or 'OnPremises'.</returns>
    procedure GetTargetPlatform(): Text
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        if EnvironmentInformation.IsSaaS() then
            exit('Cloud');
        exit('OnPremises');
    end;

    /// <summary>
    /// Resolves the owning app of the target object and builds a Dependencies XML fragment.
    /// If the target belongs to a platform object (empty/zero GUID), returns empty dependencies.
    /// </summary>
    /// <param name="TargetAppPackageId">The App Package ID of the target object's owning app.</param>
    /// <returns>A Dependencies XML element string.</returns>
    procedure BuildDependencyXml(TargetAppPackageId: Guid): Text
    var
        DependencyAppId: Guid;
        DependencyName: Text;
        DependencyPublisher: Text;
        DependencyVersion: Text;
        TB: TextBuilder;
    begin
        if not ResolveDependency(TargetAppPackageId, DependencyAppId, DependencyName, DependencyPublisher, DependencyVersion) then
            exit('<Dependencies />');

        // Microsoft apps (Application, Base Application, System Application) are covered
        // by the Application attribute on <App>. Only add explicit dependencies for
        // third-party / ISV apps.
        if DependencyPublisher = 'Microsoft' then
            exit('<Dependencies />');

        TB.Append('<Dependencies>');
        TB.Append(GetLf());
        TB.Append('    <Dependency Id="');
        TB.Append(LowerCase(DelChr(Format(DependencyAppId, 0, 9), '=', '{}')));
        TB.Append('" Name="');
        TB.Append(DependencyName);
        TB.Append('" Publisher="');
        TB.Append(DependencyPublisher);
        TB.Append('" MinVersion="');
        TB.Append(DependencyVersion);
        TB.Append('" />');
        TB.Append(GetLf());
        TB.Append('  </Dependencies>');
        exit(TB.ToText());
    end;

    /// <summary>
    /// Resolves the owning app details from a given App Package ID by looking up the
    /// NAV App Installed App system table (2000000153).
    /// Returns false if the Package ID is empty/zero (platform object -- no dependency needed).
    /// </summary>
    /// <param name="AppPackageId">The App Package ID to resolve.</param>
    /// <param name="DependencyAppId">Output: The App ID of the owning app.</param>
    /// <param name="DependencyName">Output: The name of the owning app.</param>
    /// <param name="DependencyPublisher">Output: The publisher of the owning app.</param>
    /// <param name="DependencyVersion">Output: The version of the owning app.</param>
    /// <returns>True if the dependency was resolved; false if it is a platform object.</returns>
    procedure ResolveDependency(AppPackageId: Guid;
        var DependencyAppId: Guid; var DependencyName: Text;
        var DependencyPublisher: Text; var DependencyVersion: Text): Boolean
    var
        NavAppInstalledApp: Record "NAV App Installed App";
        EmptyGuid: Guid;
    begin
        if AppPackageId = EmptyGuid then
            exit(false);

        NavAppInstalledApp.SetLoadFields("App ID", Name, Publisher, "Version Major", "Version Minor", "Version Build", "Version Revision");
        NavAppInstalledApp.SetRange("Package ID", AppPackageId);
        if not NavAppInstalledApp.FindFirst() then
            exit(false);

        DependencyAppId := NavAppInstalledApp."App ID";
        DependencyName := NavAppInstalledApp.Name;
        DependencyPublisher := NavAppInstalledApp.Publisher;
        DependencyVersion := Format(NavAppInstalledApp."Version Major") + '.0.0.0';

        exit(true);
    end;

    /// <summary>
    /// Derives the Base Application App ID dynamically by querying the
    /// NAV App Installed App system table for the 'Base Application' published by 'Microsoft'.
    /// </summary>
    /// <returns>The App ID GUID of the installed Base Application.</returns>
    local procedure GetBaseAppId(): Guid
    var
        NavAppInstalledApp: Record "NAV App Installed App";
    begin
        NavAppInstalledApp.SetLoadFields("App ID");
        NavAppInstalledApp.SetRange(Name, 'Base Application');
        NavAppInstalledApp.SetRange(Publisher, 'Microsoft');
        NavAppInstalledApp.FindFirst();
        exit(NavAppInstalledApp."App ID");
    end;

    local procedure MapMajorToRuntime(MajorVersion: Integer): Text
    begin
        exit(Format(MajorVersion - 11) + '.0');
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