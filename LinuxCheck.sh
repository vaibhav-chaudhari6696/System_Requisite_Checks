#!/bin/bash


#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^     LINUX     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#


host_ip=$1
user=$2
pass=$3

function main {
    local host=$1
    local username=$2
    local password=$3

    root_user_check_linux  $host $username $password
    echo -e "-------------------------------------------------------------------------------\n\n"

    volume_group_free_extents_check_linux_v1 $host $username $password
    echo -e "-------------------------------------------------------------------------------\n\n"

}




#################################################################################################################
#################################################################################################################

function root_user_check_linux {
    local host=$1
    local username=$2
    local password=$3
    echo -e "------- CHECK FOR ROOT USER  -------"

    idval=$(sshpass -p "$password" ssh -n "$username@$host" "id -u")
    if [[ -z "$idval" ]]; then
            echo "Error: No Output "
    else
        # Cheking user is root user or not
        if [ $idval -eq 0 ]; then
            echo "User $username is the root user."
        
        # If not root user cheking user is in sudo group or not
        else
            echo "User $username is not the root user."
            echo "Checking for sudo privileges....."

            command_output=$(sshpass -p "$password" ssh -n "$username@$host" "groups $username")
            if echo "$command_output" | grep &>/dev/null '\bsudo\b'; then
                echo "User $username has sudo privileges."
            
            # If user is not in sudo group then adding user to sudo group
            else
                echo "User $username has not sudo privileges"
            fi
            
        fi
    fi

}
#################################################################################################################
#################################################################################################################






#################################################################################################################
#################################################################################################################

function volume_group_free_extents_check_linux_v1 {
    echo -e "------- CHECK FOR VOLUME GROUP HAVE 15% OR MORE FREE SPACE -------"

    if command -v vgs >/dev/null 2>&1; then
        # Get a list of all volume groups
        VG_LIST=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'vgs --noheadings --readonly --separator : --options vg_name'")
        VG_LIST=$(echo "$VG_LIST" |  cut -d':' -f2  )
        VG_LIST=$(echo "$VG_LIST" |  tr -d '\r\n'  )


        if [[ -z "$VG_LIST" ]]; then
                echo "No Volume Groups on system."
        else
            echo "List of volume groups:"
            echo "$VG_LIST"
            # Loop over each volume group
            while IFS=: read -r vg_name; do
                # Remove leading and trailing spaces from the volume group name
                vg_name=$(echo "$vg_name" | sed 's/^ *//;s/ *$//')

                # Get the free and total size of the volume group
                VG_FREE=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'vgs --noheadings --readonly --units g --separator : --options vg_free '$vg_name''")
                VG_SIZE=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'vgs --noheadings --readonly --units g --separator : --options vg_size '$vg_name''")
                
                # Remove the unit from the free and total size values
                VG_FREE=$(echo "$VG_FREE" | sed 's/[^0-9.]//g')
                VG_SIZE=$(echo "$VG_SIZE" | sed 's/[^0-9.]//g')

                # Calculate the percentage of free space
                FREE_PERCENT=$(echo "scale=2; $VG_FREE * 100 / $VG_SIZE" | bc)

                # Check if the free space is at least 15%
                if (( $(echo "$FREE_PERCENT >= 15" | bc -l) )); then
                    echo "More than 15% of total extents of volume group $vg_name is available as free extents."
                else
                    echo "WARNING:Volume group $vg_name have less than 15% of total extents of volume group available as free extents."
                fi
            done <<< "$VG_LIST"
        fi

    else
        echo "ERROR: Volume Group detection command not found."
    fi
}


#################################################################################################################
#################################################################################################################



# Below is Alternative method to get free extents percentage for volume group
# (Note: Both Methods gives proper results anyone can be used.)

#################################################################################################################
#################################################################################################################

function volume_group_free_extents_check_linux_v2 {
    echo -e "------- CHECK FOR VOLUME GROUP HAVE 15% OR MORE FREE SPACE -------"

    if command -v vgs >/dev/null 2>&1; then
        # Get a list of all volume groups
        VG_LIST=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'vgs --noheadings --readonly --separator : --options vg_name'")
        VG_LIST=$(echo "$VG_LIST" |  cut -d':' -f2  )
        VG_LIST=$(echo "$VG_LIST" |  tr -d '\r\n'  )



        if [[ -z "$VG_LIST" ]]; then
                echo "No Volume Groups on system."
        else
            echo "List of volume groups:"
            echo "$VG_LIST"

            threshold=15
            # Loop over each volume group
            while IFS=: read -r vg_name; do
                # Remove leading and trailing spaces from the volume group name
                vg_name=$(echo "$vg_name" | sed 's/^ *//;s/ *$//')

                #  Get the used and total extents for the volume group
                extents=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'vgs --noheadings -o vg_extent_size,vg_extent_count $vg_name '")
                extents=$(echo "$extents" | cut -d':' -f2 )
                extents=$(echo $extents | awk '{ print $1 * $2 }' )
            
                used_extents=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c ' vgs --noheadings -o vg_extent_size,vg_free_count $vg_name '")
                used_extents=$(echo "$used_extents" | cut -d':' -f2 )
                used_extents=$(echo $used_extents | awk '{ print ($1 * $2) }')

            
                # Calculate the percentage of used space
                used_percent=$(echo "scale=4; $used_extents / $extents" | bc)
                used_percent=$(echo "scale=2; $used_percent*100" | bc)
                
                # Check if the used percentage exceeds the threshold
                if (( $(echo "$used_percent > $threshold" | bc -l) )); then
                    echo "More than 15% of total extents of volume group $vg_name is available as free extents."
                else
                    echo "WARNING:Volume group $vg_name have less than 15% of total extents of volume group available as free extents."
                fi
            done <<< "$VG_LIST"
        fi

    else
        echo "ERROR: Volume Group detection command not found."
    fi
}


#################################################################################################################
#################################################################################################################



#################################################################################################################
main $host_ip $user $pass
#################################################################################################################



