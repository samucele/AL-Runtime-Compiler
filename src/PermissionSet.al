/// <summary>
/// Grants execution permissions for all AL Runtime Compiler codeunits.
/// Assign this permission set to users who need to generate .app files at runtime.
/// </summary>
permissionset 50112 "AL Runtime Compiler"
{
    Assignable = true;
    Caption = 'AL Runtime Compiler';
    Permissions = table "App Builder Buffer" = X,
        codeunit "App Builder" = X,
        codeunit "Content Generator" = X,
        codeunit "Binary Writer" = X,
        codeunit "Environment Resolver" = X,
        codeunit "AL Code Writer" = X,
        codeunit "Table Ext. Builder" = X,
        codeunit "Page Ext. Builder" = X,
        codeunit "App Publisher" = X,
        codeunit "App Build Runner" = X,
        tabledata "App Builder Buffer" = RIMD,
        page "App Builder Wizard" = X,
        page "Page Lookup" = X,
        page "Page Control Lookup" = X;
}