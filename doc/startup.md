# Startup of the Clixon backend

  * [Background](#background)
  * [Modes](#modes)
  * [Startup configuration](#startup-configuration)
  * [Model-state](#model-state)
  * [Upgrade callback](#upgrade-callback)
  * [Extra XML](#extra-xml)
  * [Startup status](#startup-status)
  * [Failsafe mode](#failsafe-mode)
  * [Flowcharts](#flowcharts)
  * [Thanks](#thanks)
  * [References](#references)

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

## Model-state

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

If the module-state of the startup configuration does not match the
module-state of the backend daemon, an _upgrade_ callback is
made. This allows the user to automatically upgrade the XML to the
recent version. As a hint, the module-state differences is passed to
the callback.

Example upgrade callback:
```
  /*! Upgrade configuration from one version to another
   * @param[in]  h      Clicon handle
   * @param[in]  xms    Module state differences
   * @retval     0      OK
   * @retval    -1      Error
   */
  int 
  example_upgrade(clicon_handle       h,
                  cxobj              *xms)
  {
    if (xms)
	clicon_log_xml(LOG_NOTICE, xms, "%s", __FUNCTION__);
    // Perform upgrade of startup XML
    return 0;
  }

  static clixon_plugin_api api = {
    "example",                              /* name */    
    ...
    .ca_upgrade=example_upgrade,            /* upgrade configuration */
  };
```

Note that the example shown is only a template for an upgrade
function. Actual upgrading code may be implemented by a user.

If no action is made by the upgrade calback, and thus the XML is not
upgraded, the next step is XML/Yang validation.

An out-dated XML may still pass validation and the system will go up
in normal state.

However, if the validation fails, the backend will try to enter the
failsafe mode so that the user may perform manual upgarding of the
configuration.


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
backend terminates.

If the failsafe is found, the failsafe config is loaded and
committed into the running db.

If the startup mode was `startup`, the `startup` database will
contain syntax errors or invalidated XML.

If the startup mode was `running`, the the `tmp` database will contain
syntax errors or invalidated XML.

A user can repair a broken configuration and either restart the
backend or copy the repaired configuration to candidate and then commit.

Note that if the broken configuration contains syntactic errors
(eg `STARTUP_ERR`) you cannot access the startup via Restconf or
Netconf operations since the XML may be broken.

If the startup is not valid (no syntax errors), you can edit the XML
and then copy/commit it via CLI, Netconf or Restconf.

## Flowcharts

This section contains "pseudo" flowcharts showing the dynamics of
the configuration databases in the startup phase.

The flowchart starts in one of the modes (none, init, startup, running):

### init mode

```
                 reset     
running   |--------+------------> GOTO EXTRA XML
```

### running mode

```
running   ----+                   |----------+--------> GOTO EXTRA XML
               \ copy   parse  validate OK  / commit 
tmp       ------+-------+------+-----------+        

```

### startup mode
```
                              reset     
running                         |--------+------------> GOTO EXTRA XML
                parse validate OK       / commit 
startup -------+--+-------+------------+          
```

### Failure
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
                   repair     restart
tmp/startup --------+---------+-----------------------> 



## Thanks
Thanks matt smith and dave cornejo for input

## References

[RFC7895](https://tools.ietf.org/html/rfc7895)

