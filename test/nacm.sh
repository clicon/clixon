#!/bin/bash
# Authentication and authorization and IETF NACM
# Library variable and functions

USER=$(whoami)

# Three groups from RFC8341 A.1 (admin extended with $USER)
NGROUPS=$(cat <<EOF
     <groups>
       <group>
         <name>admin</name>
         <user-name>admin</user-name>
         <user-name>andy</user-name>
         <user-name>$USER</user-name>
       </group>
       <group>
         <name>limited</name>
         <user-name>wilma</user-name>
         <user-name>bam-bam</user-name>
       </group>
       <group>
         <name>guest</name>
         <user-name>guest</user-name>
         <user-name>guest@example.com</user-name>
       </group>
     </groups>
EOF
)

# Permit all rule for admin group from RFC8341 A.2
NADMIN=$(cat <<EOF
     <rule-list>
       <name>admin-acl</name>
       <group>admin</group>
       <rule>
         <name>permit-all</name>
         <module-name>*</module-name>
         <access-operations>*</access-operations>
         <action>permit</action>
         <comment>
             Allow the 'admin' group complete access to all operations and data.
         </comment>
       </rule>
     </rule-list>
EOF
)

