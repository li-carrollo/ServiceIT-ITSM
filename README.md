# ServiceIT-ITSM



localhost
sitadmin
S3********

1. Download the script
We use wget to download the raw version of the file so you don't accidentally download the GitHub HTML page:


wget https://raw.githubusercontent.com/li-carrollo/ServiceIT-ITSM/main/sit-itsm.sh
2. Make it executable
In Linux, new files aren't allowed to run as programs by default. You need to grant execution permissions:

chmod +x sit-itsm.sh
3. Run the script
Now you can execute it. Since it's an ITSM service script, it might require administrative privileges (sudo) depending on what it installs:

Bash
./sit-itsm.sh
(If it gives you a "Permission Denied" error inside the script, try sudo ./sit-itsm.sh instead).
