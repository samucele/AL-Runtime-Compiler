/// <summary>
/// Main dashboard for the AL Runtime Compiler.
/// Thin UI layer that delegates all business logic to the App Build Runner codeunit.
/// Backed by a temporary App Builder Buffer record for user input state.
/// </summary>
page 50111 "App Builder Dashboard"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'App Builder Dashboard';
    SourceTable = "App Builder Buffer";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            group(AppMetadata)
            {
                Caption = 'App Metadata';

                field(AppNameField; Rec."App Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The name for the generated extension.';
                }
                field(PublisherField; Rec.Publisher)
                {
                    ApplicationArea = All;
                    ToolTip = 'The publisher name for the generated extension.';
                }
                field(VersionMajorField; Rec."Version Major")
                {
                    ApplicationArea = All;
                    ToolTip = 'Major version number.';
                }
                field(VersionMinorField; Rec."Version Minor")
                {
                    ApplicationArea = All;
                    ToolTip = 'Minor version number.';
                }
                field(VersionBuildField; Rec."Version Build")
                {
                    ApplicationArea = All;
                    ToolTip = 'Build version number.';
                }
                field(VersionRevisionField; Rec."Version Revision")
                {
                    ApplicationArea = All;
                    ToolTip = 'Revision version number.';
                }
            }
            group(Target)
            {
                Caption = 'Target';

                field(TargetTableNoField; Rec."Target Table No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The ID of the table to extend.';
                }
                field(TargetTableNameField; Rec."Target Table Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The name of the selected target table.';
                }
                field(TargetPageNoField; Rec."Target Page No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The ID of the page to extend.';
                }
                field(TargetPageNameField; Rec."Target Page Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The name of the selected target page.';
                }
            }
            group(FieldDefinition)
            {
                Caption = 'Field Definition';

                field(FieldIdField; Rec."Field Id")
                {
                    ApplicationArea = All;
                    ToolTip = 'The ID for the new field.';
                }
                field(FieldNameField; Rec."Field Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The name for the new field.';
                }
                field(FieldDataTypeField; Rec."Field Data Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'The data type for the new field.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(false);
                    end;
                }
                group(FieldLengthGroup)
                {
                    ShowCaption = false;
                    Visible = (Rec."Field Data Type" = Rec."Field Data Type"::Text) or (Rec."Field Data Type" = Rec."Field Data Type"::Code);

                    field(FieldLengthField; Rec."Field Length")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Max length for Text or Code fields.';
                    }
                }
                group(OptionStringGroup)
                {
                    ShowCaption = false;
                    Visible = Rec."Field Data Type" = Rec."Field Data Type"::Option;

                    field(OptionStringField; Rec."Option String")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Comma-separated option values for Option fields.';
                    }
                }
            }
            group(Placement)
            {
                Caption = 'Placement';

                field(PlacementTypeField; Rec."Placement Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Where to place the field group on the page.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(false);
                    end;
                }
                group(AnchorControlGroup)
                {
                    ShowCaption = false;
                    Visible = (Rec."Placement Type" = Rec."Placement Type"::addafter) or (Rec."Placement Type" = Rec."Placement Type"::addbefore);

                    field(AnchorControlField; Rec."Anchor Control")
                    {
                        ApplicationArea = All;
                        ToolTip = 'The control name for addafter/addbefore placement.';
                    }
                }
            }
            group(ObjectIds)
            {
                Caption = 'Object IDs';

                field(TableExtObjectIdField; Rec."Table Ext. Object Id")
                {
                    ApplicationArea = All;
                    ToolTip = 'Object ID for the generated table extension.';
                }
                field(PageExtObjectIdField; Rec."Page Ext. Object Id")
                {
                    ApplicationArea = All;
                    ToolTip = 'Object ID for the generated page extension.';
                }
            }
            group(StatusGroup)
            {
                Caption = 'Installation Status';
                Visible = Rec.Status <> Rec.Status::None;

                field(StatusField; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Current deployment status.';
                }
                group(StatusMessageGroup)
                {
                    ShowCaption = false;
                    Visible = Rec.Status = Rec.Status::Failed;

                    field(StatusMessageField; Rec."Status Message")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Error details if deployment failed.';
                        MultiLine = true;
                    }
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(GenerateApp)
            {
                ApplicationArea = All;
                Caption = 'Generate App';
                ToolTip = 'Generate the .app file from the configured inputs.';
                Image = Process;

                trigger OnAction()
                begin
                    Runner.GenerateApp(Rec);
                    IsAppGenerated := Runner.GetIsAppGenerated();
                    CurrPage.Update(false);
                end;
            }
            action(DownloadApp)
            {
                ApplicationArea = All;
                Caption = 'Download App';
                ToolTip = 'Download the generated .app file.';
                Image = Export;
                Enabled = IsAppGenerated;

                trigger OnAction()
                begin
                    Runner.DownloadApp(Rec);
                end;
            }
            action(PublishApp)
            {
                ApplicationArea = All;
                Caption = 'Publish App';
                ToolTip = 'Upload the .app to this BC environment.';
                Image = Apply;
                Enabled = IsAppGenerated;

                trigger OnAction()
                begin
                    Runner.PublishApp(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(PreviewCode)
            {
                ApplicationArea = All;
                Caption = 'Preview AL Code';
                ToolTip = 'Preview the generated AL source code.';
                Image = ShowChart;

                trigger OnAction()
                begin
                    Message(Runner.PreviewCode(Rec));
                end;
            }
            action(RefreshStatus)
            {
                ApplicationArea = All;
                Caption = 'Refresh Status';
                ToolTip = 'Refresh the deployment status from the server.';
                Image = Refresh;
                Visible = Rec.Status <> Rec.Status::None;

                trigger OnAction()
                begin
                    Runner.RefreshStatus(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(GenerateApp_Promoted; GenerateApp) { }
                actionref(DownloadApp_Promoted; DownloadApp) { }
                actionref(PublishApp_Promoted; PublishApp) { }
                actionref(PreviewCode_Promoted; PreviewCode) { }
                actionref(RefreshStatus_Promoted; RefreshStatus) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Init();
        Rec."Primary Key" := '';
        Rec."App Name" := 'My Extension';
        Rec.Publisher := 'Publisher';
        Rec."Version Major" := 1;
        Rec."Field Id" := 50100;
        Rec."Field Length" := 100;
        Rec."Table Ext. Object Id" := 50100;
        Rec."Page Ext. Object Id" := 50101;
        Rec.Insert();
    end;

    var
        Runner: Codeunit "App Build Runner";
        IsAppGenerated: Boolean;
}
