/// <summary>
/// Integration tests for AL Runtime Compiler - tests cross-object interactions
/// and end-to-end workflows for Table Extension Builder and Page Extension Builder.
/// </summary>
codeunit 50160 "ARC Integration Tests"
{
    Subtype = Test;

    var
        LibraryAssert: Codeunit "Library Assert";

    // ======================================================================
    // TABLE EXTENSION BUILDER INTEGRATION TESTS
    // ======================================================================

    [Test]
    procedure TableExtBuilder_FullTextFieldGeneration()
    var
        Builder: Codeunit "Table Ext. Builder";
        Output: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Full table extension source generation with Text field produces correct AL syntax

        // [GIVEN] A table extension targeting table 18 "Customer"
        Builder.SetTarget(18, 'Customer', EmptyGuid);
        Builder.SetObjectId(50100);
        Builder.AddField(50100, 'My Custom Field', "Field Data Type"::Text, 100, '');

        // [WHEN] We preview the source
        Output := Builder.PreviewSource();

        // [THEN] Output contains correct AL syntax
        LibraryAssert.IsTrue(Output.Contains('tableextension 50100'), 'Should contain object declaration');
        LibraryAssert.IsTrue(Output.Contains('extends "Customer"'), 'Should contain extends clause');
        LibraryAssert.IsTrue(Output.Contains('"My Custom Field"'), 'Should contain field name');
        LibraryAssert.IsTrue(Output.Contains('Text[100]'), 'Should contain field type');
        LibraryAssert.IsTrue(Output.Contains('DataClassification = CustomerContent'), 'Should contain DataClassification');
        LibraryAssert.IsTrue(Output.Contains('Caption = ''My Custom Field'''), 'Should contain Caption');
    end;

    [Test]
    procedure TableExtBuilder_IntegerFieldGeneration()
    var
        Builder: Codeunit "Table Ext. Builder";
        Output: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Table extension with Integer field produces Integer type, not Text

        // [GIVEN] A table extension with an Integer field
        Builder.SetTarget(18, 'Customer', EmptyGuid);
        Builder.SetObjectId(50101);
        Builder.AddField(50101, 'My Integer Field', "Field Data Type"::Integer, 0, '');

        // [WHEN] We preview the source
        Output := Builder.PreviewSource();

        // [THEN] Output contains Integer type
        LibraryAssert.IsTrue(Output.Contains('; Integer)'), 'Should contain Integer type');
        LibraryAssert.IsFalse(Output.Contains('Text['), 'Should not contain Text type');
    end;

    [Test]
    procedure TableExtBuilder_CodeFieldGeneration()
    var
        Builder: Codeunit "Table Ext. Builder";
        Output: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Table extension with Code field and custom length produces Code[20]

        // [GIVEN] A table extension with a Code field of length 20
        Builder.SetTarget(23, 'Vendor', EmptyGuid);
        Builder.SetObjectId(50102);
        Builder.AddField(50102, 'External Code', "Field Data Type"::Code, 20, '');

        // [WHEN] We preview the source
        Output := Builder.PreviewSource();

        // [THEN] Output contains Code[20] type
        LibraryAssert.IsTrue(Output.Contains('Code[20]'), 'Should contain Code[20] type');
    end;

    [Test]
    procedure TableExtBuilder_OptionFieldGeneration()
    var
        Builder: Codeunit "Table Ext. Builder";
        Output: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Table extension with Option field includes OptionMembers and OptionCaption

        // [GIVEN] A table extension with an Option field
        Builder.SetTarget(18, 'Customer', EmptyGuid);
        Builder.SetObjectId(50103);
        Builder.AddField(50103, 'Priority Level', "Field Data Type"::Option, 0, 'Low,Medium,High');

        // [WHEN] We preview the source
        Output := Builder.PreviewSource();

        // [THEN] Output contains Option type and option properties
        LibraryAssert.IsTrue(Output.Contains('; Option)'), 'Should contain Option type');
        LibraryAssert.IsTrue(Output.Contains('OptionMembers = Low,Medium,High'), 'Should contain OptionMembers');
        LibraryAssert.IsTrue(Output.Contains('OptionCaption = ''Low,Medium,High'''), 'Should contain OptionCaption');
    end;

    [Test]
    procedure TableExtBuilder_SymbolReferenceJSON()
    var
        Builder: Codeunit "Table Ext. Builder";
        SymRef: JsonObject;
        Token: JsonToken;
        FieldsArray: JsonArray;
        FieldObj: JsonObject;
        TypeDef: JsonObject;
        TargetObj: Text;
        TestGuid: Guid;
    begin
        // [SCENARIO] GenerateSymbolReference produces correct JSON structure

        // [GIVEN] A table extension with a Text field
        TestGuid := CreateGuid();
        Builder.SetTarget(18, 'Customer', TestGuid);
        Builder.SetObjectId(50104);
        Builder.AddField(50104, 'Test Field', "Field Data Type"::Text, 50, '');

        // [WHEN] We generate the symbol reference
        SymRef := Builder.GenerateSymbolReference();

        // [THEN] JSON contains all required elements
        LibraryAssert.IsTrue(SymRef.Get('Id', Token), 'Should have Id');
        LibraryAssert.AreEqual(50104, Token.AsValue().AsInteger(), 'Id should match');

        LibraryAssert.IsTrue(SymRef.Get('Name', Token), 'Should have Name');
        LibraryAssert.AreEqual('Customer Ext', Token.AsValue().AsText(), 'Name should match');

        LibraryAssert.IsTrue(SymRef.Get('TargetObject', Token), 'Should have TargetObject');
        TargetObj := Token.AsValue().AsText();
        LibraryAssert.IsTrue(TargetObj.StartsWith('#'), 'TargetObject should start with #');
        LibraryAssert.IsTrue(TargetObj.EndsWith('#Customer'), 'TargetObject should end with #Customer');

        LibraryAssert.IsTrue(SymRef.Get('Fields', Token), 'Should have Fields array');
        FieldsArray := Token.AsArray();
        LibraryAssert.AreEqual(1, FieldsArray.Count(), 'Should have 1 field');

        FieldsArray.Get(0, Token);
        FieldObj := Token.AsObject();
        LibraryAssert.IsTrue(FieldObj.Get('Id', Token), 'Field should have Id');
        LibraryAssert.AreEqual(50104, Token.AsValue().AsInteger(), 'Field Id should match');

        LibraryAssert.IsTrue(FieldObj.Get('TypeDefinition', Token), 'Field should have TypeDefinition');
        TypeDef := Token.AsObject();
        LibraryAssert.IsTrue(TypeDef.Get('Name', Token), 'TypeDef should have Name');
        LibraryAssert.AreEqual('Text', Token.AsValue().AsText(), 'TypeDef Name should be Text');
        LibraryAssert.IsTrue(TypeDef.Get('Subtype', Token), 'TypeDef should have Subtype');
        LibraryAssert.AreEqual('50', Token.AsValue().AsText(), 'TypeDef Subtype should be 50');
    end;

    [Test]
    procedure TableExtBuilder_SourceFilePath()
    var
        Builder: Codeunit "Table Ext. Builder";
        FilePath: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] GetSourceFilePath returns correct path format

        // [GIVEN] A table extension targeting "Customer"
        Builder.SetTarget(18, 'Customer', EmptyGuid);
        Builder.SetObjectId(50105);
        Builder.AddField(50105, 'Test', "Field Data Type"::Text, 50, '');

        // [WHEN] We get the source file path
        FilePath := Builder.GetSourceFilePath();

        // [THEN] Path follows the expected format
        LibraryAssert.AreEqual('src/TableExtension/Customer.TableExt.al', FilePath, 'File path should match');
    end;

    [Test]
    procedure TableExtBuilder_EntitlementTypeCode()
    var
        Builder: Codeunit "Table Ext. Builder";
        TypeCode: Integer;
    begin
        // [SCENARIO] GetEntitlementTypeCode returns 9 for table extensions

        // [GIVEN] A table extension builder instance
        // [WHEN] We get the entitlement type code
        TypeCode := Builder.GetEntitlementTypeCode();

        // [THEN] It returns 9
        LibraryAssert.AreEqual(9, TypeCode, 'Entitlement type code should be 9');
    end;

    [Test]
    procedure TableExtBuilder_MultipleFields()
    var
        Builder: Codeunit "Table Ext. Builder";
        Output: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Adding multiple fields generates all fields in source

        // [GIVEN] A table extension with two fields
        Builder.SetTarget(18, 'Customer', EmptyGuid);
        Builder.SetObjectId(50106);
        Builder.AddField(50106, 'First Field', "Field Data Type"::Text, 50, '');
        Builder.AddField(50107, 'Second Field', "Field Data Type"::Integer, 0, '');

        // [WHEN] We preview the source
        Output := Builder.PreviewSource();

        // [THEN] Both fields appear in the output
        LibraryAssert.IsTrue(Output.Contains('"First Field"'), 'Should contain first field');
        LibraryAssert.IsTrue(Output.Contains('"Second Field"'), 'Should contain second field');
        LibraryAssert.IsTrue(Output.Contains('Text[50]'), 'Should contain first field type');
        LibraryAssert.IsTrue(Output.Contains('Integer'), 'Should contain second field type');
    end;

    [Test]
    procedure TableExtBuilder_ResetClearsState()
    var
        Builder: Codeunit "Table Ext. Builder";
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Reset clears all state and PreviewSource errors

        // [GIVEN] A configured table extension builder
        Builder.SetTarget(18, 'Customer', EmptyGuid);
        Builder.SetObjectId(50107);
        Builder.AddField(50107, 'Test', "Field Data Type"::Text, 50, '');

        // [WHEN] We reset the builder
        Builder.Reset();

        // [THEN] PreviewSource throws an error because state is not set
        asserterror Builder.PreviewSource();
        LibraryAssert.ExpectedError('Call SetTarget() before generating output.');
    end;

    // ======================================================================
    // PAGE EXTENSION BUILDER INTEGRATION TESTS
    // ======================================================================

    [Test]
    procedure PageExtBuilder_FullAddAfterGeneration()
    var
        Builder: Codeunit "Page Ext. Builder";
        Output: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Full page extension source generation with addafter produces correct AL syntax

        // [GIVEN] A page extension targeting Customer Card with addafter placement
        Builder.SetTarget(21, 'Customer Card', EmptyGuid);
        Builder.SetObjectId(50200);
        Builder.SetPlacement("Placement Type"::addafter, 'Name');
        Builder.AddField('My Custom Field', 'Rec."My Custom Field"');

        // [WHEN] We preview the source
        Output := Builder.PreviewSource();

        // [THEN] Output contains correct AL syntax
        LibraryAssert.IsTrue(Output.Contains('pageextension 50200'), 'Should contain object declaration');
        LibraryAssert.IsTrue(Output.Contains('extends "Customer Card"'), 'Should contain extends clause');
        LibraryAssert.IsTrue(Output.Contains('addafter("Name")'), 'Should contain addafter with anchor');
        LibraryAssert.IsTrue(Output.Contains('field("My Custom Field"'), 'Should contain field control');
        LibraryAssert.IsTrue(Output.Contains('Rec."My Custom Field"'), 'Should contain source expression');
        LibraryAssert.IsTrue(Output.Contains('ApplicationArea = All'), 'Should contain ApplicationArea');
    end;

    [Test]
    procedure PageExtBuilder_AddBeforePlacement()
    var
        Builder: Codeunit "Page Ext. Builder";
        Output: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Page extension with addbefore placement generates correct syntax

        // [GIVEN] A page extension with addbefore placement
        Builder.SetTarget(21, 'Customer Card', EmptyGuid);
        Builder.SetObjectId(50201);
        Builder.SetPlacement("Placement Type"::addbefore, 'Address');
        Builder.AddField('Custom Field', 'Rec."Custom Field"');

        // [WHEN] We preview the source
        Output := Builder.PreviewSource();

        // [THEN] Output contains addbefore syntax
        LibraryAssert.IsTrue(Output.Contains('addbefore("Address")'), 'Should contain addbefore with anchor');
        LibraryAssert.IsFalse(Output.Contains('addafter'), 'Should not contain addafter');
    end;

    [Test]
    procedure PageExtBuilder_SymbolReferenceJSON()
    var
        Builder: Codeunit "Page Ext. Builder";
        SymRef: JsonObject;
        Token: JsonToken;
        ControlChanges: JsonArray;
        ChangeObj: JsonObject;
        Controls: JsonArray;
        CtrlObj: JsonObject;
        TestGuid: Guid;
    begin
        // [SCENARIO] GenerateSymbolReference produces correct JSON with ControlChanges

        // [GIVEN] A page extension with addafter placement
        TestGuid := CreateGuid();
        Builder.SetTarget(21, 'Customer Card', TestGuid);
        Builder.SetObjectId(50202);
        Builder.SetPlacement("Placement Type"::addafter, 'Name');
        Builder.AddField('Test Field', 'Rec."Test Field"');

        // [WHEN] We generate the symbol reference
        SymRef := Builder.GenerateSymbolReference();

        // [THEN] JSON contains all required elements
        LibraryAssert.IsTrue(SymRef.Get('Id', Token), 'Should have Id');
        LibraryAssert.AreEqual(50202, Token.AsValue().AsInteger(), 'Id should match');

        LibraryAssert.IsTrue(SymRef.Get('Name', Token), 'Should have Name');
        LibraryAssert.AreEqual('Customer Card Ext', Token.AsValue().AsText(), 'Name should match');

        LibraryAssert.IsTrue(SymRef.Get('ControlChanges', Token), 'Should have ControlChanges array');
        ControlChanges := Token.AsArray();
        LibraryAssert.AreEqual(1, ControlChanges.Count(), 'Should have 1 control change');

        ControlChanges.Get(0, Token);
        ChangeObj := Token.AsObject();

        LibraryAssert.IsTrue(ChangeObj.Get('Anchor', Token), 'ControlChange should have Anchor');
        LibraryAssert.AreEqual('Name', Token.AsValue().AsText(), 'Anchor should be Name');

        LibraryAssert.IsTrue(ChangeObj.Get('ChangeKind', Token), 'ControlChange should have ChangeKind');
        LibraryAssert.AreEqual(1, Token.AsValue().AsInteger(), 'ChangeKind should be 1 for addafter');

        LibraryAssert.IsTrue(ChangeObj.Get('Controls', Token), 'ControlChange should have Controls array');
        Controls := Token.AsArray();
        LibraryAssert.AreEqual(1, Controls.Count(), 'Should have 1 control');

        Controls.Get(0, Token);
        CtrlObj := Token.AsObject();
        LibraryAssert.IsTrue(CtrlObj.Get('Kind', Token), 'Control should have Kind');
        LibraryAssert.AreEqual(8, Token.AsValue().AsInteger(), 'Kind should be 8 for field control');
    end;

    [Test]
    procedure PageExtBuilder_SourceFilePath()
    var
        Builder: Codeunit "Page Ext. Builder";
        FilePath: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] GetSourceFilePath returns correct path format

        // [GIVEN] A page extension targeting "Customer Card"
        Builder.SetTarget(21, 'Customer Card', EmptyGuid);
        Builder.SetObjectId(50203);
        Builder.SetPlacement("Placement Type"::addafter, 'Name');
        Builder.AddField('Test', 'Rec."Test"');

        // [WHEN] We get the source file path
        FilePath := Builder.GetSourceFilePath();

        // [THEN] Path follows the expected format
        LibraryAssert.AreEqual('src/PageExtension/CustomerCard.PageExt.al', FilePath, 'File path should match');
    end;

    [Test]
    procedure PageExtBuilder_EntitlementTypeCode()
    var
        Builder: Codeunit "Page Ext. Builder";
        TypeCode: Integer;
    begin
        // [SCENARIO] GetEntitlementTypeCode returns 8 for page extensions

        // [GIVEN] A page extension builder instance
        // [WHEN] We get the entitlement type code
        TypeCode := Builder.GetEntitlementTypeCode();

        // [THEN] It returns 8
        LibraryAssert.AreEqual(8, TypeCode, 'Entitlement type code should be 8');
    end;

    [Test]
    procedure PageExtBuilder_QuotedAnchor()
    var
        Builder: Codeunit "Page Ext. Builder";
        Output: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] SetPlacement with anchor containing special characters quotes correctly

        // [GIVEN] A page extension with an anchor containing special characters
        Builder.SetTarget(26, 'Vendor Card', EmptyGuid);
        Builder.SetObjectId(50204);
        Builder.SetPlacement("Placement Type"::addafter, 'Vendor No.');
        Builder.AddField('Custom Field', 'Rec."Custom Field"');

        // [WHEN] We preview the source
        Output := Builder.PreviewSource();

        // [THEN] Output contains the anchor with quotes preserved
        LibraryAssert.IsTrue(Output.Contains('addafter("Vendor No.")'), 'Should contain anchor with preserved text');
    end;

    [Test]
    procedure PageExtBuilder_ResetClearsState()
    var
        Builder: Codeunit "Page Ext. Builder";
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Reset clears all state and PreviewSource errors

        // [GIVEN] A configured page extension builder
        Builder.SetTarget(21, 'Customer Card', EmptyGuid);
        Builder.SetObjectId(50205);
        Builder.SetPlacement("Placement Type"::addafter, 'Name');
        Builder.AddField('Test', 'Rec."Test"');

        // [WHEN] We reset the builder
        Builder.Reset();

        // [THEN] PreviewSource throws an error because state is not set
        asserterror Builder.PreviewSource();
        LibraryAssert.ExpectedError('Call SetTarget() before generating output.');
    end;

    [Test]
    procedure PageExtBuilder_ChangeKindAddbefore()
    var
        Builder: Codeunit "Page Ext. Builder";
        SymRef: JsonObject;
        Token: JsonToken;
        ControlChanges: JsonArray;
        ChangeObj: JsonObject;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] addbefore placement generates ChangeKind value 2 in SymbolReference

        // [GIVEN] A page extension with addbefore placement
        Builder.SetTarget(21, 'Customer Card', EmptyGuid);
        Builder.SetObjectId(50206);
        Builder.SetPlacement("Placement Type"::addbefore, 'Name');
        Builder.AddField('Test Field', 'Rec."Test Field"');

        // [WHEN] We generate the symbol reference
        SymRef := Builder.GenerateSymbolReference();

        // [THEN] ChangeKind is 2 for addbefore
        LibraryAssert.IsTrue(SymRef.Get('ControlChanges', Token), 'Should have ControlChanges');
        ControlChanges := Token.AsArray();
        ControlChanges.Get(0, Token);
        ChangeObj := Token.AsObject();
        LibraryAssert.IsTrue(ChangeObj.Get('ChangeKind', Token), 'Should have ChangeKind');
        LibraryAssert.AreEqual(2, Token.AsValue().AsInteger(), 'ChangeKind should be 2 for addbefore');
    end;

    // ======================================================================
    // CROSS-BUILDER INTEGRATION TESTS
    // ======================================================================

    [Test]
    procedure TableAndPageBuilder_ObjectIdRetrieval()
    var
        TableBuilder: Codeunit "Table Ext. Builder";
        PageBuilder: Codeunit "Page Ext. Builder";
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Both builders correctly store and return configured object IDs

        // [GIVEN] A table extension with object ID 50300
        TableBuilder.SetTarget(18, 'Customer', EmptyGuid);
        TableBuilder.SetObjectId(50300);
        TableBuilder.AddField(50300, 'Test', "Field Data Type"::Text, 50, '');

        // [GIVEN] A page extension with object ID 50301
        PageBuilder.SetTarget(21, 'Customer Card', EmptyGuid);
        PageBuilder.SetObjectId(50301);
        PageBuilder.SetPlacement("Placement Type"::addafter, 'Name');
        PageBuilder.AddField('Test', 'Rec."Test"');

        // [THEN] Both builders return their configured IDs
        LibraryAssert.AreEqual(50300, TableBuilder.GetObjectId(), 'Table builder should return 50300');
        LibraryAssert.AreEqual(50301, PageBuilder.GetObjectId(), 'Page builder should return 50301');
    end;

    [Test]
    procedure TableExtBuilder_AllFieldTypes()
    var
        Builder: Codeunit "Table Ext. Builder";
        Output: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Table extension supports all defined field data types

        // [GIVEN] A table extension with all field types
        Builder.SetTarget(18, 'Customer', EmptyGuid);
        Builder.SetObjectId(50400);
        Builder.AddField(50401, 'TextField', "Field Data Type"::Text, 50, '');
        Builder.AddField(50402, 'CodeField', "Field Data Type"::Code, 20, '');
        Builder.AddField(50403, 'IntegerField', "Field Data Type"::Integer, 0, '');
        Builder.AddField(50404, 'DecimalField', "Field Data Type"::Decimal, 0, '');
        Builder.AddField(50405, 'BooleanField', "Field Data Type"::Boolean, 0, '');
        Builder.AddField(50406, 'DateField', "Field Data Type"::Date, 0, '');
        Builder.AddField(50407, 'DateTimeField', "Field Data Type"::DateTime, 0, '');
        Builder.AddField(50408, 'OptionField', "Field Data Type"::Option, 0, 'A,B,C');

        // [WHEN] We preview the source
        Output := Builder.PreviewSource();

        // [THEN] All field types are present in the output
        LibraryAssert.IsTrue(Output.Contains('Text[50]'), 'Should contain Text field');
        LibraryAssert.IsTrue(Output.Contains('Code[20]'), 'Should contain Code field');
        LibraryAssert.IsTrue(Output.Contains('Integer'), 'Should contain Integer field');
        LibraryAssert.IsTrue(Output.Contains('Decimal'), 'Should contain Decimal field');
        LibraryAssert.IsTrue(Output.Contains('Boolean'), 'Should contain Boolean field');
        LibraryAssert.IsTrue(Output.Contains('Date'), 'Should contain Date field');
        LibraryAssert.IsTrue(Output.Contains('DateTime'), 'Should contain DateTime field');
        LibraryAssert.IsTrue(Output.Contains('Option'), 'Should contain Option field');
    end;

    [Test]
    procedure TableExtBuilder_SymRefMultipleFields()
    var
        Builder: Codeunit "Table Ext. Builder";
        SymRef: JsonObject;
        Token: JsonToken;
        FieldsArray: JsonArray;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] SymbolReference includes all added fields in Fields array

        // [GIVEN] A table extension with three fields
        Builder.SetTarget(18, 'Customer', EmptyGuid);
        Builder.SetObjectId(50500);
        Builder.AddField(50501, 'Field1', "Field Data Type"::Text, 50, '');
        Builder.AddField(50502, 'Field2', "Field Data Type"::Integer, 0, '');
        Builder.AddField(50503, 'Field3', "Field Data Type"::Code, 10, '');

        // [WHEN] We generate the symbol reference
        SymRef := Builder.GenerateSymbolReference();

        // [THEN] Fields array contains 3 elements
        LibraryAssert.IsTrue(SymRef.Get('Fields', Token), 'Should have Fields array');
        FieldsArray := Token.AsArray();
        LibraryAssert.AreEqual(3, FieldsArray.Count(), 'Should have 3 fields');
    end;

    [Test]
    procedure PageExtBuilder_MultipleFields()
    var
        Builder: Codeunit "Page Ext. Builder";
        Output: Text;
        EmptyGuid: Guid;
    begin
        // [SCENARIO] Page extension supports multiple field controls

        // [GIVEN] A page extension with three field controls
        Builder.SetTarget(21, 'Customer Card', EmptyGuid);
        Builder.SetObjectId(50600);
        Builder.SetPlacement("Placement Type"::addafter, 'Name');
        Builder.AddField('Field1', 'Rec."Field1"');
        Builder.AddField('Field2', 'Rec."Field2"');
        Builder.AddField('Field3', 'Rec."Field3"');

        // [WHEN] We preview the source
        Output := Builder.PreviewSource();

        // [THEN] All three fields appear in the output
        LibraryAssert.IsTrue(Output.Contains('field("Field1"'), 'Should contain Field1');
        LibraryAssert.IsTrue(Output.Contains('field("Field2"'), 'Should contain Field2');
        LibraryAssert.IsTrue(Output.Contains('field("Field3"'), 'Should contain Field3');
    end;
}
