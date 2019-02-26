# Startup of the Clixon backend

## Background

This document describes the startup mechanism of the Clixon backend
daemon from a configuration point-of-view. The startup behaviour has
evolved and this document describes the Clixon 3.10 version and
supports the following features:
* A _startup_ XML or JSON configuration
* Loading of additional XML
* _Detection_ of in-compatible XML and yang models.
* When in-compatible XML is loaded, an _upgrade_ callback is invoked enabling for automated XML upgrade.
* A _failsafe_ mode allowing a user to repair the startup on errors or failed validation.

## Operation

The backend daemon goes through the following approximate phases on startup:
1. Determine startup _mode_, one of none, init, startup or running
2. Startup _configuration_ is loaded, syntax-checked, validated and committed.
3. _Extra-xml_ is loaded.
4. If failures are detected, a _failsafe_ mode is entered.

### Modes

When the Clixon backend starts, it can start in one of four modes:
* _none_: No databases are touched - the system starts and loads existing running database without validation or commits.
* _init_: Similar to none, bit the running databsae is cleared before loading
* _startup_: The configuration is loaded from a persistent `startup` database. This database is loaded, validated and committed into the running database.
* _running_: Similar to startup, but instead the `running` database is used as persistent database.

### Startup configuration

When the backend daemon is started in `startup` mode, the system loads
the `startup` database. The `running` mode is very similar, the only
difference is that the running database is copied (overwrites) the
startup database before this phase.

When loading the startup configuration, it is checked for parse
errors, the yang model-state is detected and the XML is validated
against the backend Yang models.


### Yang model-state

Clixon has the ability to store module-state information according to
RFC7895 in the datastores. Including yang module-state in the
datastores is enabled by the following entry in the Clixon
configuration: ``` <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
```

If the datastore does not contain module-state info, no detection of
incompatible XML is made, and the upgrade feature described in
this section will not happen.

A backend does not perform detection of mismatching XML/Yang if:
1. The datastore was saved in a pre-3.10 system or;
2. `CLICON_XMLDB_MODSTATE` was not enabled when saving the file
3. The backend configuration does not have `CLICON_XMLDB_MODSTATE` enabled.

Note that the module-state detetion is independent of the other steps
of startup operation: syntax errors, validation checks, failsafe mode
are still made.

Further, if a 3.10 Clixon system with `CLICON_XMLDB_MODSTATE` disabled
will silently ignore the module state.

Example of a (simplified) datastore with prepended Yang module-state:
```
<config>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:a</namespace>
      </module>
   </modules-state>
   <a1 xmlns="urn:example:a">some text</a1>
</config>
```

### Upgrade callback

If a mismatch of Yang models in the loaded configuration is
detected. That is, if the module-state of the startup configuration
does not match the module-state of the backend daemon, then an _upgrade_
callback is made. This allows the user to automatically upgrade the
XML to the recent version. As a hint, the module-state differences is
passed to the callback.

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

Note that this is simply a template for upgrade. Advanced automatic
upgrading may be implememted by a user.

Clixon may also add functionality for automated XML upgrades in future releases.

### Extra XML

There are two ways to add extra XML to running database after start. Note that this XML is not "committed" into running.

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
plugin. The example code contains an example on how to do this (see plugin_reset() in example_backend.c).

The extra-xml feature is not available if startup mode is `none`. It will also not occur in failsafe mode.

### Startup status and failsafe mode

A startup status is set and is accessible via `clixon_startup_status_get(h)` with the following values:
  * STARTUP_ERR        XML/JSON syntax error
  * STARTUP_INVALID,   XML / Yang validation failure
  * STARTUP_OK         OK

If the startup fails, the backend looks for a `failsafe` configuration
in `CLICON_XMLDB_DIR/failsafe_db`. If such a config is not found, the
backend terminates.

If the failsafe is found, the failsafe config is loaded and
committed into the running db. The `startup` database will contain syntax
errors or invalidated XML.

A user can repair the `startup`
configuration and either restart the backend or copy the startup
configuration to candidate and the commit.

Note that the if the startup configuration contains syntactic errors
(eg `STARTUP_ERR`) you cannot access the startup via Restconf or
Netconf operations since the XML may be broken.

If the startup is not valid (no syntax errors), you can edit the XML
and then copy/commit it via CLI, Netconf or Restconf.

## Flowcharts

### Init

```
                 reset     
running   |--------+------------> 
```

### Running
```
running   ----+
               \ copy 
startup         +------------> GOTO STARTUP

```
### Startup
```
                              reset     
running                         |--------+------------> RUNNING
                parse validate OK       / commit 
startup -------+--+-------+------------+          
```

If validation of startup fails:
```
failsafe      ----------------------+
                            reset    \ commit
running                       |-------+---------------> RUNNING FAILSAFE
              parse validate fail 
startup      ---+-------------------------------------> INVALID XML
```

## Thanks
Thanks matt smith and dave cornejo for input