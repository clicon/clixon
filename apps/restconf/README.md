# Clixon Restconf

### Installation using Nginx

Ensure www-data is member of the CLICON_SOCK_GROUP (default clicon). If not, add it:
```
  sudo usermod -a -G clicon www-data
```

This implementation uses FastCGI, see http://www.mit.edu/~yandros/doc/specs/fcgi-spec.html.

Define nginx config file: /etc/nginx/sites-available/default
```
server {
  ...
  location /restconf {
     fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
     include fastcgi_params;
  }
  location /stream { # for restconf notifications
     fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
     include fastcgi_params;
     proxy_http_version 1.1;
     proxy_set_header Connection "";
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