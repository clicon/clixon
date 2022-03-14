# Startup and upgrading

  * [Background](#background)
  * [Modes](#modes)
  * [Startup configuration](#startup-configuration)
  * [Module-state](#module-state)
  * [Upgrade callback](#upgrade-callback)
  * [Extra XML](#extra-xml)
  * [Startup status](#startup-status)
  * [Failsafe mode](#failsafe-mode)
  * [Repair](#repair)
  * [Automatic upgrades](#automatic-upgrades)
  * [Flowcharts](#flowcharts)
  * [Thanks](#thanks)
  * [References](#references)

NOTE: Outdated docs, see: https://clixon-docs.readthedocs.io for updated docs

## Background

This document describes the configuration startup mechanism of the Clixon backend. It describes the mechanism of Clixon version 3.10 which supports the following features:
* Loading of a "startup" XML or JSON configuration
* Loading of "extra" XML.
* Detection of in-compatible XML and Yang models in the startup configuration.
* An upgrade callback when in-compatible XML is encountered
* A "failsafe" mode allowing a user to repair the startup on errors or failed validation.

Notes on this document:
* "database" and "datastore" are used interchangeably for the same XML or JSON file storing a configuration.
* For some scenarios, such a the "running" startup mode, a "temporary" datastore is used (called tmp_db). This file may have to be accessed out-of-band in failure scenarios.

## Modes

Clixon by default supports the Netconf `startup` feature. But a clixon
system nevertheless can be started in four different ways, starting
from the `startup` datastore is mainly only an option on reboot of a
system.

When the Clixon backend starts, it can start in one of four modes:
* `startup`: The configuration is loaded from a persistent `startup` datastore. The XML is loaded, parsed, validated and committed into the running database.
* `running`: Similar to `startup`, but instead the `running` datastore is used as a persistent database. The system copies the original running-db to a temporary store(tmp_db), and commits that temporary datastore into the (new) running datastore.
* `none`: No data stores are touched - the system starts and loads existing running datastore without validation or commits.
* `init`: Similar to `none`, but the running database is cleared before loading

`Startup` targets usecases where running db may be in memory and a
separate persistent storage (such as flash) is available. `Running` is
for usecases when the running db is located in persistent. The `none`
and `init` modes are mostly for debugging, or restart at crashes or updates.

## Startup configuration

When the backend daemon is started in `startup` mode, the system loads
the `startup` database.

The `running` mode is similar, the only difference is that the running
database is copied into a temporary database which then acts as the
startup store.

When loading the startup/tmp configuration, the following actions are performed by the system:

* It is checked for parse errors,
* the yang model-state is detected (if present)
* the XML is validated against the Yang models loaded in the backend (NB: may be different from the model-state).

If yang-models do not match, an `upgrade` callback is made.

If any errors are detected, the backend enters a `failsafe` mode.

## Module-state

Clixon has the ability to store Yang module-state information according to
RFC7895 in the datastores. Including yang module-state in the
datastores is enabled by the following entry in the Clixon
configuration:
```
   <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
```

If the datastore does not contain module-state info, no detection of
incompatible XML is made, and the upgrade feature described in
this section will not occur.

A backend does not perform detection of mismatching XML/Yang if:
1. The datastore was saved in a pre-3.10 system 
2. `CLICON_XMLDB_MODSTATE` was not enabled when saving the file
3. The backend configuration does not have `CLICON_XMLDB_MODSTATE` enabled.

Note that the module-state detection is independent of the other steps
of the startup operation: syntax errors, validation checks, failsafe mode, etc,
are still made, even though module-state detection does not occur.

Note also that a 3.10 Clixon system with `CLICON_XMLDB_MODSTATE` disabled
will silently ignore the module state.

Example of a (simplified) datastore with Yang module-state:
```
<config>
   <a1 xmlns="urn:example:a">some text</a1>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:a</namespace>
      </module>
   </modules-state>
</config>
```

## Upgrade callback

This section describes how a user can write upgrade callbacks for data
modeled by outdated Yang models. The scenario is a Clixon system with
a set of current yang models that loads a datastore with old or even
obsolete data.

Note that this feature is only available if
[module-state](#module-state) in the datastore is enabled.

If the module-state of the startup configuration does not match the
module-state of the backend daemon, a set of _upgrade_ callbacks are
made. This allows a user to program upgrade funtions in the backend
plugins to automatically upgrade the XML to the current version.

Clixon also has an experimental [automatic upgrading method](#automatic-upgrades) based on Yang changelogs covered in a separate chapter.

A user registers upgrade callbacks based on module and revision
ranges. A user can register many callbacks, or choose wildcards.
When an upgrade occurs, the callbacks will be called if they match the
module and revision ranges registered.

Different strategies can be used for upgrade functions. One
coarse-grained method is to register a single callback to handle all
modules and all revisions. 

A fine-grained method is to register a separate _stepwise_ upgrade
callback per module and revision range that will be called in a series.

### Registering a callback

A user registers upgrade callbacks in the backend `clixon_plugin_init()` function. The signature of upgrade callback is as follows:
```
  upgrade_callback_register(h, cb, namespace, from, revision, arg);
```
where:
* `h` is the Clicon handle,
* `cb` is the name of the callback function,
* `namespace` defines a Yang module. NULL denotes all modules. Note that module `name` is not used (XML uses namespace, whereas JSON uses name, XML is more common).
* `from` is a revision date indicated an optional start date of the upgrade. This allows for defining a partial upgrade. It can also be `0` to denote any version.
* `revision` is the revision date "to" where the upgrade is made. It is either the same revision as the Clixon system module, or an older version. In the latter case, you can provide another upgrade callback to the most recent revision. 
* `arg` is a user defined argument which can be passed to the callback.

One example of registering a "catch-all" upgrade: 
```
   upgrade_callback_register(h, xml_changelog_upgrade, NULL, 0, 0, NULL);
```

Another example are fine-grained stepwise upgrades of a single module [upgrade example](#example-upgrade):
```
   upgrade_callback_register(h, upgrade_2016, "urn:example:interfaces",
                             20140508, 20160101, NULL);
   upgrade_callback_register(h, upgrade_2018, "urn:example:interfaces",
                             20160101, 20180220, NULL);
```
```
   20140508       20160101       20180220
------+--------------+--------------+-------->
        upgrade_2016   upgrade_2018
```
In the latter case, the first callback upgrades
from revision 2014-05-08 to 2016-01-01; while the second makes upgrades from
2016-01-01 to 2018-02-20. These are run in series.

### Upgrade callback

When Clixon loads a startup datastore with outdated modules, the matching
upgrade callbacks will be called.

Note the following:
* Upgrade callbacks _will_ _not_ be called for data that is up-to-date with the current system
* Upgrade callbacks _will_ _not_ be called if there is no module-state in the datastore, or if module-state support is disabled.
* Upgrade callbacks _will_ be called if the datastore contains a version of a module that is older than the module loaded in Clixon.
* Upgrade callbacks _will_ also be called if the datastore contains a version of a module that is not present in Clixon - an obsolete module.

Re-using the previous stepwise example, if a datastore is loaded based on revision 20140508 by a system supporting revision 2018-02-20, the following two callbacks are made:
```
  upgrade_2016(h, <xml>, "urn:example:interfaces", 20140508, 20180220, NULL, cbret);
  upgrade_2018(h, <xml>, "urn:example:interfaces", 20140508, 20180220, NULL, cbret);
```
Note that the example shown is a template for an upgrade function. It
gets the nodes of an yang module given by `namespace` and the
(outdated) `from` revision, and iterates through them. 

If no action is made by the upgrade calback, and thus the XML is not
upgraded, the next step is XML/Yang validation.

An out-dated XML may still pass validation and the system will go up
in normal state.

However, if the validation fails, the backend will try to enter the
failsafe mode so that the user may perform manual upgarding of the
configuration.

### Example upgrade

The example and  shows the code for upgrading of an interface module. The example is inspired by the ietf-interfaces module that made a subset of the upgrades shown in the examples.

The code is split in two steps. The `upgrade_2016` callback does the following transforms:
  * Move /if:interfaces-state/if:interface/if:admin-status to /if:interfaces/if:interface/
  * Move /if:interfaces-state/if:interface/if:statistics to if:interfaces/if:interface/
  * Rename /interfaces/interface/description to /interfaces/interface/descr

The `upgrade_2018` callback does the following transforms:
  * Delete /if:interfaces-state
  * Wrap /interfaces/interface/descr to /interfaces/interface/docs/descr
  * Change type /interfaces/interface/statistics/in-octets to decimal64 and divide all values with 1000

Please consult the `upgrade_2016` and `upgrade_2018` functions in [the
example](../example/example_backend.c) and
[test](../test/test_upgrade_interfaces.sh) for more details.

## Extra XML

If the Yang validation succeeds and the startup configuration has been committed to the running database, a user may add "extra" XML.

There are two ways to add extra XML to running database after start. Note that this XML is "merged" into running, not "committed".

The first way is via a file. Assume you want to add this xml:
```
<config>
   <x xmlns="urn:example:clixon">extra</x>
</config>
```
You add this via the -c option:
```
clixon_backend ... -c extra.xml
```

The second way is by programming the plugin_reset() in the backend
plugin. The example code contains an example on how to do this (see
plugin_reset() in example_backend.c).

The extra-xml feature is not available if startup mode is `none`. It
will also not occur in failsafe mode.

## Startup status

When the startup process is completed, a startup status is set and is accessible via `clixon_startup_status_get(h)` with the following values:
```
  STARTUP_ERR        XML/JSON syntax error
  STARTUP_INVALID,   XML / Yang validation failure
  STARTUP_OK         OK
```

## Failsafe mode

If the startup fails, the backend looks for a `failsafe` configuration
in `CLICON_XMLDB_DIR/failsafe_db`. If such a config is not found, the
backend terminates. In this mode, running and startup mode should be
unchanged.

If the failsafe is found, the failsafe config is loaded and
committed into the running db.

If the startup mode was `startup`, the `startup` database will
contain syntax errors or invalidated XML.

If the startup mode was `running`, the the `tmp` database will contain
syntax errors or invalidated XML.

## Repair

If the system is in failsafe mode (or fails to start), a user can
repair a broken configuration and then restart the backend. This can
be done out-of-band by editing the startup db and then restarting
clixon.

In some circumstances, it is also possible to repair the startup
configuration on-line without restarting the backend. This section
shows how to repair a startup datastore on-line.

However, on-line repair _cannot_ be made in the following circumstances:
* The broken configuration contains syntactic errors - the system cannot parse the XML.
* The startup mode is `running`. In this case, the broken config is in the `tmp` datastore that is not a recognized Netconf datastore, and has to be accessed out-of-band.
* Netconf must be used. Restconf cannot separately access the different datastores.

First, copy the (broken) startup config to candidate. This is necessary since you cannot make `edit-config` calls to the startup db:
```
  <rpc>
    <copy-config>
      <source><startup/></source>
      <target><candidate/></target>
    </copy-config>
  </rpc>
```

You can now edit the XML in candidate. However, there are some restrictions on the edit commands. For example, you cannot access invalid XML (eg that does not have a corresponding module) via the edit-config operation.
For example, assume `x` is obsolete syntax, then this is _not_ accepted:
```
  <rpc>
    <edit-config>
      <target><candidate/></target>
      <config>
        <x xmlns="example" operation='delete'/>
      </config>
    </edit-config>
  </rpc>
```

Instead, assuming `y` is a valid syntax, the following operation is allowed since `x` is not explicitly accessed:
```
  <rpc>
    <edit-config>
      <target><candidate/></target>
      <config operation='replace'>
        <y xmlns="example"/>
      </config>
    </edit-config>
  </rpc>
```

Finally, the candidate is validate and committed:
```
  <rpc>
    <commit/>
  </rpc>
```

The example shown in this Section is also available as a regression [test script](../test/test_upgrade_repair.sh).

## Automatic upgrades

Clixon supports an EXPERIMENTAL xml changelog feature based on
"draft-wang-netmod-module-revision-management-01" (Zitao Wang et al)
where changes to the Yang model are documented and loaded into
Clixon. The implementation is not complete.

When upgrading, the system parses the changelog and tries to upgrade
the datastore automatically. This feature is experimental and has
several limitations.

You enable the automatic upgrading by registering the changelog upgrade method in `clixon_plugin_ini()` using wildcards:
```
   upgrade_callback_register(h, xml_changelog_upgrade, NULL, 0, 0, NULL);
```

The transformation is defined by a list of changelogs. Each changelog defined how a module (defined by a namespace) is transformed from an old revision to a nnew. Example from [test_upgrade_auto.sh](../test/test_upgrade_auto.sh)
```
<changelogs xmlns="http://clicon.org/xml-changelog">
  <changelog>
    <namespace>urn:example:b</namespace>
    <revfrom>2017-12-01</revfrom>
    <revision>2017-12-20</revision>
    ...
  <changelog>
</changelogs>
```
Each changelog consists of set of (orderered) steps:
```
    <step>
      <name>1</name>
      <op>insert</op>
      <where>/a:system</where>
      <new><y>created</y></new>
    </step>
    <step>
      <name>2</name>
      <op>delete</op>
      <where>/a:system/a:x</where>
    </step>
```
Each step has an (atomic) operation:
* rename - Rename an XML tag
* replace - Replace the content of an XML node
* insert - Insert a new XML node
* delete - Delete and existing node
* move - Move a node to a new place

Step have the following mandatory arguments:
* where - An XPath node-vector pointing at a set of target nodes. In most operations, the vector denotes the target node themselves, but for some operations (such as insert) the vector points to parent nodes.
* when - A boolean XPath determining if the step should be evaluated for that (target) node.

Extended arguments:
* tag - XPath string argument (rename)
* new - XML expression for a new or transformed node (replace, insert)
* dst - XPath node expression (move)

Step summary:
* rename(where:targets, when:bool, tag:string)
* replace(where:targets, when:bool, new:xml)
* insert(where:parents, when:bool, new:xml)
* delete(where:parents, when:bool)
* move(where:parents, when:bool, dst:node)

## Flowcharts

This section contains "pseudo" flowcharts showing the dynamics of
the configuration databases in the startup phase.

The flowchart starts in one of the modes (none, init, startup, running):

### Init mode

```
                 reset     
running   |--------+------------> GOTO EXTRA XML
```

### Running mode

On failure, running is restored to initial state
```
running   ----+                   |----------+--------> GOTO EXTRA XML
               \ copy   parse  validate OK  / commit 
tmp       ------+-------+------+-----------+        

```

### Startup mode
```
                              reset     
running                         |--------+------------> GOTO EXTRA XML
                parse validate OK       / commit 
startup -------+--+-------+------------+          
```

### Failure if failsafe
```
failsafe      ----------------------+
                            reset    \ commit
running                       |-------+---------------> GOTO SYSTEM UP
              parse validate fail 
tmp/startup --+-----+---------------------------------> INVALID XML
```

### Extra XML
```
running -----------------+----+------> GOTO SYSTEM UP
           reset  loadfile   / merge
tmp     |-------+-----+-----+
```

### System UP
```
running ----+-----------------------> RUNNING
             \ copy
candidate     +---------------------> CANDIDATE

```

### Invalid XML

```
                   repair     restart
tmp/startup --------+---------+-----------------------> 
```

## Thanks
Thanks matt smith and dave cornejo for input

## References

[RFC7895](https://tools.ietf.org/html/rfc7895)

