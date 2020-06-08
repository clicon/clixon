#!/usr/bin/env bash
# Nginx config script. There are different variants of nginx configs, just off-loading
# this to a separate script to hide the complexity

set -eux

if [ $# -ne 3 ]; then 
    echo "usage: $0 <dir> <idfile> <port>"
    exit -1
fi
dir=$1
idfile=$2
port=$3

sshcmd="ssh -o StrictHostKeyChecking=no -i $idfile -p $port vagrant@127.0.0.1"
scpcmd="scp -o StrictHostKeyChecking=no -p -i $idfile -P $port"

if $($sshcmd test -d /etc/nginx/conf.d) ; then
    confd=true
else
    confd=false
fi

if $confd; then # conf.d nginx config
cat <<EOF > $dir/default.conf
#
server {
        listen 80 default_server;
        listen localhost:80 default_server;
        listen [::]:80 default_server;
	server_name localhost;
	server_name _;
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
EOF
    $scpcmd $dir/default.conf vagrant@127.0.0.1:
cat<<EOF > $dir/startnginx.sh
  sudo cp default.conf /etc/nginx/conf.d/
#  if [ ! -d /run/nginx ]; then
#    sudo mkdir /run/nginx
#  fi
  # Start nginx
  /usr/sbin/nginx -c /etc/nginx/nginx.conf
  >&2 echo "nginx started"

EOF

else # full nginx config

# Nginx conf file
cat<<'EOF' > $dir/nginx.conf
#
worker_processes  1;
events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

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
cat<<EOF > $dir/startnginx.sh
    #!/usr/bin/env bash
    # start nginx
    sudo cp nginx.conf /usr/local/etc/nginx/
    if [ ! $(grep nginx_enable /etc/rc.conf) ]; then
	sudo sh -c ' echo 'nginx_enable="YES"' >> /etc/rc.conf'
    fi
    sudo /usr/local/etc/rc.d/nginx restart
EOF

fi # full nginx config

chmod a+x $dir/startnginx.sh
$scpcmd $dir/startnginx.sh vagrant@127.0.0.1:
$sshcmd ./startnginx.sh

