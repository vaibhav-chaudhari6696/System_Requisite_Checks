#!/bin/bash


  
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^     LINUX     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
    #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#



host=$1
username=$2
password=$3






#################################################################################################################
#################################################################################################################

# echo -e "------- PUBLIC KEY TRANSFER -------"

# # Define variable for public key file path
# PUBLIC_KEY_FILE="/path/to/public_key_file.pub"
# # Check if public key file exists
# if [ ! -f $PUBLIC_KEY_FILE ]; then
#     echo "Public key file not found."
#     exit 1
# fi

# # Copy public key to remote device using sshpass
# sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'< $PUBLIC_KEY_FILE"

# # Check if copy was successful
# if [ $? -eq 0 ]; then
#     echo "Public key successfully copied to remote device."
# else
#     echo "Failed to copy public key to remote device."
# fi


#echo -e "-------------------------------------------------------------------------------\n\n"
#################################################################################################################
#################################################################################################################









#################################################################################################################
#################################################################################################################

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
            sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'usermod -aG sudo $username >/dev/null'"
            echo "Added  user $username to sudo group"
        fi


        # Check if the user has passwordless sudo access
        command_output=$(sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'sudo -l'")

        if echo "$command_output" | grep -q "(ALL) NOPASSWD: ALL"; then
            echo "User has passwordless sudo access."
        else
            echo "User does not have passwordless sudo access."

            # Add the user to the sudoers file with passwordless access
            sshpass -p "$password" ssh -t -t -n "$username@$host" "echo \"$password\" | sudo -S sh -c 'echo \"$username ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers'"
            echo "User has been added to the sudoers file with passwordless access."
        fi
        
    fi
fi

echo -e "-------------------------------------------------------------------------------\n\n"

#################################################################################################################
#################################################################################################################










#################################################################################################################
#################################################################################################################

echo -e "------- CHECK FOR VOLUME GROUP HAVE 15% OR MORE FREE SPACE -------"

if command -v vgs >/dev/null 2>&1; then
    # Get a list of all volume groups
    VG_LIST=$(sshpass -p "$password" ssh -n "$username@$host" "sudo vgs --noheadings --readonly --separator : --options vg_name")
    
    if [[ -z "$VG_LIST" ]]; then
            echo "No Volume Groups on system."
    else
        # Loop over each volume group
        while IFS=: read -r vg_name; do
            # Remove leading and trailing spaces from the volume group name
            vg_name=$(echo "$vg_name" | sed 's/^ *//;s/ *$//')

            # Get the free and total size of the volume group
            VG_FREE=$(sshpass -p "$password" ssh -n "$username@$host" "sudo vgs --noheadings --readonly --units g --separator : --options vg_free "$vg_name"")
            VG_SIZE=$(sshpass -p "$password" ssh -n "$username@$host" "sudo vgs --noheadings --readonly --units g --separator : --options vg_size "$vg_name"")

            # Remove the unit from the free and total size values
            VG_FREE=$(echo "$VG_FREE" | sed 's/[^0-9.]//g')
            VG_SIZE=$(echo "$VG_SIZE" | sed 's/[^0-9.]//g')

            
            # Calculate the percentage of free space
            FREE_PERCENT=$(echo "scale=2; $VG_FREE * 100 / $VG_SIZE" | bc)

            # Check if the free space is at least 15%
            if (( $(echo "$FREE_PERCENT >= 15" | bc -l) )); then
                echo "Volume group $vg_name has more than 15% free space"
                
            else
                echo "Volume group $vg_name has less than 15% free space"
            fi
        done <<< "$VG_LIST"
    fi

else
    echo "ERROR: Volume Group detection command not found."
fi

#################################################################################################################
#################################################################################################################






