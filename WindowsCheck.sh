#!/bin/bash


#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^     WINDOWS     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#

host_ip=$1
user=$2
pass=$3

function main {
    local host=$1
    local username=$2
    local password=$3

    shadowcopy_check_windows  $host $username $password
    echo -e "-------------------------------------------------------------------------------\n\n"

    shadowcopy_storage_space_check_windows $host $username $password
    echo -e "-------------------------------------------------------------------------------\n\n"

    drive_free_space_check_windows $host $username $password
    echo -e "-------------------------------------------------------------------------------\n\n"

    antivirus_check_windows $host $username $password
    echo -e "-------------------------------------------------------------------------------\n\n"

    language_check_windows $host $username $password
    echo -e "-------------------------------------------------------------------------------\n\n"

}



#################################################################################################################
#################################################################################################################

function shadowcopy_check_windows {
    local host=$1
    local username=$2
    local password=$3
    echo -e "------- CHECK FOR VOLUMES HAVE SHADOWCOPY STORAGE --------"

    # Get list of volumes
    volumes_raw=$(sshpass -p "$password" ssh -n "$username@$host" 'wmic logicaldisk get caption')
    volumes_raw=$(echo "$volumes_raw" | tail -n+2)
    volumes=$(echo "$volumes_raw" | grep -oP '([A-Z])+' | tr '[:lower:]' '[:upper:]' | tr '\n' ' ')

    # Get the list of volumes that have shadow copy
    shadow_volumes_raw=$(sshpass -p "$password" ssh -n "$username@$host" 'vssadmin list shadowstorage')
    shadow_volumes=$(echo "$shadow_volumes_raw" | awk -F':' '/For volume/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' | grep -oP '([A-Z])' | tr '\n' ' ')

    # Find the non-shadow volumes
    non_shadow_volumes=$(echo "$volumes_raw" | grep -oP '([A-Z])+' | tr '[:lower:]' '[:upper:]' | tr -d "$shadow_volumes" | tr '\n' ' ')


    echo "Volumes List : $volumes"
    if [ -z "$shadow_volumes" ]; then
        echo "No volumes with shadow copy."
    else
        echo "Volumes with shadow copies : $shadow_volumes"
    fi
    echo "Volumes without shadow copies : $non_shadow_volumes"

}
    
#################################################################################################################
#################################################################################################################








#################################################################################################################
#################################################################################################################
function shadowcopy_storage_space_check_windows {
    local host=$1
    local username=$2
    local password=$3

    echo -e "------- CHECK FOR VOLUMES HAVE 15% OR MORE SHADOWCOPY STORAGE SPACE --------"

    # Run the command to get shadow copy storage space on all volumes
    output=$(sshpass -p "$password" ssh -n "$username@$host" 'vssadmin list shadowstorage')

    # Extract maximum shadow copy storage space for each volume using AWK
    awk_output=$(echo "$output" | awk -F':' '
        /For volume/{
            volume=$2
        }
        /Maximum Shadow Copy Storage space/{
            gsub(/^[ \t]+|[ \t]+$/, "", $0)
            if (volume) {
                gsub(/^[ \t]+|[ \t]+$/, "", volume)
                match($0, /[0-9]+%/)
                percentage=substr($0, RSTART, RLENGTH)
                print "For Volume "volume ") - Maximum Shadow Copy Storage space is : " percentage
                if (percentage ~ /^0*([1-9]|1[0-4])%$/) {
                    print "Shadow copy storage space is less than 15% for volume " volume")"
                    print " "
                } else {
                    print "Shadow copy storage space is more than or equal to 15% for volume " volume")"
                    print " "
                }
                volume=""
            }
        }
    ')
    echo "$awk_output"
    # Check if the awk command produced any output
    if [ -z "$awk_output" ]; then
        echo "No volumes with shadow copy."
    fi

}
#################################################################################################################
#################################################################################################################









#################################################################################################################
#################################################################################################################
function drive_free_space_check_windows {
    local host=$1
    local username=$2
    local password=$3

    echo -e "------- CHECK FOR FREE SPACE ON DRIVES --------"

    # Get the drive letter of the OS drive
    os_drive=$(sshpass -p "$password" ssh -n "$username@$host" 'echo %systemdrive%')
    echo "OS drive : ${os_drive:0:1}"

    # Run the command to get free space and total size on the OS drive
    output=$(sshpass -p "$password" ssh -n "$username@$host" "wmic logicaldisk where DeviceID='$os_drive' get FreeSpace,Size /value")

    if [[ -z "$output" ]]; then
        echo "Error No output "
    else
        # Get the free space and total size in bytes and convert them to GB
        free_space_bytes=$(echo "$output" | awk -F "=" '/FreeSpace/ {print $2}' | tr -d '\r')
        total_size_bytes=$(echo "$output" | awk -F "=" '/Size/ {print $2}' | tr -d '\r')
        free_space_gb=$(echo "scale=2; $free_space_bytes/(1024*1024*1024)" | bc)
        total_size_gb=$(echo "scale=2; $total_size_bytes/(1024*1024*1024)" | bc)
        
        echo "Free space is $free_space_gb GB from $total_size_gb GB"

        # Check if free space on the OS drive is greater than or equal to 1 GB
        if (( $(echo "$free_space_gb >= 1" | bc -l) )); then
            echo "Free space on the OS drive is greater than or equal to 1 GB"
        else
            echo "Free space on the OS drive is less than 1 GB"
        fi
    fi

}
   

#################################################################################################################
#################################################################################################################


   




#################################################################################################################
#################################################################################################################
function antivirus_check_windows {
    local host=$1
    local username=$2
    local password=$3
    echo -e "------- CHECK FOR WINDOWS DEFENDER AND ANTIVIRUS --------"

    output=$(sshpass -p "$password" ssh -n "$username@$host" 'sc query Windefend')

    if [ $? -eq 1060 ]; then
            echo "Windows Defender is not installed."
    else
        # Check if Windows Defender is running
        status=$(echo "$output" | grep STATE)
        if [[ "$status" == *"RUNNING"* ]]; then
            echo "Windows Defender is running."
        else
            echo "Windows Defender is not running."
        fi
    fi


    # Check for antivirus
    antivirus=$(sshpass -p "$password" ssh -n "$username@$host" 'wmic /namespace:\\root\SecurityCenter2 path AntivirusProduct get displayName' 2>/dev/null) 

    if [ -n "$antivirus" ]; then
        echo -e  "\n\nList of third party antivirus installed: "     
        echo "$antivirus" | grep -v "Windows Defender"
    else
        echo -e "\n\nNo third party antivirus installed."
    fi


}
#################################################################################################################
#################################################################################################################









#################################################################################################################
#################################################################################################################
function language_check_windows {
    local host=$1
    local username=$2
    local password=$3
    echo -e "------- CHECK FOR WINDOWS LANGUAGE SUPPORT --------"

    language=$(sshpass -p "$password" ssh -n "$username@$host" 'systeminfo | findstr /B /C:"System Locale')

    if [[ -z "$language" ]]; then
        echo "Error No output "
    else
        # Extract the language code from the system locale string
        language=$(echo $language | awk -F": " '{print $2}')

        # Check if the default system language is set to English
        if [[ "$language" =~ "en" || "$language" =~ "EN" ]]; then
            echo "The default system language is set to English"
        else
            echo "The default system language is not set to English. The default system language is $language"
        fi
    fi
}
#################################################################################################################
#################################################################################################################


#################################################################################################################
main $host_ip $user $pass
#################################################################################################################
