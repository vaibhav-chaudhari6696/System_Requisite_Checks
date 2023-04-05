#!/bin/bash



# Define the path to the text file containing the list of devices
devices_list="./devices.txt"

# Loop through each line in the text file
while IFS= read -r line || [ -n "$line" ]; do

    # Extract the host address, username, and password from the line
    host=$(echo $line | cut -d ' ' -f 1)
    username=$(echo $line | cut -d ' ' -f 2)
    password=$(echo $line | cut -d ' ' -f 3)
    ostype=$(echo $line | cut -d ' ' -f 4)

    
    echo -e "###########################################################################"
    echo "Machine"
    echo -e "$host  ""$ostype"
    echo -e "###########################################################################\n"




    
    #################################################################################################################
    #################################################################################################################
    echo -e "------------ PORT 22 CHECK ------------"

    # First Checking for nc  installed on local system    
    if command -v nc &> /dev/null; then

        # Check for port 22 open
        nc -z -w 1 "$host" 22

        # If port 22 is not open on remote device then skip pre requisite checking for that device
        if [ "$?" -ne 0 ]; then
            echo "Port 22 is closed on $host, skipping"
            continue
        else
            echo "Port 22 is open on $host"

        fi
   
    # If nc is not installed on local system script execution is stop    
    else
        echo "Error: nc is not installed on this system install nc."
    fi

    echo -e "-------------------------------------------------------------------------------\n\n"   
    #################################################################################################################
    #################################################################################################################








    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^     LINUX     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#

    if [ "$ostype" == "linux" ]; then



    #################################################################################################################
    #################################################################################################################
        echo -e "------------ OS CHECK ------------"

        # Get a os of system
        os=$(sshpass -p "$password" ssh -n "$username@$host" "cat /etc/*-release ")
        osname=$(echo "$os" | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/"//g')

        # Checking whether system os is supported or not
        if [[ -z "$osname" ]]; then
            echo "Error No output "
        else
            if grep -q "^$osname$" os_list.txt; then
                echo "OS $osname is Supported."
            else
                echo "OS $osname is not Supported."
            fi
        fi

        echo -e "-------------------------------------------------------------------------------\n\n"
    #################################################################################################################
    #################################################################################################################






      
        


    #################################################################################################################
    #################################################################################################################
        echo -e "----------- CLOUD CHECK -----------"

        if command -v dmidecode >/dev/null 2>&1; then
            system_info=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'dmidecode'")
        else
            echo "ERROR: Cloud detection command not found."
            system_info=""
        fi


        if [[ -z "$system_info" ]]; then
            echo "Error No output "
            flg=0
        else

            flg=1
            # Check if the output contains the string "OracleCloud.com", which indicates the system is running on OCI
            if [[ $system_info =~ "OracleCloud.com" ]]; then
                echo "The system is running on Oracle Cloud Infrastructure."
            # Check if the output contains the string "Amazon EC2", which indicates the system is running on AWS
            elif [[ $system_info =~ "Amazon EC2" ]]; then
                echo "The system is running on Amazon Web Services."
            # Check if the output contains the string "Microsoft Corporation Hyper-V", which indicates the system is running on Azure
            elif [[ $system_info =~ "Microsoft Corporation Hyper-V" ]]; then
                echo "The system is running on Microsoft Azure."
            # Check if the output contains the string "Google Compute Engine", which indicates the system is running on GCP
            elif [[ $system_info =~ "Google Compute Engine" ]]; then
                echo "The system is running on Google Cloud Platform."
            else
                echo "The system is not running on a known cloud provider."
                flg=0
            fi
        fi


        if [ $flg == 0 ]; then
           
            echo -e "-------------------------------------------------------------------------------\n\n"

            echo -e "----------- HYPERVISOR CHECK -----------"

            # Get a hypervisor of system
            
            if command -v systemd-detect-virt >/dev/null 2>&1; then
                hypervisor=$(sshpass -p "$password" ssh -n "$username@$host" "systemd-detect-virt")
            elif command -v dmidecode >/dev/null 2>&1; then
                hypervisor=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'dmidecode -s system-product-name | tr '[:upper:]' '[:lower:]''")
            elif command -v virt-what >/dev/null 2>&1; then
                hypervisor=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'virt-what'")
            else
                echo "ERROR: Hypervisor detection command not found."
                hypervisor=""
            fi


            # Checking whether  hypervisor is supported or not
            if [[ -z "$hypervisor" ]]; then
                echo "Error No output "
            else
                if grep -qi "^${hypervisor// /.*}.*$" hypervisor_list.txt; then
                    echo "Hypervisor $hypervisor is Supported."
                else
                    echo "Hypervisor $hypervisor is not Supported or not running on hypervisor"
                fi
            fi
        fi

        echo -e "-------------------------------------------------------------------------------\n\n"
    #################################################################################################################
    #################################################################################################################









    

    #################################################################################################################
    #################################################################################################################
        echo -e "------------ FILESYSTEM CHECK -----------"


        # Supported file system types file
        fs_types_file="./file_systems.txt"

        # Get a list of all mounted file systems and their types, excluding loop devices and system file systems
        df_output=$(sshpass -p "$password" ssh -n "$username@$host" "df -T")
        mounted_fs=$( echo "$df_output" | awk '{if($1 !~ /^\/dev\/loop/ && $2 !~ /^(sysfs|proc|udev|devtmpfs|tmpfs)$/ ) print $1":"$2}' | tail -n +2)

        if [[ -z "$mounted_fs" ]]; then
            echo "Error No output "
        else
            unsupported_list=""

            # Loop through each file system and check if its type is supported
            while IFS=: read -r fs_name fs_type; do
                echo "$fs_name is of file system type: $fs_type"
            
                if ! grep -q "^${fs_type}$" "$fs_types_file"; then
                    unsupported_list+="$fs_name\n"
                fi
            done <<< "$mounted_fs"


            # If there are unsupported file system types, list file systems at the end
            if [[ -n "$unsupported_list" ]]; then
                echo -e "\n\nUnsupported File Systems:\n$unsupported_list"

            else
                echo -e "\n\nAll mounted file systems have supported file system types"
            fi
        fi


        echo -e "-------------------------------------------------------------------------------\n\n"

    #################################################################################################################
    #################################################################################################################
    
        #------------------------- Checking Linux Specific Pre-Requisites ------------------------#
        ./LinuxCheck.sh "$host" "$username" "$password"


    #################################################################################################################
    #################################################################################################################
    










    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^     WINDOWS     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#


    elif [ "$ostype" == "windows" ]; then
        

    #################################################################################################################
    #################################################################################################################
        echo -e "----------- OS CHECK ------------"

        # Get a os of system
        os=$(sshpass -p "$password" ssh -n "$username"@"$host" "wmic os get caption /value")
        osname=$(echo "$os" |  tr -d '\r\n'  )
        osname=$(echo "$osname" |  cut -d'=' -f2  )

        # Checking whether system os is supported or not
        if [[ -z "$osname" ]]; then
            echo "Error No output "
        else
            if grep -q "^$osname$" os_list.txt; then
                echo "OS $osname is Supported."
            else
                echo "OS $osname is not Supported."
            fi
        fi

        echo -e "-------------------------------------------------------------------------------\n\n"
    #################################################################################################################
    #################################################################################################################









    #################################################################################################################
    #################################################################################################################
        
        echo -e "------------ HYPERVISOR CHECK -------------"

        # Get a hypervisor of system
        hypervisor=$(sshpass -p "$password" ssh -n "$username@$host" "systeminfo | findstr /C:\"A hypervisor has been detected.\"")

        # Checking whether  hypervisor is present or not
        if [[ "$hypervisor" == *"A hypervisor has been detected."* ]]; then
            echo "Device is running on a hypervisor"
        else
            echo "Device is not running on a hypervisor"
        fi

        echo -e "-------------------------------------------------------------------------------\n\n"
    #################################################################################################################
    #################################################################################################################






    
    

    #################################################################################################################
    #################################################################################################################
        echo -e "------------- FILESYSTEM CHECK ----------------"

        # Get a list of all volumes  and their file systems types
        volumes=$(sshpass -p "$password" ssh -n "$username"@"$host" "wmic logicaldisk where drivetype=3 get name, filesystem")

        # Filter out volumes not have NTFS file system
        non_ntfs_volumes=$(echo "$volumes" | grep -vE "NTFS" | grep -E "^[A-Z]" | awk '{print $2" "$1}'| tail -n+2)

       
        if [[ -z "$volumes" ]]; then
            echo "Error No output "
        else
             
            echo "List of volumes and their file systems:"
            echo "$volumes"
            echo ""
 
            if [ -n "$non_ntfs_volumes" ]; then
                echo "Volumes with unsupported file systems:"
                echo "$non_ntfs_volumes"
                echo ""
            else
                echo "All volumes have supported file system  NTFS "
            fi
        fi


        echo -e "-------------------------------------------------------------------------------\n\n"
    #################################################################################################################
    #################################################################################################################
         

        #------------------------- Checking Winodws Specific Pre-Requisites ------------------------#
        ./WindowsCheck.sh "$host" "$username" "$password"

    #################################################################################################################
    #################################################################################################################
    







    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^     OTHER OS     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    else
        echo "Unknown OS type $ostype for $host, skipping"
        continue
        
    fi

    echo -e "--------------------------------------------------------------------------------------------"
    echo -e "#############################################################################################"
    echo -e "#############################################################################################\n\n\n\n\n\n\n"




done < "$devices_list"





