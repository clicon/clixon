#!/usr/bin/env bash
# Create server certs
# Assume: the following variables set:
# $dir, $certdir, $srvkey, $srvcert, $cakey, $cacert
# and that $certdir exists

# 1. CA
cat<<EOF > $dir/ca.cnf
[ ca ]
default_ca      = CA_default

[ CA_default ]
serial = ca-serial
crl = ca-crl.pem
database = ca-database.txt
name_opt = CA_default
cert_opt = CA_default
default_crl_days = 9999
default_md = md5

[ req ]
default_bits           = ${CERTKEYLEN}
days                   = 1
distinguished_name     = req_distinguished_name
attributes             = req_attributes
prompt                 = no
output_password        = password

[ req_distinguished_name ]
C                      = SE
L                      = Stockholm
O                      = Clixon
OU                     = clixon
CN                     = ca
emailAddress           = olof@hagsand.se

[ req_attributes ]
challengePassword      = test

EOF

# Generate CA cert
openssl req -x509 -days 1 -config $dir/ca.cnf -keyout $cakey -out $cacert

cat<<EOF > $dir/srv.cnf
[req]
prompt = no
distinguished_name = dn
req_extensions = ext
[dn]
CN = www.clicon.org # localhost
emailAddress = olof@hagsand.se
O = Clixon
L = Stockholm
C = SE
[ext]
subjectAltName = DNS:clicon.org
EOF

# Generate server key
openssl genrsa -out $srvkey ${CERTKEYLEN}

# Generate CSR (signing request)
openssl req -new -config $dir/srv.cnf -key $srvkey -out $certdir/srv_csr.pem

# Sign server cert by CA
openssl x509 -req -extfile $dir/srv.cnf -days 1 -passin "pass:password" -in $certdir/srv_csr.pem -CA $cacert -CAkey $cakey -CAcreateserial -out $srvcert
