-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2002                            --
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

with Gtk.Box;
with Gtk.Check_Button;
with Gtk.Scrolled_Window;
with Gtk.Tree_Model;
with Gtk.Tree_Store;
with GPS.Kernel;
with Projects;
with GNAT.OS_Lib;

package Scenario_Selectors is

   ----------------------
   -- Project selector --
   ----------------------

   type Project_Selector_Record is new Gtk.Box.Gtk_Box_Record with private;
   type Project_Selector is access all Project_Selector_Record'Class;

   procedure Gtk_New
     (Selector : out Project_Selector;
      Kernel   : access GPS.Kernel.Kernel_Handle_Record'Class;
      Ref_Project : Projects.Project_Type);
   --  Create a new project selector.
   --  Ref_Project is the project whose settings are shown in the project
   --  properties editor. As a result, it can never be unselected.

   procedure Initialize
     (Selector : access Project_Selector_Record'Class;
      Kernel   : access GPS.Kernel.Kernel_Handle_Record'Class;
      Ref_Project : Projects.Project_Type);
   --  Internal version of Gtk_New

   type Project_Iterator (<>) is private;

   function Start (Selector : access Project_Selector_Record'Class)
      return Project_Iterator;
   --  Return a new iterator that will iterate over all the selected projects
   --  in Selector.
   --  The first project returned with Current will be the reference project
   --  for the selector

   function Count (Iter : Project_Iterator) return Natural;
   --  Return the number of selected projects in Selector

   procedure Next (Iter : in out Project_Iterator);
   --  Move to the next project

   function Current (Iter : Project_Iterator) return Projects.Project_Type;
   --  Return the current project, or No_Project if there are no more projects.

   -----------------------
   -- Scenario selector --
   -----------------------

   type Scenario_Selector_Record is new
     Gtk.Scrolled_Window.Gtk_Scrolled_Window_Record with private;
   type Scenario_Selector is access all Scenario_Selector_Record'Class;

   procedure Gtk_New
     (Selector : out Scenario_Selector;
      Kernel   : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Create a new project selector.
   --  Ref_Project is the project whose settings are shown in the project
   --  properties editor. As a result, it can never be unselected.

   procedure Initialize
     (Selector : access Scenario_Selector_Record'Class;
      Kernel   : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Internal version of Gtk_New

   type Scenario_Iterator (<>) is private;

   function Start (Selector : access Scenario_Selector_Record'Class)
      return Scenario_Iterator;
   --  Return a new iterator that will iterate over all the selected scenarios
   --  in Selector.

   function Has_Multiple_Scenario (Iter : Scenario_Iterator) return Boolean;
   --  Return True if multiple scenariis are selected.

   procedure Next (Iter : in out Scenario_Iterator);
   --  Move to the next project

   function At_End (Iter : Scenario_Iterator) return Boolean;
   --  Return True if there are no more scenario to return

   function Current (Iter : Scenario_Iterator)
      return GNAT.OS_Lib.Argument_List;
   --  Return the current scenario. The order of the variables is the same as
   --  in GPS.Kernel.Scenario_Variables.
   --  The returned value must be freed by the caller.

   function Get_Current_Scenario (Variables : Projects.Scenario_Variable_Array)
      return GNAT.OS_Lib.Argument_List;
   --  Return the current values of the environment variables in Variables.
   --  The returned array must be freed by the caller.

   procedure Set_Environment
     (Variables : Projects.Scenario_Variable_Array;
      Values    : GNAT.OS_Lib.Argument_List);
   --  Set the value of each variable described in Variables to the value at
   --  the matching index in Values. This directly modifies the environment
   --  variables. Values can be the result of Current above.


private

   type Project_Selector_Record is new Gtk.Box.Gtk_Box_Record with record
      Model       : Gtk.Tree_Store.Gtk_Tree_Store;
      Ref_Project : Projects.Project_Type;
      Kernel      : GPS.Kernel.Kernel_Handle;
      Select_All  : Boolean := True;
      Show_As_Hierarchy : Gtk.Check_Button.Gtk_Check_Button;
   end record;

   type Scenario_Selector_Record is new
     Gtk.Scrolled_Window.Gtk_Scrolled_Window_Record with
   record
      Model      : Gtk.Tree_Store.Gtk_Tree_Store;
      Kernel     : GPS.Kernel.Kernel_Handle;
      Select_All : Boolean := True;
   end record;

   type Project_Iterator (Num_Projects : Natural) is record
      Project   : Projects.Project_Type_Array (1 .. Num_Projects);
      Current   : Natural;
   end record;

   type Iter_Array is array (Natural range <>) of Gtk.Tree_Model.Gtk_Tree_Iter;

   type Scenario_Iterator (Num_Vars : Natural) is record
      Selector   : Scenario_Selector;
      Current    : Iter_Array (1 .. Num_Vars);
      Variables  : Iter_Array (1 .. Num_Vars);
      At_End     : Boolean;
   end record;

end Scenario_Selectors;
