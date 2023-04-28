#!/bin/bash
 
# Export essential Vars
#
# DCUUID where all the machines we want to work live
DCUUID= "<INSERT DCD ID>"
# The LANID for the network connected to Cube
LANID= "<INSERT LAN ID - ID OF LAN ON WHICH CUBE IS>"
#Bearer token for authentication to the IONOS Cloud API v6
token= "<INSERT BEARER TOKEN OR SECURE REFERENCE>"


for uuid in $(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/lans/${LANID}/nics -H "Authorization: Bearer ${token}" | grep servers | sed 's/^.*servers\/\(.*\)\/nics.*$/\1/') ; do
    SERVERUUID=${uuid}
    echo "Current server is: ${SERVERUUID}"
    #Start all servers 
    curl -X POST https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${SERVERUUID}/start -H "Authorization: Bearer ${token}"
    echo "Spinning up server: ${SERVERUUID}"
done
