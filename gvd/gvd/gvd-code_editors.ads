-----------------------------------------------------------------------
--                 Odd - The Other Display Debugger                  --
--                                                                   --
--                         Copyright (C) 2000                        --
--                 Emmanuel Briot and Arnaud Charlet                 --
--                                                                   --
-- Odd is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

--  This package implements a text area target to the display of source
--  code.
--  It knows how to highligh keywords, strings and commands, and how
--  to display icons at the beginning of each line where a function
--  returns True.

--  ??? Should have an function to set the current line (and display an icon
--  one the side).
--  ??? Should have an function to print line numbers on the side.

with Glib;
with Gtk.Text;
with Gtk.Layout;
with Gtk.Box;
with Gdk.Pixmap;
with Gdk.Bitmap;
with Gdk.Font;
with Language;
with Gtkada.Types;
with Debugger;
with Gdk.Color;

package Gtkada.Code_Editors is


   type Code_Editor_Record is new Gtk.Box.Gtk_Box_Record with private;
   type Code_Editor is access all Code_Editor_Record'Class;

   procedure Gtk_New_Hbox
     (Editor : out Code_Editor;
      Homogeneous : Boolean := False;
      Spacing     : Glib.Gint := 0);
   --  Create a new editor window.
   --  The name and the parameters are chosen so that this type is compatible
   --  with the code generated by Gate for a Gtk_Box.

   procedure Initialize
     (Editor      : access Code_Editor_Record'Class;
      Homogeneous : Boolean := False;
      Spacing     : Glib.Gint := 0);
   --  Internal procedure.

   procedure Configure
     (Editor : access Code_Editor_Record;
      Ps_Font_Name   : String;
      Font_Size      : Glib.Gint;
      Default_Icon   : Gtkada.Types.chars_ptr_array;
      Comments_Color : String;
      Strings_Color  : String;
      Keywords_Color : String);
   --  Ps_Font_Name is the name of the postscript font that will be used to
   --  display the text. It should be a fixed-width font, which is nice for
   --  source code.
   --  Default_Icon is used for the icon that can be displayed on the left of
   --  each line.
   --
   --  The editor will automatically free its allocated memory when it is
   --  destroyed.

   procedure Set_Current_Language
     (Editor : access Code_Editor_Record;
      Lang   : access Language.Language_Root'Class);
   --  Change the current language for the editor.
   --  The text already present in the editor is not re-highlighted for the
   --  new language, this only influences future addition to the editor.

   procedure Clear (Editor : access Code_Editor_Record);
   --  Clear the contents of the editor.

   procedure Load_File
     (Editor    : access Code_Editor_Record;
      File_Name : String;
      Debug     : access Debugger.Debugger_Root'Class);
   --  Load and append a file in the editor.
   --  The contents is highlighted based on the current language.
   --  Debugger is used to calculate which lines should get icons on the side,
   --  through calls to Line_Contains_Code.

   type Icon_Function is access
     function (File : String; Line : Positive) return Boolean;
   --  Return True if the given line in File should get an icon on the side.

   procedure Load_File
     (Editor    : access Code_Editor_Record;
      File_Name : String;
      Icon_Func : Icon_Function;
      Pixmap    : Gdk.Pixmap.Gdk_Pixmap;
      Mask      : Gdk.Bitmap.Gdk_Bitmap);
   --  More general version of Load_File above, where you can choose your own
   --  pixmap and decide where to put it.

private

   type Color_Array is array (Language.Language_Entity'Range) of
     Gdk.Color.Gdk_Color;

   type Code_Editor_Record is new Gtk.Box.Gtk_Box_Record with record
      Text           : Gtk.Text.Gtk_Text;
      Buttons        : Gtk.Layout.Gtk_Layout;

      Lang           : Language.Language_Access;
      Font           : Gdk.Font.Gdk_Font;
      Default_Pixmap : Gdk.Pixmap.Gdk_Pixmap := Gdk.Pixmap.Null_Pixmap;
      Default_Mask   : Gdk.Bitmap.Gdk_Bitmap := Gdk.Bitmap.Null_Bitmap;
      Colors         : Color_Array := (others => Gdk.Color.Null_Color);
   end record;

end Gtkada.Code_Editors;
