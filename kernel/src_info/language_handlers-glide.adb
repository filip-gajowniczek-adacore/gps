-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                        Copyright (C) 2002                         --
--                            ACT-Europe                             --
--                                                                   --
-- GPS is free  software; you can  redistribute it and/or modify  it --
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

with Language;                  use Language;
with Language.Unknown;          use Language.Unknown;
with Basic_Types;               use Basic_Types;
with Src_Info;                  use Src_Info;
with Ada.Unchecked_Deallocation;
with Ada.Characters.Handling;   use Ada.Characters.Handling;
with Prj_API;                   use Prj_API;
with Types;                     use Types;
with Namet;                     use Namet;
with Prj;                       use Prj;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;

package body Language_Handlers.Glide is

   function Get_Index_From_Language
     (Handler       : access Glide_Language_Handler_Record'Class;
      Language_Name : String) return Natural;
   --  Return the index of Language in Handler.Languages, or 0 if no such
   --  language is known.

   function Get_Language_From_File
     (Handler         : access Glide_Language_Handler_Record;
      Source_Filename : String;
      Project         : Prj.Project_Id) return String;
   --  Same as the default one, except we already know the project to which for
   --  Source_Filename belongs.

   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (Language_Info_Array, Language_Info_Access);
   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (Handler_Info_Array, Handler_Info_Access);

   function Get_LI_Handler_By_Name
     (Handler : access Glide_Language_Handler_Record;
      Name    : String) return Natural;
   --  Return the index of the LI handler Name, or 0 if not found.

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New (Handler : out Glide_Language_Handler) is
   begin
      Handler := new Glide_Language_Handler_Record;
   end Gtk_New;

   ----------------------
   -- Set_Project_View --
   ----------------------

   procedure Set_Project_View
     (Handler : access Glide_Language_Handler_Record;
      Project_View : Prj.Project_Id) is
   begin
      Handler.Project_View := Project_View;
   end Set_Project_View;

   -----------------------------
   -- Get_Index_From_Language --
   -----------------------------

   function Get_Index_From_Language
     (Handler       : access Glide_Language_Handler_Record'Class;
      Language_Name : String) return Natural is
   begin
      if Handler.Languages /= null then
         for Index in Handler.Languages'Range loop
            if To_Lower (Language_Name) =
              To_Lower (Handler.Languages (Index).Language_Name.all)
            then
               return Index;
            end if;
         end loop;
      end if;
      return 0;
   end Get_Index_From_Language;

   ----------------------------
   -- Get_Language_From_File --
   ----------------------------

   function Get_Language_From_File
     (Handler : access Glide_Language_Handler_Record;
      Source_Filename : String) return Language.Language_Access
   is
      Index : Natural;
   begin
      Index := Get_Index_From_Language
        (Handler, Get_Language_From_File (Handler, Source_Filename));
      if Index /= 0 then
         return Handler.Languages (Index).Lang;
      end if;

      return Unknown_Lang;
   end Get_Language_From_File;

   ----------------------------
   -- Get_Language_From_File --
   ----------------------------

   function Get_Language_From_File
     (Handler : access Glide_Language_Handler_Record;
      Source_Filename : String) return String is
   begin
      return Get_Language_From_File (Handler, Source_Filename, No_Project);
   end Get_Language_From_File;

   ----------------------------
   -- Get_Language_From_File --
   ----------------------------

   function Get_Language_From_File
     (Handler         : access Glide_Language_Handler_Record;
      Source_Filename : String;
      Project         : Prj.Project_Id) return String
   is
      --  ??? Could be optimized, since both Get_Project_From_File and
      --  Get_Language_Of traverse the project structure
      Proj : Project_Id := Project;
      Lang : Name_Id;

   begin
      if Project = No_Project then
         Proj := Get_Project_From_File
           (Handler.Project_View, Source_Filename);

         if Proj = No_Project then
            --  ??? Should use the default file extensions instead
            Proj := Handler.Project_View;
         end if;
      end if;

      Lang := Get_Language_Of (Proj, Base_Name (Source_Filename));

      if Lang = No_Name then
         return "";
      else
         return Get_Name_String (Lang);
      end if;
   end Get_Language_From_File;

   -------------------------
   -- Register_LI_Handler --
   -------------------------

   procedure Register_LI_Handler
     (Handler : access Glide_Language_Handler_Record;
      Name    : String;
      LI      : Src_Info.LI_Handler)
   is
      Tmp   : Handler_Info_Access;
      Index : Natural;
   begin
      if Handler.Handlers /= null then
         Index := Get_LI_Handler_By_Name (Handler, Name);
         if Index /= 0 then
            Handler.Handlers (Index).Handler := LI;
            return;
         end if;

         Tmp := new Handler_Info_Array
           (Handler.Handlers'First .. Handler.Handlers'Last + 1);
         Tmp (Handler.Handlers'Range) := Handler.Handlers.all;
         Unchecked_Free (Handler.Handlers);
         Handler.Handlers := Tmp;

      else
         Handler.Handlers := new Handler_Info_Array (1 .. 1);
      end if;

      Handler.Handlers (Handler.Handlers'Last) :=
        (Name    => new String' (Name),
         Handler => LI);
   end Register_LI_Handler;

   ----------------------------
   -- Get_LI_Handler_By_Name --
   ----------------------------

   function Get_LI_Handler_By_Name
     (Handler : access Glide_Language_Handler_Record;
      Name    : String) return Natural is
   begin
      if Handler.Handlers /= null then
         for J in Handler.Handlers'Range loop
            if Handler.Handlers (J).Name.all = Name then
               return J;
            end if;
         end loop;
      end if;

      return 0;
   end Get_LI_Handler_By_Name;

   ----------------------------
   -- Get_LI_Handler_By_Name --
   ----------------------------

   function Get_LI_Handler_By_Name
     (Handler : access Glide_Language_Handler_Record;
      Name    : String) return Src_Info.LI_Handler
   is
      Index : Natural := Get_LI_Handler_By_Name
        (Handler, Name);
   begin
      if Index = 0 then
         return null;
      else
         return Handler.Handlers (Index).Handler;
      end if;
   end Get_LI_Handler_By_Name;

   -----------------
   -- Get_LI_Name --
   -----------------

   function Get_LI_Name
     (Handler : access Glide_Language_Handler_Record;
      Nth     : Natural) return String is
   begin
      if Handler.Handlers /= null
        and then Nth <= Handler.Handlers'Length
      then
         return Handler.Handlers (Handler.Handlers'First + Nth - 1).Name.all;
      end if;
      return "";
   end Get_LI_Name;

   -----------------------
   -- Register_Language --
   -----------------------

   procedure Register_Language
     (Handler : access Glide_Language_Handler_Record;
      Name    : String;
      Lang    : Language.Language_Access)
   is
      Tmp : Language_Info_Access;
      Index : Natural;
   begin
      if Handler.Languages /= null then
         Index := Get_Index_From_Language (Handler, Name);
         if Index /= 0 then
            Handler.Languages (Index).Lang := Lang;
            return;
         end if;

         Tmp := new Language_Info_Array
           (Handler.Languages'First .. Handler.Languages'Last + 1);
         Tmp (Handler.Languages'Range) := Handler.Languages.all;
         Unchecked_Free (Handler.Languages);
         Handler.Languages := Tmp;
      else
         Handler.Languages := new Language_Info_Array (1 .. 1);
      end if;

      Handler.Languages (Handler.Languages'Last) :=
        (Language_Name => new String' (Name),
         Handler       => null,
         Lang          => Lang);
   end Register_Language;

   ---------------------
   -- Known_Languages --
   ---------------------

   function Known_Languages
     (Handler : access Glide_Language_Handler_Record)
      return Basic_Types.String_Array is
   begin
      if Handler.Languages /= null then
         declare
            Result : String_Array (Handler.Languages'Range);
         begin
            for Index in Handler.Languages'Range loop
               Result (Index) := new String'
                 (Handler.Languages (Index).Language_Name.all);
            end loop;
            return Result;
         end;
      else
         declare
            Result : String_Array (1 .. 0);
         begin
            return Result;
         end;
      end if;
   end Known_Languages;

   -----------------------
   -- Add_Language_Info --
   -----------------------

   procedure Add_Language_Info
     (Handler             : access Glide_Language_Handler_Record;
      Language_Name       : String;
      LI                  : Src_Info.LI_Handler;
      Default_Spec_Suffix : String;
      Default_Body_Suffix : String)
   is
      Index : Natural := Get_Index_From_Language (Handler, Language_Name);
      Lang : Name_Id;
      Spec, Impl : Name_Id;
   begin
      if Index /= 0 then
         Handler.Languages (Index).Handler := LI;

         Name_Len := Language_Name'Length;
         Name_Buffer (1 .. Name_Len) := Language_Name;
         Lang := Name_Find;

         Name_Len := Default_Spec_Suffix'Length;
         Name_Buffer (1 .. Name_Len) := Default_Spec_Suffix;
         Spec := Name_Find;

         Name_Len := Default_Body_Suffix'Length;
         Name_Buffer (1 .. Name_Len) := Default_Body_Suffix;
         Impl := Name_Find;

         Register_Default_Naming_Scheme
           (Language => Lang,
            Default_Spec_Suffix => Spec,
            Default_Impl_Suffix => Impl);
      end if;
   end Add_Language_Info;

   ------------------------------
   -- Get_LI_Handler_From_File --
   ------------------------------

   function Get_LI_Handler_From_File
     (Handler         : access Glide_Language_Handler_Record;
      Source_Filename : String;
      Project         : Prj.Project_Id := Prj.No_Project)
      return Src_Info.LI_Handler
   is
      Lang : constant String :=
        Get_Language_From_File (Handler, Source_Filename, Project);
      Index : Natural := Get_Index_From_Language (Handler, Lang);
   begin
      if Index /= 0
        and then Handler.Languages (Index).Handler /= null
      then
         return Handler.Languages (Index).Handler;
      else
         raise Unsupported_Language;
         return null;
      end if;
   end Get_LI_Handler_From_File;

   ---------------------
   -- Languages_Count --
   ---------------------

   function Languages_Count (Handler : access Glide_Language_Handler_Record)
      return Natural is
   begin
      if Handler.Languages = null then
         return 0;
      else
         return Handler.Languages'Length;
      end if;
   end Languages_Count;

   -----------------------
   -- LI_Handlers_Count --
   -----------------------

   function LI_Handlers_Count (Handler : access Glide_Language_Handler_Record)
      return Natural is
   begin
      if Handler.Handlers = null then
         return 0;
      else
         return Handler.Handlers'Length;
      end if;
   end LI_Handlers_Count;

   ---------------------
   -- Get_Nth_Handler --
   ---------------------

   function Get_Nth_Handler
     (Handler : access Glide_Language_Handler_Record;
      Num     : Positive) return Src_Info.LI_Handler is
   begin
      if Handler.Handlers = null
        or else Num > Handler.Handlers'Length
      then
         return null;
      else
         return Handler.Handlers (Handler.Handlers'First + Num - 1).Handler;
      end if;
   end Get_Nth_Handler;

   ----------------------
   -- Get_Nth_Language --
   ----------------------

   function Get_Nth_Language
     (Handler : access Glide_Language_Handler_Record;
      Num     : Positive) return String is
   begin
      if Handler.Languages = null
        or else Num > Handler.Languages'Length
      then
         return "";
      else
         return Handler.Languages
           (Handler.Languages'First + Num - 1).Language_Name.all;
      end if;
   end Get_Nth_Language;

end Language_Handlers.Glide;
