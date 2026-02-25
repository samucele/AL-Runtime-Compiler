/// <summary>
/// Generates page extension AL source code and SymbolReference JSON fragments.
/// Uses AL Code Writer for structured source generation.
/// No dependency on the Compiler layer.
/// </summary>
codeunit 50106 "Page Ext. Builder"
{
    Access = Public;

    var
        TargetPageId: Integer;
        TargetPageName: Text[250];
        TargetAppPackageId: Guid;
        ObjectId: Integer;
        Placement: Enum "Placement Type";
        AnchorControl: Text[250];
        PageFieldNames: List of [Text];
        PageFieldSourceExprs: List of [Text];
        IsTargetSet: Boolean;
        IsObjectIdSet: Boolean;
        IsPlacementSet: Boolean;
        TargetNotSetErr: Label 'Call SetTarget() before generating output.', Locked = true;
        ObjectIdNotSetErr: Label 'Call SetObjectId() before generating output.', Locked = true;
        NoFieldsAddedErr: Label 'Add at least one field with AddField() before generating output.', Locked = true;

    /// <summary>
    /// Sets the target page being extended.
    /// </summary>
    /// <param name="PageId">The ID of the page to extend.</param>
    /// <param name="PageName">The name of the page to extend.</param>
    /// <param name="AppPackageId">The App Package ID of the owning app (from AllObjWithCaption).</param>
    procedure SetTarget(PageId: Integer; PageName: Text[250]; AppPackageId: Guid)
    begin
        TargetPageId := PageId;
        TargetPageName := PageName;
        TargetAppPackageId := AppPackageId;
        IsTargetSet := true;
    end;

    /// <summary>
    /// Sets the object ID for the generated page extension.
    /// </summary>
    /// <param name="NewObjectId">The object ID to assign.</param>
    procedure SetObjectId(NewObjectId: Integer)
    begin
        ObjectId := NewObjectId;
        IsObjectIdSet := true;
    end;

    /// <summary>
    /// Sets where the field group appears on the page.
    /// For addlast/addfirst, AnchorControl defaults to 'Content' if left empty.
    /// </summary>
    /// <param name="NewPlacement">The placement type (addlast, addfirst, addafter, addbefore).</param>
    /// <param name="NewAnchorControl">The anchor control name. Use empty string for addlast/addfirst defaults.</param>
    procedure SetPlacement(NewPlacement: Enum "Placement Type"; NewAnchorControl: Text[250])
    begin
        Placement := NewPlacement;
        AnchorControl := NewAnchorControl;
        IsPlacementSet := true;
    end;

    /// <summary>
    /// Adds a page field control to the page extension.
    /// Multiple calls are supported to add multiple fields.
    /// </summary>
    /// <param name="FieldName">The display name of the field control (will be double-quoted).</param>
    /// <param name="SourceExpression">The AL source expression (e.g., 'Rec."My Custom Field"').</param>
    procedure AddField(FieldName: Text; SourceExpression: Text)
    begin
        PageFieldNames.Add(FieldName);
        PageFieldSourceExprs.Add(SourceExpression);
    end;

    /// <summary>
    /// Generates the complete AL source file content for the page extension.
    /// Writes UTF-8 without BOM to the provided TempBlob.
    /// </summary>
    /// <param name="SourceBlob">The TempBlob to receive the AL source content.</param>
    procedure GenerateSource(var SourceBlob: Codeunit "Temp Blob")
    var
        Writer: Codeunit "AL Code Writer";
    begin
        ValidateState();
        BuildSource(Writer);
        Writer.WriteToBlob(SourceBlob);
    end;

    /// <summary>
    /// Returns the AL source code as text for preview purposes.
    /// </summary>
    /// <returns>The complete AL source code as a text string.</returns>
    procedure PreviewSource(): Text
    var
        Writer: Codeunit "AL Code Writer";
    begin
        ValidateState();
        BuildSource(Writer);
        exit(Writer.ToText());
    end;

    /// <summary>
    /// Generates the SymbolReference JSON fragment for this page extension.
    /// The returned JsonObject is ready to be added to the 'PageExtensions' array.
    /// </summary>
    /// <returns>A JsonObject representing the page extension symbol reference.</returns>
    procedure GenerateSymbolReference(): JsonObject
    var
        Result: JsonObject;
        ControlChanges: JsonArray;
        ChangeObj: JsonObject;
        ChangeControls: JsonArray;
        FieldCtrl: JsonObject;
        FieldCtrlType: JsonObject;
        FieldCtrlProps: JsonArray;
        i: Integer;
        ControlId: Integer;
    begin
        ValidateState();

        ControlId := 100000001;

        for i := 1 to PageFieldNames.Count() do begin
            Clear(FieldCtrl);
            Clear(FieldCtrlType);
            Clear(FieldCtrlProps);

            FieldCtrlType.Add('Name', 'Text');
            AddSymRefProperty(FieldCtrlProps, 'ApplicationArea', '#All');
            AddSymRefProperty(FieldCtrlProps, 'SourceExpression', PageFieldSourceExprs.Get(i));

            FieldCtrl.Add('Kind', 8); // Field control
            FieldCtrl.Add('TypeDefinition', FieldCtrlType);
            FieldCtrl.Add('Properties', FieldCtrlProps);
            FieldCtrl.Add('Id', ControlId);
            FieldCtrl.Add('Name', SanitizeName(PageFieldNames.Get(i)));
            ChangeControls.Add(FieldCtrl);

            ControlId += 1;
        end;

        // ControlChange
        ChangeObj.Add('Anchor', ResolveAnchorControl());
        ChangeObj.Add('ChangeKind', GetChangeKind(Placement));
        ChangeObj.Add('Controls', ChangeControls);
        ControlChanges.Add(ChangeObj);

        Result.Add('TargetObject', FormatTargetObject(TargetAppPackageId, TargetPageName));
        Result.Add('ControlChanges', ControlChanges);
        Result.Add('ReferenceSourceFileName', GetSourceFilePath());
        Result.Add('Id', ObjectId);
        Result.Add('Name', GetObjectName());

        exit(Result);
    end;

    /// <summary>
    /// Returns the recommended ZIP path for the generated source file.
    /// </summary>
    /// <returns>A path like 'src/PageExtension/CustomerCard.PageExt.al'.</returns>
    procedure GetSourceFilePath(): Text
    begin
        exit('src/PageExtension/' + SanitizeName(TargetPageName) + '.PageExt.al');
    end;

    /// <summary>
    /// Returns the BC entitlement type code for page extensions.
    /// </summary>
    /// <returns>Always returns 8.</returns>
    procedure GetEntitlementTypeCode(): Integer
    begin
        exit(8);
    end;

    /// <summary>
    /// Returns the configured object ID.
    /// </summary>
    /// <returns>The object ID of this page extension.</returns>
    procedure GetObjectId(): Integer
    begin
        exit(ObjectId);
    end;

    /// <summary>
    /// Resets all internal state for reuse.
    /// </summary>
    procedure Reset()
    begin
        TargetPageId := 0;
        TargetPageName := '';
        Clear(TargetAppPackageId);
        ObjectId := 0;
        Placement := "Placement Type"::addlast;
        AnchorControl := '';
        Clear(PageFieldNames);
        Clear(PageFieldSourceExprs);
        IsTargetSet := false;
        IsObjectIdSet := false;
        IsPlacementSet := false;
    end;

    // --- Internal Helpers ---

    local procedure ValidateState()
    begin
        if not IsTargetSet then
            Error(TargetNotSetErr);
        if not IsObjectIdSet then
            Error(ObjectIdNotSetErr);
        if PageFieldNames.Count() = 0 then
            Error(NoFieldsAddedErr);
    end;

    local procedure GetObjectName(): Text
    begin
        exit(TargetPageName + ' Ext');
    end;

    local procedure BuildSource(var Writer: Codeunit "AL Code Writer")
    var
        i: Integer;
    begin
        Writer.BeginObject('pageextension', ObjectId, GetObjectName(), 'extends', TargetPageName);
        Writer.BeginBlock('layout');

        Writer.BeginBlockWithArg(GetPlacementKeyword(Placement), ResolveAnchorControl());

        for i := 1 to PageFieldNames.Count() do begin
            Writer.BeginPageField(PageFieldNames.Get(i), PageFieldSourceExprs.Get(i));
            Writer.AddProperty('ApplicationArea', 'All');
            Writer.EndPageField();
        end;

        Writer.EndBlock(); // placement
        Writer.EndBlock(); // layout
        Writer.EndObject();
    end;

    local procedure ResolveAnchorControl(): Text
    begin
        if AnchorControl <> '' then
            exit(AnchorControl);

        // Default anchor for addlast/addfirst
        exit('Content');
    end;

    local procedure GetPlacementKeyword(PlacementType: Enum "Placement Type"): Text
    begin
        case PlacementType of
            "Placement Type"::addlast:
                exit('addlast');
            "Placement Type"::addfirst:
                exit('addfirst');
            "Placement Type"::addafter:
                exit('addafter');
            "Placement Type"::addbefore:
                exit('addbefore');
            else
                exit('addlast');
        end;
    end;

    local procedure GetChangeKind(PlacementType: Enum "Placement Type"): Integer
    begin
        // ChangeKind mapping: addlast=4, addfirst=3, addafter=1, addbefore=2
        case PlacementType of
            "Placement Type"::addlast:
                exit(4);
            "Placement Type"::addfirst:
                exit(3);
            "Placement Type"::addafter:
                exit(1);
            "Placement Type"::addbefore:
                exit(2);
            else
                exit(4);
        end;
    end;

    local procedure FormatTargetObject(AppPackageId: Guid; ObjectName: Text): Text
    var
        GuidStr: Text;
    begin
        // Format: #<guid-no-dashes-lowercase>#<ObjectName>
        GuidStr := LowerCase(DelChr(Format(AppPackageId, 0, 9), '=', '{}-'));
        exit('#' + GuidStr + '#' + ObjectName);
    end;

    local procedure SanitizeName(Name: Text): Text
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

    local procedure AddSymRefProperty(var PropsArray: JsonArray; PropName: Text; PropValue: Text)
    var
        Prop: JsonObject;
    begin
        Prop.Add('Name', PropName);
        Prop.Add('Value', PropValue);
        PropsArray.Add(Prop);
    end;
}
