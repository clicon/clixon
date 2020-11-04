#!/usr/bin/env bash
# Example-module from draft-netconf-list-pagination-nc-00.txt
# Assumes variable fexample is set to name of yang file
# An extra leaf-list is added (clixon)

cat <<EOF > $fexample
module example-module {
  yang-version 1.1;
  namespace "http://example.com/ns/example-module";
  prefix exm;

  import iana-crypt-hash {
    prefix ianach;
  }
  import ietf-inet-types {
    prefix inet;
  }
  import ietf-yang-types {
    prefix yang;
  }

  organization
    "Example, Inc.";
  contact
    "support at example.com";
  description
    "Example Data Model Module.";

  revision 2020-10-06 {
    description
      "Initial version.";
    reference
      "example.com document 1-4673.";
  }

  container admins {
    description
      "Admin Group configuration.";
    list admin {
      key "name";
      description
        "List of admins for admin group configuration.";
      ordered-by system;
      leaf name {
        type string {
          length "1 .. max";
        }
        description
          "The name of the admin.";
      }
      leaf access {
        type enumeration {
          enum permit {
            description
              "Permit access privilege.";
          }
          enum deny {
            description
              "Deny access privilege.";
          }
          enum limited {
            description
              "Limited access privilege.";
          }
        }
        default "permit";
        description
          "The Access privilege type for this admin.";
      }
      leaf email-address {
        type inet:email-address;
        description
          "Contact email of the admin.";
      }
      leaf password {
        type ianach:crypt-hash;
        description
          "The password for this entry.";
      }
      leaf-list status {
        type string;
        config false;
        description
          "The status for this entry.";
      }
      container preference {
        leaf-list number {
          type uint8;
          description
            "Defines the perference numbers for the admin.";
        }
        description
          "Preference parameters.";
      }
      list skill {
        key "name";
        description
          "Represents one 'sill' resource within one
           'admin' resource.";
        leaf name {
          type string {
            length "1 .. max";
          }
          description
            "The name of the skill.";
        }
        leaf rank {
          type uint16;
          description
            "The rank identifying the rank on
             the skill.";
        }
      }
    }
  }
  container rulebase {
    description
      "Rule base configuration";
    list rule {
      key "name";
      description
        "List of rules for rulebase.";
      ordered-by user;
      leaf name {
        type string {
          length "1 .. max";
        }
        description
          "The name of the rule.";
      }
      leaf match {
        type string {
          length "1 .. max";
        }
        description
          "The rules in this rulebase determine what fields will be
           matched upon before any action is taken on them.";
      }
      leaf action {
        type enumeration {
          enum forwarding {
            description
              "Specify forwarding behavior per rule entry.";
          }
          enum logging {
            description
              "Specify logging behavior per rule entry.";
          }
        }
        default "logging";
        description
          "Defintion of the action for this rule entry.";
      }
    }
  }
  container device-logs {
    description
      "Device log configuration";
    list device-log {
      description
        "List of device logs.";
      config false;
      leaf device-id {
        type string;
        description
          "The device id of the device log.";
      }
      leaf time-received {
        type yang:date-and-time;
        description
          "The timestamp value at the time this
           log was received.";
      }
      leaf time-generated {
        type yang:date-and-time;
        description
          "The timestamp value at the time this
           log was generated.";
      }
      leaf message {
        type string;
        description
          "Message given at start of login session.";
      }
    }
  }
  container audit-logs {
    description
      "Audit log configuration";
    list audit-log {
      key "log-creation";
      description
        "List of audit logs.";
      config false;
      leaf source-ip {
        type inet:ip-address;
        description
          "The IP address of the targeted object.";
      }
      leaf log-creation {
        type yang:date-and-time;
        description
          "The timestamp value at the time this
           log was created.";
      }
      leaf request {
        type string;
        description
          "Request type of audit log.";
      }
      leaf outcome {
        type boolean;
        default "true";
        description
          "Indicate the audit log is retrieved sucessfully or not.";
      }
    }
  }
  container prefixes {
    description
      "Enclosing container for the list of prefixes in a policy
       prefix list";
    list prefix-list {
      key "ip-prefix masklength-lower masklength-upper";
      description
        "List of prefixes in the prefix set";
      leaf ip-prefix {
        type inet:ip-prefix;
        mandatory true;
        description
          "The prefix member in CIDR notation -- while the
           prefix may be either IPv4 or IPv6, most
           implementations require all members of the prefix set
           to be the same address family.  Mixing address types in
           the same prefix set is likely to cause an error.";
      }
      leaf masklength-lower {
        type uint8;
        description
          "Masklength range lower bound.";
      }
      leaf masklength-upper {
        type uint8 {
          range "1..128";
        }
        must '../masklength-upper >= ../masklength-lower' {
          error-message "The upper bound should not be lessthan lower bound.";
        }
        description
          "Masklength range upper bound.

           The combination of masklength-lower and masklength-upper
           define a range for the mask length, or single 'exact'
           length if masklength-lower and masklenght-upper are equal.

           Example: 10.3.192.0/21 through 10.3.192.0/24 would be
           expressed as prefix: 10.3.192.0/21,
                        masklength-lower=21,
                        masklength-upper=24

           Example: 10.3.192.0/21 (an exact match) would be
           expressed as prefix: 10.3.192.0/21,
                        masklength-lower=21,
                        masklength-upper=21";
      }
    }
  }
}
EOF


