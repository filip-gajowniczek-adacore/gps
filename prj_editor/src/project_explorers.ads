-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2001-2004                       --
--                            ACT-Europe                             --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

--  This package groups a tree (that shows projects, directories, files, and
--  entities in the files), and the display of the scenario variables that the
--  user can modify.
--  This widget also knows how to save its state to an Ada stream, and re-read
--  a previously saved configuration.

with GPS.Kernel;
with Scenario_Views;
with Gtk.Handlers;
with Gtk.Box;
with Gtkada.Tree_View;
with GVD.Tooltips;
with Glib;
with Gdk.Pixmap;
with Gdk.Rectangle;

package Project_Explorers is

   type Project_Explorer_Record is new Gtk.Box.Gtk_Box_Record with private;
   type Project_Explorer is access all Project_Explorer_Record'Class;

   procedure Gtk_New
     (Explorer : out Project_Explorer;
      Kernel   : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Create a new explorer.
   --  On each update, and since the list of withed projects can not changed,
   --  the open/close status of all the project nodes is kept.

   procedure Initialize
     (Explorer : access Project_Explorer_Record'Class;
      Kernel   : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Internal initialization procedure.

   Explorer_Module_ID : GPS.Kernel.Module_ID := null;
   --  Id for the explorer module

   procedure Register_Module
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Register the module into the list

   -------------
   -- Signals --
   -------------

   --  <signals>
   --  You should connect to the "context_changed" signal in the kernel to get
   --  report on selection changes.
   --  </signals>

private
   type Project_Explorer_Access is access all Project_Explorer_Record;

   procedure Draw_Tooltip
     (Widget : access Gtkada.Tree_View.Tree_View_Record'Class;
      Data   : in out Project_Explorer_Access;
      Pixmap : out Gdk.Pixmap.Gdk_Pixmap;
      Width  : out Glib.Gint;
      Height : out Glib.Gint;
      Area   : out Gdk.Rectangle.Gdk_Rectangle);
   --  Draw the tooltip. See GVD.Tooltips.

   package Project_Explorer_Tooltips is new GVD.Tooltips
     (User_Type    => Project_Explorer_Access,
      Widget_Type  => Gtkada.Tree_View.Tree_View_Record,
      Draw_Tooltip => Draw_Tooltip);

   type Project_Explorer_Record is new Gtk.Box.Gtk_Box_Record with record
      Scenario  : Scenario_Views.Scenario_View;
      Tree      : Gtkada.Tree_View.Tree_View;

      Kernel    : GPS.Kernel.Kernel_Handle;
      Expand_Id : Gtk.Handlers.Handler_Id;
      --  The signal for the expansion of nodes in the project view

      Expanding : Boolean := False;

      Tooltip   : Project_Explorer_Tooltips.Tooltips;
   end record;

end Project_Explorers;
