# Time Backup

Time Backup is a shell script that provides **Time Machine-like backup functionality** for Linux, BSD, and other Unix systems. Inspired by Apple's Time Machine, it brings simple and reliable backup capabilities to platforms outside of macOS.

## Features

- **Full and Partial Backups**: Supports both full system backups and partial backups of specific directories or files.
- **Windows, Linux, macOS, BSD Compatible**: Works across multiple UNIX systems, including macOS, Linux, BSD, Solaris. It can back up files from remote systems incluing Windows shares.
- **Efficient Use of Disk Space**: Utilizes **hard links** to save disk space, ensuring incremental backups without duplicating files.
- **Network Storage Support**: Easily back up to network storage locations such as Windows network shared folders, NAS devices, or use SSH for secure remote backups.
- **Backup on Schedule**: Schedule backups to run automatically using `cron`, or trigger them when a removable drive is connected.

## Requirements

- The script requires the `rsync` utility to be installed on the target system.

## Typical Use Cases

1. **Laptop Backup**: Keep your essential personal files safe with automated backups.
1. **Web Hosting Backup**: Safeguard your hosted websites and databases (e.g., WordPress).
1. **Raspberry Pi Backup**: Ensure your smart home, 3D printer or other Raspberry Pi-based projects are securely backed up.
1. **Cloud Storage Backup**: Back up your data to AWS S3 for offsite storage.

## Usage

### Option 1: Run Directly from GitHub
You can try it out without installing using `curl` or `wget`:

  ```bash
  curl -s https://raw.githubusercontent.com/ananich/time-backup/main/time-backup.sh | bash -s ~/documents /mnt/usb-stick
  ```

### Option 2: Download and Run Locally

Download the script and make it executable:
```bash
curl -O time-backup.sh https://raw.githubusercontent.com/ananich/time-backup/main/time-backup.sh
chmod +x time-backup.sh
```

Schedule *hourly* backups using `cron` from Windows network shared folder `/mnt/net-share` to `/mnt/nas-disk`:

```bash
crontab -l | { cat; echo '0 * * * * $HOME/time-backup.sh /mnt/net-share /mnt/nas-disk'; } | crontab -
```
