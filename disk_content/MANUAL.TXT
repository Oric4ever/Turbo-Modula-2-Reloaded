Chapter 9 - Turbo Modula-2 Extensions
=====================================

Turbo Modula-2 offers several extensions to Wirth's definition that are not covered by standard
Modula-2, such as general-purpose READ and WRITE statements, string comparison and assignment, 
multidimensional open arrays, and exception handling. These extensions can be suppressed with
the embedded compiler option (* $X- *), or from the Options menu. If this option is turned off,
the compiler will flag all extensions with a warning message.

Input and Output Extensions
---------------------------

Although the various input/output modules provide procedures for reading and writing data to
external devices, Turbo Modula-2 defines four new statements that allow a simplified approach
to input/output: READ, WRITE, READLN, and WRITELN.

  The four statements provide you with a quick way to do output. The following program shows
some of the many possible uses for these extensions.

 MODULE READWRITE;
 VAR aNumber: CARDINAL;
     aCharacter: CHAR;

 BEGIN
  WRITELN('The READ and WRITE statements',' take any number ','of arguments');
  WRITE('Enter a number and a character: ');
  READ(aNumber,aCharacter);
  WRITE('You may even mix types. The number is ',aNumber);
  WRITELN(' The character is ',aCharacter);
  WRITELN('Number may be formatted, as in Pascal ');
  WRITELN('The number 3 in a field of length of 4: "',3:4,'"');
  WRITELN('A real number ',34.556:10:2);
 END READWRITE.

  READ and WRITE extensions have essentially the same function as the Pascal equivalents: they
eliminate the need to use Modula-2's precise library procedures.

  During compilation, the READ and WRITE statements are translated into calls to the
appropriate input/output procedures from the library module Texts. Using these statements
replaces the need to import the specific procedure from the Texts module.

  For a more thorough discussion of these statements, refer to the module Texts in Chapter 11,
`The Standard Library'.

String Extensions
-----------------

Standard Modula-2 allows the assignment of arrays only if both sides are of the same type, and
it completely forbids comparisons of arrays. In Turbo Modula-2, assignments and comparisons of
strings are allowed. A string is any variable whose type is an array with elements of type
CHAR. The starting and ending bounds do not matter; strings are assigned and compared as if 
both strings involved start at the same lower bound.

  The end of a string is denoted either by the end of the array (if the arrays is completely
filled) or by the null character 0C. Any two strings can be assigned to each other, even if
they are defined as different lengths of start at different bounds.

  Additionally, any two strings can be compared using the relational operators =, <>, #, <, >,
<=, or >=.

Multidimensional Open Arrays
----------------------------

Turbo Modula-2 allows open array parameters to be of any dimension. This extension is
invaluable for programs that use matrixes. The standard procedure HIGH will return the highest
bound for each dimension. The next higher bound is found by passing HIGH the variable with [0]
appended (see Chapter 6, `Open Array Parameters').

Error-Handling Extensions
=========================

Program errors can be divided into the following three types:

  Compiler-time errors        Syntax errors discovered by the compiler (for example, a missing
                              semicolon or a misspelling)

  I/O errors                  Problems occurring during input/output operations (for example,
                              file not on disk or file not open)

  Runtime errors              Errors occurring while executing a program (for example, division
                              by zero or integer type passing out of range)

  Compiler errors are corrected before the program can be run. However, I/O and runtime errors
are only apparent while executing a program.

  Should an error occur while running a program, the computer has two options:
(1) to write an error message on the screen and halt the program, or 
(2) to send an error signal to the program.

  The first option is fine for simple programs, but could have disastrous results in real-time
applications. The second method requires that the running program test some king of flag after
each operation capable of producing an error. This can clutter up the program's logic and
reduce efficiency, particularly if the tested condition occurs only in rare circumstances.

  As an example, consider a dis-write operation. Testing for a full disk after each disk write
is clearly inconvenient. On the other hand, halting the program unconditionally prevents the
running program from reacting to this error.

  Pascal solves this problem by using a compiler option that determines the program's reaction
to I/O errors. However, this is not possible in Modula-2 since disk writes are performed in a
library module not within the control of the compiler. It is evident that a system consisting
of several largely independent modules needs some way to signal error conditions.

  Exceptions serve this purpose well. We do suggest, however, that you use exceptions only if
there is no other appropriate way to handle errors. In general, their use should be confined
to the signaling of errors across module boundaries. (There are a number of predefined
exceptions in Appendix D.)

Syntax and Semantics of Exception Handling
------------------------------------------

An exception consists of three parts: the exception declaration, which defines the exception
identifier and uses the reserved word EXCEPTION; the exception handler, which is the programmed
response to the error condition; and the RAISE statement, which calls the exception.

  An advantage of exception handlin is that handlers are present statically in the program
text, near the location they are needed. In comparison to other error handling methods,
exception handlers are much clearer. They also follow the nested structure of the Modula-2
language itself.

Declaration of Exceptions
-------------------------

An exception declaration contains the reserved word EXCEPTION, followed by a list of
identifiers. Exception declarations have the following form:

 EXCEPTION <identifier list> ;

  And the following example is taken from the module Files:

 EXCEPTION EndError, StatusError, UseError, DeviceError, DiskFull;

  All of the usual scope rules of Modula-2 apply here. Exception identifiers can be exported
and imported like normal Modula-2 identifiers.

Raising Exceptions
------------------

Exceptions are raised when the program detects an error condition; for example when the module
Files has detected that the disk is full. Raising an exception will transfer control to an
exception handler that is provided by either the user or the system.

  A program may raise an exception with the reserved word RAISE, followed by the exception
identifier and optionally by a string. The RAISE statement takes the form

 RAISE <exception identifier> , <string> ;

  This next example is taken from the standard module Mathlib.

 IF x < 0.0 THEN
  RAISE ArgumentError, 'Negative argument for Sqrt';
 END;

  When an exception is raised, the system looks in the current procedure for a matching
exception handler. If none is found, the calling procedure is examined, then the caller of
that procedure, and so on, until a matching exception handler is found. This handler is then
executed, and the procedure containing the handler is exited. If no handler is found, the 
system prints the exception identifier's name and the optional message string.

  There is an alternate form of the RAISE statement that is only allowed within exception
handlers. It is the reserved word RAISE by itself, as shown in the following:

  RAISE ;

  This has the effection of passing an exception through one handler and on to the next in the
calling chain.

Exception Handlers
------------------

Exception handlers are written at the end of procedures and modules to handle exceptions issued
by a RAISE statement. The syntax is similar to the familiar CASE statement. Exception handlers
have the following form:

 EXCEPTION
   | <exception identifier list> : <statement sequence>
   | <exception identifier list> : <statement sequence>
   ...
 ELSE
   <statement sequence>
 END <procedure identifier> ;

  Exception handlers consist of the reserved word EXCEPTION, followed by any number of
exception cases. Each exception case is separated by a vertical bar, and each consists of a
list of exception identifiers followed by a colon and a statement sequence. In addition, an
ELSE part is executed if the raised exception is not in any of the exception identifier lists.

  In the following example, pretend you are running a program-controlled laser experiment and
want to guarantee that the experiment turns off in all cases.

 MODULE LaserExperiment;
 IMPORT MathLib;

  MODULE GuardedMath;
  FROM MathLib IMPORT Exp;
  EXPORT ExpG, UndefinedExp;
  EXCEPTION UndefinedExp;     (* Exception Declaration *)

  PROCEDURE ExpG(X,Y:REAL):REAL;
  BEGIN
   IF (1.E-10<X) AND (X<1.E10) THEN RETURN Y/X
   ELSE RAISE UndefinedExp    (* Signal an error *)
   END
  END ExpG;

  END GuardedMath;

 (* Procedure Declarations ommited *)

 BEGIN
  SetupExperiment;
  PerformExperiment;
                              (* Normal termination *)
  TurnOffLaser;
  ShutDownLab;
  PrintOutResults;

 EXCEPTION                    (* Exception Handler *)
  UndefinedExp: WRITELN("WARNING: Bad Math");
                TurnOffLaser;
                ShutDownLab;
                DumpProgramVars;
  ELSE
                TurnOffLaser;
                ShutDownLab;

 END LaserExperiment.

  There is one explicit exception raised in a special exponentiation routine. The exception 
handler in the main body of code has two clauses: one to catch the exception explicitly raised
in ExpG, the other to catch all other possibilities.

  If no exception handler is present for a given exception condition, the RAISE statement
writes the exception identifier and an optional message to the screen, and halts the program.
For example:

 RAISE ZeroDivision;

  would react to an error by printing the following message:

 ZeroDivision in module Division
 Press "C" for calling chain >

  If a more comprehensive error message is desired, an additional string can be included in 
the RAISE statement. The string can be a literal or any variable whose type is an array with
elements of type CHAR. The string will be printed below the exception name, like so:

 DiskFull in module MYPROG
 While processing file OUTDATA
 Press "C" for calling chain >

  A program can respond to an exception by appending a handler to the end of the program unit
where an exception may be raised. Such a program unit can be a procedure or the main program.
When an exception is raised, normal execution is suspended and the corresponding exception
handler is invoked; that is, the handler is executed instead of the rest of the program unit.

Exception Propagation
---------------------

A scheme requiring an exception handler in the program unit where the exception is raised is
really not very useful. After all, you need exceptions to signal your program that an error
has occurred in a called library module. There must be some way to propagate exceptions. If
the procedure that raises an exception does not contain a handler for it, the procedure is
aborted completely and its caller is searched for a handler.

  If the calling procedure also does not contain a handler, the search is continued in the
procedure that called the caller, and so on. This continues until a handler for the raised
exception is found, or until the main program (or a coroutine) is searched. Note that the
order in which procedures are searched for exception handlers duplicates the order in which
they are displayed in the calling chain.

  If a handler for a raised exception is found in the calling chain, it is invoked and thus
replaces the rest of the procedure containing the handler. If all statements in the handler
are executed, the procedure returns. Note that a program cannot be restarted at the point
where the exception is raised. This restriction makes the exception-handling mechanism
relatively sage. The restriction is not severe, since an exception can easily be converted
into a flag that indicates an unsuccessful operation.

  A handler for an exception can of course raise an exception itself. In this case, the
exception is always propagated to the next procedure in the calling sequence thus preventing
an infinite loop where every time an exception is handled, another is raised. To propagate the
handled exception to higher-level procedures, a handler can raise the handled exception again
by using the short form of the RAISE statement. If the following statement is found in some
exception handler, the handled exception is propagated to the calling procedure (or module):

 EXCEPTION
  EndError, DeviceError: Close(infile); RAISE
 END ReadFile;

  If a library module should signal an exception, it must first be declared with an exception
declaration. An exception declaration can be given anywhere in a program where constant,
variable, or type declarations would be legal. And like other identifiers, exceptions can be
exported and imported.

  Many of the library modules export exception identifiers that can be incorporated into 
programming error handlers. For example, the following program reads data input from the
keyboard and writes it to disk. The exception DiskFull is declared in the module Files and
raised when the disk is full (Texts is implemented with Files).

 MODULE DataWrite;
  FROM Files IMPORT DiskFull;
  FROM Texts IMPORT TEXT,OpenText,CloseText;
  FROM ComLine IMPORT PromptFor;
 VAR Value: CARDINAL;
  DataFile: TEXT;
  Str: ARRAY [0..30] OF CHAR;
 BEGIN
  Str := "Input value (99 to stop): ";
  (* Request filename and open file *)
  PromptFor("Data file name: ", DataName);
  OpenText(DataFile, DataName);
  (* Request data from keyboard and write to file *)
  WRITELN(Str);
  READ(Value);
  WHILE Value # 99 DO
   WRITE(DataFile, Value);
   WRITELN(Str);
   READ(Value);
  END;
  (* Close completed file *)
  CloseText(DataFile);
  (* If disk full, die *)
 EXCEPTION
  DiskFull: WRITELN("DISKFULL - YOU JUST LOST ALL YOUR INPUT");
 END DataWrite;




APPENDIX A - Turbo Modula-2 and Turbo Pascal
============================================


This appendix examines the differences between Turbo Pascal and Turbo Modula-2 in a detailed
manner. First, we will point out some of the features found only in Turbo Modula-2 and then
we will compare the differences in the features of both languages.

  In general, Turbo Modula-2 and Turbo Pascal are quite similar. Some features found in Turbo
Modula-2 will be more familiar to Turbo Pascal programmers than they will be to regular Pascal
programmers. This is because Turbo Pascal provides a rich set of standard procedures and useful
extensions that are defined directly in the Turbo Modula-2 language.

  Modula-2's separate compilation and library facilities provide a full and extensible set of
primitives. The differences between the language implementations range from simple items like
case sensitivity to complex issues involving type- and version-checking across compilation 
units.

  Modula-2 can be used for large program development and for expressing operating system
concepts like concurrency and interrupt handling. Rather than using Include files, Modula-2
separates programs textually into modules. Like Pascal procedures, modules can used to control
the scope of identifiers. Unlike procedures, the walls around a module are opaque in both
directions, with only explicitely defined changes in scope. This control of scope occurs in
both local (nested) and library (separately compiled) modules. In the case of a library
identifier, any identifier needed from another module must be requested. And both local and
library modules must explicitly make the identifier visible.

  Library modules can be separately compiled. Though some other languages allow separate
compilation, Modula-2 does full typ- and version-checking. This helps prevent errors that 
occur because the program is textually broken into pieces. Thus you have the same safety as
Turbo Pascal's Include files without having to recompile support procedures all the time.

  Two new low-level features found in Turbo Modula-2 are coroutines and interrupt handlers. As
described in Chapter 8, coroutines simulate concurrent processes by using their own data space
and sharing the processor.

  While some people have expressed interrupt handlers in Turbo Pascal using inline code,
Modula-2 allows interrupt handlers to be defined in a high-level manner. This is done by
initializing the machine and then having the interrupt handler install itseld at some
predetermined vector. The rest is handled by Turbo Modula-2.

What's the Difference?
----------------------

  The following overview compares the elements of Turbo Modula-2 to Turbo Pascal and should
quickly acquaint the Turbo Pascal programmer with Turbo Modula-2. (For a complete explanation
of any feature, refer to the body of this manual.)

  To start, let's consider the following Pascal and Modula-2 programs:

 PROGRAM prime( OUTPUT );                   MODULE prime;
 CONST                                      CONST
  size = 8190;                               size = 8190;
 VAR                                        VAR
  i,k,prime,count : INTEGER;                 i,k,prime,count : INTEGER;
  flags : ARRAY [0..size] OF BOOLEAN;        flags : ARRAY [0..size] OF BOOLEAN;
 BEGIN                                      BEGIN
  count := 0;                                count := 0;
  FOR i := 0 TO size DO                      FOR i := 0 TO size DO
   flags[i] := TRUE;                          flags[i] := TRUE;
                                             END;
  FOR i := 0 TO size DO BEGIN                FOR i := 0 TO size DO
   IF flags[i] THEN BEGIN                     IF flags[i] THEN
    prime := i + i + 3;                        prime := i + i + 3;
    k := i + prime;                            k := i + prime;
    WHILE k <= size DO BEGIN                   WHILE k <= size DO
     flags[k] := FALSE;                         flags[k] := FALSE;
     k := k + prime;                            k := k + prime;
    END ;                                      END ;
    count := count + 1;                        count := count + 1;
   END;                                       END;
  END;                                       END;
  WRITELN(count,' Primes');                  WRITELN(count,' Primes');
 END (* prime *).                           END prime.

Vocabulary
----------

There are minor differences in the vocabularies of the two language implementations. For the
most part, it is simple to convert a Turbo Pascal program into Turbo Modula-2.

Identifier Names
----------------
Turbo Modula-2's identifiers are written in the same manner as Pascal's. There are two major
differences: (1) Turbo Modula-2 does not allow underscores in identifier names, and (2) it is
case-sensitive. The latter has been made optional with a compiler switch. The following are
some legal and illegal Modula identifiers:

Legal           Illegal

AnotherIdent    An_Ident
n
N


Characters
----------
Character constants may either be denoted by the character enclosed in single or double quotes
or by the character's ordinal number written in octal notation and followed by the letter C.
For example:

32C     A character constant representing a Control-Z
101C    The letter A
'B'     The letter B
"C"     The letter C

Numbers
-------
The numbers of Turbo Modula-2 are a superset of those allowed in Pascal. In addition to the
integers and reals in Turbo Pascal, Turbo Modula-2 has an unsigned integer, called a CARDINAL,
and two double-precision types, an integer (LONGINT), and a real (LONGREAL).

  Like Turbo Pascal, Turbo Modula-2 allows you to specify the base and type of a constant
number. In Turbo Pascal, a hexadecimal number is written starting with a dollar sign, such as
$0F; but in Turbo Modula-2 hex numbers are written starting with a decimal digit and ending
with the letter H, such as 0FH. The various classes are Octal, Hexadecimal, Character, Real,
and Long. The following are examples of numerice constants in Turbo Modula-2:

23B     Octal cardinal          (19 decimal)
23H     Hexadecimal cardinal    (35 decimal)

  Real constants are written the same as they are in Turbo Pascal: a decimal point must be 
present. The scale factor is preceded by E. For example:

1.1414  A single-precision real approximating the square root of 2
3.02E9  A single-precision real in scientific notation

  Double-precision constants are just like real constants with a scale factor, but with a D in
place of the E. For example:

0.0D0   A double-precision real of value 0

  In the same way a C following an octal number makes a CHAR constant, an L following a integer
makes a LONGINT constant. Of course, the integer can be larger than normal integers if followed
by an L, as shown in the following:

1483236283L     A long integer over a trillion (1,483,236,283).
-1L             Internally, this long integer is 4 bytes of ones.


Strings
-------
The two differences between strings in Turbo Pascal and Turbo Modula-2 are (1) strings can be
enclosed in either single or double quotes, and (2) the quote used to enclose the string may
not appear in the string.

  In Pascal, to have a quote within a string you would write the quote twice. In Modula-2, you
may include whichever quote you are not using to enclose the string. Thus, the following
strings yield the same result:

Modula-2    Pascal

"'"         ''''
'"'         '"'

  Here are other examples of legal strings in Modula-2

 "abba"   'The language "Modula-2"'   "Peter's programs"


Set Constants
-------------
Sets in Turbo Modula-2 are substantially different than those in Turbo Pascal. In Turbo
Modula-2, sets are represented by one machine word and thus are very efficient. Tests for set
membership are much faster. However, there is one drawback: a machine word has only enough
bits to represent a set of 16 elements. Pascal programmers who are used to using SET OF CHAR
may miss it; however, there are other ways to obtain the same results.

  The syntactic differences are that sets are delimited by curly brackets instead of the square
brackets used in Pascal. A set must be preceded by its type identifier when used in expressions
otherwise it is assumed to be the predefined set type BITSET. For example:

 TYPE
  UserSet = SET OF (red, green, blue);
 CONST
  hibit = {7};
  CurrentColor = UserSet{green};


Comments
--------
In Turbo Pascal, comments can only be nested one level deep by using one of the two forms
within the other. In Turbo Modula-2, the only form of comment uses the delimiters (* and *).
(As previously shown, the curly braces, { and }, are used to denote sets.) In contrast to
Turbo Pascal, Turbo Modula-2 comments may be nested to any depth. This is especially useful
for debugging programs. For example:

 c := 2.997925E8; (* the speed of light in meters per second *)
 (*D WriteReal(c); (* printout for debugging *) D*)


Declarations
------------
In contrast to standard Pascal, Turbo Modula-2's order of declarations (like Turbo Pascal's)
is not fixed. Constant, type, variable, and procedure declarations can be written in any order.
This gives the programmer more freedom to group related items together. Of course, every
declaration section must be preceded by the appropriate CONST, TYPE, VAR, or PROCEDURE symbol.

Constant Declarations

There are two major differences between Turbo Pascal's constants and Turbo Modula-2's:
(1) Turbo Modula-2 allows constant expressions in declarations.
(2) There is no equivalent for Turbo Pascal's typed constants (which are actually pre-
initialized variables).

  Turbo Modula-2's constant expressions may be used anyplace Pascal allows only constants.
Constant expressions consist of constants connected by the usual operators. Some examples of
declarations follow (constant expressions are seen in lines 2, 5 and 8):

 CONST
  PiBytwo = 3.141592 / 2.0;
  version = "1.6 last changes: Oct 84";
  mask = {0..3,8};
  Truth = NOT FALSE;
  Size = 1000;
 TYPE
  a = ARRAY [0..Size-1] OF CHAR;

  Turbo Pascal's typed constants can be simulated with normal Turbo Modula-2 variables and the
initialization part of modules. The only difference is that the values are initialized at
runtime instead of at load-time.

Type Declarations

Turbo Modula-2 has all of the types offered by Turbo Pascal, whether defined directly as
standard identifiers or as library types. In addition, Turbo Modula-2 has procedure types.
In defining types in Turbo Modula-2, a constant expression may be used anywhere a constant is
used to define a type in Pascal.

  Standard types in Turbo Modula-2 are CHAR, BOOLEAN, BITSET, INTEGER, CARDINAL, REAL, LONGINT,
LONGREAL, and PROC. Of these, INTEGER, BOOLEAN, CHAR, and REAL are used exactly as they are in
Turbo Pascal. We have alreadu mentioned the additional numeric types, CARDINAL, LONGINT, and
LONGREAL; the remaining types, BITSET and PROC, will be explained shortly. The user-defined
types of both languages are similar, but have slight differences.

  Subrange and enumeration types are the same for both languages except Turbo Modula-2 encloses
in square brackets ([]) the values defining a subrange. For example:

 TYPE
  bitnumber = [0..wordlength-1];
  smallint  = [0..255];

  The presence of the types INTEGER and CARDINAL causes a slight ambiguity when defining a
subrance. In the previous example, it's not known if the base type of the subrange is INTEGER
or CARDINAL. This problem is resolved by the convention that the base type is assumed to be
CARDINAL if the lower bound is not negative; otherwise, it is INTEGER. You may override this
convention by explicitly specifying the base type as follows:

 TYPE
  ismall = INTEGER[0..255];


Arrays
------
As with subranges, the syntax of an array is slightly different in each language. When the
bounds of an array are specified by a subrange, brackets are not needed; for example:

 TYPE
  color = (brown,purple,orange);
  c = ARRAY color OF CHAR;
  a = ARRAY [0..9],[0..9] OF REAL;
  charkind = ARRAY OF CHAR(letter,digit,special,illegal);

Records
-------
In Turbo Modula-2, records without variant parts are identical to those of Turbo Pascal.
Turbo Modula-2 variant parts have a somewhat different syntax. If the name of the tag field
is omitted, the colon and the type must still be written. The vertical bar serves to separate
cases. Like Turbo Pascal, label ranges (for example, 0..5) and an optional ELSE part may be
used. More than one variant part is allowed and it need not be written at the end of the record
as in Turbo Pascal. Variant parts in Turbo Modula-2 must have an END statement; for example:

 complex = RECORD x, y : REAL END ;

 sneaky = RECORD
           CASE : BOOLEAN OF
            FALSE : c : CARDINAL            |
            TRUE  : p : POINTER TO CARDINAL |
           END
          END ;

 demo = RECORD
         a, b : CARDINAL;
         x : REAL;
         CASE t1 : CARDINAL OF
          0..3,7  : f1,f2 : File                 |
          4,6     : name  : ARRAY [0..7] OF CHAR |
         ELSE
                    link  : POINTER TO sneaky
         END ;
         d, e : BOOLEAN ;
         CASE c : color OF
          red, blue:          |
          green    : g : date |
         END ;
         last : BOOLEAN ;
        END ;


Procedure Types
---------------
Procedure types are new to Turbo Pascal programmers. They can be used to define the interface
of a procedure that is passed to some other procedure as a parameter. This is useful for
allowing one data access routine to perform many different functions on the data.

  For example, you may pass a tree-traversal procedure a procedure parameter that prints the
node, uses the node for a calculation, or performs some other function on the nodes of the
tree. The point is that each of these operations have the same interface, which can be defined
globally and exported.

  The type PROC is a predefined procedure type with no parameters. Variables of this type may
receive assignments from procedures declared as

 PROCEDURE Foo;
 BEGIN
  (* Statements *)
 END Foo;

  Procedure variables are defined withe the reserved word PROCEDURE, followed by a formal type
list. In contrast to normal parameter lists, the names of the parameters are not given. Types
are separated by commas and may be preceded by a VAR to indicate variable parameters. Function
procedures declare a result type (see the section, `Function Procedures').

  Variables of a procedure type may assume as their values procedures whose formal parameter
list is compatible with the formal type list of the procedure type. However, procedures local
to another procedure and standard procedures may not be assigned to procedure variables. Note
that arithmetice and file-handling procedures (for example, Sin and Open) are not standard
procedures in Turbo Modula-2. They are library procedures and can be assigned to procedure
variables of the correct type. For example:

 MODULE ProcedureVars;
 FROM Texts IMPORT TEXT;
 TYPE
  RealFunc = PROCEDURE (REAL): REAL;
  TextDriver = PROCEDURE(VAR Text, CHAR);
 VAR
  MyExp: RealFunc;
  MyWriteChar: TextDriver;
  MyClearScreen: PROC;  (* Predefined parameterless procedure *)
 
 PROCEDURE MyExponentiation(r:REAL): REAL;
 BEGIN
  (* Statements *)
 END MyExponentiation.

 PROCEDURE MyWriteCharacter(VAR t: TEXT; ch: CHAR);
 BEGIN
  (* Statements *)
 END MyClearTheScreen;

 PROCEDURE ExecuteP(p:PROC);
 BEGIN  p;
 END ExecuteP;

 BEGIN  (* Assign procedures to the procedure variables *)
  MyExp := MyExponentiation;
  MyWriteChar := MyWriteCharacter;
  MyClearScreen := MyClearTheScreen;
  (* Execute procedure variables *)
  MyClearScreen;
  WRITE(MyExp(29.0));
  MyWriteChar(output, "A");
  ExecuteP(MyClearScreen);
END ProcedureVars.


Variable Declarations
---------------------

  Turbo Modula-2's variable declarations are identical to those of Pascal: A list of varialble
identifiers are given (separated by commas), along with a colon and the variable's type.
For example:

 i, j, k   : INTEGER;
 printer   : textwriter;

  Like Turbo Pascal, Turbo Modula-2 offers a facility to specify the address of a variable. This
must be considered a low-level facility and must be used with care. The address is specified in
brackets after the variable identifier. Unlink Turbo Pascal, Turbo Modula-2 restricts absolute
variables from assuming dynamic values. Thus when a Turbo Pascal program uses a local variable
"absoluted" with a parameter to the procedure, the Turbo Modula-2 equivalent would simply be
pointer assignments that may require type coercion. Variables in Turbo Modula-2 are made
absolute as shown here.

 maskregister [0FFCDH]: BITSET;


Procedure Declarations
----------------------

Procedures in both languages are declared in much the same way. Unlike Turbo Pascal but available
in other Pascals, Turbo Modula-2's procedures and functions may be passed as parameters. The
parameter must be declared as an already defined procedure type (shown in the previous section,
"Variable Declarations").


Open Array Parameters
---------------------

Open array parameters allow arrays declared of different length to be passed to the same
procedure. In Turbo Pascal, this can be done only with string parameters, and only when the
V compiler option is turned on. In Turbo Modula-2, there is a provision for open arrays of any
type and there is a mechanism to dynamically obtain the upper bound of open array parameters.

  Within the procedure, the lowest array element always has an index of zero. The index of the
highest array element can be obtained as HIGH(a), `a' being specified as ARRAY OF <some type>.
For example:

 PROCEDURE writevector(v : ARRAY OF REAL);
 VAR
  i : CARDINAL;
 BEGIN
  FOR i := 0 TO HIGH(v) DO WRITE(v[i]) END
 END writevector;


Untyped Parameters
------------------

Turbo Pascal allows you to skip type-checking with untyped parameters by simply leaving off
the type specification. This is useful for writing generic procedures. Of course, Turbo Modula-2
also allows this with an explicit declaration that uses the SYSTEM type WORD. Turbo Modula-2
goes one step further by allowing you to dynamically determine the size of the object passed
with the standard procedures SIZE and HIGH. This is shown in the following example:

 MODULE Untyped;

 PROCEDURE foo(object: ARRAY OF WORD);
 BEGIN
  WRITELN(SIZE(object), HIGH(object));
 END foo;

 VAR
  c: CARDINAL;
  r: REAL;
 BEGIN
  foo(c);
  foo(r);
 END Untyped.

  The first call to the procedure foo results in the output of 2 and 0. Thus, the procedure
knows the passed is 2 bytes and the highest index into the array of words is 0. During the
second call, this procedure outputs a 4 and 1, indicating the object is 4 bytes and occupies
positions 0 and 1 of the word array.


Function Procedures
-------------------

In Turbo Modula-2, FUNCTION is no longer a reserved word; function declarations differ from
procedure declarations only by the indication of a result type. The following is an example of
a function declaration that finds the length of a string:

 PROCEDURE len(s: ARRAY OF CHAR): CARDINAL;
 (* return length of string s *)
 VAR
  i : CARDINAL;
 BEGIN
  i := 0;
  WHILE (i <= HIGH(s)) & (s[i] # 0C) DO i := i+1 END ;
  RETURN i
 END len;


Expressions
-----------

Turbo Modula-2 expressions are very similar to those of Turbo Pascal. The usual operators,
+, -, *, /, DIV, and MOD, are available for operands of type INTEGER, CARDINAL, and REAL,
(DIV and MOD apply to INTEGER and CARDINAL, / applies to REAL). Of course, those operators
applicalbe to INTEGER also work on LONGINT, and the same is true for REAL and LONGREAL.

  There are, however, no implicit conversions. The following example would therefore be legal
in Turbo Pascal but illegal in Turbo Modula-2, because REAL and CARDINAL are not compatible:

  x := 1.0 + 1;

  The logical operators AND (also written &), OR, and NOT (also written ~), are available. If
the first operand of an AND evaluates to FALSE, the second is not evaluated. Similarly, the
second operanf of an OR is not evaluated if the first one is TRUE. This rule sometimes shortens
programs by eliminating a Boolean flag and a GOTO statement. For example:

 WHILE (I # 0) AND (s[I]>0) DO
   (* Something *)
 END ;

  would have to be translated to the following Pascal statement if s is not defined for I equal
to 0:

 while I <> 0 do begin
  if s[I] <= 0 then goto endwhile;
   (* Something *)
 end ;
 endwhile:

Set Operators
-------------
The major benefit of Turbo Modula-2 sets is the ability to treat bits in a word as elements in
a set. This makes bit manipulation very easy and defines it directly in the language instead of
as an extension as in Turbo Pascal.

  The type BITSET is a special predefined set type. It is declared as

 TYPE
  BITSET = SET OF [0..wordlength-1];

  where wordlength is the word length of the computer, which is 16 for Turbo Modula-2.

  Since Turbo Modula-2 sets only take one word, the operations defined for sets can be viewed
as equivalent to Turbo Pascal bitwise operations. Thus Turbo Modula-2 set operators can be
viewed as abstract set operations or low-level bit-wise operations as seen in Turbo Pascal
equivalents.

Operation               Modula Symbol   Pascal Symbol

Union                   +               OR
Difference              -               XOR and the AND
Intersection            *               AND
Symmetric Difference    /               XOR

  In terms of set operations available in Turbo Pascal, only / is new. It is called symmetric
set difference and is an exclusive OR. The resulting set contains all elements that are in
either the first set operand or the second, but not in both. 
The following is an example using sets:

 MODULE ExampleSet;
 TYPE
  colors = (Red,White,Blue,Orange,Purple,Black,Yellow,Green,Cyan);
  flagColors = SET OF colors;
 CONST
  frenchFlag = flagColors{Red,White};
 VAR
  currentColors: flagColors;
 BEGIN
  currentColors := flagColors{Red};
  currentColors := currentsColors + flagColors{White};
  IF currentColors=frenchFlag THEN
   WRITELN('Viva la France !');
  END ;
 END ExampleSet;

  Familiar to Turbo Pascal programmers is Turbo Modula-2's alternate use for the preceding
logical operators (AND, OR, XOR); in Turbo Pascal, these are also bitwise operators. As previously
shown, Turbo Modula-2 has set operators that double as bitwise operators. The only bitwise
operators defined in Turbo Pascal and not in Turbo Modula-2 are the shl and shr operators.
However this is not a problem because Turbo Modula-2 translates multiplication and division by 2
into machine-language shifts in the appropriate direction. Thus, we have the following equivalents
for the integer variable I:

  Modula        Pascal

  I * 2         I shl 1
  I * 2 * 2     I shl 2
  I * 256       I shl 8
  I DIV 16      I shr 4

  Turbo Modula-2 and Turbo Pascal use the same relational operators. The only difference is 
that Turbo Modula-2 provides an additional inequality operator, the pound sign (#), which has
the same effect as <>. Both symbols are allowed in Turbo Modula-2.

  Operands in expressions in Turbo Modula-2 are very similar to those found in Pascal. The
familiar operations of indexing, field selection, dereferencing, and function invocation are
available. One difference is seen in expressions that include parameterless function calls.
This helps distinguish functino identifiers from variable and constant identifiers.

  The following are examples of expressions in Turbo Modula-2:

  c + b*3                   Integer or cardinal expression
  list IN options           Boolean expression
  sum + a[i,k]*a[k,j]       Numeric expression using arrays
  (ch >= "A") & (ch <= "Z") Boolean expression with relations
  s * {0..3}                Set expression
  Exp(Random( ))            Real expression with nested function calls


Statements
----------

Like Pascal, the most elementary statement in Turbo Modula-2 is the assignment statement. It
is stricter in Turbo Modula-2 than in Turbo Pascal in that no implicit type conversions are
made. This means you may not assign an integer expression to a real variable, as is allowed in
Turbo Pascal. Of course, Turbo Modula-2 provides a mechanism to do this with explicit type-
transfer functions; thus we have the following equalities (where x is a real and i is an integer):

  Modula                        Pascal

  x := FLOAT(i)                 x := i;
  i := TRUNC(x * FLOAT(i));     i := trunc(x * i);

  Turbo Modula-2's structured statements have a more modern syntax that does away with Turbo
Pascal's compound statement (begin ... end). Where Pascal requires the compound statement, 
Turbo Modula-2 allows a statement sequence to be terminated by an END statement.

Procedure Calls
The procedure call statement remains essentially unaltered in Turbo Modula-2. If a procedure
has no parameters, empty parentheses are allowed but not required, as in function procedures.

Looping Statements
Turbo Modula-2's WHILE and REPEAT statements are essentially the same as Turbo Pascal's.

  Turbo Modula-2 has an EXIT statement, but is is used to terminate the LOOP statement. The
LOOP statement is the same as a Turbo Pascal's repeat until FALSE or while TRUE do begin end,
except that instead of using a GOTO to exit the endless loop, Turbo Modula-2 uses the explicit
EXIT statement. EXIT causes control to pass to the statement directly after the END that matches
the LOOP statement.

  The FOR statement has been slightly changed. A step value may now be given using a BY clause
(default is +1 if the BY part is left out). The step value must be a constant expression. The
Turbo Pascal downto symbol is no longer used. You now simply specify a step value of -1.
For example:

 FOR i := 0 size DO
  flags[i] := TRUE                      (* Notice the explicit END *)
 END ;
 FOR i := n-2 TO 2 BY -1 DO             (* Pascal's DOWNTO *)
  s[i] := (b[i] - a2[i]*s[i+1])/a1[i];  (* Any number of statements *)
  j := j + i                            (* between DO and END *)
 END ;

CASE Statements
Turbo Modula-2's CASE statement has a different syntax than Pascal's. The vertical bar | is
used to separate cases, thus eliminating the need for begin end in the statement part of the
case statement. Like Turbo Pascal, Turbo Modula-2 allows ranges of values for CASE labels (like
"A".."Z") and an optional ELSE part. For example:

CASE ch OF
 | "A".."Z,"a".."z"         : chartype := letter
 | "0".."9"                 : chartype := digit
 | " ",'"',"#","&".."/",
 ":"..">","[".."^","{".."~" : chartype := special
 |
 ELSE WRITELN('illegal character'); chartype := illegal
END ;

  Note that the first and last vertical bars in this example are optional.

WITH Statements
The WITH statement has remained essentially unchanged. While in Turbo Pascal a list of record
variables is allowed after WITH, Turbo Modula-2 makes you nest WITH statements to achieve the
same effect. For example:

 WITH p^ DO     (* in Pascal, only one WITH would have been used *)
  WITH valu^ DO
   typ := reel; rval := nxrval;
  END;
  link := head
 END ;

RETURN Statements
There are two reserved words that take the place of Turbo Pascal's goto statement: the EXIT
statement (already discussed) and the RETURN statement. The RETURN statement serves to terminate
procedures the same way as the exit statement in Turbo Pascal. In addition, it is used to return
function results instead of an assignment to the Pascal function identifier.


Standard Procedures in Turbo Modula-2
-------------------------------------

Several standard functions and procedures found in Turbo Pascal are no longer directly 
available in Turbo Modula-2: Some standard procedures have been added and some have been left
to be implemented in library modules. Only the most important and commonly used standard 
procedures are still within the language.

  Mathematical functions like Sqrt, Sin, Exp, and so on, are no longer standard functions. They
must now be imported from the module MathLib (see Chapter 11). File-handling procedures must
also be imported from the appropriate library modules (Files, Texts, or InOut).

  The Turbo Pascal functions pred and succ can be replaced by the procedures INC and DEC.
These procedures accept one argument of any scalar type and one count argument that determines
the size of the increment or decrement.
  Thus, Turbo Pascal statements that look like the following:

 i := i + 1;
 color := pred(Green);

  will look like this in Turbo Modula-2:

 INC(i);
 DEC(color);

  NEW and DISPOSE still exist and are translated by the compiler into calls to procedures
ALLOCATE and DEALLOCATE, which must be imported from the module STORAGE but may also be 
redefined within the user program. In contrast to Pascal, a FLOAT function exists in Turbo
Modula-2. You may be surprised to find that there is no ROUND or EVEN function; instead, use
Entier(Value + 0.5) for negative numbers and TRUNC(Value + 0.5) for positive numbers.

  Tables A-1 through A-3 show which identifiers remain defined within the language. If you
don't find what you're looking for here, try Chapter 12, "Turbo Modula-2 Reference Directory".

Table A-1 - Standard Modula-2 Functions

ABS(x)          Returns absolute value of x; result type is the same as argument type.

CAP(c)          Return argument and result type are of type CHAR, returns the capital letter
                corresponding to c.

CHR(x)          Returns the character with ordinal number x.

FLOAT(x)        Converts value x of type CARDINAL to type REAL.

HIGH(a)         Returns high index bound of array a.

MAX(T)          Returns the largest element of the argument type.
                T is CARDINAL, INTEGER, BOOLEAN, CHAR, REAL, LONGREAL, LONGINT, any enumeration
                or scalar type.

MIN(T)          Returns the smallest element of type T.

ODD(x)          Returns TRUE if x is odd; otherwise it returns FALSE.

ORD(x)          Returns the ordinal value of x, where x is of type BOOLEAN, CHAR, INTEGER,
                CARDINAL, or every enumeration type.

SIZE(T)         Returns the storage requirements of type T in bytes.

SIZE(x)         Returns the storage requirements of variable x in bytes.

TRUNC(x)        Returns CARDINAL result; x of type REAL truncated to integral part.

VAL(T,x)        Returns the value of type T, which has ordinal number x. T is BOOLEAN,
                CHAR, INTEGER, CARDINAL or every enumeration type.


Table A-2. Additional Functions offered by Turbo Modula-2

LONG(x)         Converts its argument to LONGINT

INT(x)          Converts its argument to INTEGER

CARD(x)         Converts its argument to CARDINAL

FLOAT(x)        Converts its argument to REAL

DOUBLE(x)       Converts its argument to LONGREAL

Note: These functions only work on numeric types.


Table A-3. Standard Procedures in Turbo Modula-2

DEC(x)          x := x - 1

DEC(x,n)        x := x - n

EXCL(s,i)       s := s - {i}

HALT            Terminates program execution

INC(x)          x := x + 1

INC(x,n)        x := x + n

INCL(s,i)       s := s + {i}

  Note that type identifiers may be used like function identifiers denoting so-called type-
transfer functions. (This is considered a low-level facility and is discussed in Chapter 8.)


============================================================================================