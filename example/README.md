# Clixon yang routing example

## Compile and run
```
    cd example
    make && sudo make install
```
Start backend:
```
    clixon_backend -f /usr/local/etc/routing.conf -I
```
Edit cli:
```
    clixon_cli -f /usr/local/etc/routing.conf
```
Send netconf command:
```
    clixon_netconf -f /usr/local/etc/routing.conf
```

## Setting data example using netconf
```
<rpc><edit-config><target><candidate/></target><config>
      <interfaces>
         <interface>
            <name>eth1</name>
            <enabled>true</enabled>
            <ipv4>
               <address>
                  <ip>9.2.3.4</ip>
                  <prefix-length>24</prefix-length>
               </address>
            </ipv4>
         </interface>
      </interfaces>
</config></edit-config></rpc>]]>]]>
```

## Getting data using netconf
```
<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter/></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter type="xpath"/></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter type="subtree"><configuration><interfaces><interface><ipv4/></interface></interfaces></configuration></filter></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter type="xpath" select="/interfaces/interface/ipv4"/></get-config></rpc>]]>]]>
<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>
```

## Creating notification

The example has an example notification triggering every 10s. To start a notification 
stream in the session, create a subscription:
```
<rpc><create-subscription><stream>ROUTING</stream></create-subscription></rpc>]]>]]>
<rpc-reply><ok/></rpc-reply>]]>]]>
<notification><event>Routing notification</event></notification>]]>]]>
<notification><event>Routing notification</event></notification>]]>]]>
...
```
This can also be triggered via the CLI:
```
cli> notify 
cli> Routing notification
Routing notification
...
```

## Extending

Clixon has an extension mechanism which can be used to make extended internal
netconf messages to the backend configuration engine. You may need this to
make some special operation that is not covered by standard
netconf functions. The example has a simple "echo" downcall
mechanism that simply echoes what is sent down and is included for
reference. A more realistic downcall would perform some action, such as
reading some status.

Example:
```
cli> downcall "This is a  string"
This is a string
```

## Run as docker container
```
cd docker
# look in README
```