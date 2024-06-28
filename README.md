# bkmedia.sh

`bkmedia.sh` is a bash script for managing backups and restores based on locations specified in `locations.cfg`.

## Prerequisites

- **Bash**
- **rsync**

## Configuration

Create a `locations.cfg` file with locations to backup, one per line:

user@hostname:/path/to/directory/

## Usage

Run the script with the following options:

./bkmedia.sh [OPTION]

### Options

- `-B`: Backup all locations.
  - `-B -L <line_number>`: Backup specific location by line number.
- `-R <backup_number>`: Restore recent backup by index.
  - `-R -L <line_number>`: Restore specific location by line number.
- `-V`: List available backups.
- `-I`: Development option.

If no options are provided, it lists locations in `locations.cfg`.

## Directories

- **Backups**: `backups/`
- **Restores**: `restored/`
- **Logs**: `backup_logs/`

## Examples

- Simple locations.cfg output `./bkmedia.sh`
- Backup all locations: `./bkmedia.sh -B`
- Backup all locations Error: `./bkmedia.sh -B 2`
- Backup specific line: `./bkmedia.sh -B -L 2`
- Restore recent backup Error: `./bkmedia.sh -R`
- Restore recent backup: `./bkmedia.sh -R 1`
- List backups: `./bkmedia.sh -V`

Ensure `locations.cfg` exists and is properly formatted before running the script.
