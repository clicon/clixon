#!/bin/bash
# Restconf RFC8040 Appendix A and B "jukebox" example

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/example-jukebox.yang
fxml=$dir/initial.xml

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
</clixon-config>
EOF

cat <<EOF > $fyang
   module example-jukebox {

      namespace "http://example.com/ns/example-jukebox";
      prefix "jbox";

      organization "Example, Inc.";
      contact "support at example.com";
      description "Example Jukebox Data Model Module.";
      revision "2016-08-15" {
        description "Initial version.";
        reference "example.com document 1-4673.";
      }

      identity genre {
        description
          "Base for all genre types.";
      }

      // abbreviated list of genre classifications
      identity alternative {
        base genre;
        description
          "Alternative music.";
      }
      identity blues {
        base genre;
        description
          "Blues music.";
      }
      identity country {
        base genre;
        description
          "Country music.";
      }
      identity jazz {
        base genre;
        description
          "Jazz music.";
      }
      identity pop {
        base genre;
        description
          "Pop music.";
      }
      identity rock {
        base genre;
        description
          "Rock music.";
      }

      container jukebox {
        presence
          "An empty container indicates that the jukebox
           service is available.";

        description
          "Represents a 'jukebox' resource, with a library, playlists,
           and a 'play' operation.";

        container library {

          description
            "Represents the 'jukebox' library resource.";

          list artist {
            key name;
            description
              "Represents one 'artist' resource within the
               'jukebox' library resource.";

            leaf name {
              type string {
                length "1 .. max";
              }
              description
                "The name of the artist.";
            }

            list album {
              key name;
              description
                "Represents one 'album' resource within one
                 'artist' resource, within the jukebox library.";

              leaf name {
                type string {
                  length "1 .. max";
                }
                description
                  "The name of the album.";
              }

              leaf genre {
                type identityref { base genre; }
                description
                  "The genre identifying the type of music on
                   the album.";
              }

              leaf year {
                type uint16 {
                  range "1900 .. max";
                }
                description
                  "The year the album was released.";
              }

              container admin {
                description
                  "Administrative information for the album.";

                leaf label {
                  type string;
                  description
                    "The label that released the album.";
                }
                leaf catalogue-number {
                  type string;
                  description
                    "The album's catalogue number.";
                }
              }

              list song {
                key name;
                description
                  "Represents one 'song' resource within one
                   'album' resource, within the jukebox library.";

                leaf name {
                  type string {
                     length "1 .. max";
                  }
                  description
                    "The name of the song.";
                }

                leaf location {
                  type string;
                  mandatory true;
                  description
                    "The file location string of the
                     media file for the song.";
                }
                leaf format {
                  type string;
                  description
                    "An identifier string for the media type
                     for the file associated with the
                     'location' leaf for this entry.";
                }
                leaf length {
                  type uint32;
                  units "seconds";
                  description
                    "The duration of this song in seconds.";
                }
              }   // end list 'song'
            }   // end list 'album'
          }  // end list 'artist'

          leaf artist-count {
             type uint32;
             units "artists";
             config false;
             description
               "Number of artists in the library.";
          }
          leaf album-count {
             type uint32;
             units "albums";
             config false;
             description
               "Number of albums in the library.";
          }
          leaf song-count {
             type uint32;
             units "songs";
             config false;
             description
               "Number of songs in the library.";
          }
        }  // end library

        list playlist {
          key name;
          description
            "Example configuration data resource.";

          leaf name {
            type string;
            description
              "The name of the playlist.";
          }
          leaf description {
            type string;
            description
              "A comment describing the playlist.";
          }
          list song {
            key index;
            ordered-by user;

            description
              "Example nested configuration data resource.";

            leaf index {    // not really needed
              type uint32;
              description
                "An arbitrary integer index for this playlist song.";
            }
            leaf id {
              type instance-identifier;
              mandatory true;
              description
                "Song identifier.  Must identify an instance of
                 /jukebox/library/artist/album/song/name.";
            }
          }
        }

        container player {
          description
            "Represents the jukebox player resource.";

          leaf gap {
            type decimal64 {
              fraction-digits 1;
              range "0.0 .. 2.0";
            }
            units "tenths of seconds";
            description
              "Time gap between each song.";
          }
        }
      }

      rpc play {
        description
          "Control function for the jukebox player.";
        input {
          leaf playlist {
            type string;
            mandatory true;
            description
              "The playlist name.";
          }
          leaf song-number {
            type uint32;
            mandatory true;
            description
              "Song number in playlist to play.";
          }
        }
      }
   }
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill clixon_backend # to be sure
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

new "B.1.1.  Retrieve the Top-Level API Resource root"
expectpart "$(curl -s -i -X GET -H 'Accept: application/xrd+xml' http://localhost/.well-known/host-meta)" 0 "HTTP/1.1 200 OK" "Content-Type: application/xrd+xml" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"

d='{"ietf-restconf:restconf":{"data":{},"operations":{},"yang-library-version":"2016-06-21"}}'
new "B.1.1.  Retrieve the Top-Level API Resource /restconf json"
expectpart "$(curl -s -i -X GET -H 'Accept: application/yang-data+json' http://localhost/restconf)" 0 "HTTP/1.1 200 OK" 'Cache-Control: no-cache' "Content-Type: application/yang-data+json" "$d"

new "B.1.1.  Retrieve the Top-Level API Resource /restconf xml (not in RFC)"
expectpart "$(curl -s -i -X GET -H 'Accept: application/yang-data+xml' http://localhost/restconf)" 0 "HTTP/1.1 200 OK" 'Cache-Control: no-cache' "Content-Type: application/yang-data+xml" '<restconf xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><data/><operations/><yang-library-version>2016-06-21</yang-library-version></restconf>'

# This just catches the header and the jukebox module, the RFC has foo and bar which
# seems wrong to recreate
new "B.1.2.  Retrieve the Server Module Information"
expectpart "$(curl -s -i -X GET -H 'Accept: application/yang-data+json' http://localhost/restconf/data/ietf-yang-library:modules-state)" 0 "HTTP/1.1 200 OK" 'Cache-Control: no-cache' "Content-Type: application/yang-data+json" '{"ietf-yang-library:modules-state":{"module-set-id":' '"module":\[{"name":"example-jukebox","revision":"2016-08-15","namespace":"http://example.com/ns/example-jukebox","conformance-type":"implement"}'

new "B.1.3.  Retrieve the Server Capability Information"
expectpart "$(curl -s -i -X GET -H 'Accept: application/yang-data+xml' http://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/capabilities)" 0 "HTTP/1.1 200 OK" "Content-Type: application/yang-data+xml" 'Cache-Control: no-cache' '<capabilities xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf-monitoring"><capability>urn:ietf:params:restconf:capability:defaults:1.0?basic-mode=explicit</capability></capabilities>'

new "B.2.1.  Create New Data Resources (artist+json)"
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox/library -d '{"example-jukebox:artist":[{"name":"Foo Fighters"}]}')" 0 "HTTP/1.1 201 Created" "Location: http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters"

new "B.2.1.  Create New Data Resources (album+xml)"
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+xml' http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters -d '<album xmlns="http://example.com/ns/example-jukebox"><name>Wasting Light</name><year>2011</year></album>')" 0 "HTTP/1.1 201 Created" "Location: http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters/album=Wasting%20Light"

new "B.2.1.  Add Data Resources again (conflict - not in RFC)"
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+xml' http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters -d '<album xmlns="http://example.com/ns/example-jukebox"><name>Wasting Light</name><year>2011</year></album>')" 0 "HTTP/1.1 409 Conflict"

new "4.5. PUT replace content"
# XXX should be: jbox:alternative --> example-jukebox:alternative
expectpart "$(curl -s -i -X PUT -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters/album=Wasting%20Light -d '{"example-jukebox:album":[{"name":"Wasting Light","genre":"example-jukebox:alternative","year":2011}]}')" 0 "HTTP/1.1 204 No Content"

new "4.5. PUT replace content (xml encoding)"
expectpart "$(curl -s -i -X PUT -H 'Content-Type: application/yang-data+xml' http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters/album=Wasting%20Light -d '<album xmlns="http://example.com/ns/example-jukebox" xmlns:jbox="http://example.com/ns/example-jukebox"><name>Wasting Light</name><genre>jbox:alternative</genre><year>2011</year></album>')" 0 "HTTP/1.1 204 No Content"

new "4.5. PUT create new identity"
expectpart "$(curl -s -i -X PUT -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -d '{"example-jukebox:album":[{"name":"London Calling","year":1979}]}')" 0 "HTTP/1.1 201 Created"


if false; then # NYI

new "B.2.2.  Detect Datastore Resource Entity-Tag Change"
new "B.2.3.  Edit a Datastore Resource"
new "B.2.4.  Replace a Datastore Resource"
new "B.2.5.  Edit a Data Resource"
new 'B.3.1.  "content" Parameter'
new 'B.3.2.  "depth" Parameter'
new 'B.3.3.  "fields" Parameter'
new 'B.3.4.  "insert" Parameter'
new 'B.3.5.  "point" Parameter'
new 'B.3.6.  "filter" Parameter'
new 'B.3.7.  "start-time" Parameter'
new 'B.3.8.  "stop-time" Parameter'
new 'B.3.9.  "with-defaults" Parameter'
fi

new "Kill restconf daemon"
stop_restconf 

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
