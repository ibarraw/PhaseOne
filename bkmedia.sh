#!/bin/bash

# Store our data location in a variable
DATA="locations.cfg"
currentDateTime=$(date +"%Y_%m_%d---%H_%M_%S_%3N")  #YYYY_MM_DD---HH_MM_SS_MMM
BACKUP_LOG_DIR="backup_logs"
BACKUP_DIR="backups"
RESTORE_DIR="restored"


# Styling for log detection in red
red=$(tput setaf 1)
normal=$(tput sgr 0)

# Function to display all locations in $DATA
displayLocations() {
    if [[ ! -f $DATA ]]; then
        echo "$DATA not found!"
        exit 1
    fi

    nl -s '. ' "$DATA"
}

# Function to log actions to a single file with millisecond precision
logAction() {
    mkdir -p "$BACKUP_LOG_DIR"
    local LOG_FILE="$BACKUP_LOG_DIR/${currentDateTime}_backup.log"

    # Ensure the log file exists and is writable
    touch "$LOG_FILE" || { echo "Error: Unable to write to log file $LOG_FILE"; exit 1; }

    echo "$(date +"%Y-%m-%d %H:%M:%S.%3N") - $1" >> "$LOG_FILE"
}


calculateChecksum() {
    sha256sum "$1" | awk '{ print $1 }'
      
    #TODO: Implement checksum for cloud storage for challenge #3
    #aws_checksum=$(calculate_checksum "s3://bucket/$file")
    
    #azure_checksum=$(calculate_checksum "azure://)
    
    #gcp_checksum=$(calculate_checksum "gs://")
}

# Function to detect and handle phantom alterations
handlePhantom() {
	
    local originalDir="$1"
    local backupDir="$2"
    local phantomFileName="cat.png" # The phantom file we are simulating

    # Loop through each file in the original directory
    for file in "$originalDir"/*; do
    
        # Check if the file exists
        if [[ -f $file ]]; then
            local fileName=$(basename "$file")
            local originalFile="$originalDir/$fileName"
            local backupFile="$backupDir/$fileName"

            local originalChecksum=$(calculateChecksum "$originalFile")

            # Check if backup file exists
            if [[ -f $backupFile ]]; then

                local backupChecksum=$(calculateChecksum "$backupFile")

                if [[ "$fileName" == "$phantomFileName" ]]; then
                    newBackupFileName="${backupFile}.phantom"

                    echo "Add Phantom modification to backupFile" >> "$backupFile"
                    newBackupChecksum=$(calculateChecksum "$backupFile")
                    cp "$backupFile" "$newBackupFileName"

                    logAction ""
                    logAction "${red}Phantom file detected: $fileName${normal}"
                    logAction "${red}Original checksum: $originalChecksum${normal}"
                    logAction "${red}New checksum: $newBackupChecksum${normal}"
    
                else
                    logAction ""
                    logAction "Original checksum of $fileName: $originalChecksum"
                    logAction "New checksum of $fileName: $backupChecksum"
                fi

            else
                logAction ""
                logAction "Backup file $backupFile not found."
            fi
        fi
    done

    #     # Copy all .phantom files to backup directory
    # cp "$originalDir"/*.phantom "$backupDir"
}

# Function to perform backup for all locations
backupLocations() {
    mkdir -p "$BACKUP_DIR"

    logAction "Starting full backup for all locations."

    logAction "------------------------------------"
    logAction "------------------------------------"

    while IFS= read -r LINE; do
        if [[ -n "$LINE" ]]; then
            addressPath=$(echo "$LINE" | cut -d':' -f2- | sed 's#^/##')
            if [[ -z $addressPath ]]; then
                logAction "Skipping line due to invalid format."
                continue
            fi
		#echo "Address path is " "$addressPath"
		
            logAction "Backing up $addressPath"
            mkdir -p "$BACKUP_DIR/${currentDateTime}"
            #rsync -avz "$addressPath" "$BACKUP_DIR/${currentDateTime}_$(basename "$addressPath")"
            rsync -avz "$addressPath" "$BACKUP_DIR/${currentDateTime}/$(basename "$addressPath")"
            handlePhantom "$addressPath" "$BACKUP_DIR/${currentDateTime}/$(basename "$addressPath")"
            logAction ""
            logAction "Backup of $addressPath completed."
            logAction "------------------------------------"

        fi
    done < "$DATA"

    logAction "------------------------------------"
    logAction "Full backup completed."
}

# Function to backup a specific location by line number
# Function to backup a specific location by line number
backupSpecificLine() {
    local lineNumber=$1

    if [[ ! -f $DATA ]]; then
        echo "Data file $DATA not found!"
        exit 1
    fi

    if [[ -z $lineNumber ]]; then
        echo "No line number specified!"
        exit 1
    fi

    location=$(sed -n "${lineNumber}p" "$DATA")
    if [[ -z $location ]]; then
        echo "Invalid line number!"
        exit 1
    fi

    mkdir -p "$BACKUP_DIR"

    addressPath=$(echo "$location" | cut -d':' -f2- | sed 's#^/##')
    if [[ -z $addressPath ]]; then
        logAction "Skipping line due to invalid format."
        exit 1
    fi

    logAction "Starting backup for line $lineNumber: $addressPath"

    # Construct backup directory name with Line_x suffix
    backupDir="$BACKUP_DIR/${currentDateTime}_Line_${lineNumber}"
    mkdir -p "$backupDir/$addressPath"    
    # Use rsync with -avz options to backup files and directories recursively
    rsync -avz "$addressPath/" "$backupDir/$addressPath"

    handlePhantom "$addressPath" "$backupDir"

    logAction ""
    logAction "Backup for line $lineNumber: $addressPath completed."
    logAction "------------------------------------"
}


listBackups() {
    local backups=($(ls -d "$BACKUP_DIR"/* | sort -r))

    if [[ ${#backups[@]} -eq 0 ]]; then
        echo "No backups found."
        exit 1
    fi

    printf "Available backups (Most recent to oldest):\n\n"
    for ((i = 0; i < ${#backups[@]}; i++)); do
        echo "$((i + 1)). $(basename "${backups[$i]}")"  # Displaying just the directory name
    done
}


# Function to restore a backup to the restored directory
# Function to restore a backup to the restored directory
restoreRecentBackup() {
    printf "Starting restore...\nRestoring from recent backup index with backup number: $1\n"
    local backupIndex=$(($1 - 1))
    local backups=($(ls -d "$BACKUP_DIR"/* | sort -r))

    if [[ $backupIndex -lt 0 || $backupIndex -ge ${#backups[@]} ]]; then
        echo "Invalid backup number: $1"
        exit 1
    fi

    local backupDir="${backups[$backupIndex]}"
    printf "Selected backup directory: $backupDir\n"
    logAction "Starting restore from backup directory $backupDir."

    mkdir -p "$RESTORE_DIR"

    # Use rsync to preserve directory structure
    rsync -avz "$backupDir/" "$RESTORE_DIR/"

    logAction "Restore from backup directory $backupDir to $RESTORE_DIR completed."
}


restoreBackupFromLine() {
    local lineNumber=$1

    if [[ ! -f $DATA ]]; then
        echo "Data file $DATA not found!"
        exit 1
    fi

    location=$(sed -n "${lineNumber}p" "$DATA")
    echo "Location is $location"
    if [[ -z $location ]]; then
        echo "Invalid line number: $lineNumber"
        exit 1
    fi

    mkdir -p "$BACKUP_DIR"

    addressPath=$(echo "$location" | cut -d':' -f2- | sed 's#^/##')
    if [[ -z $addressPath ]]; then
        logAction "Skipping line due to invalid format."
        exit 1
    fi

    logAction "Starting restore from location $lineNumber: $addressPath"

    # Find the most recent backup directory
    local recentBackup=$(ls -d "$BACKUP_DIR"/* | sort -r | head -n 1)

    mkdir -p "$RESTORE_DIR"

    # Restore specific files from the specified location within the most recent backup
    rsync -avz "$recentBackup/$(basename "$addressPath")" "$RESTORE_DIR/"

    logAction "Restore from location $lineNumber: $addressPath completed."
}


# TODO: Alternative to case statement?
# Parse script arguments
while getopts ":BRL:I" option; do
    case "${option}" in
        B)
            # TODO: This error checking is not comprehensive enough. Better Technique?
            if [[ $2 == "-L" && -n $3 ]]; then
                echo "Backing up specific line: $3"
                backupSpecificLine "$3"
                exit 1
            # -B {letter} still breaks the code
            elif [[ $2 =~ ^[0-9]+$ ]]; then
                echo "Error: Invalid usage. Option -B cannot be followed by a number by itself. Must be in format -B -L <Line Number> or -B."
                exit 1
            elif [[ $2 == "-L" && -z $3 ]]; then
                echo "Error: Invalid usage. Option -L must be followed by a line number."
                exit 1
            else
                backupLocations
            fi
            exit 0
            ;;
        R)
            # TODO: Change this to be more robust; too many if statements isn't the solution if I want to expand
            if [[ $1 == "-R" && -n $2 ]]; then
                restoreRecentBackup "$2"
            elif [[ $1 == "-R" && $2 == "-L" && -n $3 ]]; then
                restoreBackupFromLine "$3"
            else
                printf "No backup number specified. Command must be in format: -R <Backup Number>\n\n"
                listBackups
            fi
            exit 0
            ;;
        I)
            echo "-I is still in development."
            exit 0
            ;;
        L)
            listBackups
            exit 0
            ;;
        *)
            echo "Defaulting to display locations."
            displayLocations
            exit 0
            ;;
    esac
done

# If no options were included, display locations
if [[ $# -eq 0 ]]; then
    displayLocations
fi
