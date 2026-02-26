/// <summary>
/// Wizard-style page for the App Builder Wizard.
/// Guides the user through 4 steps: Identity, Target, Field/Placement, Review/Build.
/// Thin UI layer that delegates all business logic to the App Build Runner codeunit.
/// </summary>
page 50111 "App Builder Wizard"
{
    PageType = NavigatePage;
    SourceTable = "App Builder Buffer";
    SourceTableTemporary = true;
    Caption = 'App Builder Wizard';
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(Step1)
            {
                Caption = 'Step 1: Extension Identity';
                InstructionalText = 'Name your extension and set the version number.';
                Visible = Step1Visible;

                field(AppName; Rec."App Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The name for the generated extension.';
                }
                field(Publisher; Rec.Publisher)
                {
                    ApplicationArea = All;
                    ToolTip = 'The publisher name for the generated extension.';
                }
                field(VersionMajor; Rec."Version Major")
                {
                    ApplicationArea = All;
                    ToolTip = 'Major version number.';
                }
                field(VersionMinor; Rec."Version Minor")
                {
                    ApplicationArea = All;
                    ToolTip = 'Minor version number.';
                }
                field(VersionBuild; Rec."Version Build")
                {
                    ApplicationArea = All;
                    ToolTip = 'Build version number.';
                }
                field(VersionRevision; Rec."Version Revision")
                {
                    ApplicationArea = All;
                    ToolTip = 'Revision version number.';
                }
            }

            group(Step2)
            {
                Caption = 'Step 2: Target Selection';
                InstructionalText = 'Choose the table and page to extend. The page list is filtered to pages using the selected table.';
                Visible = Step2Visible;

                field(TargetTableNo; Rec."Target Table No.")
                {
                    ApplicationArea = All;
                    LookupPageId = "Table Objects";
                    ToolTip = 'The ID of the table to extend.';
                }
                field(TargetTableName; Rec."Target Table Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The name of the selected target table.';
                }
                field(TargetPageNo; Rec."Target Page No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The ID of the page to extend.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        PageMeta: Record "Page Metadata";
                    begin
                        PageMeta.SetRange(SourceTable, Rec."Target Table No.");
                        if Page.RunModal(Page::"Page Lookup", PageMeta) = Action::LookupOK then begin
                            Text := Format(PageMeta.ID);
                            exit(true);
                        end;
                    end;
                }
                field(TargetPageName; Rec."Target Page Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The name of the selected target page.';
                }

                group(AdvancedIdsGroup)
                {
                    Caption = 'Advanced: Object IDs';

                    field(TableExtObjectId; Rec."Table Ext. Object Id")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Object ID for the generated table extension.';
                    }
                    field(PageExtObjectId; Rec."Page Ext. Object Id")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Object ID for the generated page extension.';
                    }
                }
            }

            group(Step3)
            {
                Caption = 'Step 3: Field & Placement';
                InstructionalText = 'Define the new field and choose where it appears on the page.';
                Visible = Step3Visible;

                group(FieldDefinitionGroup)
                {
                    Caption = 'Field Definition';

                    field(FieldId; Rec."Field Id")
                    {
                        ApplicationArea = All;
                        ToolTip = 'The ID for the new field.';
                    }
                    field(FieldName; Rec."Field Name")
                    {
                        ApplicationArea = All;
                        ToolTip = 'The name for the new field.';
                    }
                    field(FieldDataType; Rec."Field Data Type")
                    {
                        ApplicationArea = All;
                        ToolTip = 'The data type for the new field.';

                        trigger OnValidate()
                        begin
                            UpdateConditionalVisibility();
                        end;
                    }
                    group(FieldLengthWrapper)
                    {
                        ShowCaption = false;
                        Visible = ShowFieldLength;

                        field(FieldLength; Rec."Field Length")
                        {
                            ApplicationArea = All;
                            ToolTip = 'Max length for Text or Code fields.';
                        }
                    }
                    group(OptionStringWrapper)
                    {
                        ShowCaption = false;
                        Visible = ShowOptionString;

                        field(OptionString; Rec."Option String")
                        {
                            ApplicationArea = All;
                            ToolTip = 'Comma-separated option values for Option fields.';
                        }
                    }
                }

                group(PlacementGroup)
                {
                    Caption = 'Placement';

                    field(PlacementType; Rec."Placement Type")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Where to place the field group on the page.';
                    }
                    field(AnchorControl; Rec."Anchor Control")
                    {
                        ApplicationArea = All;
                        ToolTip = 'The existing field control to place relative to.';

                        trigger OnLookup(var Text: Text): Boolean
                        var
                            PageCtrlField: Record "Page Control Field";
                        begin
                            PageCtrlField.SetRange(PageNo, Rec."Target Page No.");
                            if Page.RunModal(Page::"Page Control Lookup", PageCtrlField) = Action::LookupOK then begin
                                Text := PageCtrlField.ControlName;
                                exit(true);
                            end;
                        end;
                    }
                }

            }

            group(Step4)
            {
                Caption = 'Step 4: Review & Build';
                InstructionalText = 'Review your configuration and generate the extension.';
                Visible = Step4Visible;

                group(ReviewIdentity)
                {
                    Caption = 'Extension Identity';

                    field(ReviewAppName; Rec."App Name")
                    {
                        ApplicationArea = All;
                        Editable = false;
                        ToolTip = 'The name for the generated extension.';
                    }
                    field(ReviewPublisher; Rec.Publisher)
                    {
                        ApplicationArea = All;
                        Editable = false;
                        ToolTip = 'The publisher name for the generated extension.';
                    }
                    field(ReviewVersion; VersionDisplayText)
                    {
                        ApplicationArea = All;
                        Editable = false;
                        Caption = 'Version';
                        ToolTip = 'The version number for the generated extension.';
                    }
                }
                group(ReviewTarget)
                {
                    Caption = 'Target';

                    field(ReviewTableName; Rec."Target Table Name")
                    {
                        ApplicationArea = All;
                        Editable = false;
                        ToolTip = 'The name of the selected target table.';
                    }
                    field(ReviewPageName; Rec."Target Page Name")
                    {
                        ApplicationArea = All;
                        Editable = false;
                        ToolTip = 'The name of the selected target page.';
                    }
                }
                group(ReviewField)
                {
                    Caption = 'Field';

                    field(ReviewFieldName; Rec."Field Name")
                    {
                        ApplicationArea = All;
                        Editable = false;
                        ToolTip = 'The name for the new field.';
                    }
                    field(ReviewFieldType; Rec."Field Data Type")
                    {
                        ApplicationArea = All;
                        Editable = false;
                        ToolTip = 'The data type for the new field.';
                    }
                }
                group(ReviewPlacement)
                {
                    Caption = 'Placement';

                    field(ReviewPlacementType; Rec."Placement Type")
                    {
                        ApplicationArea = All;
                        Editable = false;
                        ToolTip = 'Where to place the field on the page.';
                    }
                    field(ReviewAnchorControl; Rec."Anchor Control")
                    {
                        ApplicationArea = All;
                        Editable = false;
                        ToolTip = 'The existing field control to place relative to.';
                    }
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(BackAction)
            {
                ApplicationArea = All;
                Caption = 'Back';
                InFooterBar = true;
                Image = PreviousRecord;
                Visible = CurrentStep > 1;

                trigger OnAction()
                begin
                    GoBack();
                end;
            }
            action(NextAction)
            {
                ApplicationArea = All;
                Caption = 'Next';
                InFooterBar = true;
                Image = NextRecord;
                Visible = CurrentStep < 4;

                trigger OnAction()
                begin
                    GoNext();
                end;
            }
            action(FinishAction)
            {
                ApplicationArea = All;
                Caption = 'Finish';
                InFooterBar = true;
                Image = Approve;
                Visible = CurrentStep = 4;

                trigger OnAction()
                begin
                    CurrPage.Close();
                end;
            }
            action(DownloadApp)
            {
                ApplicationArea = All;
                Caption = 'Download App';
                InFooterBar = true;
                Image = Export;
                Visible = CurrentStep = 4;

                trigger OnAction()
                begin
                    DoGenerateApp();
                    DoDownloadApp();
                end;
            }
            action(PublishApp)
            {
                ApplicationArea = All;
                Caption = 'Publish App';
                InFooterBar = true;
                Image = Apply;
                Visible = CurrentStep = 4;

                trigger OnAction()
                begin
                    DoGenerateApp();
                    DoPublishApp();
                end;
            }
            action(ExtensionDeploymentStatus)
            {
                ApplicationArea = All;
                Caption = 'Extension Deployment Status';
                Image = Info;
                RunObject = page "Extension Deployment Status";
                Visible = CurrentStep = 4;
            }
        }
    }

    trigger OnOpenPage()
    begin
        InitializePage();
    end;

    var
        Runner: Codeunit "App Build Runner";
        CurrentStep: Integer;
        Step1Visible: Boolean;
        Step2Visible: Boolean;
        Step3Visible: Boolean;
        Step4Visible: Boolean;
        ShowFieldLength: Boolean;
        ShowOptionString: Boolean;
        VersionDisplayText: Text;
        PublishInitiatedMsg: Label 'Extension upload initiated. Use the action below to check progress.';
        PublishFailedErr: Label 'Publish failed: %1', Comment = '%1 = Error message';
        ViewDeploymentStatusLbl: Label 'View Deployment Status';

    local procedure InitializePage()
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

        CurrentStep := 1;
        SetStepVisibility();
        UpdateConditionalVisibility();
    end;

    local procedure GoBack()
    begin
        CurrentStep -= 1;
        SetStepVisibility();
        CurrPage.Update(false);
    end;

    local procedure GoNext()
    begin
        Runner.ValidateStep(CurrentStep, Rec);
        CurrentStep += 1;
        if CurrentStep = 4 then
            UpdateReviewFields();
        SetStepVisibility();
        CurrPage.Update(false);
    end;

    local procedure DoGenerateApp()
    begin
        Runner.GenerateApp(Rec);
    end;

    local procedure DoDownloadApp()
    begin
        Runner.DownloadApp(Rec);
    end;

    local procedure DoPublishApp()
    var
        DeploymentNotification: Notification;
    begin
        if Runner.PublishApp(Rec) then begin
            DeploymentNotification.Message(PublishInitiatedMsg);
            DeploymentNotification.Scope(NotificationScope::LocalScope);
            DeploymentNotification.AddAction(ViewDeploymentStatusLbl,
                Codeunit::"App Build Runner", 'OpenDeploymentStatus');
            DeploymentNotification.Send();
        end else
            Error(PublishFailedErr, GetLastErrorText());
    end;

    local procedure SetStepVisibility()
    begin
        Step1Visible := CurrentStep = 1;
        Step2Visible := CurrentStep = 2;
        Step3Visible := CurrentStep = 3;
        Step4Visible := CurrentStep = 4;
    end;

    local procedure UpdateConditionalVisibility()
    begin
        ShowFieldLength := Rec."Field Data Type" in [Rec."Field Data Type"::Text, Rec."Field Data Type"::Code];
        ShowOptionString := Rec."Field Data Type" = Rec."Field Data Type"::Option;
        CurrPage.Update(false);
    end;

    local procedure UpdateReviewFields()
    begin
        VersionDisplayText := Format(Rec."Version Major") + '.' + Format(Rec."Version Minor") + '.' +
            Format(Rec."Version Build") + '.' + Format(Rec."Version Revision");
    end;
}
