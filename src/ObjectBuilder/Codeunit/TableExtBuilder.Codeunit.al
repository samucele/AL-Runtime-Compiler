/// <summary>
/// Generates table extension AL source code and SymbolReference JSON fragments.
/// Uses AL Code Writer for structured source generation.
/// No dependency on the Compiler layer.
/// </summary>
codeunit 50105 "Table Ext. Builder"
{
    Access = Public;

    var
        TargetTableId: Integer;
        TargetTableName: Text[250];
        TargetAppPackageId: Guid;
        ObjectId: Integer;
        FieldIds: List of [Integer];
        FieldNames: List of [Text];
        FieldDataTypes: List of [Integer];
        FieldLengths: List of [Integer];
        FieldOptionStrings: List of [Text];
        IsTargetSet: Boolean;
        IsObjectIdSet: Boolean;
        TargetNotSetErr: Label 'Call SetTarget() before generating output.', Locked = true;
        ObjectIdNotSetErr: Label 'Call SetObjectId() before generating output.', Locked = true;
        NoFieldsAddedErr: Label 'Add at least one field with AddField() before generating output.', Locked = true;

    /// <summary>
    /// Sets the target table being extended.
    /// </summary>
    /// <param name="TableId">The ID of the table to extend.</param>
    /// <param name="TableName">The name of the table to extend.</param>
    /// <param name="AppPackageId">The App Package ID of the owning app (from AllObjWithCaption).</param>
    procedure SetTarget(TableId: Integer; TableName: Text[250]; AppPackageId: Guid)
    begin
        TargetTableId := TableId;
        TargetTableName := TableName;
        TargetAppPackageId := AppPackageId;
        IsTargetSet := true;
    end;

    /// <summary>
    /// Sets the object ID for the generated table extension.
    /// </summary>
    /// <param name="NewObjectId">The object ID to assign.</param>
    procedure SetObjectId(NewObjectId: Integer)
    begin
        ObjectId := NewObjectId;
        IsObjectIdSet := true;
    end;

    /// <summary>
    /// Adds a field definition to the table extension.
    /// Multiple calls are supported to add multiple fields.
    /// </summary>
    /// <param name="FieldId">The field ID number.</param>
    /// <param name="FieldName">The field name.</param>
    /// <param name="DataType">The field data type.</param>
    /// <param name="Length">The field length (used for Text and Code types; 0 uses defaults).</param>
    /// <param name="OptionString">The option string (used for Option type; comma-separated values).</param>
    procedure AddField(FieldId: Integer; FieldName: Text[100]; DataType: Enum "Field Data Type"; Length: Integer; OptionString: Text[250])
    begin
        FieldIds.Add(FieldId);
        FieldNames.Add(FieldName);
        FieldDataTypes.Add(DataType.AsInteger());
        FieldLengths.Add(Length);
        FieldOptionStrings.Add(OptionString);
    end;

    /// <summary>
    /// Generates the complete AL source file content for the table extension.
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
    /// Generates the SymbolReference JSON fragment for this table extension.
    /// The returned JsonObject is ready to be added to the 'TableExtensions' array.
    /// </summary>
    /// <returns>A JsonObject representing the table extension symbol reference.</returns>
    procedure GenerateSymbolReference(): JsonObject
    var
        Result: JsonObject;
        FieldsArray: JsonArray;
        FieldObj: JsonObject;
        FieldTypeDef: JsonObject;
        FieldPropsArray: JsonArray;
        FieldDataType: Enum "Field Data Type";
        TypeName: Text;
        TypeSubtype: Text;
        i: Integer;
        CurrentFieldName: Text;
    begin
        ValidateState();

        for i := 1 to FieldIds.Count() do begin
            Clear(FieldObj);
            Clear(FieldTypeDef);
            Clear(FieldPropsArray);

            FieldDataType := "Field Data Type".FromInteger(FieldDataTypes.Get(i));
            GetSymRefTypeInfo(FieldDataType, FieldLengths.Get(i), FieldOptionStrings.Get(i), TypeName, TypeSubtype);

            FieldTypeDef.Add('Name', TypeName);
            if TypeSubtype <> '' then
                FieldTypeDef.Add('Subtype', TypeSubtype);

            CurrentFieldName := FieldNames.Get(i);
            AddSymRefProperty(FieldPropsArray, 'Caption', CurrentFieldName);
            AddSymRefProperty(FieldPropsArray, 'DataClassification', 'CustomerContent');

            FieldObj.Add('TypeDefinition', FieldTypeDef);
            FieldObj.Add('Properties', FieldPropsArray);
            FieldObj.Add('Id', FieldIds.Get(i));
            FieldObj.Add('Name', CurrentFieldName);
            FieldsArray.Add(FieldObj);
        end;

        Result.Add('TargetObject', FormatTargetObject(TargetAppPackageId, TargetTableName));
        Result.Add('Fields', FieldsArray);
        Result.Add('ReferenceSourceFileName', GetSourceFilePath());
        Result.Add('Id', ObjectId);
        Result.Add('Name', GetObjectName());

        exit(Result);
    end;

    /// <summary>
    /// Returns the recommended ZIP path for the generated source file.
    /// </summary>
    /// <returns>A path like 'src/TableExtension/Customer.TableExt.al'.</returns>
    procedure GetSourceFilePath(): Text
    begin
        exit('src/TableExtension/' + SanitizeName(TargetTableName) + '.TableExt.al');
    end;

    /// <summary>
    /// Returns the BC entitlement type code for table extensions.
    /// </summary>
    /// <returns>Always returns 9.</returns>
    procedure GetEntitlementTypeCode(): Integer
    begin
        exit(9);
    end;

    /// <summary>
    /// Returns the configured object ID.
    /// </summary>
    /// <returns>The object ID of this table extension.</returns>
    procedure GetObjectId(): Integer
    begin
        exit(ObjectId);
    end;

    /// <summary>
    /// Resets all internal state for reuse.
    /// </summary>
    procedure Reset()
    begin
        TargetTableId := 0;
        TargetTableName := '';
        Clear(TargetAppPackageId);
        ObjectId := 0;
        Clear(FieldIds);
        Clear(FieldNames);
        Clear(FieldDataTypes);
        Clear(FieldLengths);
        Clear(FieldOptionStrings);
        IsTargetSet := false;
        IsObjectIdSet := false;
    end;

    // --- Internal Helpers ---

    local procedure ValidateState()
    begin
        if not IsTargetSet then
            Error(TargetNotSetErr);
        if not IsObjectIdSet then
            Error(ObjectIdNotSetErr);
        if FieldIds.Count() = 0 then
            Error(NoFieldsAddedErr);
    end;

    local procedure GetObjectName(): Text
    begin
        exit(TargetTableName + ' Ext');
    end;

    local procedure BuildSource(var Writer: Codeunit "AL Code Writer")
    var
        FieldDataType: Enum "Field Data Type";
        TypeString: Text;
        i: Integer;
    begin
        Writer.BeginObject('tableextension', ObjectId, GetObjectName(), 'extends', TargetTableName);
        Writer.BeginBlock('fields');

        for i := 1 to FieldIds.Count() do begin
            FieldDataType := "Field Data Type".FromInteger(FieldDataTypes.Get(i));
            TypeString := GetFieldTypeString(FieldDataType, FieldLengths.Get(i));

            Writer.BeginField(FieldIds.Get(i), FieldNames.Get(i), TypeString);
            Writer.AddProperty('DataClassification', 'CustomerContent');
            Writer.AddStringProperty('Caption', FieldNames.Get(i));

            if FieldDataType = "Field Data Type"::Option then
                if FieldOptionStrings.Get(i) <> '' then begin
                    Writer.AddProperty('OptionMembers', FieldOptionStrings.Get(i));
                    Writer.AddStringProperty('OptionCaption', FieldOptionStrings.Get(i));
                end;

            Writer.EndField();
        end;

        Writer.EndBlock(); // fields
        Writer.EndObject();
    end;

    local procedure GetFieldTypeString(DataType: Enum "Field Data Type"; Length: Integer): Text
    var
        EffectiveLength: Integer;
    begin
        case DataType of
            "Field Data Type"::Text:
                begin
                    EffectiveLength := Length;
                    if EffectiveLength <= 0 then
                        EffectiveLength := 100;
                    exit('Text[' + Format(EffectiveLength) + ']');
                end;
            "Field Data Type"::Code:
                begin
                    EffectiveLength := Length;
                    if EffectiveLength <= 0 then
                        EffectiveLength := 20;
                    exit('Code[' + Format(EffectiveLength) + ']');
                end;
            "Field Data Type"::Integer:
                exit('Integer');
            "Field Data Type"::Decimal:
                exit('Decimal');
            "Field Data Type"::Boolean:
                exit('Boolean');
            "Field Data Type"::Date:
                exit('Date');
            "Field Data Type"::DateTime:
                exit('DateTime');
            "Field Data Type"::Option:
                exit('Option');
            else
                exit('Text[100]');
        end;
    end;

    local procedure GetSymRefTypeInfo(DataType: Enum "Field Data Type"; Length: Integer; OptionString: Text; var TypeName: Text; var TypeSubtype: Text)
    var
        EffectiveLength: Integer;
    begin
        TypeSubtype := '';
        case DataType of
            "Field Data Type"::Text:
                begin
                    TypeName := 'Text';
                    EffectiveLength := Length;
                    if EffectiveLength <= 0 then
                        EffectiveLength := 100;
                    TypeSubtype := Format(EffectiveLength);
                end;
            "Field Data Type"::Code:
                begin
                    TypeName := 'Code';
                    EffectiveLength := Length;
                    if EffectiveLength <= 0 then
                        EffectiveLength := 20;
                    TypeSubtype := Format(EffectiveLength);
                end;
            "Field Data Type"::Integer:
                TypeName := 'Integer';
            "Field Data Type"::Decimal:
                TypeName := 'Decimal';
            "Field Data Type"::Boolean:
                TypeName := 'Boolean';
            "Field Data Type"::Date:
                TypeName := 'Date';
            "Field Data Type"::DateTime:
                TypeName := 'DateTime';
            "Field Data Type"::Option:
                begin
                    TypeName := 'Option';
                    if OptionString <> '' then
                        TypeSubtype := OptionString;
                end;
            else
                TypeName := 'Text';
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
