#!/bin/sh

CFG_COUCHDB_ADMIN="" 
CURL_CREDENTIALS=""

if [[ -z "$COUCHDB_USER" ]] || [[ -z "$COUCHDB_PASSWORD" ]]; then
 echo ">> COUCHDB admin credentials not defined - ADMIN PARTY is not supported on 3.x"
else
 echo ">> COUCHDB admin credentials provided"
 CFG_COUCHDB_ADMIN="-e COUCHDB_USER=$COUCHDB_USER -e COUCHDB_PASSWORD=$COUCHDB_PASSWORD"
 CURL_CREDENTIALS="-u $COUCHDB_USER:$COUCHDB_PASSWORD"
fi

echo "Starting Docker..."
sh -c "docker run -d -p 5984:5984 -p 5986:5986 --tmpfs /ram_disk $CFG_COUCHDB_ADMIN couchdb:$INPUT_COUCHDB_VERSION"

# CouchDB container name
export NAME=`docker ps --format "{{.Names}}" --last 1`

docker exec $NAME sh -c 'mkdir -p /opt/couchdb/etc/local.d && echo "[couchdb]\ndatabase_dir = /ram_disk\nview_index_dir = /ram_disk\ndelayed_commits = true\n[httpd]\nsocket_options = [{nodelay, true}]\n[native_query_servers]\nerlang = {couch_native_process, start_link, []}" >> /opt/couchdb/etc/local.d/01-github-action-custom.ini'

wait_for_couchdb() {
  echo "Waiting for CouchDB..."
  hostip=$(ip route show | awk '/default/ {print $3}')

  while ! curl -f http://$hostip:5984/ &> /dev/null
  do
    echo "."
    sleep 1
  done
}
wait_for_couchdb

# Set up system databases
echo "Setting up CouchDB system databases..."
docker exec $NAME curl -sS $CURL_CREDENTIALS 'http://127.0.0.1:5984/_users' -X PUT -H 'Content-Type: application/json' --data '{"id":"_users","name":"_users"}' > /dev/null
docker exec $NAME curl -sS $CURL_CREDENTIALS 'http://127.0.0.1:5984/_global_changes' -X PUT -H 'Content-Type: application/json' --data '{"id":"_global_changes","name":"_global_changes"}' > /dev/null
docker exec $NAME curl -sS $CURL_CREDENTIALS 'http://127.0.0.1:5984/_replicator' -X PUT -H 'Content-Type: application/json' --data '{"id":"_replicator","name":"_replicator"}' > /dev/null
