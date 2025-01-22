#!/bin/bash

HOSTNAME=$(uname -n | cut -d"." -f1)  # this script is not for enterprises, there are no domains

# Configuration parameters
SOURCE="$1"
BACKUP_DIR="$2/$HOSTNAME"
LOCKFILE="/tmp/$(basename "$0" .sh).lock"
LATEST_DIR="$BACKUP_DIR/latest"

# Define platform-dependant rsync options for further use
uname -o | grep -q 'Darwin' && RSYNC_OPTS="-aEH" || RSYNC_OPTS="-aAXH"  # "Darwin" or "GNU/Linux"

# Ensure only one instance runs
[ -f "$LOCKFILE" ] && { echo "Backup script is already running. Exiting."; exit 1; }
touch "$LOCKFILE"

# Create a temporary exclude list
EXCLUDE_LIST=$(mktemp)
mount | grep '^[^/]' | sed -n -e 's/^.* on \(.*\)(.*/\1/p' | cut -d ' ' -f1 > "$EXCLUDE_LIST"
cat >> "$EXCLUDE_LIST" <<- EOF
/mnt
/tmp/*
/Volumes/*
EOF

# Cleanup lockfile and exclude file on exit
trap 'rm -f "$LOCKFILE" "$EXCLUDE_LIST"; exit $?' INT TERM EXIT

# Extract available space in the backup directory filesystem
AVAILABLE_SPACE=$(df -k "$BACKUP_DIR" | tail -1 | awk '{print $4}')
AVAILABLE_SPACE_BYTES=$(( AVAILABLE_SPACE * 1024 ))
AVAILABLE_SPACE_HUMAN=$(df -h "$BACKUP_DIR" | tail -1 | awk '{print $4}')
echo "Available space on backup disk: $AVAILABLE_SPACE_HUMAN"

# Extract the estimated data to be transferred
TRANSFERRED_SIZE=$(rsync "$RSYNC_OPTS" --dry-run --stats --exclude-from="$EXCLUDE_LIST" --human-readable "$SOURCE" "$LATEST_DIR" \
    | grep "Total transferred file size" | awk -F: '{print $2}' | awk -F' ' '{print $1}' | xargs)
echo "Estimated backup size: $TRANSFERRED_SIZE"
TRANSFERRED_SIZE_BYTES=$(rsync "$RSYNC_OPTS" --dry-run --stats --exclude-from="$EXCLUDE_LIST" "$SOURCE" "$LATEST_DIR" \
    | grep "Total transferred file size" | awk -F: '{print $2}' | awk -F' ' '{print $1}' | xargs)

# Prune backups if there isn't enough space
if (( AVAILABLE_SPACE_BYTES < TRANSFERRED_SIZE_BYTES )); then
    echo "Not enough space for the backup. Pruning old backups..."

    # Prune backups from hourly, daily, or weekly
    while (( AVAILABLE_SPACE_BYTES < TRANSFERRED_SIZE_BYTES )); do
        # Find the oldest backup file in hourly, daily, and weekly directories
        OLDEST_BACKUP=$(ls "$BACKUP_DIR" | head -n 1)
        echo "Removing $BACKUP_DIR/$OLDEST_BACKUP"
        rm -rf "$BACKUP_DIR/$OLDEST_BACKUP"
        
        # Update available space
        AVAILABLE_SPACE=$(df -k "$BACKUP_DIR" | tail -1 | awk '{print $4}')
        AVAILABLE_SPACE_BYTES=$(( AVAILABLE_SPACE * 1024 ))
    done

    # Check if there is still not enough space
    if (( AVAILABLE_SPACE_BYTES < TRANSFERRED_SIZE_BYTES )); then
        echo "Not enough space for backup, even after pruning old backups. Exiting."
        rm -f "$EXCLUDE_LIST"
        exit 1
    fi
fi

echo "Backing up..."
# generate list of changed files, skip all the directories and delete these hard links from LATEST_DIR
rsync -nr --out-format='%i %f' --dry-run --exclude-from="$EXCLUDE_LIST" "$SOURCE" "$LATEST_DIR" \
    | grep '^.[^d].*' | sed -n -e 's/^.* //p' | while read -r line; do rm -f "${LATEST_DIR}${line#"$SOURCE"}"; done

# Rsync changes to the latest backup
rsync "$RSYNC_OPTS" --delete --exclude-from="$EXCLUDE_LIST" "$SOURCE/" "$LATEST_DIR/" || exit 1  #  --progress

# Get the current timestamp for cleanup reference
CURRENT_TIMESTAMP=$(date +%s)
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M")

# Clone directory structure and create hard links 
cp -al "$LATEST_DIR" "$BACKUP_DIR/tmp"
mv "$BACKUP_DIR/tmp" "$BACKUP_DIR/$CURRENT_DATE" || exit 1

# Prune outdated backups
echo "Cleaning up outdated backups..."

# Get all directories in the backup folder and sort them in descending order
backup_dirs=$(ls "$BACKUP_DIR" | sort -r)
# Create an empty list for processed days and weeks
processed_days=""
processed_weeks=""

for backup_dir in $backup_dirs; do
    [ "$backup_dir" == "latest" ] && continue  # latest should never be deleted
    day=$(echo "$backup_dir" | cut -d'_' -f1)
    week=$(date -jf '%Y-%m-%d_%H-%M' "$backup_dir" +"%Y-%W")

    # Skip the first 24 hours
    #FILE_TIMESTAMP=$(stat -f %m "$BACKUP_DIR/$backup_dir")
    FILE_TIMESTAMP=$(date -jf '%Y-%m-%d_%H-%M' "$backup_dir" +%s)
    (( CURRENT_TIMESTAMP - FILE_TIMESTAMP < 24 * 60 * 60 )) && continue
    # Prunge hourly backups 
    echo "$processed_days" | grep -q "$day" && rm -rf "$BACKUP_DIR/$backup_dir" || processed_days="$processed_days\n$day"

    # Skip the first 30 days
    (( CURRENT_TIMESTAMP - FILE_TIMESTAMP < 30 * 24 * 60 * 60 )) && continue
    # Prunge daily backups
    echo "$processed_weeks" | grep -q "$week" && rm -rf "$BACKUP_DIR/$backup_dir" || processed_weeks="$processed_weeks\n$week"
done

# Output the status
echo "Backup completed. Latest backup: $CURRENT_DATE"