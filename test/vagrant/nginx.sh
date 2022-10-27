#!/usr/bin/env bash
# Nginx config script. There are different variants of nginx configs, just off-loading
# this to a separate script to hide the complexity

set -ux

if [ $# -ne 4 ]; then 
    echo "usage: $0 <dir> <idfile> <port> <wwwuser>"
    exit -1
fi
dir=$1
idfile=$2
port=$3
wwwuser=$4

# Macros to access target via ssh
sshcmd="ssh -o StrictHostKeyChecking=no -i $idfile -p $port vagrant@127.0.0.1"
scpcmd="scp -o StrictHostKeyChecking=no -p -i $idfile -P $port"

if [ $($sshcmd test -d /usr/local/etc/nginx; echo $?) = 0 ]; then
    prefix=/usr/local # eg freebsd
else
    prefix=
fi

# Nginx conf file
cat<<EOF > $dir/nginx.conf
#
user $wwwuser;
error_log  /var/log/nginx/error.log;
worker_processes  1;
events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;
  server {
        listen 80 default_server;
        listen localhost:80 default_server;
        listen [::]:80 default_server;
        server_name localhost;
        server_name _;
      #:well-known is in root, otherwise restconf would be ok
        location / {
            fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
            include fastcgi_params;
        }
        location /streams {
            fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
            include fastcgi_params;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }
  }
}
EOF
$scpcmd $dir/nginx.conf vagrant@127.0.0.1:
# This is problematic since it does not use systemctl (lib.sh check does)
cat<<'EOF' > $dir/startnginx.sh
    #!/usr/bin/env bash
    set -x
    if [ $# -ne 0 -a $# -ne 1 ]; then 
       echo "usage: $0 [<prefix>"]
       exit
    fi     
    prefix=$1
    # start nginx
    sudo cp nginx.conf $prefix/etc/nginx/

    if [ -d /etc/rc.conf ]; then # freebsd
        if [ ! $(grep nginx_enable /etc/rc.conf) ]; then
          sudo sh -c ' echo 'nginx_enable="YES"' >> /etc/rc.conf'
        fi              
        sudo /usr/local/etc/rc.d/nginx restart
    else         
        sudo pkill nginx
        nginxbin=$(sudo which nginx)
        sudo $nginxbin -c $prefix/etc/nginx/nginx.conf
    fi
EOF

chmod a+x $dir/startnginx.sh
$scpcmd $dir/startnginx.sh vagrant@127.0.0.1:

$sshcmd ./startnginx.sh $prefix

