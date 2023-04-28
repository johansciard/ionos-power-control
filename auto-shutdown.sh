#!/bin/bash

# Export essential Vars
#
# DCUUID where all the machines we want to work live
DCUUID= "<INSERT DCD ID>"
# The LANID for the network connected to Cube
LANID= "<INSERT LAN ID - ID OF LAN ON WHICH CUBE IS>"
#Bearer token for authentication to the IONOS Cloud API v6
token= "<INSERT BEARER TOKEN OR SECURE REFERENCE>"


PAYLOAD="$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/lans/${LANID}/nics?depth=1 -H "Authorization: Bearer ${token}")"


WINDOWSADMIN=administrator
WINDOWSPASS=securepassword
LINUXADMIN=root

shutoff_check() {
    ISUP=$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${SERVERUUID}?depth=3 -H "Authorization: Bearer ${token}" | tr "," "\n" | grep -i vmstate | sed 's/^.*"vmState":"\(.*\)\".*$/\1/')
    while [ $ISUP != SHUTOFF ]; do
        sleep 5
        #Remap the variable to the updated state (as it will eventually shut off)
        ISUP=$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${SERVERUUID}?depth=3 -H "Authorization: Bearer ${token}" | tr "," "\n" | grep -i vmstate | sed 's/^.*"vmState":"\(.*\)\".*$/\1/')
        echo "VMstate for ${SERVERUUID} is -> $ISUP"
    done
    echo "The server ${SERVERUUID} is safely shutoff"
}

shutdown_windows() {
    ADMIN="$WINDOWSADMIN"
    PASS="$WINDOWSPASS"
    net rpc shutdown -f -t -0 -C 'testing shutdown' -U "${ADMIN}"%"${PASS}" -I "${PRIVATEIP}"
}

shutdown_linux() {
    ADMIN="$LINUXADMIN"
    ssh -t ${ADMIN}@${PRIVATEIP} 'shutdown -h now'
}


#Loop through the NICs for the LAN of the Cube to find all server IDs of the VMs (through using the Members of the LAN)
for uuid in $(echo ${PAYLOAD} | tr "," "\n"  | grep servers | sed 's/^.*servers\/\(.*\)\/nics.*$/\1/' | sort -u); do
    #Create variable for the Server ID to use in next part of script
    SERVERUUID=${uuid}
    echo "Current server is ${SERVERUUID}"
    #Grab the NIC fror PRIVATEIP matching
    NICUUID=$(echo ${PAYLOAD} | tr "," "\n" | grep -A 2 "type.*nic"  | grep "${SERVERUUID}/nics" | sed 's/^.*nics\/\(.*\)\"/\1/')
    echo "Getting the private IP for NIC: ${NICUUID}"
    #Grab the IP of the NIC for use in the local script
    PRIVATEIP=$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${SERVERUUID}/nics/${NICUUID} -H "Authorization: Bearer ${token}" | tr "," "\n" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    echo "Private IP of Server ${SERVERUUID} is ${PRIVATEIP}"
    # Variable to identify if VM is Cube - Cubes cannot be managed by auto-shutdown so will be removed from list
    CUBE="$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${SERVERUUID}?depth=3 -H "Authorization: Bearer ${token}" | grep CUBE)"
    #If condition to skip if VM is Cube (using the "Is Empty" condition to validate the VMs that are actual Servers)
    if [ -z "${CUBE}" ]; then
        #Grab the OS from the Server ID - Will allow for different OS shutdown scripts
        OSType="$(curl -s https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${SERVERUUID}/volumes?depth=3 -H "Authorization: Bearer ${token}" | grep licenceType | sed 's/^.*"licenceType" : "\(.*\)\".*$/\1/')"
        #Check current state of VM OS state - i.e. SHUTOFF means OS is OFF
        #N.B: SHUTDOWN means the Server is off (slight nuance)
        #If there is no Disk (for whatever reason) then skip OS Shutdown
        if [ -z "${OSType}" ]; then
            echo "No disks attached - please attach OS disk for graceful shutdown"
        #If LINUX (regardless of Distribution) then run the Root level shutdown script
        elif [ ${OSType} = "LINUX" ]; then
            # echo "ISDHW"
            #Keep checking whether the OS is gracefully shut down
            echo "The server is running on ${OSType} and will be treated accordingly"
            shutdown_linux
            shutoff_check
        #If WINDOWS (regardless of Distribution) then run the Admin level shutdown script
        elif [[ $(echo ${OSType} | grep -i WINDOWS) ]]; then
            #Keep checking whether the OS is gracefully shut down
            echo "The server is running on ${OSType} and will be treated accordingly"
            shutdown_windows
            shutoff_check
        # If it is a custom image where the OS Type is not defined (for whatever reason) then we will not gracefully shutoff OS
        else
            echo  "OS not supported - shutdown will not be graceful"
        fi
        #Run Shutdown command for the server
        curl -X POST https://api.ionos.com/cloudapi/v6/datacenters/${DCUUID}/servers/${SERVERUUID}/stop -H "Authorization: Bearer ${token}"
        echo -e "Shutting down server ${SERVERUUID}\n"
    #If it is a Cube return that information to the user for visibility
    else
        echo -e "This is a Cube - Shutdown is not possible\n"
    fi
done
