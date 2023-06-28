# Clixon CLI

* [CLIgen](#cligen)
* [Command history](#history)
* [Large spec designs](#large-specs)
* [Output pipes](#output-pipes)

## CLIgen

The Clixon CLI uses [CLIgen](http://github.com/clicon/cligen) best described by the [CLIgen tutorial](https://github.com/clicon/cligen/blob/master/cligen_tutorial.pdf). The [example](example) is also helpful.

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

## History

Clixon CLI supports persistent command history. There are two CLI history related configuration options: `CLICON_CLI_HIST_FILE` with default value `~/.clixon_cli_history` and `CLICON_CLI_HIST_SIZE` with default value 300.

The design is similar to bash history but is simpler in some respects:
   * The CLI loads/saves its complete history to a file on entry and exit, respectively
   * The size (number of lines) of the file is the same as the history in memory
   * Only the latest session dumping its history will survive (bash merges multiple session history).

Further, tilde-expansion is supported and if history files are not found or lack appropriate access will not cause an exit but will be logged at debug level

## Large specs

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

## Output pipes

This section describes implementation aspects of Clixon output pipes.

Output pipes resemble UNIX shell pipes and are useful to filter or modify CLI output. Example:
  ```
  cli> show config | grep parameter
    <parameter>5</parameter>
    <parameter>x</parameter>
  cli>
  ```

Clixon and CLIgen implements a limited variant of output pipes using a set of mechanisms, as follows:

* Pipe trees, name starts with vertical bar
* Pipe functions, marked with flag
* Explicit pipe reference, use tree reference mechanism with appended function
* Default pipe reference, dynamic expansion of parse-tree
* Callback evaluation

Note that `cligen_output` must be used for all output to use output pipes. This is already true for scrolling.

Further, multiple pipe functions are not (yet) supported, such as: `fn | tail | count`. There are no fundamental obstacles to implement them.

### Pipe trees

Clixon uses the CLIgen `tree` mechanism to specify a set of output
pipes. A pipe tree is similar to other trees, but is distinguished
using a vertical bar as the first character in its name.

For example, the name of a pipe tree could be `|mypipe` and a reference to such a pipe would be: `@|mypipe`.

A pipetree is declared in Clixon assigning the `CLICON_MODE` variable. The tree itself usually starts with the escaped vertical bar character (but could be something else), followed by a set of pipe functions. Example:
```
  CLICON_MODE="|mypipe";
  \| { 
     grep <arg:rest>, grep_fn("grep -e", "arg");
     tail, tail_fn();
  }
```

The CLIgen method uses the treename assignment instead, but is otherwise similar:
```
  treename="|mypipe";
```

Callbacks referenced in a pipe tree, such as `grep_fn`, are marked
with a `CC_FLAGS_PIPE_FUNCTION` flag, to distingusih them from regular
callbacks. All callbacks in a pipe tree are marked as pipe
functions. This is done when parsing (or just after). Clixon and
CLIgen does it slightly different:
* CLIgen: If the "active" tree is a pipe-tree (starts with '|') then a parsed callback is a pipe function
* Clixon: After parsing, if the 'mode' is a pipe-tree, the  traverse all callbacks and mark them

### Pipe functions

The pipe callback functions example, are called with the same arguments as regular CLIgen callbacks
```
  int tail_fn(cligen_handle h, cvec *cvv, cvec *argv)
```
where `cvv` is the command line and `argv` are the arguments in the call.

However, the difference is that a pipe function is expected to receive
input on stdin and produce output to stdout.

This can be done by making an `exec` call to a UNIX command, as follows:
```
   execl("/usr/bin/tail", (char *) NULL);
```

Another way to write a pipe function is just by using stdin and stdout directly, without an exec.

The clixon system itself arranges the input and output to be
redirected properly, if the pipe function is a part of a pipe tree as described below.

### Explicit pipe references

A straightforward way to reference a pipe tree is by using an explicit pipe-tree reference as follows:
```
  set {     
      @|mypipe, regular_cb();
  }
```
Note that the `regular_cb()` is stated as an argument to the mypipe reference. This means it will be preended to each callback in 'mypipe'.

For example, in the following CLI call:
```
  cli> set | tail
```
Two callbacks will be evaluated as follows:
```
  regular_cb() | tail_fn()
```
where the stdout of `regular_cb()` is redirected to the stdin of `tail_fn()`.

If a call without pipe is wanted, the CLI explicit reference can be extended as follows:
```
  set, regular_cb(); {
      @|mypipe, regular_cb();
  }
```

### Default pipe references

Instead of explicitly stating a pipe tree after each command, it is
possible to make a default pipe-tree rule, which uses dynamic expansion to add pipe-trees automatically.

In Clixon:
```
  CLICON_PIPETREE="|mypipe"; # in Clixon
  pipetree="|mypipe";        # in CLIgen
```

This autoamtically expands each terminal command into a pipe-tree reference in a dynamic way. For example, assume the command `set, regular_cb();` is specified and a user types `set `.

This expands the syntax by adding the `@|mypipe, regular_cb()` which is in turn expanded to:
```
  set, regular_cb(); {
     \| { 
        grep <arg:rest>, grep_fn("grep -e", "arg");
        tail, tail_fn();
     }
  }
```

### Callback evaluation

When a callback is evaluated, a pipe function, if present, is run in a forked sub-process and a
'pipe-socket' is registered as input to that process.

Then, the regular callback is called. When the callback calls `cligen_output()`, the output is redirected to the pipe-socket (sock) to the pipe-function, then back to `cligen_output_basic()`,  as shown in the following sketch:
```
   regular_cb() --> cligen_output() --> (sock) --> tail_fn() --> (sock) --> cligen_output_basic()
```

The `cligen_output_basic()` makes no redirection to avoid recursion.

### Discussion

The explicit syntax may seem counterintuitive, since the pipe-tree reference is made *before* the original call: `@|mypipe, regular_cb()`.

It would be nicer to place the pipe-tree reference *after* the original call, something like:
```
regular_cb() |mypipe;
```

Further, the default pipe references rely on a statement (`pipetree=`
or `CLICON_PIPETREE=`) in the *top-level* tree. This means that any
different setting in a referenced tree is not significant.

It can be discussed whether this is good or bad. The advantage is that
it is easy to make a default statement in a single place. It could be
a lot of work to find out which sub-trees are referenced and change
them all.


