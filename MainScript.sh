#!/bin/bash



#################################################################################################################
#################################################################################################################
# Checking for nc installed on local system    
if ! command -v nc &> /dev/null; then
    echo "Error: nc is not installed. Please install it and try again."
    exit 1
fi

# Checking for sshpass installed on local system 
if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass is not installed. Please install it and try again."
    exit 1
fi
#################################################################################################################
#################################################################################################################
    





#################################################################################################################
#################################################################################################################
    
function main {
    # Define the path to the text file containing the list of devices
    devices_list="./devices.txt"


    # Loop through each line in the text file
    while IFS= read -r line || [ -n "$line" ]; do

        # Extract the host address, username, and password from the line
        local host=$(echo $line | cut -d ' ' -f 1)
        local username=$(echo $line | cut -d ' ' -f 2)
        local password=$(echo $line | cut -d ' ' -f 3)
        local ostype=$(echo $line | cut -d ' ' -f 4)


        #################################################################################################################
        #################################################################################################################

        # Check if the IP address is value present
        if ! [[ "$host" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || [ -z "$host" ] || [ "$host" == " " ]; then
            echo "Error: Missing IP address Skipping device"
            continue
        fi

        # Check if the username is value present
        if [ -z "$username" ] || [ "$username" == " " ]; then
            echo "Error: Missing username in Skipping device"
            continue
        fi

        # Check if the password is value present
        if [ -z "$password" ] || [ "$password" == " " ]; then
            echo "Error: Missing password in Skipping device"
            continue
        fi

        # Check if the operating system is value present
        if [ -z "$ostype" ] || [ "$ostype" == " " ]; then
            echo "Error: Missing OS Type in Skipping device"
            continue
        fi
        #################################################################################################################
        #################################################################################################################



        
        echo -e "###########################################################################"
        echo "Machine"
        echo -e "$host  ""$ostype"
        echo -e "###########################################################################\n"



        #################################################################################################################
        #################################################################################################################
        echo -e "------------ PORT 22 CHECK ------------"

        # Check for port 22 open
        nc -z -w 1 "$host" 22

        # If port 22 is not open on remote device then skip pre requisite checking for that device
        if [ "$?" -ne 0 ]; then
            echo "Port 22 is closed on $host, skipping"
            continue
        else
            echo "Port 22 is open on $host"

        fi

        echo -e "-------------------------------------------------------------------------------\n\n"  
        #################################################################################################################
        #################################################################################################################





        #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
        #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^     LINUX     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
        #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
        
        if [ "$ostype" == "linux" ]; then

            os_check_linux $host $username $password
            echo -e "-------------------------------------------------------------------------------\n\n"  

            cloud_check_linux $host $username $password
            echo -e "-------------------------------------------------------------------------------\n\n"  

            filesystem_check_linux $host $username $password
            echo -e "-------------------------------------------------------------------------------\n\n"  


        
            #------------------------- Checking Linux Specific Pre-Requisites ------------------------#
            ./LinuxCheck.sh "$host" "$username" "$password"

        #################################################################################################################
        #################################################################################################################





        #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
        #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^     WINDOWS     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
        #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#

        
        elif [ "$ostype" == "windows" ]; then
            
            os_check_windows $host $username $password
            echo -e "-------------------------------------------------------------------------------\n\n"  

            cloud_check_windows $host $username $password
            echo -e "-------------------------------------------------------------------------------\n\n"  

            filesystem_check_windows $host $username $password
            echo -e "-------------------------------------------------------------------------------\n\n"  


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
        #################################################################################################################
        #################################################################################################################
            
        echo -e "--------------------------------------------------------------------------------------------"
        echo -e "#############################################################################################"
        echo -e "#############################################################################################\n\n\n\n\n\n\n"

    done < "$devices_list"

}
#################################################################################################################
#################################################################################################################
    





#################################################################################################################
#################################################################################################################
    
function os_check_linux {

    local host=$1
    local username=$2
    local password=$3
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

}
#################################################################################################################
#################################################################################################################


    
    


#################################################################################################################
#################################################################################################################
    
function cloud_check_linux {
    local host=$1
    local username=$2
    local password=$3


    if command -v dmidecode >/dev/null 2>&1; then
        system_info=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'dmidecode'")
    else
        echo "ERROR: Cloud detection command not found."
        system_info=""
    fi

    cloud_name=""
    if [[ -z "$system_info" ]]; then
        echo "Error No output "
        hypervisor_check_linux $host $username $password
    else

        # Check if the output contains the string "OracleCloud.com", which indicates the system is running on OCI
        if [[ $system_info =~ "OracleCloud.com" ]]; then
            cloud_name="OCI"

        # Check if the output contains the string "Amazon EC2", which indicates the system is running on AWS
        elif [[ $system_info =~ "Amazon EC2" ]]; then
            cloud_name="AWS"
            
            
        # Check if the output contains the string "Microsoft Corporation Hyper-V", which indicates the system is running on Azure
        elif [[ $system_info =~ "Microsoft Corporation Hyper-V" ]]; then
            cloud_name="Azure"

        # Check if the output contains the string "Google Compute Engine", which indicates the system is running on GCP
        elif [[ $system_info =~ "Google Compute Engine" ]]; then
            cloud_name="GCP"
        
        # Check if the output contains the string "IBM Corporation Power System", which indicates the system is running on IBM Gen2 Cloud
        elif [[ $system_info =~ "IBM Corporation Power System" ]]; then
            cloud_name="IBM Gen2"

        # Check if the output contains the string "Zadara Storage Cloud", which indicates the system is running on Zadara
        elif [[ $system_info =~ "Zadara Storage Cloud" ]]; then
            cloud_name="Zadara"
            
        # If not running on supported clouds check for hypervisor 
        else
            hypervisor_check_linux $host $username $password
        fi
    fi
}
#################################################################################################################
#################################################################################################################
    




#################################################################################################################
#################################################################################################################
    
function hypervisor_check_linux {
    
    local host=$1
    local username=$2
    local password=$3
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
            echo "Device is running on $hypervisor which is supported hypervisor."
        else
            echo "Device is running on unsupported hypervisor or not running on hypervisor"
        fi
    fi
    
}

#################################################################################################################
#################################################################################################################






#################################################################################################################
#################################################################################################################

function filesystem_check_linux {
    
    local host=$1
    local username=$2
    local password=$3
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

}    
#################################################################################################################
#################################################################################################################






#################################################################################################################
#################################################################################################################
function os_check_windows {
    local host=$1
    local username=$2
    local password=$3
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

}
#################################################################################################################
#################################################################################################################



#################################################################################################################
#################################################################################################################
function cloud_check_windows {
    local host=$1
    local username=$2
    local password=$3
    
    system_info=$(sshpass -p "$password" ssh -n "$username"@"$host" "wmic systemenclosure get SMBIOSAssetTag /format:list")
    system_info=$(echo "$system_info" |  tr -d '\r\n'  )
    system_info=$(echo "$system_info" |  cut -d'=' -f2  )
    

    cloud_name=""
    if [[ -z "$system_info" ]]; then
        echo "Error No output "
        hypervisor_check_windows $host $username $password
    else

        if [[ "$system_info" == *"OracleCloud.com"* ]]; then
            cloud_name="OCI"
        elif [[ "$system_info" == *"Amazon EC2"* ]]; then
            cloud_name="AWS"
        elif [[ "$system_info" == *"Google Compute Engine"* ]]; then
            cloud_name="GCP"
        elif [[ "$system_info" == *"Microsoft Corporation Hyper-V"* ]]; then
            cloud_name="Azure"
        elif [[ "$system_info" == *"IBM Corporation Power System"* ]]; then
            cloud_name="IBM Gen2"
        elif [[ "$system_info" == *"Zadara Storage Cloud"* ]]; then
            cloud_name="Zadara"  

        # If not running on supported clouds, check for hypervisor.
        else
            hypervisor_check_windows $host $username $password
        fi
    fi
}
#################################################################################################################
#################################################################################################################






#################################################################################################################
#################################################################################################################
function hypervisor_check_windows {
    local host=$1
    local username=$2
    local password=$3
    echo -e "------------ HYPERVISOR CHECK -------------"

    # Get a hypervisor of system
    hypervisor=$(sshpass -p "$password" ssh -n "$username@$host" "wmic csproduct get name /format:list")
    hypervisor=$(echo "$hypervisor" |  tr -d '\r\n'  )
    hypervisor=$(echo "$hypervisor" |  cut -d'=' -f2  )
    
   # Checking whether  hypervisor is supported or not
    if [[ -z "$hypervisor" ]]; then
        echo "Error No output "
    else
        if grep -qi "^${hypervisor// /.*}.*$" hypervisor_list.txt; then
            echo "Device is running on $hypervisor which is supported hypervisor."
        else
            echo "Device is running on unsupported hypervisor or not running on hypervisor"
        fi
    fi

}
#################################################################################################################
#################################################################################################################






#################################################################################################################
#################################################################################################################

function filesystem_check_windows {
    local host=$1
    local username=$2
    local password=$3
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

}
#################################################################################################################
#################################################################################################################
    





#################################################################################################################
main
#################################################################################################################





