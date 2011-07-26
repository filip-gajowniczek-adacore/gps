-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2011, AdaCore                   --
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

with Entities;         use Entities;
with GNATCOLL.Symbols; use GNATCOLL.Symbols;
with Doc_Utils;        use Doc_Utils;

package body Completion.C.Constructs_Extractor is
   use Completion_List_Pckg;
   use Completion_List_Extensive_Pckg;
   use Extensive_List_Pckg;

   Resolver_ID : constant String := "CNST_C  ";

   function To_Language_Category (Kind : E_Kind) return Language_Category;
   --  Make a simple association between entity categories and construct
   --  categories. This association is known to be inaccurate.

   -----------------------------------------
   -- New_C_Construct_Completion_Resolver --
   -----------------------------------------

   function New_C_Construct_Completion_Resolver
     (Kernel       : Kernel_Handle;
      Current_File : Virtual_File) return Completion_Resolver_Access is
   begin
      return
        new Construct_Completion_Resolver'
              (Manager     => null,
               Kernel      => Kernel,
               GLI_Handler => Get_LI_Handler
                                (Get_Database (Kernel), Current_File));
   end New_C_Construct_Completion_Resolver;

   -------------------------
   -- Get_Completion_Root --
   -------------------------

   overriding procedure Get_Completion_Root
     (Resolver : access Construct_Completion_Resolver;
      Offset   : String_Index_Type;
      Context  : Completion_Context;
      Result   : in out Completion_List)
   is
      function Doc_Header (E_Info : Entity_Information) return String;
      --  Generate the header of the documentation of each entity

      function Doc_Header (E_Info : Entity_Information) return String is
         K : constant E_Kinds := Get_Kind (E_Info).Kind;
      begin
         if K = Include_File then
            return "";
         else
            return
              Attributes_To_String (Get_Attributes (E_Info))
                & " " & Kind_To_String (Get_Kind (E_Info))
                & ASCII.LF;
         end if;
      end Doc_Header;

      --  Local variables

      Prefix   : constant UTF8_String
        (Natural (Offset) + 1 .. Natural (Context.Offset)) :=
           Context.Buffer (Natural (Offset) + 1 .. Natural (Context.Offset));

      use Entities_Search_Tries;
      use Completion_List_Extensive_Pckg.Extensive_List_Pckg;

      Iter     : Vector_Trie_Iterator;
      E_Info   : Entity_Information;
      E_List   : Completion_List_Extensive_Pckg.Extensive_List_Pckg.List;
      Proposal : C_Completion_Proposal;

   begin
      --  Our candidates are all the the C/C++ entities stored in the trie
      --  database whose prefix matches this one!

      Iter :=
        Start (Trie       => Get_Name_Index (Resolver.GLI_Handler),
               Prefix     => Prefix,
               Is_Partial => True);

      while not At_End (Iter) loop
         E_Info := Get (Iter);

         declare
            Name : aliased constant String := Get (Get_Name (E_Info)).all;
            Doc  : constant String :=
                    Doc_Header (E_Info)
                    & Doc_Utils.Get_Documentation
                       (Get_Language_Handler (Resolver.Kernel), E_Info);

         begin
            Proposal :=
              (Resolver      => Resolver,
               Name          => new String'(Name),
               Category      => To_Language_Category (Get_Kind (E_Info)),
               Documentation => new String'(Doc),
               Entity_Info   => E_Info);

            Append (E_List, Proposal);
         end;

         Next (Iter);
      end loop;

      Completion_List_Pckg.Append
        (Result.List,
         Completion_List_Extensive_Pckg.To_Extensive_List (E_List));

      --  We must initialize the value of Searched_Identifier to ensure that
      --  Smart_Complete() displaces the cursor backward to the beginning
      --  of the searched identifier. Otherwise it will be duplicated in
      --  the buffer.

      Result.Searched_Identifier := new String'(Prefix);
   end Get_Completion_Root;

   ------------
   -- Get_Id --
   ------------

   overriding function Get_Id
     (Resolver : Construct_Completion_Resolver) return String
   is
      pragma Unreferenced (Resolver);
   begin
      return Resolver_ID;
   end Get_Id;

   ----------
   -- Free --
   ----------

   overriding procedure Free (This : in out Construct_Completion_Resolver) is
      pragma Unreferenced (This);
   begin
      null;
   end Free;

   ------------------
   -- Get_Category --
   ------------------

   overriding
   function Get_Category
     (Proposal : C_Completion_Proposal) return Language_Category is
   begin
      return Proposal.Category;
   end Get_Category;

   ------------------
   -- Get_Location --
   ------------------

   overriding function Get_Location
     (Proposal : C_Completion_Proposal) return File_Location
   is
      Loc : constant Entities.File_Location :=
              Get_Declaration_Of (Proposal.Entity_Info);
   begin
      return (Get_Filename (Get_File (Loc)), Get_Line (Loc), Get_Column (Loc));
   end Get_Location;

   overriding function Get_Visibility
     (Proposal : C_Completion_Proposal) return Construct_Visibility is
      pragma Unreferenced (Proposal);
   begin
      return Visibility_Public;
   end Get_Visibility;

   --------------------------
   -- To_Language_Category --
   --------------------------

   function To_Language_Category (Kind : E_Kind) return Language_Category is
   begin
      case Kind.Kind is
         when Access_Kind
            | Array_Kind
            | Boolean_Kind
            | Decimal_Fixed_Point
            | Enumeration_Kind
            | Exception_Entity
            | Floating_Point
            | Modular_Integer
            | Ordinary_Fixed_Point
            | Private_Type
            | Signed_Integer
            | String_Kind
            | Named_Number =>
            return Cat_Variable;

         when Class_Wide
            | Class
            | Interface_Kind =>
            return Cat_Class;

         when Enumeration_Literal =>
            return Cat_Literal;

         when Function_Or_Operator =>
            return Cat_Function;

         when Include_File =>
            return Cat_Include;

         when Procedure_Kind =>
            return Cat_Procedure;

         when Record_Kind =>
            return Cat_Structure;

         when Union =>
            return Cat_Union;

         when Unresolved_Entity
            | Function_Macro
            | Macro
            | Reference =>
            return Cat_Unknown;

         --  Kinds exlusive of Ada

         when Overloaded_Entity
            | Entry_Or_Entry_Family
            | Label_On_Block
            | Label_On_Loop
            | Label_On_Statement
            | Package_Kind
            | Protected_Kind
            | Private_Object
            | Task_Kind =>
            return Cat_Unknown;

         --  Unused language categories:
         --    Cat_Type
         --    Cat_Subtype
         --    Cat_Local_Variable
         --    Cat_Parameter

         --    Cat_Case_Inside_Record
         --    Cat_Discriminant
         --    Cat_Representation_Clause

         --    Cat_Loop_Statement
         --    Cat_If_Statement
         --    Cat_Case_Statement
         --    Cat_Select_Statement
         --    Cat_Accept_Statement
         --    Cat_Declare_Block
         --    Cat_Return_Block
         --    Cat_Simple_Block

         --    Cat_Package
         --    Cat_Task

         --    Cat_Protected
         --    Cat_Entry

         --    Cat_Exception_Handler
         --    Cat_Pragma

         --    Cat_Custom

      end case;
   end To_Language_Category;

end Completion.C.Constructs_Extractor;
