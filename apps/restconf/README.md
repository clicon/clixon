# Clixon Restconf

### Installation using Nginx

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

### Event streams

Clixon have two experimental restconf event stream implementations following
RFC8040 Section 6 using SSE.  One native and one using Nginx
nchan. The two variants to subscribe to the stream is described in the
next section.

The example [../../example/README.md] creates and EXAMPLE stream.

Set the Clixon configuration options if they differ from default values - if they are OK you do not need to modify them:
```
<CLICON_STREAM_PATH>streams</CLICON_STREAM_PATH>
<CLICON_STREAM_URL>https://example.com</CLICON_STREAM_URL>
<CLICON_STREAM_PUB>http://localhost/pub</CLICON_STREAM_PUB>
```
where
- https://example.com/streams is the public fronting subscription base URL. A specific stream NAME can be accessed as https://example.com/streams/NAME
- http://localhost/pub is the local internal base publish stream.

You access the streams using curl, but they differ slightly in behaviour as described in the following two sections.

Add the following to extend the nginx configuration file with the following statements:
```
	location /streams {
	    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
	    include fastcgi_params;
 	    proxy_http_version 1.1;
	    proxy_set_header Connection "";
        }
```

You access a native stream as follos:
```
   curl -H "Accept: text/event-stream" -s -X GET http://localhost/streams/EXAMPLE
   curl -H "Accept: text/event-stream" -s -X GET http://localhost/streams/EXAMPLE?start-time=2014-10-25T10%3A02%3A00Z&stop-time=2014-10-25T12%3A31%3A00Z
```
where the first command retrieves only new notifications, and the second receives a range of messages.

### Nginx Nchan streams

As an alternative, Nginx/Nchan can be used for streams.
Nginx uses pub/sub channels and can be configured in a variety of
ways. The following uses a simple variant with one generic subscription
channel (streams) and one publication channel (pub). 

Configure clixon with `--enable-publish` which enables curl code for publishing streams to nchan.
Set configure option CLICON_STREAM_PUB to, for example, http://localhost/pub to enable pushing notifications to nchan.

Download and install nchan, see (https://nchan.io/#install).

Add the following to extend the nginx configuration file with the following statements:
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

Access the event stream EXAMPLE using curl:
```
   curl -H "Accept: text/event-stream" -s -X GET http://localhost/streams/EXAMPLE
   curl -H "Accept: text/event-stream" -H "Last-Event-ID: 1539961709:0" -s -X GET http://localhost/streams/EXAMPLE
```
where the first command retrieves the whole stream history, and the second only retreives the most recent messages given by the ID.

See (https://nchan.io/#eventsource) on more info on how to access an SSE sub endpoint.

### Debugging

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