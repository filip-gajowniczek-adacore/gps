with Ada.Exceptions;            use Ada.Exceptions;
with Ada.Unchecked_Deallocation;
with ALI;
with Atree;
with Basic_Types;               use Basic_Types;
with Csets;
with Errout;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.OS_Lib;               use GNAT.OS_Lib;
with Glide_Intl;                use Glide_Intl;
with Namet;                     use Namet;
with Output;                    use Output;
with Prj.Ext;                   use Prj.Ext;
with Prj.PP;                    use Prj.PP;
with Prj.Part;                  use Prj.Part;
with Prj.Proc;                  use Prj.Proc;
with Prj.Tree;                  use Prj.Tree;
with Prj;                       use Prj;
with Projects.Editor;           use Projects.Editor;
with Snames;                    use Snames;
with String_Hash;
with Stringt;                   use Stringt;
with Traces;                    use Traces;
with Types;                     use Types;

package body Projects.Registry is

   Me : constant Debug_Handle := Create ("Projects.Registry");

   Project_Backward_Compatibility : constant Boolean := True;
   --  Should be set to true if saved project should be compatible with GNAT
   --  3.15a1, False if they only need to be compatible with GNAT 3.16 >=
   --  20021024


   procedure Do_Nothing (Project : in out Project_Type);
   --  Do not free the project (in the hash tables), since it shared by several
   --  entries and several htables

   package Project_Htable is new String_Hash
     (Data_Type => Project_Type,
      Free_Data => Do_Nothing,
      Null_Ptr  => No_Project);
   use Project_Htable.String_Hash_Table;

   type Source_File_Data is record
      Project : Project_Type;
      Lang    : Name_Id;

      --  ??? Should we cache directories as well
   end record;
   No_Source_File_Data : constant Source_File_Data :=
     (No_Project, No_Name);

   procedure Do_Nothing (Data : in out Source_File_Data);

   package Source_Htable is new String_Hash
     (Data_Type => Source_File_Data,
      Free_Data => Do_Nothing,
      Null_Ptr  => No_Source_File_Data);
   use Source_Htable.String_Hash_Table;

   type Project_Registry_Data is record
      Root    : Project_Type;
      --  The root of the project hierarchy

      Sources  : Source_Htable.String_Hash_Table.HTable;
      --  Index on base source file names, return the managing project

      Projects : Project_Htable.String_Hash_Table.HTable;
      --  Index on project names. Some project of the hierarchy might not
      --  exist, since the Project_Type are created lazily the first time they
      --  are needed.

      Scenario_Variables : Scenario_Variable_Array_Access;
      --  Cached value of the scenario variables. This should be accessed only
      --  through the function Scenario_Variables, since it needs to be
      --  initialized first.

      --  Implicit dependency on the global htables in the Prj.* packages.
   end record;


   procedure Add_Foreign_Source_Files
     (Registry : Project_Registry;
      Project  : Project_Type;
      Errors   : Error_Report);
   --  Add to Project the list of source files for languages other than
   --  Ada. These sources are also cached in the registry.

   procedure Reset
     (Registry  : in out Project_Registry;
      View_Only : Boolean);
   --  Reset the contents of the project registry. This should be called only
   --  if a new project is loaded, otherwise no project is accessible to the
   --  application any more.
   --  If View_Only is true, then the projects are not destroyed, but all the
   --  fields related to the current view are reset.

   procedure Create_Environment_Variables (Registry : in out Project_Registry);
   --  Make sure that all the environment variables actually exist (possibly
   --  with their default value). Otherwise, GNAT will not be able to compute
   --  the project view.

   procedure Reset_Environment_Variables (Registry : Project_Registry);
   --  Find all the environment variables for the project, and cache the list
   --  in the registry.
   --  Does nothing if the cache is not empty.

   procedure Parse_Source_Files
     (Registry : in out Project_Registry;
      Errors   : Error_Report);
   --  Find all the source files for the project, and cache them in the
   --  registry.
   --  At the same time, check that the gnatls attribute is coherent between
   --  all projects and subprojects, and memorize the sources in the
   --  hash-table.

   function Normalize_Project_Path (Path : String) return String;
   --  Normalize the full path to a project (and make sure the project file
   --  extension is set)

   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (Scenario_Variable_Array, Scenario_Variable_Array_Access);

   ----------------
   -- Do_Nothing --
   ----------------

   procedure Do_Nothing (Project : in out Project_Type) is
      pragma Unreferenced (Project);
   begin
      null;
   end Do_Nothing;

   procedure Do_Nothing (Data : in out Source_File_Data) is
      pragma Unreferenced (Data);
   begin
      null;
   end Do_Nothing;

   ---------------------------
   -- Is_Valid_Project_Name --
   ---------------------------

   function Is_Valid_Project_Name (Name : String) return Boolean is
   begin
      if Name'Length = 0
        or else (Name (Name'First) not in 'a' .. 'z'
                 and then Name (Name'First) not in 'A' .. 'Z')
      then
         return False;
      end if;

      for N in Name'First + 1 .. Name'Last loop
         if Name (N) not in 'a' .. 'z'
           and then Name (N) not in 'A' .. 'Z'
           and then Name (N) not in '0' .. '9'
           and then Name (N) /= '_'
         then
            return False;
         end if;
      end loop;

      return True;
   end Is_Valid_Project_Name;

   ------------------------------------
   -- Reset_Scenario_Variables_Cache --
   ------------------------------------

   procedure Reset_Scenario_Variables_Cache (Registry : Project_Registry) is
   begin
      Unchecked_Free (Registry.Data.Scenario_Variables);
   end Reset_Scenario_Variables_Cache;

   -----------
   -- Reset --
   -----------

   procedure Reset
     (Registry  : in out Project_Registry;
      View_Only : Boolean)
   is
      Project : Project_Type;
      Iter    : Project_Htable.String_Hash_Table.Iterator;
   begin
      if Registry.Data /= null then
         --  Free all projects

         Get_First (Registry.Data.Projects, Iter);
         loop
            Project := Get_Element (Iter);
            exit when Project = No_Project;

            if View_Only then
               Reset (Project);
            else
               Destroy (Project);
            end if;
            Get_Next (Registry.Data.Projects, Iter);
         end loop;

         if not View_Only then
            Reset (Registry.Data.Projects);
            Prj.Ext.Reset;
            Prj.Tree.Tree_Private_Part.Projects_Htable.Reset;
            Registry.Data.Root := No_Project;
         end if;

         Reset (Registry.Data.Sources);
         Reset_Scenario_Variables_Cache (Registry);
      else
         Registry.Data := new Project_Registry_Data;
      end if;
   end Reset;

   ------------------
   -- Load_Or_Find --
   ------------------

   function Load_Or_Find
     (Registry     : Project_Registry;
      Project_Path : String) return Project_Type
   is
      P : Project_Type;
      Node : Project_Node_Id;
      Path : constant String :=
        Base_Name (Project_Path, Project_File_Extension);
   begin
      Name_Len := Path'Length;
      Name_Buffer (1 .. Name_Len) := Path;
      P := Get_Project_From_Name (Registry, Name_Find);
      if P = No_Project then
         Prj.Part.Parse (Node, Normalize_Project_Path (Project_Path), True);
         P := Get_Project_From_Name (Registry, Prj.Tree.Name_Of (Node));
      end if;
      return P;
   end Load_Or_Find;

   ----------------------------
   -- Normalize_Project_Path --
   ----------------------------

   function Normalize_Project_Path (Path : String) return String is
      function Extension return String;
      --  Return the extension to add to the file name (.gpr if not already
      --  there)

      function Extension return String is
      begin
         if File_Extension (Path) /= Project_File_Extension then
            return Project_File_Extension;
         else
            return "";
         end if;
      end Extension;
   begin
      return Normalize_Pathname (Path, Resolve_Links => False) & Extension;
   end Normalize_Project_Path;

   ----------
   -- Load --
   ----------

   procedure Load
     (Registry           : in out Project_Registry;
      Root_Project_Path  : String;
      Errors             : Projects.Error_Report;
      New_Project_Loaded : out Boolean)
   is
      Path : constant String := Normalize_Project_Path (Root_Project_Path);
      Project : Project_Node_Id;
   begin
      if not Is_Regular_File (Path) then
         Trace (Me, "Load: " & Path & " is not a regular file");
         if Errors /= null then
            Errors (Root_Project_Path & (-" is not a a regular file"));
         end if;
         New_Project_Loaded := False;
         return;
      end if;

      if Registry.Data /= null
        and then Project_Path (Get_Root_Project (Registry)) = Path
      then
         Trace (Me, "Load: " & Path & " already loaded");
         if Errors /= null then
            Errors (Root_Project_Path & (-" already loaded"));
         end if;
         New_Project_Loaded := False;
         return;
      end if;

      New_Project_Loaded := True;

      Output.Set_Special_Output (Output_Proc (Errors));
      Reset (Registry, View_Only => False);

      Prj.Part.Parse (Project, Path, True);

      if Project = Empty_Node then
         if Errors /= null then
            Errors (-"Couldn't parse the project " & Root_Project_Path
                    & ASCII.LF & (-"Using default project instead"));
         end if;
         Load_Default_Project (Registry, Get_Current_Dir);
         return;
      end if;

      Registry.Data.Root := Get_Project_From_Name
        (Registry, Prj.Tree.Name_Of (Project));
      Unchecked_Free (Registry.Data.Scenario_Variables);

      Set_Is_Default (Registry.Data.Root, False);
      Output.Set_Special_Output (null);

   exception
      when E : others =>
         Trace (Me, "Load: unexpected exception: "
                & Exception_Information (E));
         Output.Set_Special_Output (null);
         raise;
   end Load;

   --------------------------
   -- Load_Default_Project --
   --------------------------

   procedure Load_Default_Project
     (Registry  : in out Project_Registry;
      Directory : String) is
   begin
      Reset (Registry, View_Only => False);
      Registry.Data.Root := Create_Default_Project
        (Registry, "default", Directory);
      Set_Is_Default (Registry.Data.Root, True);
      Set_Project_Modified (Registry.Data.Root, False);
   end Load_Default_Project;

   --------------------
   -- Recompute_View --
   --------------------

   procedure Recompute_View
     (Registry : in out Project_Registry;
      Errors   : Projects.Error_Report)
   is
      procedure Report_Error (S : String; Project : Project_Id);
      --  Handler called when the project parser finds an error

      procedure Report_Error (S : String; Project : Project_Id) is
      begin
         if Errors /= null then
            if Project = Prj.No_Project then
               Errors (S);
            elsif not Is_Default (Registry.Data.Root) then
               Errors (Get_String (Prj.Projects.Table (Project).Name)
                       & ": " & S);
            end if;
         end if;
      end Report_Error;

      View : Project_Id;
   begin
      Reset (Registry, View_Only => True);

      Unchecked_Free (Registry.Data.Scenario_Variables);
      Create_Environment_Variables (Registry);

      Prj.Reset;
      Errout.Initialize;
      Prj.Proc.Process
        (View, Registry.Data.Root.Node,
         Report_Error'Unrestricted_Access);

      --  Parsing failed ? => revert to the default project
      if View = Prj.No_Project then
         Load_Default_Project (Registry, Get_Current_Dir);
         return;
      end if;

      Parse_Source_Files (Registry, Errors);
   end Recompute_View;

   ------------------------
   -- Parse_Source_Files --
   ------------------------

   procedure Parse_Source_Files
     (Registry : in out Project_Registry;
      Errors   : Error_Report)
   is
      Iter : Imported_Project_Iterator := Start (Registry.Data.Root, True);
      Gnatls : constant String := Get_Attribute_Value
        (Registry.Data.Root, Gnatlist_Attribute, Ide_Package);
      Sources : String_List_Id;
      P       : Project_Type;
   begin
      loop
         P := Current (Iter);
         exit when P = No_Project;

         declare
            Ls : constant String := Get_Attribute_Value
              (P, Gnatlist_Attribute, Ide_Package);
         begin
            if Ls /= "" and then Ls /= Gnatls and then Errors /= null then
               Errors
                 (Project_Name (P) & ": "
                  & (-("gnatls attribute is not the same in this project as in"
                       & " the root project. It will be ignored in the"
                       & " subproject.")));
            end if;
         end;

         --  Add the Ada sources that are already in the project. The foreign
         --  files

         Sources := Prj.Projects.Table (Get_View (P)).Sources;
         while Sources /= Nil_String loop
            Set (Registry.Data.Sources,
                 K => Get_String (String_Elements.Table (Sources).Value),
                 E => (P, Name_Ada));
            Sources := String_Elements.Table (Sources).Next;
         end loop;

         Add_Foreign_Source_Files (Registry, P, Errors);

         Next (Iter);
      end loop;
   end Parse_Source_Files;

   ----------------------------------
   -- Create_Environment_Variables --
   ----------------------------------

   procedure Create_Environment_Variables
     (Registry : in out Project_Registry) is
   begin
      Reset_Environment_Variables (Registry);

      for J in Registry.Data.Scenario_Variables'Range loop
         Ensure_External_Value (Registry.Data.Scenario_Variables (J));
      end loop;
   end Create_Environment_Variables;

   ---------------------------------
   -- Reset_Environment_Variables --
   ---------------------------------

   procedure Reset_Environment_Variables (Registry : Project_Registry) is
   begin
      if Registry.Data.Scenario_Variables = null then
         Trace (Me, "Reset_Environment_Variables");
         Registry.Data.Scenario_Variables := new Scenario_Variable_Array'
           (Find_Scenario_Variables
            (Registry.Data.Root, Parse_Imported => True));
      end if;
   end Reset_Environment_Variables;

   ------------------------------
   -- Add_Foreign_Source_Files --
   ------------------------------

   procedure Add_Foreign_Source_Files
     (Registry : Project_Registry;
      Project  : Project_Type;
      Errors   : Error_Report)
   is
      procedure Record_Source (File : String; Lang : Name_Id);
      --  Add file to the list of source files for Project

      procedure Record_Source (File : String; Lang : Name_Id) is
      begin
         String_Elements.Increment_Last;
         Start_String;
         Store_String_Chars (File);
         String_Elements.Table (String_Elements.Last) :=
           (Value    => End_String,
            Location => No_Location,
            Next     => Prj.Projects.Table (Get_View (Project)).Sources);
         Prj.Projects.Table (Get_View (Project)).Sources :=
           String_Elements.Last;

         Set (Registry.Data.Sources, K => File, E => (Project, Lang));
      end Record_Source;

      Languages : Argument_List                := Get_Languages (Project);
      Dirs      : constant String_Array_Access := Source_Dirs (Project, False);
      Dir       : Dir_Type;
      Length    : Natural;
      Buffer    : String (1 .. 2048);
      Part      : Unit_Part;
      Unit, Lang : Name_Id;

   begin
      --  Nothing to do if the only language is Ada, since this has already
      --  been taken care of

      if Languages'Length = 0
        or else (Languages'Length = 1
                 and then Languages (Languages'First).all = Ada_String)
      then
         Free (Languages);
         return;
      end if;

      --  Note: we do not have to check Source_File_List and Source_Files
      --  attributes, since they have already been processed by the Ada parser.

      --  ??? We are parsing Ada files twice

      for D in Dirs'Range loop
         Open (Dir, Dirs (D).all);

         loop
            Read (Dir, Buffer, Length);
            exit when Length = 0;

            --  Have to use the naming scheme, since the hash-table hasn't been
            --  filled yet (Get_Language_From_File wouldn't work)

            Get_Unit_Part_And_Name_From_Filename
              (Filename  => Buffer (1 .. Length),
               Project   => Get_View (Project),
               Part      => Part,
               Unit_Name => Unit,
               Lang      => Lang);

            if Lang /= No_Name and then Lang /= Name_Ada then
               Get_Name_String (Lang);

               for L in Languages'Range loop
                  if Languages (L) /= null
                    and then Languages (L).all = Name_Buffer (1 .. Name_Len)
                  then
                     Free (Languages (L));
                     exit;
                  end if;
               end loop;

               Record_Source (Buffer (1 .. Length), Lang);
            end if;
         end loop;

         Close (Dir);
      end loop;

      --  Print error messages for remaining messages

      Length := 0;
      for L in Languages'Range loop
         if Languages (L) /= null
           and then Languages (L).all /= Ada_String
         then
            Length := Length + Languages (L)'Length + 2;
         end if;
      end loop;

      if Length /= 0 then
         declare
            Error : String (1 .. Length);
            Index : Natural := Error'First;
         begin
            for L in Languages'Range loop
               if Languages (L) /= null
                 and then Languages (L).all /= Ada_String
               then
                  Error (Index .. Index + Languages (L)'Length + 1) :=
                    Languages (L).all & ", ";
                  Index := Index + Languages (L)'Length + 2;
               end if;
            end loop;

            if Errors /= null then
               Errors (Project_Name (Project) &
                       Prj.Project_File_Extension
                       & ": Warning, no source files for "
                       & Error (Error'First .. Error'Last - 2));
            end if;
         end;
      end if;

      Free (Languages);
   end Add_Foreign_Source_Files;

   ------------------------
   -- Scenario_Variables --
   ------------------------

   function Scenario_Variables (Registry : Project_Registry)
      return Projects.Scenario_Variable_Array is
   begin
      Reset_Environment_Variables (Registry);
      return Registry.Data.Scenario_Variables.all;
   end Scenario_Variables;

   ----------------------
   -- Get_Root_Project --
   ----------------------

   function Get_Root_Project (Registry : Project_Registry)
      return Projects.Project_Type is
   begin
      return Registry.Data.Root;
   end Get_Root_Project;

   ---------------------------
   -- Get_Project_From_Name --
   ---------------------------

   function Get_Project_From_Name
     (Registry : Project_Registry; Name : Types.Name_Id) return Project_Type
   is
      P : Project_Type;
      Node : Project_Node_Id;
   begin
      if Registry.Data = null then
         return No_Project;

      else
         Get_Name_String (Name);
         P := Get (Registry.Data.Projects, Name_Buffer (1 .. Name_Len));

         if P = No_Project then
            Node := Prj.Tree.Tree_Private_Part.Projects_Htable.Get (Name).Node;

            if Node = Empty_Node then
               P := No_Project;
            else
               Create_From_Node (P, Registry, Node);
               Set (Registry.Data.Projects, Name_Buffer (1 .. Name_Len), P);
            end if;
         end if;
         return P;
      end if;
   end Get_Project_From_Name;

   ---------------------------
   -- Get_Project_From_File --
   ---------------------------

   function Get_Project_From_File
     (Registry          : Project_Registry;
      Source_Filename   : String;
      Root_If_Not_Found : Boolean := True)
      return Project_Type
   is
      P : constant Project_Type :=
        Get (Registry.Data.Sources, Source_Filename).Project;
   begin
      if P = No_Project and then Root_If_Not_Found then
         return Registry.Data.Root;
      end if;
      return P;
   end Get_Project_From_File;

   ----------------------------
   -- Get_Language_From_File --
   ----------------------------

   function Get_Language_From_File
     (Registry : Project_Registry; Source_Filename : String)
      return Types.Name_Id is
   begin
      return Get (Registry.Data.Sources, Source_Filename).Lang;
   end Get_Language_From_File;

   ----------------------
   -- Language_Matches --
   ----------------------

   function Language_Matches
     (Registry        : Project_Registry;
      Source_Filename : String;
      Filter          : Projects.Name_Id_Array) return Boolean
   is
      Lang : Name_Id;
   begin
      if Filter'Length = 0 then
         return True;
      end if;

      Lang := Get_Language_From_File (Registry, Source_Filename);
      for L in Filter'Range loop
         if Filter (L) = Lang then
            return True;
         end if;
      end loop;

      return False;
   end Language_Matches;

   -------------
   -- Destroy --
   -------------

   procedure Destroy (Registry : in out Project_Registry) is
   begin
      Reset (Registry, View_Only => False);
   end Destroy;

   ------------------
   -- Pretty_Print --
   ------------------

   procedure Pretty_Print
     (Project                            : Project_Type;
      Increment                          : Positive      := 3;
      Eliminate_Empty_Case_Constructions : Boolean       := False;
      Minimize_Empty_Lines               : Boolean       := False;
      W_Char                             : Prj.PP.Write_Char_Ap := null;
      W_Eol                              : Prj.PP.Write_Eol_Ap  := null;
      W_Str                              : Prj.PP.Write_Str_Ap  := null) is
   begin
      Pretty_Print
        (Project.Node,
         Increment,
         Eliminate_Empty_Case_Constructions,
         Minimize_Empty_Lines,
         W_Char, W_Eol, W_Str,
         Backward_Compatibility => Project_Backward_Compatibility);
   end Pretty_Print;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      Namet.Initialize;
      Csets.Initialize;
      Snames.Initialize;
      Prj.Initialize;
      Prj.Tree.Initialize;

      Name_C_Plus_Plus := Get_String (Cpp_String);
   end Initialize;

   --------------
   -- Finalize --
   --------------

   procedure Finalize is
   begin
      Prj.Reset;
      Prj.Ext.Reset;
      Prj.Tree.Tree_Private_Part.Projects_Htable.Reset;
      Prj.Tree.Tree_Private_Part.Project_Nodes.Free;
      Namet.Finalize;
      Stringt.Initialize;

      --  ??? Should this be done every time we parse an ali file ?
      ALI.ALIs.Free;
      ALI.Units.Free;
      ALI.Withs.Free;
      ALI.Args.Free;
      ALI.Linker_Options.Free;
      ALI.Sdep.Free;
      ALI.Xref.Free;
      Atree.Atree_Private_Part.Nodes.Free;
   end Finalize;

end Projects.Registry;

