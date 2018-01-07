# Clixon Restconf
### Features

Clixon restconf is a daemon based on FASTCGI. Instructions are available to
run with NGINX. 
The implementatation supports plain OPTIONS, HEAD, GET, POST, PUT, PATCH, DELETE.
and is based on draft-ietf-netconf-restconf-13. 
There is currently (2017) a [RFC 8040: RESTCONF Protocol](https://tools.ietf.org/html/rfc8040), many of those features are _not_ implemented,
including:
- query parameters (section 4.9)
- notifications (sec 6)
- GET /restconf/ (sec 3.3)
- GET /restconf/yang-library-version (sec 3.3.3)
- only rudimentary error reporting exists (sec 7)

### Installation using Nginx

Define nginx config file/etc/nginx/sites-available/default
```
server {
  ...
  location /restconf {
    root /usr/share/nginx/html/restconf;
    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
    include fastcgi_params;
  }
}
```
Start nginx daemon
```
sudo /etc/init.d nginx start
```

Start clixon restconf daemon
```
olof@vandal> sudo su -c "/www-data/clixon_restconf -f /usr/local/etc/routing.xml " -s /bin/sh www-data
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

### Debugging

Start the restconf fastcgi program with debug flag:
```
sudo su -c "/www-data/clixon_restconf -Df /usr/local/etc/routing.xml" -s /bin/sh www-data
```
Look at syslog:
```
tail -f /var/log/syslog | grep clixon_restconf
```

Send command:
```
curl -G http://127.0.0.1/restconf/data/*
```
