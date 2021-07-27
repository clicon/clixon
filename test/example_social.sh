#!/usr/bin/env bash
# Example-social from draft-netconf-list-pagination-00.txt appendix A.1
# Assumes variable fexample is set to name of yang file
# Note inverted pattern is commented

cat <<EOF > $fexample
   module example-social {
     yang-version 1.1;
     namespace "http://example.com/ns/example-social";
     prefix es;

     import ietf-yang-types {
       prefix yang;
       reference
         "RFC 6991: Common YANG Data Types";
     }
     import ietf-inet-types {
       prefix inet;
       reference
         "RFC 6991: Common YANG Data Types";
     }

     import iana-crypt-hash {
       prefix ianach;
       reference
         "RFC 7317: A YANG Data Model for System Management";
     }

     organization "Example, Inc.";
     contact      "support@example.com";
     description  "Example Social Data Model.";

     revision 2021-07-21 { /* clixon edit */
       description
         "Initial version.";
       reference
         "RFC XXXX: Example social module.";
     }

     container members {
       description
         "Container for list of members.";
       list member {
         key "member-id";
         description
           "List of members.";

         leaf member-id {
           type string {
             length "1..80";
/*
             pattern '.*[\n].*' {
              modifier invert-match;
             }
*/
           }
           description
             "The member's identifier.";
         }

         leaf email-address {
           type inet:email-address;
           mandatory true;
           description
             "The member's email address.";
         }
         leaf password {
           type ianach:crypt-hash;
           mandatory true;
           description
             "The member's hashed-password.";
         }

         leaf avatar {
           type binary;
           description
             "An binary image file.";
         }

         leaf tagline {
           type string {
             length "1..80";
/*
             pattern '.*[\n].*' {
               modifier invert-match;
             }
*/
           }
           description
             "The member's tagline.";
         }

         container privacy-settings {
           leaf hide-network {
             type boolean;
             description
               "Hide who you follow and who follows you.";
           }
           leaf post-visibility {
             type enumeration {
               enum public {
                 description
                   "Posts are public.";
               }
               enum unlisted {
                 description
                   "Posts are unlisted, though visable to all.";
               }
               enum followers-only {
                 description
                   "Posts only visible to followers.";
               }
             }
             default public;
             description
               "The post privacy setting.";
           }
           description
             "Preferences for the member.";
         }

         leaf-list following {
           type leafref {
             path "/members/member/member-id";
           }
           description
             "Other members this members is following.";
         }

         container posts {
           description
             "The member's posts.";
           list post {
             key timestamp;
             leaf timestamp {
               type yang:date-and-time;
               description
                 "The timestamp for the member's post.";
             }
             leaf title {
               type string {
                 length "1..80";
/*
                 pattern '.*[\n].*' {
                   modifier invert-match;
                 }
*/
               }
               description
                 "A one-line title.";
             }
             leaf body {
               type string;
               mandatory true;
               description
                 "The body of the post.";
             }
             description
               "A list of posts.";
           }
         }

         container favorites {
           description
             "The member's favorites.";
           leaf-list uint8-numbers {
             type uint8;
             ordered-by user;
             description
               "The member's favorite uint8 numbers.";
           }
           leaf-list uint64-numbers {
             type uint64;
             ordered-by user;
             description
               "The member's favorite uint64 numbers.";
           }
           leaf-list int8-numbers {
             type int8;
             ordered-by user;
             description
               "The member's favorite int8 numbers.";
           }
           leaf-list int64-numbers {
             type int64;
             ordered-by user;
             description
               "The member's favorite uint64 numbers.";
           }
           leaf-list decimal64-numbers {
             type decimal64 {
               fraction-digits 5;
             }
             ordered-by user;
             description
               "The member's favorite decimal64 numbers.";
           }
           leaf-list bits {
             type bits {
               bit zero {
                 position 0;
                 description "zero";
               }
               bit one {
                 position 1;
                 description "one";
               }
               bit two {
                 position 2;
                 description "two";
               }
             }
             ordered-by user;
             description
               "The member's favorite bits.";
           }
         }

         container stats {
           config false;
           description
             "Operational state members values.";
           leaf joined {
             type yang:date-and-time;
             mandatory true;
             description
               "Timestamp when member joined.";
           }
           leaf membership-level {
             type enumeration {
               enum admin {
                 description
                   "Site administrator.";
               }
               enum standard {
                 description
                   "Standard membership level.";
               }
               enum pro {
                 description
                   "Professional membership level.";
               }
             }
             mandatory true;
             description
               "The membership level for this member.";
           }
           leaf last-activity {
             type yang:date-and-time;
             description
               "Timestamp of member's last activity.";
           }
         }
       }
     }

     container audit-logs {
       config false;
       description
         "Audit log configuration";
       list audit-log {
         description
           "List of audit logs.";
         leaf timestamp {
           type yang:date-and-time;
           mandatory true;
           description
             "The timestamp for the event.";
         }
         leaf member-id {
           type string;
           mandatory true;
           description
             "The 'member-id' of the member.";
         }
         leaf source-ip {
           type inet:ip-address;
           mandatory true;
           description
             "The apparent IP address the member used.";
         }
         leaf request {
           type string;
           mandatory true;
           description
             "The member's request.";
         }
         leaf outcome {
           type boolean;
           mandatory true;
           description
             "Indicate if request was permitted.";
         }
       }
     }
   }
EOF


