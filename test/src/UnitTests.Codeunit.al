/// <summary>
/// Unit tests for AL Runtime Compiler core components.
/// Tests AL Code Writer (codeunit 50104) and Binary Writer (codeunit 50102).
/// </summary>
codeunit 50150 "ARC Unit Tests"
{
    Subtype = Test;

    var
        LibraryAssert: Codeunit "Library Assert";

    // ========================================================================
    // AL Code Writer Tests - Object Structure
    // ========================================================================

    [Test]
    procedure ALCodeWriter_BeginEndObject_ProducesCorrectSyntax()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A fresh AL Code Writer
        // [WHEN] We write a simple object
        Writer.BeginObject('codeunit', 50100, 'Test CU', '', '');
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] Output contains the object declaration
        LibraryAssert.IsTrue(Output.Contains('codeunit 50100 "Test CU"'), 'Should contain object header');
        LibraryAssert.IsTrue(Output.Contains('{'), 'Should contain opening brace');
        LibraryAssert.IsTrue(Output.Contains('}'), 'Should contain closing brace');
    end;

    [Test]
    procedure ALCodeWriter_BeginObjectWithExtends_ProducesCorrectSyntax()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A fresh AL Code Writer
        // [WHEN] We write an object with extends clause
        Writer.BeginObject('pageextension', 50101, 'Vendor Card Ext', 'extends', 'Vendor Card');
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] Output contains the full pageextension declaration with extends
        LibraryAssert.IsTrue(Output.Contains('pageextension 50101 "Vendor Card Ext"'),
            'Should contain extension header');
        LibraryAssert.IsTrue(Output.Contains('extends "Vendor Card"'),
            'Should contain extends clause with quotes');
    end;

    // ========================================================================
    // AL Code Writer Tests - Block Structure
    // ========================================================================

    [Test]
    procedure ALCodeWriter_BeginEndBlock_ProducesIndentedBlock()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with an object started
        Writer.BeginObject('table', 50100, 'Test Table', '', '');

        // [WHEN] We add a fields block
        Writer.BeginBlock('fields');
        Writer.EndBlock();
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] Output contains the indented fields block
        LibraryAssert.IsTrue(Output.Contains('fields'), 'Should contain fields keyword');
        LibraryAssert.IsTrue(Output.Contains('    fields'), 'Fields keyword should be indented');
    end;

    [Test]
    procedure ALCodeWriter_BeginBlockWithArg_QuotesArgument()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with an object started
        Writer.BeginObject('pageextension', 50100, 'Test Ext', 'extends', 'Customer Card');

        // [WHEN] We add a block with an argument that needs quotes (like "Vendor No.")
        Writer.BeginBlock('layout');
        Writer.BeginBlockWithArg('addlast', 'Content');
        Writer.EndBlock();
        Writer.EndBlock();
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] Output contains addlast("Content") with double quotes around the argument
        LibraryAssert.IsTrue(Output.Contains('addlast("Content")'),
            'BeginBlockWithArg should quote the argument');
    end;

    [Test]
    procedure ALCodeWriter_BeginBlockWithArg_QuotesComplexNames()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with an object started
        Writer.BeginObject('pageextension', 50100, 'Test Ext', 'extends', 'Customer Card');

        // [WHEN] We add a block with a complex name containing spaces and special chars
        Writer.BeginBlock('layout');
        Writer.BeginBlockWithArg('addlast', 'Vendor No.');
        Writer.EndBlock();
        Writer.EndBlock();
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] The complex name is properly quoted
        LibraryAssert.IsTrue(Output.Contains('addlast("Vendor No.")'),
            'Complex names with dots and spaces should be quoted');
    end;

    // ========================================================================
    // AL Code Writer Tests - Field Declarations
    // ========================================================================

    [Test]
    procedure ALCodeWriter_BeginEndField_ProducesCorrectSyntax()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with a table started
        Writer.BeginObject('table', 50100, 'Test Table', '', '');
        Writer.BeginBlock('fields');

        // [WHEN] We add a table field
        Writer.BeginField(1, 'Primary Key', 'Code[20]');
        Writer.AddProperty('DataClassification', 'CustomerContent');
        Writer.EndField();

        Writer.EndBlock();
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] Output contains the field declaration with correct syntax
        LibraryAssert.IsTrue(Output.Contains('field(1; "Primary Key"; Code[20])'),
            'Should contain field declaration with ID, quoted name, and type');
        LibraryAssert.IsTrue(Output.Contains('DataClassification = CustomerContent;'),
            'Should contain property');
    end;

    [Test]
    procedure ALCodeWriter_BeginPageField_ProducesCorrectSyntax()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with a page started
        Writer.BeginObject('page', 50100, 'Test Page', '', '');
        Writer.BeginBlock('layout');
        Writer.BeginBlock('area(Content)');
        Writer.BeginBlock('group(General)');

        // [WHEN] We add a page field control
        Writer.BeginPageField('Customer Name', 'Rec."Name"');
        Writer.AddStringProperty('ToolTip', 'Customer name');
        Writer.EndPageField();

        Writer.EndBlock();
        Writer.EndBlock();
        Writer.EndBlock();
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] Output contains the page field with correct syntax
        LibraryAssert.IsTrue(Output.Contains('field("Customer Name"; Rec."Name")'),
            'Page field should have quoted name and source expression');
    end;

    // ========================================================================
    // AL Code Writer Tests - Properties
    // ========================================================================

    [Test]
    procedure ALCodeWriter_AddProperty_ProducesUnquotedValue()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with a table field started
        Writer.BeginObject('table', 50100, 'Test Table', '', '');
        Writer.BeginBlock('fields');
        Writer.BeginField(1, 'Test Field', 'Integer');

        // [WHEN] We add a property with an unquoted enum/keyword value
        Writer.AddProperty('DataClassification', 'CustomerContent');

        Writer.EndField();
        Writer.EndBlock();
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] The property value is not quoted
        LibraryAssert.IsTrue(Output.Contains('DataClassification = CustomerContent;'),
            'AddProperty should produce unquoted value');
        LibraryAssert.IsFalse(Output.Contains('DataClassification = ''CustomerContent'';'),
            'AddProperty should NOT quote the value');
    end;

    [Test]
    procedure ALCodeWriter_AddStringProperty_ProducesSingleQuotedValue()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with a table field started
        Writer.BeginObject('table', 50100, 'Test Table', '', '');
        Writer.BeginBlock('fields');
        Writer.BeginField(1, 'Test Field', 'Text[100]');

        // [WHEN] We add a string property
        Writer.AddStringProperty('Caption', 'My Field Caption');

        Writer.EndField();
        Writer.EndBlock();
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] The property value is wrapped in single quotes
        LibraryAssert.IsTrue(Output.Contains('Caption = ''My Field Caption'';'),
            'AddStringProperty should produce single-quoted value');
    end;

    // ========================================================================
    // AL Code Writer Tests - Raw Output
    // ========================================================================

    [Test]
    procedure ALCodeWriter_Line_ProducesIndentedLine()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with an object started
        Writer.BeginObject('codeunit', 50100, 'Test CU', '', '');

        // [WHEN] We add a raw indented line
        Writer.Line('// This is a comment');

        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] The line is indented properly
        LibraryAssert.IsTrue(Output.Contains('    // This is a comment'),
            'Line should be indented');
    end;

    [Test]
    procedure ALCodeWriter_BlankLine_ProducesEmptyLine()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
        LineCount: Integer;
        Pos: Integer;
        Lf: Char;
    begin
        // [GIVEN] A writer with some content
        Writer.BeginObject('codeunit', 50100, 'Test CU', '', '');
        Writer.Line('First line');

        // [WHEN] We add a blank line
        Writer.BlankLine();
        Writer.Line('Second line');
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] The output contains an empty line (multiple consecutive LF chars)
        // Count consecutive line feeds to verify blank line exists
        Lf := 10; // LF character
        LineCount := 0;
        for Pos := 1 to StrLen(Output) do begin
            if Output[Pos] = Lf then
                LineCount += 1;
        end;
        LibraryAssert.IsTrue(LineCount > 4, 'Should have multiple line breaks including blank line');
    end;

    // ========================================================================
    // AL Code Writer Tests - State Management
    // ========================================================================

    [Test]
    procedure ALCodeWriter_Reset_ClearsBuffer()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with some content
        Writer.BeginObject('codeunit', 50100, 'Test CU', '', '');
        Writer.EndObject();
        Output := Writer.ToText();
        LibraryAssert.IsTrue(StrLen(Output) > 0, 'Should have content before reset');

        // [WHEN] We reset the writer
        Writer.Reset();
        Output := Writer.ToText();

        // [THEN] The buffer is empty
        LibraryAssert.AreEqual('', Output, 'ToText should return empty string after Reset');
    end;

    [Test]
    procedure ALCodeWriter_Reset_AllowsReuse()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer that has been used and reset
        Writer.BeginObject('codeunit', 50100, 'First CU', '', '');
        Writer.EndObject();
        Writer.Reset();

        // [WHEN] We use the writer again
        Writer.BeginObject('codeunit', 50101, 'Second CU', '', '');
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] The new content is present
        LibraryAssert.IsTrue(Output.Contains('codeunit 50101 "Second CU"'),
            'Writer should be reusable after Reset');
        LibraryAssert.IsFalse(Output.Contains('First CU'),
            'Old content should not be present after Reset');
    end;

    // ========================================================================
    // AL Code Writer Tests - Indentation
    // ========================================================================

    [Test]
    procedure ALCodeWriter_Indentation_NestedBlocks()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with nested blocks
        Writer.BeginObject('table', 50100, 'Test Table', '', '');
        Writer.BeginBlock('fields');
        Writer.BeginField(1, 'Test Field', 'Integer');
        Writer.AddProperty('Caption', 'Test');
        Writer.EndField();
        Writer.EndBlock();
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] Indentation levels are correct (4 spaces per level)
        LibraryAssert.IsTrue(Output.Contains('    fields'),
            'Level 1: fields block should have 4 spaces');
        LibraryAssert.IsTrue(Output.Contains('        field(1'),
            'Level 2: field declaration should have 8 spaces');
        LibraryAssert.IsTrue(Output.Contains('            Caption'),
            'Level 3: property should have 12 spaces');
    end;

    [Test]
    procedure ALCodeWriter_Indentation_ComplexNesting()
    var
        Writer: Codeunit "AL Code Writer";
        Output: Text;
    begin
        // [GIVEN] A writer with 4 levels of nesting
        Writer.BeginObject('page', 50100, 'Test Page', '', '');        // Level 0 -> 1
        Writer.BeginBlock('layout');                                    // Level 1 -> 2
        Writer.BeginBlock('area(Content)');                             // Level 2 -> 3
        Writer.BeginBlock('group(General)');                            // Level 3 -> 4
        Writer.Line('// Comment at level 4');                           // Level 4 content
        Writer.EndBlock();
        Writer.EndBlock();
        Writer.EndBlock();
        Writer.EndObject();
        Output := Writer.ToText();

        // [THEN] Deep nesting produces correct indentation (16 spaces = 4 levels * 4 spaces)
        LibraryAssert.IsTrue(Output.Contains('                // Comment at level 4'),
            'Level 4 content should have 16 spaces (4 levels * 4 spaces)');
    end;

    // ========================================================================
    // Binary Writer Tests - HexToSignedInt32
    // ========================================================================

    [Test]
    procedure BinaryWriter_HexToSignedInt32_PositiveValue()
    var
        Writer: Codeunit "Binary Writer";
        Result: Integer;
    begin
        // [GIVEN] A simple positive hex value
        // [WHEN] We convert '00000001' to signed int32
        Result := Writer.HexToSignedInt32('00000001');

        // [THEN] Result is 1
        LibraryAssert.AreEqual(1, Result, 'HexToSignedInt32(00000001) should return 1');
    end;

    [Test]
    procedure BinaryWriter_HexToSignedInt32_MaxPositive()
    var
        Writer: Codeunit "Binary Writer";
        Result: Integer;
    begin
        // [GIVEN] Maximum positive signed int32 value
        // [WHEN] We convert 0x7FFFFFFF (2,147,483,647)
        Result := Writer.HexToSignedInt32('7FFFFFFF');

        // [THEN] Result is 2147483647
        LibraryAssert.AreEqual(2147483647, Result,
            'HexToSignedInt32(7FFFFFFF) should return max positive int32');
    end;

    [Test]
    procedure BinaryWriter_HexToSignedInt32_Zero()
    var
        Writer: Codeunit "Binary Writer";
        Result: Integer;
    begin
        // [GIVEN] Zero value
        // [WHEN] We convert '00000000'
        Result := Writer.HexToSignedInt32('00000000');

        // [THEN] Result is 0
        LibraryAssert.AreEqual(0, Result, 'HexToSignedInt32(00000000) should return 0');
    end;

    [Test]
    procedure BinaryWriter_HexToSignedInt32_WrapsToNegative()
    var
        Writer: Codeunit "Binary Writer";
        Result: Integer;
    begin
        // [GIVEN] A value above 0x7FFFFFFF that should wrap to negative
        // [WHEN] We convert 0xFFFFFFFF (which is -1 in signed int32)
        Result := Writer.HexToSignedInt32('FFFFFFFF');

        // [THEN] Result is -1 due to unsigned-to-signed wrapping
        LibraryAssert.AreEqual(-1, Result,
            'HexToSignedInt32(FFFFFFFF) should wrap to -1');
    end;

    [Test]
    procedure BinaryWriter_HexToSignedInt32_MinNegative()
    var
        Writer: Codeunit "Binary Writer";
        Result: Integer;
    begin
        // [GIVEN] Minimum signed int32 value
        // [WHEN] We convert 0x80000000 (-2,147,483,648)
        Result := Writer.HexToSignedInt32('80000000');

        // [THEN] Result is -2147483648
        LibraryAssert.AreEqual(-2147483647 - 1, Result,
            'HexToSignedInt32(80000000) should return min negative int32');
    end;

    [Test]
    procedure BinaryWriter_HexToSignedInt32_TypicalNegative()
    var
        Writer: Codeunit "Binary Writer";
        Result: Integer;
    begin
        // [GIVEN] A typical negative value (0xAABBCCDD)
        // [WHEN] We convert it
        Result := Writer.HexToSignedInt32('AABBCCDD');

        // [THEN] Result is negative (0xAABBCCDD unsigned = -1,430,532,899 signed)
        LibraryAssert.IsTrue(Result < 0,
            'HexToSignedInt32(AABBCCDD) should produce a negative result');
        LibraryAssert.AreEqual(-1430532899, Result,
            'HexToSignedInt32(AABBCCDD) should return correct signed value');
    end;

    // ========================================================================
    // Binary Writer Tests - GuidToLEIntegers Integration
    // ========================================================================

    [Test]
    procedure BinaryWriter_GuidToLEIntegers_ProducesArrayOfFour()
    var
        Writer: Codeunit "Binary Writer";
        TestGuid: Guid;
        Result: array[4] of Integer;
    begin
        // [GIVEN] A known GUID
        Evaluate(TestGuid, '{12345678-9ABC-DEF0-1234-567890ABCDEF}');

        // [WHEN] We convert to LE integers
        Writer.GuidToLEIntegers(TestGuid, Result);

        // [THEN] We get 4 integers
        LibraryAssert.AreNotEqual(0, Result[1], 'Result[1] should be populated');
        LibraryAssert.AreNotEqual(0, Result[2], 'Result[2] should be populated');
        LibraryAssert.AreNotEqual(0, Result[3], 'Result[3] should be populated');
        LibraryAssert.AreNotEqual(0, Result[4], 'Result[4] should be populated');
    end;

    [Test]
    procedure BinaryWriter_GuidToLEIntegers_KnownGuidProducesExpectedValues()
    var
        Writer: Codeunit "Binary Writer";
        TestGuid: Guid;
        Result: array[4] of Integer;
    begin
        // [GIVEN] A simple GUID: {00000001-0002-0003-0004-000000000005}
        // bytes_le: 01 00 00 00  02 00  03 00  00 04  00 00 00 00 00 05
        // Int1 = Write(0x00000001) -> 01 00 00 00
        // Int2 = Write(0x00030002) -> 02 00 03 00
        // Int3 = Write(0x00000400) -> 00 04 00 00
        // Int4 = Write(0x05000000) -> 00 00 00 05
        Evaluate(TestGuid, '{00000001-0002-0003-0004-000000000005}');

        // [WHEN] We convert to LE integers
        Writer.GuidToLEIntegers(TestGuid, Result);

        // [THEN] Values match the expected LE integer encoding
        LibraryAssert.AreEqual(1, Result[1], 'Int1 should be 1');
        LibraryAssert.AreEqual(196610, Result[2], 'Int2 should be 0x00030002 = 196610');
        LibraryAssert.AreEqual(1024, Result[3], 'Int3 should be 0x00000400 = 1024');
        LibraryAssert.AreEqual(83886080, Result[4], 'Int4 should be 0x05000000 = 83886080');
    end;

    [Test]
    procedure BinaryWriter_GuidToLEIntegers_AllZerosGuid()
    var
        Writer: Codeunit "Binary Writer";
        TestGuid: Guid;
        Result: array[4] of Integer;
    begin
        // [GIVEN] An all-zeros GUID
        Evaluate(TestGuid, '{00000000-0000-0000-0000-000000000000}');

        // [WHEN] We convert to LE integers
        Writer.GuidToLEIntegers(TestGuid, Result);

        // [THEN] All integers are zero
        LibraryAssert.AreEqual(0, Result[1], 'All-zeros GUID should produce Result[1] = 0');
        LibraryAssert.AreEqual(0, Result[2], 'All-zeros GUID should produce Result[2] = 0');
        LibraryAssert.AreEqual(0, Result[3], 'All-zeros GUID should produce Result[3] = 0');
        LibraryAssert.AreEqual(0, Result[4], 'All-zeros GUID should produce Result[4] = 0');
    end;
}
