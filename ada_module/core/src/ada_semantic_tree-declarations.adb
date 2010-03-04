-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                  Copyright (C) 2007-2010, AdaCore                 --
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

with GNAT.Strings; use GNAT.Strings;

with Ada.Characters.Handling;      use Ada.Characters.Handling;
with Ada_Semantic_Tree.Lang;       use Ada_Semantic_Tree.Lang;
with Language.Ada;                 use Language.Ada;
with Ada_Semantic_Tree.Entity_Iteration;
use Ada_Semantic_Tree.Entity_Iteration;
with Ada_Semantic_Tree.Dependency_Tree; use Ada_Semantic_Tree.Dependency_Tree;
with Ada_Semantic_Tree.Units;           use Ada_Semantic_Tree.Units;
with Ada_Semantic_Tree.Parts;           use Ada_Semantic_Tree.Parts;
with Ada_Semantic_Tree.Visibility;      use Ada_Semantic_Tree.Visibility;
with Ada_Semantic_Tree.Std_Entities;    use Ada_Semantic_Tree.Std_Entities;

package body Ada_Semantic_Tree.Declarations is

   use Token_List;

   --------------------
   -- Declaration_Id --
   --------------------

   type Declaration_Id_List
     is new Entity_List_Pckg.Virtual_List_Component
   with record
      First_File      : Structured_File_Access;
      First_Buffer    : String_Access;
      First_Offset    : String_Index_Type;
      Construct_Db    : Construct_Database_Access;
      Name            : Distinct_Identifier;
      Is_Partial      : Boolean;
      Offset          : String_Index_Type;
      From_Visibility : Visibility_Context;
   end record;

   type Iteration_Stage is (File_Hierarchy, Database);

   type Declaration_Id_Iterator
     is new Entity_List_Pckg.Virtual_List_Component_Iterator
   with record
      --  Common data

      Stage           : Iteration_Stage := File_Hierarchy;
      Name            : Distinct_Identifier;
      Is_Partial      : Boolean;
      From_Visibility : Visibility_Context;
      Hidden_Entities : aliased Visibility_Resolver;

      --  Data needed by the first iteration stage (current file)

      First_File : Structured_File_Access;
      First_Unit : Unit_Access;

      Visible_Constructs : Entity_Array_Access;
      Visible_Index      : Integer;

      --  Data needed by the second iteration stage (database)

      Construct_Db : Construct_Database_Access;
      Db_Iterator  : Construct_Db_Iterator;
   end record;

   overriding
   function First
     (List : Declaration_Id_List)
      return Entity_List_Pckg.Virtual_List_Component_Iterator'Class;
   --  Return an iterator pointing on the first element of a list

   overriding
   function At_End
     (It : Declaration_Id_Iterator) return Boolean;
   --  Return true if the iterator is at the end of the list, which means after
   --  the last element.

   overriding
   procedure Next (It : in out Declaration_Id_Iterator);
   --  Moves the iterator to the next element of the list

   overriding
   function Get
     (It : Declaration_Id_Iterator) return Entity_View;
   --  Return the element contained in this iterator

   function Is_Valid (It : Declaration_Id_Iterator'Class) return Boolean;

   overriding
   procedure Free (List : in out Declaration_Id_List);

   overriding
   procedure Free (It : in out Declaration_Id_Iterator);

   procedure Get_Possibilities
     (Identifier      : Distinct_Identifier;
      Is_Partial      : Boolean;
      Context         : Search_Context;
      From_Visibility : Visibility_Context;
      Result          : in out Entity_List);
   --  Look for the identifier given in parameter successively from:
   --  (1) The current file
   --  (2) The parent units
   --  (3) The database

   -----------------------------
   -- Declaration_Composition --
   -----------------------------

   type Declaration_Composition_List is new
     Entity_List_Pckg.Virtual_List_Component
   with record
      From_Visibility : Visibility_Context;
      Root_Entity     : Entity_Access;
      Name            : String_Access;
      Is_Partial      : Boolean;
      Is_All          : Boolean;
      Generic_Context : Generic_Instance_Information;
   end record;

   type Declaration_Composition_Iterator
     is new Entity_List_Pckg.Virtual_List_Component_Iterator
   with record
      It         : Semantic_Tree_Iterator;
      Name       : String_Access;
      Is_Partial : Boolean;
   end record;

   overriding
   procedure Free (List : in out Declaration_Composition_List);

   overriding
   procedure Free (It : in out Declaration_Composition_Iterator);

   overriding
   function First
     (List : Declaration_Composition_List)
      return Entity_List_Pckg.Virtual_List_Component_Iterator'Class;
   --  Return an iterator pointing on the first element of a list

   overriding
   function At_End
     (It : Declaration_Composition_Iterator) return Boolean;
   --  Return true if the iterator is at the end of the list, which means after
   --  the last element.

   overriding
   procedure Next (It : in out Declaration_Composition_Iterator);
   --  Moves the iterator to the next element of the list

   overriding
   function Get
     (It : Declaration_Composition_Iterator) return Entity_View;
   --  Return the element contained in this iterator

   function Is_Valid
     (It : Declaration_Composition_Iterator'Class) return Boolean;

   -----------------------------
   -- Unique_Declaration_List --
   -----------------------------

   type Unique_Declaration_List is new
     Entity_List_Pckg.Virtual_List_Component
   with record
      Object : Entity_View;
   end record;

   type Unique_Declaration_Iterator
     is new Entity_List_Pckg.Virtual_List_Component_Iterator
   with record
      Object : Entity_View;
   end record;

   overriding
   function First
     (List : Unique_Declaration_List)
      return Entity_List_Pckg.Virtual_List_Component_Iterator'Class;
   --  Return an iterator pointing on the first element of a list

   overriding
   function At_End
     (It : Unique_Declaration_Iterator) return Boolean;
   --  Return true if the iterator is at the end of the list, which means after
   --  the last element.

   overriding
   procedure Next (It : in out Unique_Declaration_Iterator);
   --  Moves the iterator to the next element of the list

   overriding
   function Get
     (It : Unique_Declaration_Iterator) return Entity_View;
   --  Return the element contained in this iterator

   overriding
   procedure Free (List : in out Unique_Declaration_List);

   -----------------------
   -- Other subprograms --
   -----------------------

   procedure Set_Actuals
     (It : Entity_View; Act : Actual_Parameter_Resolver_Access);

   function Get_Profile (It : Entity_View) return List_Profile_Access;

   -----------
   -- First --
   -----------

   overriding function First
     (List : Declaration_Id_List)
      return Entity_List_Pckg.Virtual_List_Component_Iterator'Class
   is
      Result : Declaration_Id_Iterator;
   begin
      Result.Name := List.Name;
      Result.Is_Partial := List.Is_Partial;
      Result.From_Visibility := List.From_Visibility;
      Result.Construct_Db := List.Construct_Db;

      if List.First_File /= null then
         Result.Stage := File_Hierarchy;
         Result.First_File := List.First_File;
         Result.First_Unit := Get_Owning_Unit (List.First_File, List.Offset);

         Result.Visible_Constructs :=
           new Entity_Array'
             (Get_Local_Visible_Constructs
                  (File       => List.First_File,
                   Offset     => List.First_Offset,
                   Name       => List.Name,
                   Visibility => Result.Hidden_Entities'Access,
                   Use_Wise   => True,
                   Is_Partial => List.Is_Partial));

         if Result.Visible_Constructs'Length = 0 then
            Result.Visible_Index := 0;
            Next (Result);
         else
            Result.Visible_Index := Result.Visible_Constructs'First;
         end if;
      else
         Result.Stage := Database;
         Result.Db_Iterator := Start
           (Result.Construct_Db, Result.Name.all, Result.Is_Partial);
      end if;

      if not Is_Valid (Result) then
         Next (Result);
      end if;

      return Result;
   end First;

   ----------
   -- Next --
   ----------

   overriding procedure Next (It : in out Declaration_Id_Iterator) is
   begin
      loop
         if It.Stage = File_Hierarchy then
            --  Stage 1: We return the visible constructs from the current
            --  file.

            if It.Visible_Index < It.Visible_Constructs'Length then
               It.Visible_Index := It.Visible_Index + 1;
            else
               --  If we finished to analyze the current visible constructs,
               --  we've got to switch to the database.

               Free (It.Visible_Constructs);
               It.Stage := Database;

               if not It.Is_Partial
                 and then Is_Hidden (It.Hidden_Entities, It.Name.all)
               then
                  --  If this name is already hidden by the entities extracted
                  --  and if it's not partial, then there's nothing more to
                  --  extract (all other names will be hidden). Finish
                  --  here the iteration

                  It.Db_Iterator := Null_Construct_Db_Iterator;
               else
                  It.Db_Iterator := Start
                    (It.Construct_Db, It.Name.all, It.Is_Partial);
               end if;
            end if;

         elsif It.Stage = Database then
            --  Stage 2: We return the files from the database

            if not At_End (It.Db_Iterator) then
               Next (It.Db_Iterator);
            end if;
         end if;

         exit when Is_Valid (It);
      end loop;
   end Next;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid (It : Declaration_Id_Iterator'Class) return Boolean is
   begin
      if At_End (It) then
         return True;
      end if;

      if It.Stage = File_Hierarchy then
         if It.Visible_Constructs /= null
           and then It.Visible_Index <= It.Visible_Constructs'Last
         then
            return True;
         else
            return False;
         end if;

      elsif It.Stage = Database then
         declare
            Potential_Entity : Entity_Access;
         begin
            Potential_Entity := Get (It.Db_Iterator);

            if not Is_Public_Library_Visible (Potential_Entity) then
               --  We don't return entities that are not public library visible
               --  in the case of database searches.

               return False;
            end if;

            if Is_In_Parents
              (Get_Owning_Unit (Potential_Entity), It.First_Unit)
            then
               --  Entities in the parents of the owning entity have already
               --  been returned.

               return False;
            end if;

            if Is_Hidden
              (It.Hidden_Entities,
               Get_Construct (Potential_Entity).Name.all)
            then
               --  Entities hiddent by things founds in the parent are not
               --  displayed.

               return False;
            end if;

            case It.From_Visibility.Min_Visibility_Confidence is
               when Use_Visible | With_Visible =>
                  return Is_Visible_From_Clauses
                    (Potential_Entity, It.From_Visibility);

               when others =>
                  return True;

            end case;
         end;
      end if;

      return True;
   end Is_Valid;

   ------------
   -- At_End --
   ------------

   overriding function At_End (It : Declaration_Id_Iterator) return Boolean is
   begin
      return It.Stage = Database and then At_End (It.Db_Iterator);
   end At_End;

   ---------
   -- Get --
   ---------

   overriding function Get
     (It : Declaration_Id_Iterator) return Entity_View
   is
      Declaration : Entity_View;
      Full_Cell   : Entity_Access;
   begin
      case It.Stage is
         when File_Hierarchy =>
            Declaration := new Declaration_View_Record'
              (Confidence      => It.From_Visibility.Min_Visibility_Confidence,
               Entity          => It.Visible_Constructs (It.Visible_Index),
               Is_All          => False,
               From_Prefixed   => False,
               Profile         => null,
               Actuals         => null,
               Generic_Context => Null_Generic_Instance_Information
              );

            Full_Cell := Get_Last_Visible_Declaration
              (Declaration.Entity,
               It.From_Visibility.File,
               It.From_Visibility.Offset);

            Declaration.Entity := Full_Cell;

            return Declaration;

         when Database =>
            return new Declaration_View_Record'
              (Confidence    => It.From_Visibility.Min_Visibility_Confidence,
               Entity        => To_Entity_Access
                 (Get_File (It.Db_Iterator), Get_Construct (It.Db_Iterator)),
               Is_All        => False,
               From_Prefixed => False,
               Profile       => null,
               Actuals       => null,
               Generic_Context => Null_Generic_Instance_Information
              );
      end case;
   end Get;

   ----------
   -- Free --
   ----------

   overriding procedure Free (List : in out Declaration_Id_List) is
      pragma Unreferenced (List);
   begin
      null;
   end Free;

   ----------
   -- Free --
   ----------

   overriding procedure Free (It : in out Declaration_Id_Iterator) is
   begin
      Free (It.Visible_Constructs);
      Free (It.Db_Iterator);
      Free (It.Hidden_Entities);
   end Free;

   -----------------------
   -- Find_Declarations --
   -----------------------

   function Find_Declarations
     (Context                   : Search_Context;
      From_Visibility           : Visibility_Context :=
        Null_Visibility_Context;
      Expression                : Parsed_Expression := Null_Parsed_Expression;
      Categories                : Category_Array := Null_Category_Array;
      Is_Partial                : Boolean := False;
      Excluded_Entities         : Excluded_Stack_Type := Null_Excluded_Stack)
      return Entity_List
   is
      pragma Unreferenced (Categories);

      Db                     : Construct_Database_Access;
      All_Name_Id            : Distinct_Identifier;
      Actual_From_Visibility : Visibility_Context;
      Analyzed_Expression    : Parsed_Expression;
      First_Token            : Token_List.List_Node;

      procedure Analyze_Token
        (Previous_Token       : Token_List.List_Node;
         Token                : Token_List.List_Node;
         Previous_Declaration : Entity_View;
         Result               : in out Entity_List);

      -------------------
      -- Analyze_Token --
      -------------------

      procedure Analyze_Token
        (Previous_Token       : Token_List.List_Node;
         Token                : Token_List.List_Node;
         Previous_Declaration : Entity_View;
         Result               : in out Entity_List)
      is

         procedure Handle_Identifier (Id : Distinct_Identifier);

         -----------------------
         -- Handle_Identifier --
         -----------------------

         procedure Handle_Identifier (Id : Distinct_Identifier) is
            Tmp    : Entity_List;
            Tmp_It : Entity_Iterator;

            Partial_Id : constant Boolean :=
              Next (Token) = Token_List.Null_Node
              and then Is_Partial;
            --  Computes if this identifier is a partial one.

         begin
            if Token = First_Token then
               Get_Possible_Standard_Entities
                 (Db         => Db,
                  Prefix     => Id.all,
                  Is_Partial => Partial_Id,
                  Result     => Tmp);
            end if;

            if Token = First_Token
              or else
                (Previous_Token /= Token_List.Null_Node
                 and then
                   (Data (Previous_Token).Tok_Type = Tok_Use
                      or else Data (Previous_Token).Tok_Type = Tok_With))
            then
               Get_Possibilities
                 (Id,
                  Partial_Id,
                  Context,
                  Actual_From_Visibility,
                  Tmp);

            elsif Previous_Token /= Token_List.Null_Node
              and then Data (Previous_Token).Tok_Type = Tok_Pragma
            then
               Get_Possible_Pragmas
                 (Db      => Db,
                  Prefix  => Id.all,
                  Context => (others => True),
                  Result  => Tmp);
            elsif Previous_Token /= Token_List.Null_Node
              and then Data (Previous_Token).Tok_Type = Tok_Tick
            then
               Get_Possible_Attributes
                 (Db      => Db,
                  Prefix  => Id.all,
                  Context => (others => True),
                  Result  => Tmp);
            elsif Previous_Declaration /= Null_Entity_View then
               Fill_Children
                 (E               => Previous_Declaration,
                  Name            => Id.all,
                  Is_Partial      => Partial_Id,
                  From_Visibility => Actual_From_Visibility,
                  Result          => Tmp);
            else
               return;
            end if;

            if Next (Token) = Token_List.Null_Node then
               Entity_List_Pckg.Concat
                 (Result.Contents, Tmp.Contents);
            else
               Tmp_It := First (Tmp);

               while not At_End (Tmp_It) loop
                  declare
                     View : Entity_View := Get_View (Tmp_It);
                  begin
                     if not Is_Excluded (Excluded_Entities, View.Entity) then
                        Analyze_Token
                         (Token,
                          Next (Token),
                          View,
                          Result);
                     end if;

                     Free (View);
                  end;

                  Next (Tmp_It);
               end loop;

               Free (Tmp_It);
               Free (Tmp.Contents);
            end if;
         end Handle_Identifier;

      begin
         case Data (Token).Tok_Type is
            when Tok_Dot =>
               --  ??? We could factorize that in a "Are actuals consistent"
               --  subprogram.
               if Get_Profile (Previous_Declaration) /= null
                 and then
                   ((Get_Actual_Parameters (Previous_Declaration) = null
                     and then
                       Get_Number_Of_Formals
                         (Get_Profile (Previous_Declaration).all) > 0)
                    or else
                      (Get_Actual_Parameters (Previous_Declaration) /= null
                       and then not
                         Is_Complete
                           (Get_Actual_Parameters (Previous_Declaration).all)))
               then
                  return;
               end if;

               if Next (Token) = Token_List.Null_Node then
                  Fill_Children
                    (E               => Previous_Declaration,
                     Name            => "",
                     Is_Partial      => Next (Token) = Token_List.Null_Node
                                       and then Is_Partial,
                     From_Visibility => Actual_From_Visibility,
                     Result          => Result);
               else
                  Analyze_Token
                    (Token,
                     Next (Token),
                     Previous_Declaration,
                     Result);
               end if;

            when Tok_All =>
               Handle_Identifier (All_Name_Id);

            when Tok_Identifier =>
               Handle_Identifier
                 (Db.Get_Identifier
                  (Get_Name (Analyzed_Expression, Data (Token))));

            when Tok_Open_Parenthesis =>
               if Context.Context_Type /= From_File then
                  --  We do not handle parenthesis in a search in database

                  return;
               end if;

               if Get_Profile (Previous_Declaration) = null then
                  --  There is no possible profile completion here, drop the
                  --  proposal.

                  return;
               end if;

               declare
                  Current_Token : Token_List.List_Node := Next (Token);
                  Success : Boolean := False;
                  Local_Declaration : Entity_View :=
                    Deep_Copy (Previous_Declaration);

                  Free_Local : Boolean := True;
                  --  if Local_Declarations has not been added to the list,
                  --  then it should be freed.

                  New_Param   : Actual_Parameter;
                  Param_Added : Boolean := False;
               begin
                  --  Perform the analysis of the actual parameters.
                  --  Reset any former value of the actual parameters.

                  Set_Actuals
                    (Local_Declaration, new Actual_Parameter_Resolver'
                       (Get_Actual_Parameter_Resolver
                          (Get_Profile (Previous_Declaration).all)));

                  if Local_Declaration.From_Prefixed then
                     --  If we go from a prefixed notation, then the first
                     --  actual parameter is coming from the prefix.

                     Append_Actual
                       (Declaration_View_Record
                          (Local_Declaration.all).Actuals.all,
                        Get_Actual_Parameter (Get_Buffer (Context.File), 0, 0),
                        False,
                        Param_Added,
                        Success);
                  end if;

                  while Current_Token /= Token_List.Null_Node loop
                     if Data (Current_Token).Tok_Type = Tok_Expression then
                        --  ??? It's a shame to have to recompute the actual
                        --  each time we go there.
                        New_Param := Get_Actual_Parameter
                          (Get_Buffer (Context.File),
                           Data (Current_Token).Token_First,
                           Data (Current_Token).Token_Last);

                        Append_Actual
                          (Declaration_View_Record
                             (Local_Declaration.all).Actuals.all,
                           New_Param,
                           False,
                           Param_Added,
                           Success);

                        if not Param_Added then
                           Free (New_Param);
                        end if;

                        --  ??? This way of computing the possibilities is
                        --  not very useful, since we'd like to have all the
                        --  potential matches in a row, and then do semantics
                        --  on them.
                        if not Success then
                           if Free_Local then
                              Free (Local_Declaration);
                           end if;

                           return;
                        end if;
                     elsif
                       Data (Current_Token).Tok_Type = Tok_Close_Parenthesis
                     then
                        if Is_Complete
                          (Get_Actual_Parameters (Local_Declaration).all)
                        then
                           if Next (Current_Token) = Token_List.Null_Node then
                              Append
                                (Result.Contents,
                                 Unique_Declaration_List'
                                   (Object => Local_Declaration));

                              Free_Local := False;
                           else
                              Analyze_Token
                                (Current_Token,
                                 Next (Current_Token),
                                 Local_Declaration,
                                 Result);
                           end if;
                        end if;

                        exit;
                     else
                        --  If we find something else, it's a non-parsable
                        --  statement. We cancel the analysis.

                        if Free_Local then
                           Free (Local_Declaration);
                        end if;

                        return;
                     end if;

                     Current_Token := Next (Current_Token);
                  end loop;

                  if Current_Token = Token_List.Null_Node
                    or else Data (Current_Token).Tok_Type
                    /= Tok_Close_Parenthesis
                  then
                     --  In this case, we're still in the expression  list, for
                     --  example "A (B, C, D, ". We want to add the current
                     --  construct to possible declaration list, even if it's
                     --  not complete. Other tools, such as completion, will be
                     --  able to make usage of this information.
                     --
                     --  We don't add anything if there's no remaining possible
                     --  parameter.

                     if Any_Named_Formal_Missing
                       (Get_Actual_Parameters (Local_Declaration).all)
                     then
                        Append
                          (Result.Contents,
                           Unique_Declaration_List'
                             (Object => Local_Declaration));

                        Free_Local := False;
                     end if;
                  end if;

                  if Free_Local then
                     Free (Local_Declaration);
                  end if;
               end;

            when Tok_With | Tok_Use =>
               pragma Assert (Token = First_Token);

               if Context.Context_Type = From_File then
                  Actual_From_Visibility.Filter := All_Accessible_Units;

                  if Next (Token) /= Token_List.Null_Node then
                     Analyze_Token
                       (Token,
                        Next (Token),
                        Previous_Declaration,
                        Result);
                  else
                     Get_Possibilities
                       (Null_Distinct_Identifier,
                        Is_Partial,
                        (From_File,
                         Context.File,
                         Data (Token).Token_First - 1),
                        Actual_From_Visibility,
                        Result);
                  end if;
               else
                  --  There no database-wide search starting with a with token

                  return;
               end if;

            when Tok_Pragma =>
               pragma Assert (Token = First_Token);

               if Next (Token) /= Token_List.Null_Node then
                  Analyze_Token
                    (Token,
                     Next (Token),
                     Previous_Declaration,
                     Result);
               else
                  Get_Possible_Pragmas
                    (Db      => Db,
                     Prefix  => "",
                     Context => (others => True),
                     Result  => Result);
               end if;

            when Tok_Tick =>
               if Next (Token) /= Token_List.Null_Node then
                  Analyze_Token
                    (Token,
                     Next (Token),
                     Previous_Declaration,
                     Result);
               else
                  Get_Possible_Attributes
                    (Db      => Db,
                     Prefix  => "",
                     Context => (others => True),
                     Result  => Result);
               end if;

            when others =>
               null;
         end case;
      end Analyze_Token;

      Result : Entity_List;
   begin
      case Context.Context_Type is
         when From_Database =>
            Db := Context.Db;

         when From_File =>
            Db := Get_Database (Context.File);
      end case;

      All_Name_Id := Db.Get_Identifier ("all");
      Result.Excluded_List := Excluded_Entities;
      Ref (Result.Excluded_List);

      if Expression = Null_Parsed_Expression then
         if Context.Context_Type = From_File then
            Analyzed_Expression := Parse_Expression_Backward
              (Ada_Lang, Get_Buffer (Context.File), Context.Offset);
         else
            --  We can't do a search without expression on a database wide
            --  search.

            return Result;
         end if;

      else
         Analyzed_Expression := Expression;
      end if;

      if From_Visibility /= Null_Visibility_Context then
         Actual_From_Visibility := From_Visibility;

      else
         if Context.Context_Type = From_File then
            Actual_From_Visibility.File := Context.File;
            Actual_From_Visibility.Offset := Context.Offset;
            Actual_From_Visibility.Min_Visibility_Confidence :=
              Public_Library_Visible;
         else
            Actual_From_Visibility := Null_Visibility_Context;
         end if;

         Actual_From_Visibility.Filter := Everything;
      end if;

      declare
         Analyzed_Token : Token_List.List_Node;
      begin
         --  Do a pre-analyzis of the expression - its beginning may not be
         --  relevant for our purpose.

         First_Token := First (Analyzed_Expression.Tokens);
         Analyzed_Token := First_Token;

         while Analyzed_Token /= Token_List.Null_Node loop
            if Data (Analyzed_Token).Tok_Type = Tok_Arrow then
               --  If the expression is like "Id => Exp", we only want to
               --  analyse Exp.

               First_Token := Next (Analyzed_Token);
            end if;

            Analyzed_Token := Next (Analyzed_Token);
         end loop;

         if First_Token /= Token_List.Null_Node then
            Analyze_Token
              (Token_List.Null_Node,
               First_Token,
               Null_Entity_View,
               Result);
         end if;
      end;

      if Expression = Null_Parsed_Expression then
         --  If we took the responsability of creating the expression, we have
         --  to free it.

         Free (Analyzed_Expression);
      end if;

      return Result;
   end Find_Declarations;

   ----------------------
   -- Get_Possiblities --
   ----------------------

   procedure Get_Possibilities
     (Identifier      : Distinct_Identifier;
      Is_Partial      : Boolean;
      Context         : Search_Context;
      From_Visibility : Visibility_Context;
      Result          : in out Entity_List)
   is
      Id_Name : String renames Identifier.all;
   begin
      if (From_Visibility.Filter and All_Accessible_Units) /= 0 then
         --  Create an extensive list of all the accessible units with no
         --  parent.
         declare
            C : Unit_Iterator := Get_Units
              (Get_Database (Context.File), Id_Name, Is_Partial);
            List : Entity_List_Extensive_Pckg.Extensive_List_Pckg.List;
            Construct_It : Construct_Tree_Iterator;
            Construct    : access Simple_Construct_Information;

            use Entity_List_Extensive_Pckg;
            use Entity_List_Extensive_Pckg.Extensive_List_Pckg;

            Unit        : Unit_Access;
            Entity_Unit : Entity_Access;
         begin
            while not At_End (C) loop
               Unit := Get (C);
               Entity_Unit := Get_Entity (Unit);

               Construct_It := To_Construct_Tree_Iterator (Entity_Unit);
               Construct := Get_Construct (Entity_Unit);

               if Construct_It /= Null_Construct_Tree_Iterator
                 and then Construct.Is_Declaration
               then
                  Append
                    (List,
                     new Declaration_View_Record'
                       (Confidence    => Use_Visible,
                        Entity        => Entity_Unit,
                        Is_All        => False,
                        From_Prefixed => False,
                        Actuals       => null,
                        Profile       => null,
                        Generic_Context => Null_Generic_Instance_Information));
               end if;

               Next (C);
            end loop;

            Append (Result.Contents, To_Extensive_List (List));

            Free (C);
         end;
      end if;

      if (From_Visibility.Filter and All_Visible_Entities) /= 0 then
         declare
            List : Declaration_Id_List;
         begin
            List := Declaration_Id_List'
              (Name            => Identifier,
               Is_Partial      => Is_Partial,
               From_Visibility => From_Visibility,
               others          => <>);

            case Context.Context_Type is
               when From_File =>
                  List.First_File   := Context.File;
                  List.First_Offset := Context.Offset;
                  List.Construct_Db := Get_Database (Context.File);
                  List.First_Buffer := Get_Buffer (Context.File);
                  List.Offset       := Context.Offset;

               when From_Database =>
                  List.Construct_Db := Context.Db;

            end case;

            Append (Result.Contents, List);
         end;
      end if;
   end Get_Possibilities;

   ----------------------------
   -- Match_Declaration_With --
   ----------------------------

   function Match_Declaration_With
     (Entity          : Entity_Access;
      File            : Structured_File_Access;
      Offset          : String_Index_Type;
      From_Visibility : Visibility_Context :=
        Null_Visibility_Context;
      Expression      : Parsed_Expression := Null_Parsed_Expression)
      return Visibility_Confidence
   is
      Decls : Entity_List := Find_Declarations
        (Context           => (From_File, File, Offset),
         From_Visibility   => From_Visibility,
         Expression        => Expression,
         Categories        => Null_Category_Array,
         Is_Partial        => False);

      It   : Entity_Iterator := First (Decls);
   begin
      while not At_End (It) loop
         if Get_Entity (It) = Entity then
            --   ??? We should compute a more accurate value here

            return Public_Library_Visible;
         end if;

         Next (It);
      end loop;

      Free (It);
      Free (Decls);

      return Not_Visible;
   end Match_Declaration_With;

   -----------
   -- Match --
   -----------

   function Match
     (Seeked_Name, Tested_Name : String; Is_Partial : Boolean) return Boolean
   is
   begin
      if (not Is_Partial and then Seeked_Name'Length /= Tested_Name'Length)
        or else Seeked_Name'Length > Tested_Name'Length
      then
         return False;
      end if;

      for J in 1 .. Seeked_Name'Length loop
         if To_Lower (Tested_Name (J + Tested_Name'First - 1)) /=
           To_Lower (Seeked_Name (J + Seeked_Name'First - 1))
         then
            return False;
         end if;
      end loop;

      return True;
   end Match;

   -----------
   -- First --
   -----------

   overriding function First
     (List : Declaration_Composition_List)
      return Entity_List_Pckg.Virtual_List_Component_Iterator'Class
   is
      It   : Declaration_Composition_Iterator;
      Kind : Semantic_Kind;
   begin
      if List.Is_All then
         Kind := All_Access;
      else
         Kind := None;
      end if;

      It := Declaration_Composition_Iterator'
        (It         => To_Semantic_Tree_Iterator
           ((List.Root_Entity, Kind, List.Generic_Context),
            List.From_Visibility),
         Name       => List.Name,
         Is_Partial => List.Is_Partial);

      if not Is_Valid (It) then
         Next (It);
      end if;

      return It;
   end First;

   ------------
   -- At_End --
   ------------

   overriding function At_End
     (It : Declaration_Composition_Iterator) return Boolean is
   begin
      return At_End (It.It);
   end At_End;

   ----------
   -- Next --
   ----------

   overriding procedure Next (It : in out Declaration_Composition_Iterator) is
   begin
      Next (It.It);

      while not Is_Valid (It) loop
         Next (It.It);
      end loop;
   end Next;

   ---------
   -- Get --
   ---------

   overriding function Get
     (It : Declaration_Composition_Iterator) return Entity_View
   is
      Info : Semantic_Information := Get (It.It);
   begin
      Ref (Info.Generic_Context);

      return new Declaration_View_Record'
        (Confidence      => Public_Library_Visible,
         Entity          => Info.Entity,
         Is_All          => Info.Kind = All_Access,
         From_Prefixed   => Info.Kind = Prefix_Notation,
         Actuals         => null,
         Profile         => null,
         Generic_Context => Info.Generic_Context);
   end Get;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid
     (It : Declaration_Composition_Iterator'Class) return Boolean
   is
      Name_Str : String_Access;
      Entity   : Entity_Access;
      Construct_It : Construct_Tree_Iterator;
      Construct : access Simple_Construct_Information;
   begin
      if At_End (It.It) then
         return True;
      end if;

      if Get (It.It).Kind = All_Access then
         --  If we're on a All keyword, then check that the expected name is
         --  indeed completable with "all".

         return Match (It.Name.all, "all", It.Is_Partial);
      else
         Entity := Get (It.It).Entity;
         Construct_It := To_Construct_Tree_Iterator (Entity);
         Construct := Get_Construct (Entity);

         Name_Str := Construct.Name;

         if Name_Str = null then
            return False;
         end if;

         if Is_Compilation_Unit (Construct_It) then
            --  If we are on a compilation unit, we've got to take into account
            --  composite unit names

            declare
               Composite_Name : constant Composite_Identifier :=
                 To_Composite_Identifier (Name_Str.all);
               Name           : constant String := Get_Item
                 (Composite_Name, Length (Composite_Name));
            begin
               if Match (It.Name.all, Name, It.Is_Partial) then
                  return True;
               else
                  return False;
               end if;
            end;
         else
            --  If not, then we just have to compare the names

            if Match (It.Name.all, Name_Str.all, It.Is_Partial) then
               return True;
            else
               return False;
            end if;
         end if;
      end if;
   end Is_Valid;

   ----------
   -- Free --
   ----------

   overriding procedure Free (List : in out Declaration_Composition_List) is
   begin
      Free (List.Name);
   end Free;

   ----------
   -- Free --
   ----------

   overriding procedure Free (It : in out Declaration_Composition_Iterator) is
   begin
      --  Name will be freed with List, doing free here is erroneous
      Free (It.It);
   end Free;

   ----------
   -- Free --
   ----------

   overriding procedure Free (This : in out Declaration_View_Record) is
   begin
      Unref (This.Generic_Context);
      Free (Entity_View_Record (This));

      Free (This.Profile);
      Free (This.Actuals);
   end Free;

   ---------------
   -- Deep_Copy --
   ---------------

   overriding procedure Deep_Copy (This : in out Declaration_View_Record) is
   begin
      Deep_Copy (Entity_View_Record (This));

      if This.Profile /= null then
         This.Profile := new List_Profile'
           (This.Profile.all);
      end if;

      if This.Actuals /= null then
         This.Actuals := new Actual_Parameter_Resolver'
           (Deep_Copy (This.Actuals.all));
      end if;

      Ref (This.Generic_Context);
   end Deep_Copy;

   --------------------
   -- Configure_View --
   --------------------

   overriding procedure Configure_View
     (E : in out Declaration_View_Record; It : Entity_Iterator)
   is
      pragma Unreferenced (It);
   begin
      if E.Profile = null then
         E.Profile := new List_Profile'(Get_List_Profile (E.Entity));
      end if;
   end Configure_View;

   -----------------------
   -- Get_Documentation --
   -----------------------

   overriding function Get_Documentation
     (E : access Declaration_View_Record) return UTF8_String
   is
   begin
      return Get_Documentation (Ada_Tree_Lang, E.Entity);
   end Get_Documentation;

   --------------
   -- Get_Name --
   --------------

   overriding function Get_Name
     (E : access Declaration_View_Record) return UTF8_String
   is
      Construct : constant access Simple_Construct_Information :=
        Get_Construct (E);
   begin
      if Construct /= null and then Construct.Name /= null then
         return Construct.Name.all;
      else
         return "";
      end if;
   end Get_Name;

   -------------------
   -- Fill_Children --
   -------------------

   overriding procedure Fill_Children
     (E               : access Declaration_View_Record;
      From_Visibility : Visibility_Context;
      Name            : String;
      Is_Partial      : Boolean;
      Result          : in out Entity_List)
   is
   begin
      Append
        (Result.Contents,
         Declaration_Composition_List'
           (Root_Entity     => E.Entity,
            Name            => new String'(Name),
            Is_Partial      => Is_Partial,
            Is_All          => E.Is_All,
            From_Visibility => From_Visibility,
            Generic_Context => E.Generic_Context));
   end Fill_Children;

   ---------------------------
   -- Get_Actual_Parameters --
   ---------------------------

   function Get_Actual_Parameters
     (It : Entity_View)
      return Actual_Parameter_Resolver_Access is
   begin
      if It /= null and then It.all in Declaration_View_Record then
         return Declaration_View_Record (It.all).Actuals;
      else
         return null;
      end if;
   end Get_Actual_Parameters;

   -----------
   -- First --
   -----------

   overriding function First
     (List : Unique_Declaration_List)
      return Entity_List_Pckg.Virtual_List_Component_Iterator'Class is
   begin
      return Unique_Declaration_Iterator'(Object => List.Object);
   end First;

   ------------
   -- At_End --
   ------------

   overriding function At_End
     (It : Unique_Declaration_Iterator) return Boolean is
   begin
      return It.Object = Null_Entity_View;
   end At_End;

   ----------
   -- Next --
   ----------

   overriding procedure Next (It : in out Unique_Declaration_Iterator) is
   begin
      It.Object := Null_Entity_View;
   end Next;

   ---------
   -- Get --
   ---------

   overriding function Get
     (It : Unique_Declaration_Iterator) return Entity_View is
   begin
      return Deep_Copy (It.Object);
   end Get;

   ----------
   -- Free --
   ----------

   overriding procedure Free (List : in out Unique_Declaration_List) is
   begin
      Free (List.Object);
   end Free;

   --------------------
   -- To_Declaration --
   --------------------

   function To_Declaration (Entity : Entity_Access) return Entity_View
   is
      Result : constant Entity_View := new Declaration_View_Record;
   begin
      Result.Confidence := Public_Library_Visible;
      Result.Entity := Entity;

      return Result;
   end To_Declaration;

   -----------------
   -- Set_Actuals --
   -----------------

   procedure Set_Actuals
     (It : Entity_View; Act : Actual_Parameter_Resolver_Access) is
   begin
      if It.all in Declaration_View_Record then
         declare
            Decl : Declaration_View_Record renames
              Declaration_View_Record (It.all);
         begin
            Free (Decl.Actuals);
            Decl.Actuals := Act;
         end;
      end if;
   end Set_Actuals;

   -----------------
   -- Get_Profile --
   -----------------

   function Get_Profile (It : Entity_View) return List_Profile_Access is
   begin
      if It /= null and then It.all in Declaration_View_Record then
         return Declaration_View_Record (It.all).Profile;
      else
         return null;
      end if;
   end Get_Profile;

end Ada_Semantic_Tree.Declarations;
