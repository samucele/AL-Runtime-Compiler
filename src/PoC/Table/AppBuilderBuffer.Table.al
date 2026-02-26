/// <summary>
/// Backing buffer for the App Builder Dashboard page.
/// Used with SourceTableTemporary = true to store all user inputs
/// for app generation, publishing, and status tracking.
/// </summary>
table 50113 "App Builder Buffer"
{
    Caption = 'App Builder Buffer';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "App Name"; Text[100])
        {
            Caption = 'App Name';
        }
        field(11; Publisher; Text[100])
        {
            Caption = 'Publisher';
        }
        field(12; "Version Major"; Integer)
        {
            Caption = 'Major Version';
            MinValue = 0;
        }
        field(13; "Version Minor"; Integer)
        {
            Caption = 'Minor Version';
            MinValue = 0;
        }
        field(14; "Version Build"; Integer)
        {
            Caption = 'Build';
            MinValue = 0;
        }
        field(15; "Version Revision"; Integer)
        {
            Caption = 'Revision';
            MinValue = 0;
        }
        field(20; "Target Table No."; Integer)
        {
            Caption = 'Target Table No.';
            TableRelation = AllObjWithCaption."Object ID" where("Object Type" = const(Table));

            trigger OnValidate()
            begin
                ResolveTargetTable();
            end;
        }
        field(21; "Target Table Name"; Text[250])
        {
            Caption = 'Target Table Name';
            Editable = false;
        }
        field(22; "Target Table App Package Id"; Guid)
        {
            Caption = 'Target Table App Package Id';
            Editable = false;
        }
        field(30; "Target Page No."; Integer)
        {
            Caption = 'Target Page No.';
            TableRelation = "Page Metadata".ID where(SourceTable = field("Target Table No."));

            trigger OnValidate()
            begin
                ResolveTargetPage();
            end;
        }
        field(31; "Target Page Name"; Text[250])
        {
            Caption = 'Target Page Name';
            Editable = false;
        }
        field(32; "Target Page App Package Id"; Guid)
        {
            Caption = 'Target Page App Package Id';
            Editable = false;
        }
        field(40; "Field Id"; Integer)
        {
            Caption = 'Field Id';
            MinValue = 1;
        }
        field(41; "Field Name"; Text[100])
        {
            Caption = 'Field Name';
        }
        field(42; "Field Data Type"; Enum "Field Data Type")
        {
            Caption = 'Field Data Type';
        }
        field(43; "Field Length"; Integer)
        {
            Caption = 'Field Length';
            MinValue = 0;
        }
        field(44; "Option String"; Text[250])
        {
            Caption = 'Option String';
        }
        field(50; "Placement Type"; Enum "Placement Type")
        {
            Caption = 'Placement Type';
        }
        field(51; "Anchor Control"; Text[250])
        {
            Caption = 'Anchor Control';
            TableRelation = "Page Control Field".ControlName where(PageNo = field("Target Page No."));
            ValidateTableRelation = false;
        }
        field(60; "Table Ext. Object Id"; Integer)
        {
            Caption = 'Table Extension Object ID';
            MinValue = 1;
        }
        field(61; "Page Ext. Object Id"; Integer)
        {
            Caption = 'Page Extension Object ID';
            MinValue = 1;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    local procedure ResolveTargetTable()
    var
        AllObj: Record AllObjWithCaption;
    begin
        if "Target Table No." = 0 then begin
            "Target Table Name" := '';
            Clear("Target Table App Package Id");
            exit;
        end;
        AllObj.SetLoadFields("Object Name", "App Package ID");
        AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
        AllObj.SetRange("Object ID", "Target Table No.");
        AllObj.FindFirst();
        "Target Table Name" := AllObj."Object Name";
        "Target Table App Package Id" := AllObj."App Package ID";
    end;

    local procedure ResolveTargetPage()
    var
        AllObj: Record AllObjWithCaption;
        PageMeta: Record "Page Metadata";
    begin
        if "Target Page No." = 0 then begin
            "Target Page Name" := '';
            Clear("Target Page App Package Id");
            exit;
        end;
        PageMeta.SetLoadFields(Name);
        PageMeta.Get("Target Page No.");
        "Target Page Name" := PageMeta.Name;

        AllObj.SetLoadFields("App Package ID");
        AllObj.SetRange("Object Type", AllObj."Object Type"::Page);
        AllObj.SetRange("Object ID", "Target Page No.");
        AllObj.FindFirst();
        "Target Page App Package Id" := AllObj."App Package ID";
    end;
}
