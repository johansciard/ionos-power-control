#!/bin/bash

# Export essential Vars
#
# DCUUID where all the machines we want to work live
DCUUID= "<INSERT DCD ID>"
# The LANID for the network connected to Cube
LANID= "<INSERT LAN ID - ID OF LAN ON WHICH CUBE IS>"
#Bearer token for authentication to the IONOS Cloud API v6
token= "<INSERT BEARER TOKEN OR SECURE REFERENCE>"
#Loop through the NICs for the LAN of the Cube to find all server IDs of the VMs (through using the Members of the LAN)
for uuid in $(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/lans/${LANID}/nics -H "Authorization: Bearer ${token}" | grep servers | sed 's/^.*servers\/\(.*\)\/nics.*$/\1/'); do
    #Create variable for the Server ID to use in next part of script
    SERVERUUID=${uuid}
    # Variable to identify if VM is Cube - Cubes cannot be managed by auto-shutdown so will be removed from list
    CUBE="$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${uuid}?depth=3 -H "Authorization: Bearer ${token}" | grep CUBE)"
    #If condition to skip if VM is Cube (using the "Is Empty" condition to validate the VMs that are actual Servers)
    if [ -z "${CUBE}" ]; then
        #Grab the OS from the Server ID - Will allow for different OS shutdown scripts
        OSType="$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${uuid}/volumes?depth=3 -H "Authorization: Bearer ${token}" | grep licenceType | sed 's/^.*"licenceType" : "\(.*\)\".*$/\1/')"
        #Check current state of VM OS state - i.e. SHUTOFF means OS is OFF
        #N.B: SHUTDOWN means the Server is off (slight nuance)
        ISUP=$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${uuid}?depth=3 -H "Authorization: Bearer ${token}" | tr "," "\n" | grep -i vmstate | sed 's/^.*"vmState":"\(.*\)\".*$/\1/')
        #If there is no Disk (for whatever reason) then skip OS Shutdown
        if [ -z "${OSType}" ]; then
            echo "No disks attached"
        #If LINUX (regardless of Distribution) then run the Root level shutdown script
        elif [ ${OSType} = "LINUX" ]; then
            #Keep checking whether the OS is gracefully shut down
            while [ $ISUP != SHUTOFF ]; do
                sleep 5
                #Remap the variable to the updated state (as it will eventually shut off)
                ISUP=$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${uuid}?depth=3 -H "Authorization: Bearer ${token}" | tr "," "\n" | grep -i vmstate | sed 's/^.*"vmState":"\(.*\)\".*$/\1/')
                echo "VMstate for ${uuid} is -> $ISUP"
            done
        #If WINDOWS (regardless of Distribution) then run the Admin level shutdown script
        elif [[ $(echo ${OSType} | grep -i WINDOWS) ]]; then
            #Keep checking whether the OS is gracefully shut down
            while [ $ISUP != SHUTOFF ]; do
                sleep 5
                #Remap the variable to the updated state (as it will eventually shut off)
                ISUP=$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${uuid}?depth=3 -H "Authorization: Bearer ${token}" | tr "," "\n" | grep -i vmstate | sed 's/^.*"vmState":"\(.*\)\".*$/\1/')
                echo "VMstate for ${uuid} is -> $ISUP"
            done
        # If it is a custom image where the OS Type is not defined (for whatever reason) then we will not gracefully shutoff OS
        else
            echo "OS not supported"
        fi
        #Run Shutdown command for the server
        curl -X POST https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${uuid}/stop -H "Authorization: Bearer ${token}"
        echo "Shutting down server ${uuid}"
    #If it is a Cube return that information to the user for visibility
    else
        echo "This is a Cube - Shutdown is not relevant"
    fi
done
