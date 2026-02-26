/// <summary>
/// Structured AL syntax builder that produces well-formatted AL source code.
/// Uses a TextBuilder with indent tracking and LF-only line endings.
/// No dependency on the Compiler layer.
/// </summary>
codeunit 50104 "AL Code Writer"
{
    Access = Public;

    var
        Buffer: TextBuilder;
        IndentLevel: Integer;
        IsInitialized: Boolean;

    // --- Object Structure ---

    /// <summary>
    /// Begins an AL object declaration with optional extends clause.
    /// Writes the object header line and opening brace, then increments indent.
    /// </summary>
    /// <param name="ObjectType">The AL object type keyword (e.g., 'tableextension', 'pageextension').</param>
    /// <param name="ObjectId">The object ID number.</param>
    /// <param name="ObjectName">The object name (will be double-quoted).</param>
    /// <param name="ExtendsKeyword">The extends keyword (e.g., 'extends'). Leave empty if not applicable.</param>
    /// <param name="ExtendsName">The name of the object being extended (will be double-quoted). Leave empty if not applicable.</param>
    procedure BeginObject(ObjectType: Text; ObjectId: Integer; ObjectName: Text; ExtendsKeyword: Text; ExtendsName: Text)
    begin
        Initialize();
        Buffer.Append(ObjectType);
        Buffer.Append(' ');
        Buffer.Append(Format(ObjectId));
        Buffer.Append(' "');
        Buffer.Append(ObjectName);
        Buffer.Append('"');
        if ExtendsKeyword <> '' then begin
            Buffer.Append(' ');
            Buffer.Append(ExtendsKeyword);
            Buffer.Append(' "');
            Buffer.Append(ExtendsName);
            Buffer.Append('"');
        end;
        Buffer.Append(GetLf());
        Buffer.Append('{');
        Buffer.Append(GetLf());
        IndentLevel += 1;
    end;

    /// <summary>
    /// Ends the current object declaration by decrementing indent and writing the closing brace.
    /// </summary>
    procedure EndObject()
    begin
        IndentLevel -= 1;
        AppendIndent();
        Buffer.Append('}');
        Buffer.Append(GetLf());
    end;

    // --- Block Structure ---

    /// <summary>
    /// Begins a named block (e.g., 'fields', 'layout') with opening brace and incremented indent.
    /// </summary>
    /// <param name="BlockKeyword">The block keyword to write.</param>
    procedure BeginBlock(BlockKeyword: Text)
    begin
        Initialize();
        AppendIndent();
        Buffer.Append(BlockKeyword);
        Buffer.Append(GetLf());
        AppendIndent();
        Buffer.Append('{');
        Buffer.Append(GetLf());
        IndentLevel += 1;
    end;

    /// <summary>
    /// Begins a block with an argument (e.g., 'addlast(Content)', 'group(MyGroup)').
    /// </summary>
    /// <param name="BlockKeyword">The block keyword.</param>
    /// <param name="Arg">The argument inside parentheses.</param>
    procedure BeginBlockWithArg(BlockKeyword: Text; Arg: Text)
    begin
        Initialize();
        AppendIndent();
        Buffer.Append(BlockKeyword);
        Buffer.Append('("');
        Buffer.Append(Arg);
        Buffer.Append('")');
        Buffer.Append(GetLf());
        AppendIndent();
        Buffer.Append('{');
        Buffer.Append(GetLf());
        IndentLevel += 1;
    end;

    /// <summary>
    /// Ends the current block by decrementing indent and writing the closing brace.
    /// </summary>
    procedure EndBlock()
    begin
        IndentLevel -= 1;
        AppendIndent();
        Buffer.Append('}');
        Buffer.Append(GetLf());
    end;

    // --- Table Fields ---

    /// <summary>
    /// Begins a table field declaration: field(Id; "Name"; Type) followed by opening brace.
    /// </summary>
    /// <param name="FieldId">The field ID number.</param>
    /// <param name="FieldName">The field name (will be double-quoted).</param>
    /// <param name="FieldType">The field type string (e.g., 'Text[100]', 'Integer').</param>
    procedure BeginField(FieldId: Integer; FieldName: Text; FieldType: Text)
    begin
        Initialize();
        AppendIndent();
        Buffer.Append('field(');
        Buffer.Append(Format(FieldId));
        Buffer.Append('; "');
        Buffer.Append(FieldName);
        Buffer.Append('"; ');
        Buffer.Append(FieldType);
        Buffer.Append(')');
        Buffer.Append(GetLf());
        AppendIndent();
        Buffer.Append('{');
        Buffer.Append(GetLf());
        IndentLevel += 1;
    end;

    /// <summary>
    /// Ends the current table field declaration.
    /// </summary>
    procedure EndField()
    begin
        IndentLevel -= 1;
        AppendIndent();
        Buffer.Append('}');
        Buffer.Append(GetLf());
    end;

    // --- Page Controls ---

    /// <summary>
    /// Begins a page field control: field("Name"; SourceExpr) followed by opening brace.
    /// </summary>
    /// <param name="FieldName">The field control name (will be double-quoted).</param>
    /// <param name="SourceExpression">The source expression (e.g., Rec."My Field").</param>
    procedure BeginPageField(FieldName: Text; SourceExpression: Text)
    begin
        Initialize();
        AppendIndent();
        Buffer.Append('field("');
        Buffer.Append(FieldName);
        Buffer.Append('"; ');
        Buffer.Append(SourceExpression);
        Buffer.Append(')');
        Buffer.Append(GetLf());
        AppendIndent();
        Buffer.Append('{');
        Buffer.Append(GetLf());
        IndentLevel += 1;
    end;

    /// <summary>
    /// Ends the current page field control.
    /// </summary>
    procedure EndPageField()
    begin
        IndentLevel -= 1;
        AppendIndent();
        Buffer.Append('}');
        Buffer.Append(GetLf());
    end;

    // --- Properties ---

    /// <summary>
    /// Adds a property line with an unquoted value (e.g., 'DataClassification = CustomerContent;').
    /// </summary>
    /// <param name="PropertyName">The property name.</param>
    /// <param name="PropertyValue">The property value (written without quotes).</param>
    procedure AddProperty(PropertyName: Text; PropertyValue: Text)
    begin
        Initialize();
        AppendIndent();
        Buffer.Append(PropertyName);
        Buffer.Append(' = ');
        Buffer.Append(PropertyValue);
        Buffer.Append(';');
        Buffer.Append(GetLf());
    end;

    /// <summary>
    /// Adds a property line with a single-quoted string value (e.g., "Caption = 'My Field';").
    /// </summary>
    /// <param name="PropertyName">The property name.</param>
    /// <param name="PropertyValue">The property value (will be wrapped in single quotes).</param>
    procedure AddStringProperty(PropertyName: Text; PropertyValue: Text)
    begin
        Initialize();
        AppendIndent();
        Buffer.Append(PropertyName);
        Buffer.Append(' = ''');
        Buffer.Append(PropertyValue);
        Buffer.Append(''';');
        Buffer.Append(GetLf());
    end;

    // --- Raw Output ---

    /// <summary>
    /// Writes an indented raw line of text.
    /// </summary>
    /// <param name="LineText">The text to write on the line.</param>
    procedure Line(LineText: Text)
    begin
        Initialize();
        AppendIndent();
        Buffer.Append(LineText);
        Buffer.Append(GetLf());
    end;

    /// <summary>
    /// Writes an empty line (no indent, just a line feed).
    /// </summary>
    procedure BlankLine()
    begin
        Initialize();
        Buffer.Append(GetLf());
    end;

    // --- Output ---

    /// <summary>
    /// Returns the accumulated AL source code as text.
    /// </summary>
    /// <returns>The complete AL source code string.</returns>
    procedure ToText(): Text
    begin
        Initialize();
        exit(Buffer.ToText());
    end;

    /// <summary>
    /// Writes the accumulated AL source code to a TempBlob as UTF-8 without BOM.
    /// This is the correct encoding for AL source files in .app packages.
    /// </summary>
    /// <param name="TempBlob">The TempBlob to write to.</param>
    procedure WriteToBlob(var TempBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
    begin
        Initialize();
        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Buffer.ToText());
    end;

    // --- Reset ---

    /// <summary>
    /// Resets all internal state (buffer and indent level) for reuse.
    /// </summary>
    procedure Reset()
    begin
        Clear(Buffer);
        IndentLevel := 0;
        IsInitialized := false;
    end;

    // --- Internal Helpers ---

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;
        Clear(Buffer);
        IndentLevel := 0;
        IsInitialized := true;
    end;

    local procedure AppendIndent()
    var
        i: Integer;
    begin
        for i := 1 to IndentLevel do
            Buffer.Append('    '); // 4 spaces per indent level
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