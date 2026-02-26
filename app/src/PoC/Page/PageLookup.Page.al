page 50116 "Page Lookup"
{
    PageType = List;
    SourceTable = "Page Metadata";
    Editable = false;
    Caption = 'Select Page';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Pages)
            {
                field(ID; Rec.ID)
                {
                    ApplicationArea = All;
                    ToolTip = 'The page ID.';
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    ToolTip = 'The page name.';
                }
                field(Caption; Rec.Caption)
                {
                    ToolTip = 'Specifies the value of the Caption field.', Comment = '%';
                }
                field(SourceTable; Rec.SourceTable)
                {
                    ApplicationArea = All;
                    ToolTip = 'The source table of the page.';
                }
            }
        }
    }
}
