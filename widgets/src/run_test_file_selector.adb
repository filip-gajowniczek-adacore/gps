with Gtk; use Gtk;
with Gtk.Main;

with Gdk.Pixmap; use Gdk.Pixmap;
with Gdk.Color;  use Gdk.Color;
with Test_File_Selector; use Test_File_Selector;
with Gtkada.File_Selector; use Gtkada.File_Selector;

with Pixmaps_IDE; use Pixmaps_IDE;

procedure Run_Test_File_Selector is
   File_Selector_Window : File_Selector_Window_Access;

   Filter_A : Filter_Show_All_Access := new Filter_Show_All;
   Filter_B : Filter_Show_Ada_Access := new Filter_Show_Ada;

begin
   Gtk.Main.Set_Locale;
   Gtk.Main.Init;
   Gtk_New (File_Selector_Window, "/");

   Create_From_Xpm_D
     (Filter_B.Spec_Pixmap,
      Window => null,
      Colormap => Get_System,
      Mask => Filter_B.Spec_Bitmap,
      Transparent => Null_Color,
      Data => box_xpm);

   Create_From_Xpm_D
     (Filter_B.Body_Pixmap,
      Window => null,
      Colormap => Get_System,
      Mask => Filter_B.Body_Bitmap,
      Transparent => Null_Color,
      Data => package_xpm);

   Register_Filter (File_Selector_Window, Filter_A);
   Register_Filter (File_Selector_Window, Filter_B);

   Show_All (File_Selector_Window);
   Gtk.Main.Main;
end Run_Test_File_Selector;
