/// <summary>
/// Edge case, boundary value, and error condition tests for the AL Runtime Compiler.
/// Tests validation errors, boundary values, null/empty inputs, and data type coverage.
/// </summary>
codeunit 50180 "ARC Edge Case Tests"
{
    Subtype = Test;

    var
        LibraryAssert: Codeunit "Library Assert";

    // ========================================
    // TableExtBuilder Validation Tests
    // ========================================

    [Test]
    procedure TableExtBuilder_GenerateSourceWithoutTarget_Errors()
    var
        Builder: Codeunit "Table Ext. Builder";
        SourceBlob: Codeunit "Temp Blob";
    begin
        // [GIVEN] A builder with no target set
        Builder.SetObjectId(50100);
        Builder.AddField(50100, 'Test Field', "Field Data Type"::Text, 100, '');

        // [WHEN] We try to generate source
        asserterror Builder.GenerateSource(SourceBlob);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Call SetTarget() before generating output.');
    end;

    [Test]
    procedure TableExtBuilder_GenerateSourceWithoutObjectId_Errors()
    var
        Builder: Codeunit "Table Ext. Builder";
        SourceBlob: Codeunit "Temp Blob";
        TestGuid: Guid;
    begin
        // [GIVEN] A builder with target but no object ID
        TestGuid := CreateGuid();
        Builder.SetTarget(18, 'Customer', TestGuid);
        Builder.AddField(50100, 'Test Field', "Field Data Type"::Text, 100, '');

        // [WHEN] We try to generate source
        asserterror Builder.GenerateSource(SourceBlob);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Call SetObjectId() before generating output.');
    end;

    [Test]
    procedure TableExtBuilder_GenerateSourceWithoutFields_Errors()
    var
        Builder: Codeunit "Table Ext. Builder";
        SourceBlob: Codeunit "Temp Blob";
        TestGuid: Guid;
    begin
        // [GIVEN] A builder with target and object ID but no fields
        TestGuid := CreateGuid();
        Builder.SetTarget(18, 'Customer', TestGuid);
        Builder.SetObjectId(50100);

        // [WHEN] We try to generate source
        asserterror Builder.GenerateSource(SourceBlob);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Add at least one field with AddField() before generating output.');
    end;

    [Test]
    procedure TableExtBuilder_PreviewSourceWithoutTarget_Errors()
    var
        Builder: Codeunit "Table Ext. Builder";
        Source: Text;
    begin
        // [GIVEN] A builder with no target set
        Builder.SetObjectId(50100);
        Builder.AddField(50100, 'Test Field', "Field Data Type"::Text, 100, '');

        // [WHEN] We try to preview source
        asserterror Source := Builder.PreviewSource();

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Call SetTarget() before generating output.');
    end;

    [Test]
    procedure TableExtBuilder_GenerateSymRefWithoutTarget_Errors()
    var
        Builder: Codeunit "Table Ext. Builder";
        SymRef: JsonObject;
    begin
        // [GIVEN] A builder with no target set
        Builder.SetObjectId(50100);
        Builder.AddField(50100, 'Test Field', "Field Data Type"::Text, 100, '');

        // [WHEN] We try to generate symbol reference
        asserterror SymRef := Builder.GenerateSymbolReference();

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Call SetTarget() before generating output.');
    end;

    // ========================================
    // PageExtBuilder Validation Tests
    // ========================================

    [Test]
    procedure PageExtBuilder_GenerateSourceWithoutTarget_Errors()
    var
        Builder: Codeunit "Page Ext. Builder";
        SourceBlob: Codeunit "Temp Blob";
    begin
        // [GIVEN] A builder with no target set
        Builder.SetObjectId(50100);
        Builder.AddField('Test Field', 'Rec."Test Field"');

        // [WHEN] We try to generate source
        asserterror Builder.GenerateSource(SourceBlob);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Call SetTarget() before generating output.');
    end;

    [Test]
    procedure PageExtBuilder_GenerateSourceWithoutObjectId_Errors()
    var
        Builder: Codeunit "Page Ext. Builder";
        SourceBlob: Codeunit "Temp Blob";
        TestGuid: Guid;
    begin
        // [GIVEN] A builder with target but no object ID
        TestGuid := CreateGuid();
        Builder.SetTarget(21, 'Customer Card', TestGuid);
        Builder.AddField('Test Field', 'Rec."Test Field"');

        // [WHEN] We try to generate source
        asserterror Builder.GenerateSource(SourceBlob);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Call SetObjectId() before generating output.');
    end;

    [Test]
    procedure PageExtBuilder_GenerateSourceWithoutFields_Errors()
    var
        Builder: Codeunit "Page Ext. Builder";
        SourceBlob: Codeunit "Temp Blob";
        TestGuid: Guid;
    begin
        // [GIVEN] A builder with target and object ID but no fields
        TestGuid := CreateGuid();
        Builder.SetTarget(21, 'Customer Card', TestGuid);
        Builder.SetObjectId(50100);

        // [WHEN] We try to generate source
        asserterror Builder.GenerateSource(SourceBlob);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Add at least one field with AddField() before generating output.');
    end;

    // ========================================
    // AppBuilder Validation Tests
    // ========================================

    [Test]
    procedure AppBuilder_BuildWithoutMetadata_Errors()
    var
        Builder: Codeunit "App Builder";
        ResultBlob: Codeunit "Temp Blob";
        SourceBlob: Codeunit "Temp Blob";
    begin
        // [GIVEN] A builder with source but no metadata
        CreateDummySourceBlob(SourceBlob);
        Builder.AddSourceFile('src/Test.al', SourceBlob);

        // [WHEN] We try to build
        asserterror Builder.Build(ResultBlob);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Call SetAppMetadata() before Build().');
    end;

    [Test]
    procedure AppBuilder_BuildWithoutSourceFiles_Errors()
    var
        Builder: Codeunit "App Builder";
        ResultBlob: Codeunit "Temp Blob";
    begin
        // [GIVEN] A builder with metadata but no source files
        Builder.SetAppMetadata('Test App', 'Test Publisher', 1, 0, 0, 0);

        // [WHEN] We try to build
        asserterror Builder.Build(ResultBlob);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Add at least one source file before calling Build().');
    end;

    // ========================================
    // AppBuildRunner ValidateStep Tests
    // ========================================

    [Test]
    procedure ValidateStep1_EmptyAppName_Errors()
    var
        Runner: Codeunit "App Build Runner";
        Rec: Record "App Builder Buffer" temporary;
    begin
        // [GIVEN] A buffer with empty app name
        Rec.Init();
        Rec."Primary Key" := '';
        Rec."App Name" := '';
        Rec.Publisher := 'Test Publisher';
        Rec.Insert();

        // [WHEN] We validate step 1
        asserterror Runner.ValidateStep(1, Rec);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('App Name is required.');
    end;

    [Test]
    procedure ValidateStep1_EmptyPublisher_Errors()
    var
        Runner: Codeunit "App Build Runner";
        Rec: Record "App Builder Buffer" temporary;
    begin
        // [GIVEN] A buffer with empty publisher
        Rec.Init();
        Rec."Primary Key" := '';
        Rec."App Name" := 'Test App';
        Rec.Publisher := '';
        Rec.Insert();

        // [WHEN] We validate step 1
        asserterror Runner.ValidateStep(1, Rec);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Publisher is required.');
    end;

    [Test]
    procedure ValidateStep2_TargetTableZero_Errors()
    var
        Runner: Codeunit "App Build Runner";
        Rec: Record "App Builder Buffer" temporary;
    begin
        // [GIVEN] A buffer with target table = 0
        Rec.Init();
        Rec."Primary Key" := '';
        Rec."Target Table No." := 0;
        Rec."Target Page No." := 21;
        Rec.Insert();

        // [WHEN] We validate step 2
        asserterror Runner.ValidateStep(2, Rec);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Please select a target table.');
    end;

    [Test]
    procedure ValidateStep2_TargetPageZero_Errors()
    var
        Runner: Codeunit "App Build Runner";
        Rec: Record "App Builder Buffer" temporary;
    begin
        // [GIVEN] A buffer with target page = 0
        Rec.Init();
        Rec."Primary Key" := '';
        Rec."Target Table No." := 18;
        Rec."Target Page No." := 0;
        Rec.Insert();

        // [WHEN] We validate step 2
        asserterror Runner.ValidateStep(2, Rec);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Please select a target page.');
    end;

    [Test]
    procedure ValidateStep3_EmptyFieldName_Errors()
    var
        Runner: Codeunit "App Build Runner";
        Rec: Record "App Builder Buffer" temporary;
    begin
        // [GIVEN] A buffer with empty field name
        Rec.Init();
        Rec."Primary Key" := '';
        Rec."Field Name" := '';
        Rec."Anchor Control" := 'Name';
        Rec.Insert();

        // [WHEN] We validate step 3
        asserterror Runner.ValidateStep(3, Rec);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Field Name is required.');
    end;

    [Test]
    procedure ValidateStep3_EmptyAnchorControl_Errors()
    var
        Runner: Codeunit "App Build Runner";
        Rec: Record "App Builder Buffer" temporary;
    begin
        // [GIVEN] A buffer with empty anchor control
        Rec.Init();
        Rec."Primary Key" := '';
        Rec."Field Name" := 'Test Field';
        Rec."Anchor Control" := '';
        Rec.Insert();

        // [WHEN] We validate step 3
        asserterror Runner.ValidateStep(3, Rec);

        // [THEN] We get the expected error
        LibraryAssert.ExpectedError('Please select an anchor control.');
    end;

    // ========================================
    // BinaryWriter Boundary Value Tests
    // ========================================

    [Test]
    procedure BinaryWriter_HexToSignedInt32_FFFFFFFF_EqualsNegativeOne()
    var
        Writer: Codeunit "Binary Writer";
        Result: Integer;
    begin
        // [GIVEN] Maximum unsigned 32-bit value as hex

        // [WHEN] We convert to signed int32
        Result := Writer.HexToSignedInt32('FFFFFFFF');

        // [THEN] We get -1 (unsigned wrapping)
        LibraryAssert.AreEqual(-1, Result, 'FFFFFFFF should wrap to -1');
    end;

    [Test]
    procedure BinaryWriter_HexToSignedInt32_80000000_EqualsMinSignedInt32()
    var
        Writer: Codeunit "Binary Writer";
        Result: Integer;
    begin
        // [GIVEN] Minimum signed 32-bit value as hex

        // [WHEN] We convert to signed int32
        Result := Writer.HexToSignedInt32('80000000');

        // [THEN] We get -2147483648 (minimum signed int32)
        LibraryAssert.AreEqual(-2147483647 - 1, Result, '80000000 should equal minimum signed int32');
    end;

    [Test]
    procedure BinaryWriter_HexToSignedInt32_7FFFFFFF_EqualsMaxSignedInt32()
    var
        Writer: Codeunit "Binary Writer";
        Result: Integer;
    begin
        // [GIVEN] Maximum signed 32-bit value as hex

        // [WHEN] We convert to signed int32
        Result := Writer.HexToSignedInt32('7FFFFFFF');

        // [THEN] We get 2147483647 (maximum signed int32, NO wrapping)
        LibraryAssert.AreEqual(2147483647, Result, '7FFFFFFF should equal maximum signed int32');
    end;

    [Test]
    procedure BinaryWriter_HexToSignedInt32_00000000_EqualsZero()
    var
        Writer: Codeunit "Binary Writer";
        Result: Integer;
    begin
        // [GIVEN] Zero as hex

        // [WHEN] We convert to signed int32
        Result := Writer.HexToSignedInt32('00000000');

        // [THEN] We get 0
        LibraryAssert.AreEqual(0, Result, '00000000 should equal 0');
    end;

    // ========================================
    // Field Data Type Coverage Tests
    // ========================================

    [Test]
    procedure TableExtBuilder_BooleanField_GeneratesCorrectSource()
    var
        Builder: Codeunit "Table Ext. Builder";
        Source: Text;
        TestGuid: Guid;
    begin
        // [GIVEN] A builder with a Boolean field
        TestGuid := CreateGuid();
        Builder.SetTarget(18, 'Customer', TestGuid);
        Builder.SetObjectId(50100);
        Builder.AddField(50100, 'Active', "Field Data Type"::Boolean, 0, '');

        // [WHEN] We generate source
        Source := Builder.PreviewSource();

        // [THEN] The source contains 'Boolean'
        LibraryAssert.IsTrue(StrPos(Source, 'Boolean') > 0, 'Source should contain Boolean data type');
    end;

    [Test]
    procedure TableExtBuilder_DateField_GeneratesCorrectSource()
    var
        Builder: Codeunit "Table Ext. Builder";
        Source: Text;
        TestGuid: Guid;
    begin
        // [GIVEN] A builder with a Date field
        TestGuid := CreateGuid();
        Builder.SetTarget(18, 'Customer', TestGuid);
        Builder.SetObjectId(50100);
        Builder.AddField(50100, 'Start Date', "Field Data Type"::Date, 0, '');

        // [WHEN] We generate source
        Source := Builder.PreviewSource();

        // [THEN] The source contains 'Date'
        LibraryAssert.IsTrue(StrPos(Source, 'Date') > 0, 'Source should contain Date data type');
    end;

    [Test]
    procedure TableExtBuilder_DateTimeField_GeneratesCorrectSource()
    var
        Builder: Codeunit "Table Ext. Builder";
        Source: Text;
        TestGuid: Guid;
    begin
        // [GIVEN] A builder with a DateTime field
        TestGuid := CreateGuid();
        Builder.SetTarget(18, 'Customer', TestGuid);
        Builder.SetObjectId(50100);
        Builder.AddField(50100, 'Created At', "Field Data Type"::DateTime, 0, '');

        // [WHEN] We generate source
        Source := Builder.PreviewSource();

        // [THEN] The source contains 'DateTime'
        LibraryAssert.IsTrue(StrPos(Source, 'DateTime') > 0, 'Source should contain DateTime data type');
    end;

    [Test]
    procedure TableExtBuilder_DecimalField_GeneratesCorrectSource()
    var
        Builder: Codeunit "Table Ext. Builder";
        Source: Text;
        TestGuid: Guid;
    begin
        // [GIVEN] A builder with a Decimal field
        TestGuid := CreateGuid();
        Builder.SetTarget(18, 'Customer', TestGuid);
        Builder.SetObjectId(50100);
        Builder.AddField(50100, 'Rate', "Field Data Type"::Decimal, 0, '');

        // [WHEN] We generate source
        Source := Builder.PreviewSource();

        // [THEN] The source contains 'Decimal'
        LibraryAssert.IsTrue(StrPos(Source, 'Decimal') > 0, 'Source should contain Decimal data type');
    end;

    [Test]
    procedure TableExtBuilder_TextField_LengthZero_DefaultsTo100()
    var
        Builder: Codeunit "Table Ext. Builder";
        Source: Text;
        TestGuid: Guid;
    begin
        // [GIVEN] A builder with a Text field with length 0
        TestGuid := CreateGuid();
        Builder.SetTarget(18, 'Customer', TestGuid);
        Builder.SetObjectId(50100);
        Builder.AddField(50100, 'Description', "Field Data Type"::Text, 0, '');

        // [WHEN] We generate source
        Source := Builder.PreviewSource();

        // [THEN] The source contains 'Text[100]' (default length)
        LibraryAssert.IsTrue(StrPos(Source, 'Text[100]') > 0, 'Text field with length 0 should default to Text[100]');
    end;

    [Test]
    procedure TableExtBuilder_CodeField_LengthZero_DefaultsTo20()
    var
        Builder: Codeunit "Table Ext. Builder";
        Source: Text;
        TestGuid: Guid;
    begin
        // [GIVEN] A builder with a Code field with length 0
        TestGuid := CreateGuid();
        Builder.SetTarget(18, 'Customer', TestGuid);
        Builder.SetObjectId(50100);
        Builder.AddField(50100, 'Code', "Field Data Type"::Code, 0, '');

        // [WHEN] We generate source
        Source := Builder.PreviewSource();

        // [THEN] The source contains 'Code[20]' (default length)
        LibraryAssert.IsTrue(StrPos(Source, 'Code[20]') > 0, 'Code field with length 0 should default to Code[20]');
    end;

    // ========================================
    // Helper Procedures
    // ========================================

    local procedure CreateDummySourceBlob(var SourceBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
    begin
        SourceBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText('// Dummy AL source');
    end;
}
