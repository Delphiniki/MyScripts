# This architecture ensures a 3-2-1 backup strategy (3 copies of data, 2 different media, 1 offsite) while solving the issue of Veeam chaotic naming conventions.
This unified setup ensures your daily Veeam image is correctly captured by ZFS and that your weekly Restic upload adheres to your 4-week retention policy with full logging and NTFY alerts.
I use zfs snapshot 30 days retention policy and cloud retention - 4 week snapshots per month.So i have last 4 week snapshots on cloud.

## Windows bat script :
Create a job in Veeam Agent ,without schedule, with backup repository SMB share "veeam_backup" on Truenas .I use script in C:\Scripts\RunVeeamFull.bat, totrigger backup  :

```cmd
@echo off
"C:\Program Files\Veeam\Endpoint Backup\Veeam.EndPoint.Manager.exe" /standalone 
```

## Create a scheduled task in Windows :
Create a task in Windows to trigger .bat script everyday ,creating a new backup:
1. Open Task Scheduler: Press Win + R, type taskschd.msc, and hit Enter.
2. Create Task: In the "Actions" pane on the right, do not create "basic" task...
3. Name the Task: Give your task a name (e.g., "Daily Veeam Backup") and click Next.User Account: Ensure it's set to an Administrator account, enable "Run with highest privileges".Select "Run wether user is logged on or not", configure for Windows 10/11.
4. Set Trigger: Select Daily and click Next.
5. Set Time: Set the start time to 5:00:00 AM and ensure "Recur every: 1 days" is selected. Click Next.
6. Set Action: Choose Start a program and click Next.
7. Select Script: Click Browse... and select your .bat file.
8. Critical Configuration: In the "Start in (optional)" field, enter the full path to the folder containing your script (e.g., C:\Scripts\). This ensures your script finds any relative files it needs.
(Optional: Check "Wake the computer to run this task" if your PC might be asleep at 5:00 AM.)
9. Finish and Save: Click Finish
	
## Docker Compose (docker-compose.yml)
I use restic container inside Truenas machine 
Place this in your Restic configuration directory (e.g., /mnt/pool/appdata/restic/).

```yaml
services:
  restic-worker:
    image: tofran/restic-rclone:latest
    container_name: restic_veeam_uploader
    hostname: truenas-home
    entrypoint:
      - tail
      - -f
      - /dev/null
    restart: always
    volumes:
      # Symlink managed by the shell script
      - /mnt/Tank/veeam_backup:/data:ro
      # Configuration and Credentials
      - /mnt/Tank/restic-backups/config/rclone.conf:/root/.config/rclone/rclone.conf:ro
      - /mnt/Tank/restic-backups/passwords:/passwords:ro
    environment:
      - RESTIC_REPOSITORY=rclone:nextcloud:restic-veeam-backup/backups
      - RESTIC_PASSWORD_FILE=/passwords/restic_repo_pass.txt
      - RCLONE_PASSWORD_FILE=/passwords/rclone_pw.txt
      #- RCLONE_PASSWORD_COMMAND=cat /passwords/rclone_pw.txt
      - TZ=Europe/Sofia
    network_mode: bridge
```

-----------------------------------------------
### The script:
I placed the script inside a folder "'/mnt/Tank/scripts'restic-veeam=uploader.sh".Scheduled in Truenas cronjobs:
```bash
#!/bin/bash

# --- CONFIGURATION ---
BASE_PATH="/mnt/Tank/veeam_backup"
LOG_FILE="/mnt/Tank/scripts/logs/restic-backup.log" 
CONTAINER="restic_veeam_uploader" 
NTFY_URL="https://ntfy.sh" 
NTFY_TOKEN="tk_xxxxxxxxxxxxxxxxxxxxxxx"

# 1. LOGGING INITIALIZATION
exec > >(tee -a "$LOG_FILE") 2>&1
echo "--- Process Started: $(date) ---"

# 2. VEEAM MANAGEMENT (Daily)
cd "$BASE_PATH" || { echo "Error: Cannot enter dataset path"; exit 1; }

echo "Cleaning and Organizing folders..."
# A. CATCH THE FOLDER USING GLOBBING
# This looks for any folder containing "adhoc" in the current directory
NEW_FOLDER=$(ls -d *adhoc* 2>/dev/null | head -n 1)

if [ -n "$NEW_FOLDER" ]; then
    echo "Found new backup: $NEW_FOLDER. Organizing..."
    # Force remove old static folder
    rm -rf "LatestBackup"
    # Move the new folder
    mv -f "$NEW_FOLDER" "LatestBackup"
    echo "Success: $NEW_FOLDER is now LatestBackup"
else
    echo "No fresh adhoc folder found (already organized)."
fi

# 2A. OPTIONAL CLEANUP
# Delete anything that is REALLY old (older than 24h) just in case
find . -maxdepth 1 -type d -name "*_adhoc_*" -mtime +0 -exec rm -rf {} +
# 3. WEEKLY RESTIC UPLOAD (Sundays only - Day 7)
if [ "$(date +%u)" -eq 7 ]; then
    echo "Day is Sunday. Initiating Cloud Upload..."

    if [ ! -d "$BASE_PATH/LatestBackup" ]; then
        echo "Error: LatestBackup folder not found!"
        exit 1
    fi

    docker exec $CONTAINER restic -o rclone.program=/usr/bin/rclone unlock
    
    echo "Starting Restic backup to Nextcloud..."
    if docker exec $CONTAINER restic \
       -o rclone.program=/usr/bin/rclone \
       backup "/data" --exclude "/data/.zfs" --host truenas-home && \
       docker exec $CONTAINER restic \
       -o rclone.program=/usr/bin/rclone \
       forget --host truenas-home --keep-weekly 4 --prune --max-unused 5%; then
        
        curl -H "Authorization: Bearer $NTFY_TOKEN" \
             -d "✅ Restic: Weekly sync complete." "$NTFY_URL"
    else
        curl -H "Authorization: Bearer $NTFY_TOKEN" \
             -d "❌ Restic: Backup failed." "$NTFY_URL"
    fi
else
    echo "Not Sunday. Skipping Cloud Upload."
fi

# 4. LOG ROTATION
tail -n 5000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
echo "--- Process Finished: $(date) ---"

```

## The flow :

| Time    | Action |
| -------- | ------- |
| 	05:00  |  Veeam Standalone	Windows	Creates a fresh, timestamped _adhoc_ folder on the NAS.  |
| 	05:55 | Daily Organizer	Script	Renames the _adhoc_ folder to LatestBackup.     |
|  	06:00    | ZFS Snapshot	TrueNAS	Freezes the dataset, capturing a clean /LatestBackup/ path.    |
|  	06:05    | Cloud Sync (Sunday)	Restic	Uploads the static /LatestBackup/ path to the Cloud.    |

Pro-tip: You can include the VeeamRecovery iso file in that "veeam_backup" dataset.So the iso will be in the cloud repository,even if the NAS server is damaged.

## Restore from cloud flow:
Assuming ,the restore dataset is named "restore-test"
Pull from Cloud (TrueNAS Shell)
You use Restic to "dump" the file back onto your TrueNAS.
```bash
# 1. List snapshots to find the date you want
docker exec restic_veeam_uploader restic snapshots

# 2. Dump the .vbk file from the cloud to your NAS
# (Replace ID with the snapshot ID from step 1)
docker exec restic_veeam_uploader restic restore [SNAPSHOT_ID] --target /mnt/Tank/restore-test/ --include /data/LatestBackup

```

Now that the file is back on your NAS, you treat it like a local backup.
1. Boot the target machine using the Veeam Recovery Media (ISO).
2. Select "Bare Metal Recovery".
3. Select "Network Storage" and point it to your TrueNAS SMB share.
4. Browse to the /restore-test/ folder where you extracted the files.
5. Veeam will see the .vbm file, load the restore points, and begin overwriting the local disk.

## ⚙️ Strategic Logic: The "Waterfall" Effect
This setup utilizes a precise timeline to ensure maximum storage efficiency and data integrity.
1. Path Standardization
Veeam standalone backups create unique, timestamped folders (e.g., _adhoc_2026...). This is chaotic for long-term tracking. By using the Globbing Method (ls -d *adhoc*), the script captures the newest backup regardless of its age and renames it to a static directory: LatestBackup.
2. ZFS Deduplication Efficiency
By maintaining a static folder name (LatestBackup), ZFS snapshots see changes as block-level updates to the same files rather than the creation of entirely new directories. This allows for:

    Near-zero overhead for daily local snapshots.
    Instant comparison between yesterday and today's data.

3. Restic Content-Addressable Sync
Because the path /data/LatestBackup never changes, Restic's deduplication engine performs a "lightning-fast" scan. Even if the .vbk is 14GB, Restic only uploads the specific changed chunks, drastically reducing bandwidth and cloud storage costs.
4. The "Secret Agent" (VSS)
The system relies on the Windows Volume Shadow Copy Service (VSS). By keeping VSS on Manual, the Veeam Agent "summons" it only during the 05:00 AM window, keeping the Windows OS lean and bloat-free during the day.

