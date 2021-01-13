------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                     Copyright (C) 2007-2021, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with GNAT.Expect;
with GNAT.Strings;
with GPS.Core_Kernels;       use GPS.Core_Kernels;
with GNATCOLL.Traces;
with GNATCOLL.Projects;      use GNATCOLL.Projects;
with GNATCOLL.VFS;           use GNATCOLL.VFS;
with Language_Handlers;      use Language_Handlers;
with Xref;                   use Xref;

package GNATdoc is
   DOCGEN_V31 : constant GNATCOLL.Traces.Trace_Handle :=
     GNATCOLL.Traces.Create ("Docgen.V3.1", GNATCOLL.Traces.Off);

   --  Name of the package and attribute supported by GNATdoc to ignore
   --  subprojects

   Pkg_Name                    : constant String := "documentation";
   Documentation_Dir_Name      : constant String := "documentation_dir";
   Image_Dir_Name              : constant String := "image_dir";
   Doc_Pattern_Name            : constant String := "doc_pattern";
   Custom_Tags_Definition_Name : constant String := "custom_tags_definition";
   Ignored_Subprojects_Name    : constant String := "ignored_subprojects";
   HTML_Custom_Dir_Name        : constant String := "html_custom_dir";

   type Report_Errors_Kind is (None, Errors_Only, Errors_And_Warnings);

   type Tree_Output_Kind is (None, Short, Full);
   --  Contents of the tree output generated by docgen (support for tests!)
   --  * None: no output generated
   --  * Short: One line is generated in the output for each node
   --  * Full: The full information of the node is generated in the
   --    output. Comments output and errors are under control of
   --    other options.

   type Tree_Output_Type is record
      Kind          : Tree_Output_Kind;
      With_Comments : Boolean;
      --  If Kind is not None then this switch controls if comments
      --  retrieved from sources are appended to the tree output.

      --  The addition of errors and warnings of the Tree output follows
      --  the preferences specified in field "Report_Errors".
   end record;

   type Docgen_Options is record

      Comments_Filter  : GNAT.Expect.Pattern_Matcher_Access := null;
      --  User-defined regular expression to filter comments

      Disable_Markup   : Boolean := False;
      --  Disable parsing of comments as markup

      Report_Errors    : Report_Errors_Kind := Errors_And_Warnings;
      --  Enables reporting errors and warnings on missing documentation,
      --  duplicated tags, etc.

      Leading_Doc      : Boolean := False;
      --  If True then extract the documentation of an entity declaration by
      --  first looking at the leading comments, and fallback to the comments
      --  after the entity if not found. If this flag is False then the search
      --  order is reversed.

      Skip_C_Files     : Boolean := True;
      --  Used to force skip processing C and C++ files (since, although the
      --  project may have or reference these files we may not be interested
      --  in the addition of those files to the generated documentation).

      Document_Bodies  : Boolean := False;
      --  True to enable documenting Ada bodies

      Process_Bodies   : Boolean := False;
      --  True to enable processing of body files (to retrieve documentation
      --  for public entities defined in the spec file).

      Show_Private     : Boolean := False;
      --  Show also private entities

      Quiet_Mode       : Boolean := False;
      --  Quiet mode

      Backend_Name     : Ada.Strings.Unbounded.Unbounded_String;
      --  Name of selected backend.

      Ignore_Files     : GNAT.Strings.String_Access;
      --  List of files to be skipped by GNATdoc

      --  -------------------------- Internal switches -----------------------

      Display_Time     : Boolean := False;
      --  Used to enable an extra output with the time consumed by the docgen
      --  components processing files. Used to identify which components of
      --  GNATdoc must be optimized.

      Extensions_Enabled : Boolean := False;
      --  True to enable experimental extensions

      Tree_Output      : Tree_Output_Type := (Full, True);
      --  Enables the generation of tree listings. Used to write regression
      --  tests.

      Output_Comments  : Boolean := False;
      --  Enable an extra output with the retrieved sources, retrieved sources
      --  and parsed comments. Used to write regression tests.

      Default_Encoding : GNAT.Strings.String_Access;
      --  Default encoding of source files.
   end record;

   procedure Process_Project_Files
     (Kernel    : not null access GPS.Core_Kernels.Core_Kernel_Record'Class;
      Options   : Docgen_Options;
      Project   : Project_Type;
      Recursive : Boolean := False;
      Filename  : String := "");
   --  Generate documentation for a project
   --  If Recursive is false then only the project's source files are
   --  documented; otherwise imported project's source files are also
   --  documented. If Filename is specified then only this file is
   --  documented.

   package Unbounded_String_Vectors is
     new Ada.Containers.Vectors
       (Positive, Ada.Strings.Unbounded.Unbounded_String);

private

   --  Package containing utility routines for Virtual Files

   --  This package is defined here to avoid a circular dependency
   --  problem if defined as a private child package (depencency caused by
   --  the declaration of GNATdoc_Context)

   package Files is

      package Files_List is new Ada.Containers.Vectors
        (Index_Type => Natural, Element_Type => GNATCOLL.VFS.Virtual_File);

      procedure Append_Unique_Files
        (Target : access Files_List.Vector;
         Source : access Files_List.Vector);
      --  Traverse Source appending to Target all the files which are not
      --  already stored in Target

      procedure Print_Files
        (Source         : Files_List.Vector;
         With_Full_Name : Boolean := False);
      --  Prints the name of all the files in Source

      function Less_Than
        (Left, Right : GNATCOLL.VFS.Virtual_File) return Boolean;
      package Files_Vector_Sort is new Files_List.Generic_Sorting
        ("<" => Less_Than);

      function Filename (File : Virtual_File) return Filesystem_String;
      --  Return the name of File without extension

      procedure Remove_Element
        (List   : in out Files_List.Vector;
         Cursor : in out Files_List.Cursor);
      --  Remove element located at Cursor and place the cursor just after its
      --  current position

      type Vector_Access is access all Files_List.Vector;

      type Project_Files is record
         Project   : Project_Type;
         Src_Files : Vector_Access;
      end record;

      package Project_Files_List is new Ada.Containers.Vectors
        (Index_Type => Natural, Element_Type => Project_Files);

      function Less_Than (Left, Right : Project_Files) return Boolean;
      package Project_Files_Sort is new Project_Files_List.Generic_Sorting
        ("<" => Less_Than);

   end Files;
   use Files;

   --  Docgen context for processing. This structure avoids passing the
   --  same unmodified parameters along internal routines of Docgen; in
   --  addition it avoids computing several times these values.

   type Docgen_Context is record
      Kernel       : Core_Kernel;
      Database     : General_Xref_Database;
      Lang_Handler : Language_Handler;
      Options      : Docgen_Options;
      Project      : Project_Type;
      Prj_Files    : Project_Files_List.Vector;
   end record;

   type Docgen_Context_Ptr is access Docgen_Context;

   procedure Write_To_File
     (Context   : access constant Docgen_Context;
      Directory : Virtual_File;
      Filename  : Filesystem_String;
      Text      : access Unbounded_String);
   --  Write the contents of Printout in the specified file

   procedure Write_To_File
     (Context   : access constant Docgen_Context;
      Directory : Virtual_File;
      Filename  : Filesystem_String;
      Text      : String);
   --  Write the contents of Printout in the specified file

   function Get_Doc_Directory
     (Kernel : access Core_Kernel_Record'Class)
      return GNATCOLL.VFS.Virtual_File;
   --  If the Directory_Dir attribute is defined in the project, then use the
   --  value; otherwise use the default directory (that is, a subdirectory
   --  'doc' in the object directory, or in the project directory if no
   --  object dir is defined).

   procedure Report_Skipped_File
     (Kernel : Core_Kernel;
      File   : Virtual_File);
   --  Report a warning indicating that File is not processed because
   --  cross references are not up-to-date.

   function Read_Source_File
     (Context : access constant Docgen_Context;
      File    : GNATCOLL.VFS.Virtual_File) return GNAT.Strings.String_Access;
   --  Reads source code file and make attempt to convert it to UTF-8. Replace
   --  CR/LF pairs by single LF character.

end GNATdoc;
