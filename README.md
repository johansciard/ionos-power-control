# IONOS Cloud Power OFF/ON Servers without exposing them to Internet
Script for Powering on and off IONOS virtual Machines through a local Cube running in the estate. This allows for the Cube to shut off the OS gracefully before using the Cloud API v6 to shut down the Server.

See details in the diagram below:

![Architectural Diagram showing the Linux Cube connected to a LAN exposing to Internet as well as 2 Linux servers and 1 Windows connected on a Private LAN to the Cube](https://github.com/johansciard/ionos-power-control/blob/main/images/ExampleArchitecture.PNG?raw=true)

## Disclaimer
This script is a personal project, and is not an officially supported product by IONOS nor does it offer any SLA. Please verify code is up to date and all credentials/information used is secured as per your organizational/individual needs.


## Prerequisites
### Linux Cube Setup
Setup a an XS Cube with the following configuration:
> - Allow for the Cube to be accessible from the internet (can be restricted and secured as needed).
> - Create a **separate LAN** to allow for private connection between the Cube and the servers (Script will loop through all NICs on the LAN).
> - Linux OS - tested on Ubuntu 22.04.
> - SSH key generated / imported to allow access to all other Linux Servers on the LAN.
> - Samba Common Package installed (for remote shutdown of Windows Servers) and Git.

```
apt-get -y install samba-common
```

**Note: the Cube script will require relevant permissions to remote shutoff the Servers.**

### Linux Server Setup
> - Ensure that the root user on the Cube can access the Linux servers on the LAN via SSH keys - either a new SSH key generated from the Cube or that the Public Key RSA for the Servers exist in the Cube.
> - Connect the Server to the **Private LAN of the Cube** to ensure that the NICs can be picked up correctly for selective shut off/down of specific servers.

### Windows Server Setup
> - Ensure that there is a user with relevant privileges to be able to shutdown the Windows Server - the default administrator can be used for testing purposes, but should not be used for actual running of the script inside the organisation/individual's systems (regardless of environment).
> - Connect the Server to the **Private LAN of the Cube** to ensure that the NICs can be picked up correctly for selective shut off/down of specific servers.
> - Add a remote shutdown security policy - for more information on the steps and considerations: https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/shut-down-the-system.
> - Add registry keys to disable UAC remote restrictions - for more information on the steps and considerations: https://learn.microsoft.com/en-us/troubleshoot/windows-server/windows-security/user-account-control-and-remote-restriction.
> -  Start remote registry service.

## Steps to run 
Inside of the cube (if not using Cloud Init) run:
```
git clone https://github.com/johansciard/ionos-power-control.git
```
**Note: if Git is not desired on the cube, create a new file with with the contents of the auto-shutdown.sh.**

Go to the directory of the cloned repos (only if step above was performed, otherwise navigate to the place where file was created):
```
cd ionos-power-control
```
Replace the following fields with the relevant properties (where possible ensure secrets and passwords are not stored in plain text):

```
DCUUID= "<INSERT DCD ID>"

LANID= "<INSERT LAN ID - ID OF LAN ON WHICH CUBE IS>"

token= "<INSERT BEARER TOKEN OR SECURE REFERENCE>" (can be created via API or ionosctl)

WINDOWSADMIN=administrator (default profile created - recommended to create specific profile with Least Privileges)

WINDOWSPASS=securepassword

LINUXADMIN=root 
```
Once all properties are as desired, run the following command to shut down all servers, or run a scheduled task that interacts with the script on a cron job:

```
bash auto-shutdown.sh
```
**Note: for full automation it is recommended to integrate the script with a Linux CRON job to schedule the stop (and start) of the servers at specific times.**

To start servers automatically run the following command or run a scheduled task that interacts with the script on a cron job:

```
bash auto-start.sh
```
**Note: there are no configurations necessary on any of the servers to run the automatic start script - the only paramaeters necessary are the LANID, DCDID, and token.**
