# CLixon CLI

* [CLIgen](#cligen)
* [Tricks - eg for large specs](tricks)

## CLIgen

The Clixon CLI uses [CLIgen](http://github.com/olofhagsand/cligen) best described by the [CLIgen tutorial](https://github.com/olofhagsand/cligen/blob/master/cligen_tutorial.pdf). The [example](example) is also helpful.

Clixon adds some features and structure to CLIgen which include:
* A plugin framework for both textual CLI specifications(.cli) and object files (.so)
* Object files contains compiled C functions referenced by callbacks in the CLI specification. For example, in the cli spec command: `a,fn()`, `fn` must exist oin the object file as a C function.
  * A CLI API struct is given in the plugin. See [example](example/README.md#plugins).
* A CLI specification file is enhanced with the following CLIgen variables:
  * `CLICON_MODE`: A colon-separated list of CLIgen `modes`. The CLI spec in the file are added to _all_ modes specified in the list.
  * `CLICON_PROMPT`: A string describing the CLI prompt using a very simple format with: `%H`, `%U` and `%T`.
  * `CLICON_PLUGIN`: the name of the object file containing callbacks in this file.

* Clixon generates a command syntax from the Yang specification that can be refernced as `@datamodel`. This is useful if you do not want to hand-craft CLI syntax for configuration syntax. Example:
  ```
  set    @datamodel, cli_set();
  merge  @datamodel, cli_merge();
  create @datamodel, cli_create();
  show   @datamodel, cli_show_auto("running", "xml");		   
  ```
  The commands (eg `cli_set`) will be called with the first argument an api-path to the referenced object.
* The CLIgen `treename` syntax does not work.

## Tricks

CLIgen is designed to handle large specifications in runtime, but it may be
difficult to handle large specifications from a design perspective.

Here are some techniques and hints on how to reduce the complexity of large CLI specs:

### Sub-modes
The `CLICON_MODE` can be used to add the same syntax in multiple modes. For example, if you have major modes `configure`and `operation` and a set of commands that should be in both, you can add a sub-mode that will appear in both configure and operation mode.
  ```
  CLICON_MODE="configure:operation";
  show("Show") routing("routing");
  ```
  Note that CLI command trees are _merged_ so that show commands in other files are shown together. Thus, for example:
  ```
  CLICON_MODE="operation:files";
  show("Show") files("files");
  ```
  will result in both commands in the operation mode (not the others):
  ```
  cli> show <TAB>
    routing      files
  ```
  
### Sub-trees

You can also use sub-trees and the the tree operator `@`. Every mode gets assigned a tree which can be referenced as `@name`. This tree can be either on the top-level or as a sub-tree. For example, create a specific sub-tree that is used as sub-trees in other modes:
  ```
  CLICON_MODE="subtree";
  subcommand{
    a, a();
    b, b();
  }
  ```
  then access that subtree from other modes:
  ```
  CLICON_MODE="configure";
  main @subtree;
  other @subtree,c();
  ```
  The configure mode will now use the same subtree in two different commands. Additionally, in the `other` command, the callbacks will be overwritten by `c`. That is, if `other a`, or `other b` is called, callback function `c`will be invoked.
  
### C-preprocessor

You can also add the C preprocessor as a first step. You can then define macros, include files, etc. Here is an example of a Makefile using cpp:
  ```
   C_CPP    = clispec_example1.cpp clispec_example2.cpp
   C_CLI    = $(C_CPP:.cpp=.cli
   CLIS     = $(C_CLI)
   all:     $(CLIS)
   %.cli : %.cpp
        $(CPP) -P -x assembler-with-cpp $(INCLUDES) -o $@ $<
  ```
