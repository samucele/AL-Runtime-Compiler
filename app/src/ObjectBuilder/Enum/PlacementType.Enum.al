/// <summary>
/// Defines the placement types for page extension control changes.
/// Only addafter/addbefore are supported — these use field-level anchors
/// available from the Page Control Field virtual table.
/// </summary>
enum 50108 "Placement Type"
{
    Extensible = false;

    value(0; "addafter")
    {
        Caption = 'addafter';
    }
    value(1; "addbefore")
    {
        Caption = 'addbefore';
    }
}
