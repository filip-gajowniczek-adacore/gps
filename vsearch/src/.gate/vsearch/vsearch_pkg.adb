with Glib; use Glib;
with Gtk; use Gtk;
with Gdk.Types;       use Gdk.Types;
with Gtk.Widget;      use Gtk.Widget;
with Gtk.Enums;       use Gtk.Enums;
with Gtkada.Handlers; use Gtkada.Handlers;
with Callbacks_Vsearch; use Callbacks_Vsearch;
with Vsearch_Intl; use Vsearch_Intl;

package body Vsearch_Pkg is

procedure Gtk_New (Vsearch : out Vsearch_Access) is
begin
   Vsearch := new Vsearch_Record;
   Vsearch_Pkg.Initialize (Vsearch);
end Gtk_New;

procedure Initialize (Vsearch : access Vsearch_Record'Class) is
   pragma Suppress (All_Checks);
   Replace_Combo_Items : String_List.Glist;
   Tooltips : Gtk_Tooltips;
   Context_Combo_Items : String_List.Glist;
   Pattern_Combo_Items : String_List.Glist;

begin
   Gtk.Window.Initialize (Vsearch, Window_Toplevel);
   Set_Title (Vsearch, -"Search");
   Set_Policy (Vsearch, False, False, True);
   Set_Position (Vsearch, Win_Pos_None);
   Set_Modal (Vsearch, False);

   Gtk_New_Vbox (Vsearch.Vbox_Search, False, 0);
   Add (Vsearch, Vsearch.Vbox_Search);

   Gtk_New (Vsearch.Table, 3, 2, False);
   Set_Row_Spacings (Vsearch.Table, 2);
   Set_Col_Spacings (Vsearch.Table, 3);
   Pack_Start (Vsearch.Vbox_Search, Vsearch.Table, True, True, 0);

   Gtk_New (Vsearch.Replace_Label, -("Replace with:"));
   Set_Alignment (Vsearch.Replace_Label, 0.0, 0.5);
   Set_Padding (Vsearch.Replace_Label, 0, 0);
   Set_Justify (Vsearch.Replace_Label, Justify_Center);
   Set_Line_Wrap (Vsearch.Replace_Label, False);
   Attach (Vsearch.Table, Vsearch.Replace_Label, 0, 1, 1, 2,
     Fill, 0,
     2, 0);

   Gtk_New (Vsearch.Search_For_Label, -("Search for:"));
   Set_Alignment (Vsearch.Search_For_Label, 0.0, 0.5);
   Set_Padding (Vsearch.Search_For_Label, 0, 0);
   Set_Justify (Vsearch.Search_For_Label, Justify_Center);
   Set_Line_Wrap (Vsearch.Search_For_Label, False);
   Attach (Vsearch.Table, Vsearch.Search_For_Label, 0, 1, 0, 1,
     Fill, 0,
     2, 0);

   Gtk_New (Vsearch.Search_In_Label, -("Look in:"));
   Set_Alignment (Vsearch.Search_In_Label, 0.0, 0.5);
   Set_Padding (Vsearch.Search_In_Label, 0, 0);
   Set_Justify (Vsearch.Search_In_Label, Justify_Center);
   Set_Line_Wrap (Vsearch.Search_In_Label, False);
   Attach (Vsearch.Table, Vsearch.Search_In_Label, 0, 1, 2, 3,
     Fill, 0,
     2, 0);

   Gtk_New (Vsearch.Replace_Combo);
   Set_Case_Sensitive (Vsearch.Replace_Combo, False);
   Set_Use_Arrows (Vsearch.Replace_Combo, True);
   Set_Use_Arrows_Always (Vsearch.Replace_Combo, False);
   String_List.Append (Replace_Combo_Items, -"");
   Combo.Set_Popdown_Strings (Vsearch.Replace_Combo, Replace_Combo_Items);
   Free_String_List (Replace_Combo_Items);
   Attach (Vsearch.Table, Vsearch.Replace_Combo, 1, 2, 1, 2,
     Expand or Fill, 0,
     2, 0);

   Vsearch.Replace_Entry := Get_Entry (Vsearch.Replace_Combo);
   Set_Editable (Vsearch.Replace_Entry, True);
   Set_Max_Length (Vsearch.Replace_Entry, 0);
   Set_Text (Vsearch.Replace_Entry, -"");
   Set_Visibility (Vsearch.Replace_Entry, True);
   Gtk_New (Tooltips);
   Set_Tip (Tooltips, Vsearch.Replace_Entry, -"The text that will replace each match");

   Gtk_New (Vsearch.Context_Combo);
   Set_Case_Sensitive (Vsearch.Context_Combo, False);
   Set_Use_Arrows (Vsearch.Context_Combo, True);
   Set_Use_Arrows_Always (Vsearch.Context_Combo, False);
   String_List.Append (Context_Combo_Items, -"");
   Combo.Set_Popdown_Strings (Vsearch.Context_Combo, Context_Combo_Items);
   Free_String_List (Context_Combo_Items);
   Attach (Vsearch.Table, Vsearch.Context_Combo, 1, 2, 2, 3,
     Expand or Fill, 0,
     2, 0);

   Vsearch.Context_Entry := Get_Entry (Vsearch.Context_Combo);
   Set_Editable (Vsearch.Context_Entry, False);
   Set_Max_Length (Vsearch.Context_Entry, 0);
   Set_Text (Vsearch.Context_Entry, -"");
   Set_Visibility (Vsearch.Context_Entry, True);
   Set_Tip (Tooltips, Vsearch.Context_Entry, -"The context of the search");

   Gtk_New (Vsearch.Pattern_Combo);
   Set_Case_Sensitive (Vsearch.Pattern_Combo, False);
   Set_Use_Arrows (Vsearch.Pattern_Combo, True);
   Set_Use_Arrows_Always (Vsearch.Pattern_Combo, False);
   String_List.Append (Pattern_Combo_Items, -"");
   Combo.Set_Popdown_Strings (Vsearch.Pattern_Combo, Pattern_Combo_Items);
   Free_String_List (Pattern_Combo_Items);
   Attach (Vsearch.Table, Vsearch.Pattern_Combo, 1, 2, 0, 1,
     Expand or Fill, 0,
     2, 0);

   Vsearch.Pattern_Entry := Get_Entry (Vsearch.Pattern_Combo);
   Set_Editable (Vsearch.Pattern_Entry, True);
   Set_Max_Length (Vsearch.Pattern_Entry, 0);
   Set_Text (Vsearch.Pattern_Entry, -"");
   Set_Visibility (Vsearch.Pattern_Entry, True);
   Set_Tip (Tooltips, Vsearch.Pattern_Entry, -"The searched word or pattern");

   Gtk_New_Hbox (Vsearch.Buttons_Hbox, False, 0);
   Pack_Start (Vsearch.Vbox_Search, Vsearch.Buttons_Hbox, True, True, 0);

   Gtk_New (Vsearch.Options_Frame, -"Options");
   Set_Shadow_Type (Vsearch.Options_Frame, Shadow_Etched_In);
   Pack_Start (Vsearch.Vbox_Search, Vsearch.Options_Frame, True, True, 0);

   Gtk_New_Vbox (Vsearch.Options_Vbox, False, 0);
   Add (Vsearch.Options_Frame, Vsearch.Options_Vbox);

   Gtk_New (Vsearch.Search_All_Check, -"Search All Occurrences");
   Set_Active (Vsearch.Search_All_Check, False);
   Pack_Start (Vsearch.Options_Vbox, Vsearch.Search_All_Check, False, False, 0);

   Gtk_New (Vsearch.Case_Check, -"Case Sensitive");
   Set_Active (Vsearch.Case_Check, False);
   Pack_Start (Vsearch.Options_Vbox, Vsearch.Case_Check, True, True, 0);

   Gtk_New (Vsearch.Whole_Word_Check, -"Whole Word Only");
   Set_Active (Vsearch.Whole_Word_Check, False);
   Pack_Start (Vsearch.Options_Vbox, Vsearch.Whole_Word_Check, True, True, 0);

   Gtk_New (Vsearch.Regexp_Check, -"Regular expression");
   Set_Active (Vsearch.Regexp_Check, False);
   Pack_Start (Vsearch.Options_Vbox, Vsearch.Regexp_Check, True, True, 0);

end Initialize;

end Vsearch_Pkg;
