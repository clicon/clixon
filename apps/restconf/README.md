# Clixon Restconf

  * [Installation](#Installation)
  * [Streams](Streams)
  * [Nchan Streams](Nchan)
  * [Debugging](Debugging)	

### 1. Installation

The examples are based on Nginx. Other reverse proxies should work but are not verified.

Ensure www-data is member of the CLICON_SOCK_GROUP (default clicon). If not, add it:
```
  sudo usermod -a -G clicon www-data
```

This implementation uses FastCGI, see http://www.mit.edu/~yandros/doc/specs/fcgi-spec.html.

Download and start nginx. For example on ubuntu:
```
  sudo apt install ngnix
```

Define nginx config file: /etc/nginx/sites-available/default
```
server {
  ...
  location /restconf {
     fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
     include fastcgi_params;
  }
}
```

Start nginx daemon
```
sudo /etc/init.d nginx start
```
Alternatively, start it via systemd:
```
sudo /etc/init.d/nginx start
sudo systemctl start start.service
```

Start clixon restconf daemon
```
olof@vandal> sudo su -c "/www-data/clixon_restconf -f /usr/local/etc/example.xml " -s /bin/sh www-data
```

Make restconf calls with curl
```
olof@vandal> curl -G http://127.0.0.1/restconf/data/interfaces
[
  {
    "interfaces": {
      "interface":[
        {
          "name": "eth0",
          "type": "eth",
          "enabled": "true",
          "name": "eth9",
          "type": "eth",
          "enabled": "true"
         }
      ]
    }
  }
]
olof@vandal> curl -G http://127.0.0.1/restconf/data/interfaces/interface/name=eth9/type
[
  {
    "type": "eth" 
  }
]

curl -sX POST -d '{"interfaces":{"interface":{"name":"eth1","type":"eth","enabled":"true"}}}' http://localhost/restconf/data
```

### 2. Streams

Clixon have two experimental restconf event stream implementations following
RFC8040 Section 6 using SSE.  One native and one using Nginx
nchan. The Nchan alternaitve is described in the
next section.

The (example)[../../example/README.md] creates an EXAMPLE stream.

Set the Clixon configuration options:
```
<CLICON_STREAM_PATH>streams</CLICON_STREAM_PATH>
<CLICON_STREAM_URL>https://example.com</CLICON_STREAM_URL>
<CLICON_STREAM_RETENTION>3600</CLICON_STREAM_RETENTION>
```
In this example, the stream EXAMPLE would be accessed with `https://example.com/streams/EXAMPLE`.

The retention is configured as 1 hour, i.e., the stream replay function will only save timeseries one other.

Clixon defines an internal in-memory (not persistent) replay function
controlled by the configure option above.

You may access a restconf streams using curl.

Add the following to extend the nginx configuration file with the following statements (for example):
```
	location /streams {
	    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
	    include fastcgi_params;
 	    proxy_http_version 1.1;
	    proxy_set_header Connection "";
        }
```

AN example of a stream access is as follows:
```
vandal> curl -H "Accept: text/event-stream" -s -X GET http://localhost/streams/EXAMPLE
data: <notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>2018-11-04T14:47:11.373124</eventTime><event><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event></notification>

data: <notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>2018-11-04T14:47:16.375265</eventTime><event><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event></notification>
```

You can also specify start and stop time. Start-time enables replay of existing samples, while stop-time is used both for replay, but also for stopping a stream at some future time.
```
   curl -H "Accept: text/event-stream" -s -X GET http://localhost/streams/EXAMPLE?start-time=2014-10-25T10:02:00&stop-time=2014-10-25T12:31:00
```

See (stream tests)[../test/test_streams.sh] for more examples.

### 3. Nchan

As an alternative streams implementation, Nginx/Nchan can be used. 
Nginx uses pub/sub channels and can be configured in a variety of
ways. The following uses a simple variant with one generic subscription
channel (streams) and one publication channel (pub).

The advantage with Nchan is the large eco-system of 

Native mode and Nchan mode can co-exist?
Nchan mode does not use Clixon retention, 

Download and install nchan, see (https://nchan.io/#install).

Add the following to extend the Nginx configuration file with the following statements (example):
```
        location ~ /streams/(\w+)$ {
            nchan_subscriber;
            nchan_channel_id $1; #first capture of the location match
        }
        location ~ /pub/(\w+)$ {
            nchan_publisher;
            nchan_channel_id $1; #first capture of the location match
        }        
```

Configure clixon with `--enable-publish` which enables curl code for
publishing streams to nchan.

You also need to configure CLICON_STREAM_PUB to enable pushing notifications to Nginx/Nchan. Example:
```
<CLICON_STREAM_PUB>http://localhost/pub</CLICON_STREAM_PUB>
```
Clicon will then publish events from stream EXAMPLE to `http://localhost/pub/EXAMPLE

Access the event stream EXAMPLE using curl:
```
   curl -H "Accept: text/event-stream" -s -X GET http://localhost/streams/EXAMPLE
   curl -H "Accept: text/event-stream" -H "Last-Event-ID: 1539961709:0" -s -X GET http://localhost/streams/EXAMPLE
```
where the first command retrieves the whole stream history, and the second only retreives the most recent messages given by the ID.

See (https://nchan.io/#eventsource) on more info on how to access an SSE sub endpoint.

### 4. Debugging

Start the restconf fastcgi program with debug flag:
```
sudo su -c "/www-data/clixon_restconf -D 1 -f /usr/local/etc/example.xml" -s /bin/sh www-data
```
Look at syslog:
```
tail -f /var/log/syslog | grep clixon_restconf
```

Send command:
```
curl -G http://127.0.0.1/restconf/data/*
```

You can also run restconf in a debugger.
```
sudo gdb /www-data/clixon_restconf
(gdb) run -D 1 -f /usr/local/etc/example.xml
```
but you need to ensure /www-data/fastcgi_restconf.sock has the following access:
```
rwxr-xr-x 1 www-data www-data 0 sep 22 11:46 /www-data/fastcgi_restconf.sock
```