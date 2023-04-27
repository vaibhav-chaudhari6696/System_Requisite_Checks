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
port=22
function main {
    # Define the path to the text file containing the list of devices
    devices_list="./devices.txt"


    # Loop through each line in the text file
    while IFS=$' \t,' read -r host username password ostype port_no || [ -n "$host" ]; do

        #################################################################################################################
        #################################################################################################################

        # Check if the IP address is value present
        if ! [[ "$host" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || [ -z "$host" ] || [[ "$host" =~ [[:space:]] ]]; then
            echo "Error: Missing IP address Skipping device"
            continue
        fi

        # Check if the username is value present
        if [ -z "$username" ] || [[ "$username" =~ [[:space:]] ]]; then
            echo "Error: Missing username in Skipping device"
            continue
        fi

        # Check if the password is value present
        if [ -z "$password" ] || [[ "$password" =~ [[:space:]] ]]; then
            echo "Error: Missing password in Skipping device"
            continue
        fi

        # Check if the operating system is value present
        if [ -z "$ostype" ] || [[ "$ostype" =~ [[:space:]] ]]; then
            echo "Error: Missing OS Type in Skipping device"
            continue
        fi

        # Check if the port number given
        if [[ -n "$port_no" ]] && [[ "$port_no" =~ ^[0-9]+$ ]]; then
            port=$port_no 
        else
            port=22
        fi

        #################################################################################################################
        #################################################################################################################



        
        echo -e "###########################################################################"
        echo "Machine"
        echo -e "$host  ""$ostype"
        echo -e "###########################################################################\n"



        #################################################################################################################
        #################################################################################################################
        echo -e "------------ REACHABLE PORT CHECK ------------"

        # Check for port 22 open
        nc -z -w 10 "$host" "$port"

        # If given port is not open on remote device then skip pre requisite checking for that device
        if [ "$?" -ne 0 ]; then
            echo "Machine $host is not reachable over port $port, skipping checks for machine"
            continue
        else
            echo "Machine $host is reachable over port $port"
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
            ./LinuxCheck.sh "$host" "$username" "$password" "$port"

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
    os=$(sshpass -p "$password" ssh -p "$port" -n "$username@$host" "cat /etc/*-release ")
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
    

    
    if sshpass -p "$password" ssh -p "$port" -n "$username@$host" "command -v dmidecode >/dev/null 2>&1"; then
        system_info=$(sshpass -p "$password" ssh -p "$port" -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'dmidecode'")
    else
        echo "ERROR: Cloud detection (dmidecode) command is not installed on $host"
        system_info=""
    fi

    cloud_name=""
    if [[ -z "$system_info" ]]; then
        hypervisor_check_linux $host $username $password
    else

        
        if [[ $system_info =~ "OracleCloud.com" ]]; then
            cloud_name="OCI"
            
        elif [[ $system_info =~ "Amazon EC2" ]]; then
            cloud_name="AWS"
             
        elif [[ $system_info =~ "Microsoft Corporation Hyper-V" ]] || [[ $system_info =~ "Microsoft Corporation" ]] || [[ $system_info =~ "Hyper-V" ]]; then
            cloud_name="Azure"
            
        elif [[ $system_info =~ "Google Compute Engine" ]]; then
            cloud_name="GCP"
               
        elif [[ $system_info =~ "IBM Corporation Power System" ]]; then
            cloud_name="IBM Gen2"

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
    if sshpass -p "$password" ssh -p "$port" -n "$username@$host" "command -v systemd-detect-virt >/dev/null 2>&1"; then
        hypervisor=$(sshpass -p "$password" ssh -p "$port" -n "$username@$host" "systemd-detect-virt")
    
    elif sshpass -p "$password" ssh -p "$port" -n "$username@$host" "command -v virt-what >/dev/null 2>&1"; then
        hypervisor=$(sshpass -p "$password" ssh -p "$port" -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'virt-what'")
    
    elif sshpass -p "$password" ssh -p "$port" -n "$username@$host" "command -v dmidecode >/dev/null 2>&1"; then
        hypervisor=$(sshpass -p "$password" ssh -p "$port" -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'dmidecode -s system-product-name | tr '[:upper:]' '[:lower:]''")
    
    else
        echo "ERROR: Hypervisor detection (systemd-detect-virt or virt-what or dmidecode )command not installed on $host"
        hypervisor=""
    fi


    # Checking whether  hypervisor is supported or not
    if [[ -z "$hypervisor" ]]; then
        echo "Error No output "
    else
        if grep -qi "^${hypervisor// /.*}.*$" hypervisor_list.txt; then
            echo "Device is running on $hypervisor which is supported hypervisor"
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
    df_output=$(sshpass -p "$password" ssh -p "$port" -n "$username@$host" "df -T")
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
    
    # Getting network adapter name details 
    system_info1=$(sshpass -p "$password" ssh -n "$username"@"$host" "wmic nic get name")
    system_info1=$(echo "$system_info1" |  tr -d '\r\n'  )
    system_info1=$(echo "$system_info1" |  cut -d'=' -f2  )
    
    # Getting diskdrive model name
    system_info2=$(sshpass -p "$password" ssh -n "$username"@"$host" "wmic diskdrive get model" | tail -n +2)
    system_info2=$(echo "$system_info2" |  tr -d '\r\n'  )
    system_info2=$(echo "$system_info2" |  cut -d'=' -f2  )

    cloud_name=""
    if [[ -z "$system_info1" ]] || [[ -z "$system_info2" ]] ; then
        hypervisor_check_windows $host $username $password
    else

        if [[ "$system_info1" == *"Oracle VirtIO Ethernet Adapter"* ]] && [[ "$system_info2" == *"ORACLE"* ]]; then
            cloud_name="OCI"  
           
        elif [[ "$system_info1" == *"Amazon Elastic Network Adapter"* ]] && [[ "$system_info2" == *"Amazon"* ]]; then
            cloud_name="AWS"
            


        elif [[ "$system_info1" == *"Microsoft Hyper-V Network Adapter"* ]] && [[ "$system_info2" == *"Microsoft"* ]]; then
            cloud_name="Azure"
          
    
        elif [[ "$system_info1" == *"Google VirtIO Ethernet Adapter"* ]] && [[ "$system_info2" == *"Google"* ]]; then
            cloud_name="GCP"
            

        
        elif [[ "$system_info1" == *"IBMGen2"* ]] && [[ "$system_info2" == *"IBM"* ]]; then
            cloud_name="IBM Gen2"
            

        elif [[ "$system_info1" == *"Zadara"* ]] && [[ "$system_info2" == *"Zadara"* ]]; then
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

    # Get a hypervisor state (Present or not) 
    hypervisor_state=$(sshpass -p "$password" ssh -n "$username@$host" "wmic computersystem get HypervisorPresent /format:list")
    hypervisor_state=$(echo "$hypervisor_state" |  tr -d '\r\n'  )
    hypervisor_state=$(echo "$hypervisor_state" |  cut -d'=' -f2  )

    # Get a hypervisor of system
    hypervisor=$(sshpass -p "$password" ssh -n "$username@$host" "wmic computersystem get model /format:list")
    hypervisor=$(echo "$hypervisor" |  tr -d '\r\n'  )
    hypervisor=$(echo "$hypervisor" |  cut -d'=' -f2  )
    
    
    if [[ -z "$hypervisor_state" ]] || [[ -z "$hypervisor" ]]; then
        echo "Error No output "
    else
        # Checking whether  hypervisor is present or not
        if [[ "$hypervisor_present" == *"TRUE"* ]] ; then

            # Checking whether  hypervisor is supported or not
            if grep -qi "^${hypervisor// /.*}.*$" hypervisor_list.txt; then
                echo "Device is running on $hypervisor which is supported hypervisor."
            else
                echo "Device is running on unsupported hypervisor or not running on hypervisor"
            fi

        else
            echo "Device is not running on hypervisor"
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





