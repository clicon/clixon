# New Clixon Startup functionality

## Objectives
When Clixon 3.9 backend starts, it assumes a well-formed initial XML
configuration which it parses and validates. Depending on starting
mode (-s command-line) this is the "startup" or "running"
configuration.

If this initial configuration fails, clixon backend exits. This has
the consequence that an operator cannot manage the system unless with
out-of-band mechanisms.

## Objectives
This document describes a new startup mechanism with the following goals:
* An operator should be notified of the startup status
* The backend should remain up in case of errors but may enter a "failsafe" mode.
* XML syntax errors should be detected and reported
* Yang module info is added to (startup) datastore database
* Yang module mismatch should be detected and reported
* Validation failures should be detected and reported, specifically of mismatching modules.

## Proposal

A new user callback is introduced:
```
  int startup-cb(h, status, module-state-diff, *valid)
```
which is called once at startup to report startup state to application:
- status is one of: OK, INVALID and ERROR.
- module-state-diff contains a list of RFC7895 differences between the yang modules running in the system, and the ones in the startup config.
- valid is a return value that if set to 0 forces the status to INVALID (if OK on entry).

A new read-only datastore is introduced:
```
  CLICON_XMLDB_FAILSAFE If set, a failsafe read-only datastore is expected,
                         in CLICON_XMLDB_DIR, called failsafe_db
```

Datastore databases are optionally extended with modules state according to
RFC7895. A new config option is introduced to control this:
```
  CLICON_XMLDB_MODSTATE If set, tag datastores with RFC 7895 YANG Module Library 
 info. When loaded at startup, a check is made if the system yang modules match
```

Proposed algoritm:
0. Backend starts with a set of yang module revisions as of RFC7895.
1. Parse startup XML (or JSON)
2. If syntax failure, call startup-cb(ERROR), copy failsafe db to candidate and commit. Done
3. Check yang module versions between backend and init config XML. (msdiff)
4. Validate startup db. (valid)
5. If valid fails, call startup-cb(Invalid, msdiff), keep startup in candidate and commit failsafe db. Done.
6. Call startup-cb(OK, msdiff) and commit. 

Note:

1. If done in step 2) the failsafe db is in both candidate and running. The operator need to repair the XML file before reloading.
2. If done in step 5) The operator has the non-valid database in candidate and can edit it, and when ready can commit it. During this time, the failsafe db is running.
3. If done in steps 5 and 6, the module-state-diff contains the (potential) differences in the modules-state diff.

## Thanks
Thanks matt smith and dave cornejo for input