#!/bin/bash


    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^     WINDOWS     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#

host=$1
username=$2
password=$3




#################################################################################################################
#################################################################################################################

echo -e "------- CHECK FOR VOLUMES HAVE  SHADOWCOPY STORAGE --------"

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

echo -e "-------------------------------------------------------------------------------\n\n"
#################################################################################################################
#################################################################################################################








#################################################################################################################
#################################################################################################################
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


echo -e "-------------------------------------------------------------------------------\n\n"

#################################################################################################################
#################################################################################################################









#################################################################################################################
#################################################################################################################

echo -e "------- CHECK FOR FREE SPACE ON DRIVES --------"

# Run the command to get free space on all volumes
output=$(sshpass -p "$password" ssh -n "$username@$host" 'wmic logicaldisk get caption,FreeSpace,Size | findstr /r "^[A-Z]:"')

if [[ -z "$output" ]]; then
    echo "Error No output "
else
    # Loop through the output lines
    while IFS= read -r line; do
        # Get the volume letter, free space, and total space in bytes
        volume=$(echo "$line" | awk '{print $1}')
        free_space_bytes=$(echo "$line" | awk '{print $2}')
        total_space_bytes=$(echo "$line" | awk '{print $3}')
        # Convert free space and total space from bytes to GB and remove any carriage return characters
        free_space_gb=$(echo "$free_space_bytes" | awk '{print $1/1024/1024/1024}' | tr -d '\r')
        total_space_gb=$(echo "$total_space_bytes" | awk '{print $1/1024/1024/1024}' | tr -d '\r')
        # Check if free space is greater than 1 GB and print the volume letter, free space in GB, and total space in GB
        if (( $(echo "$free_space_gb > 1" | bc -l) )); then
            echo "Volume $volume has free space of $free_space_gb GB from $total_space_gb GB"
        else
            echo "Volume $volume has free space of $free_space_gb GB (less than 1 GB) from $total_space_gb GB"
        fi
    done <<< "$output"
fi

echo -e "-------------------------------------------------------------------------------\n\n"

#################################################################################################################
#################################################################################################################









#################################################################################################################
#################################################################################################################

echo -e "------- CHECK FOR WINDOWS DEFENDER AND ANTIVIRUS --------"

# Check if Windows Defender is running
if sshpass -p "$password" ssh -n "$username@$host" 'sc query Windefend | findstr RUNNING' >/dev/null 2>&1; then
    echo "Windows Defender is running."
else
    echo "Windows Defender is not running."
fi


# Check for antivirus
antivirus=$(sshpass -p "$password" ssh -n "$username@$host" 'wmic /namespace:\\root\SecurityCenter2 path AntivirusProduct get displayName, productState /format:list' 2>/dev/null) 

if [ -n "$antivirus" ]; then
    echo "List of antivirus installed: "     
    echo "$antivirus"
else
    echo "No antivirus installed."
fi


echo -e "-------------------------------------------------------------------------------\n\n"

#################################################################################################################
#################################################################################################################









#################################################################################################################
#################################################################################################################

echo -e "------- CHECK FOR WINDOWS LANGUAGE SUPPORT --------"

language=$(sshpass -p "$password" ssh -n "$username@$host" 'systeminfo | findstr /B /C:"System Locale')

if [[ -z "$language" ]]; then
    echo "Error No output "
else
    # Extract the language code from the system locale string
    language=$(echo $language | awk -F": " '{print $2}')

    # Check if the default system language is set to English
    if [[ "$language" =~ "en" || "$language" =~ "EN" ]]; then
        echo "Success: The default system language is set to English"
    else
        echo "Error: The default system language is not set to English. The default system language is $language"
    fi
fi

echo -e "-------------------------------------------------------------------------------\n\n"

#################################################################################################################
#################################################################################################################