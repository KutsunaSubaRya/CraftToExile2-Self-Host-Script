# CraftToExile2 Self-Host Script

A comprehensive automation suite for self-hosting a CraftToExile2 Minecraft server with automated tunnel management, monitoring, and maintenance.

## Overview

This project provides a complete solution for running a CraftToExile2 modded Minecraft server with automated management through cron scheduling. The system handles server startup, Cloudflare tunnel management, performance monitoring, log archiving, and graceful server restarts.

**Target Audience**: Designed for small to medium-sized communities with up to 8 concurrent players. This automation suite provides reference scripts for self-hosted modded Minecraft server administrators who want to implement automated management and monitoring systems.

## Quick Start Note

**Important**: Before using these scripts, search for `TODO` annotations in the source code using `Ctrl + F` (or `Cmd + F` on macOS) to identify configuration values that need to be customized for your environment, such as:
- RCON passwords
- Domain names
- File paths
- Server-specific settings

**RCON Configuration**: Ensure your `server.properties` file has `rcon.password=` set to your desired password, as this is required for the monitoring and restart scripts to function properly.

## Recommended Configuration

### Software Versions
- **CraftToExile2**: 1.0.5
- **Forge**: 47.4.4
- **Minecraft**: 1.20.1

### Hardware Specifications
- **CPU**: 4 cores
- **RAM**: 14 GB
- **Environment**: PVE VM (Proxmox Virtual Environment)

**Note**: This configuration has been tested and optimized for optimal performance. While the scripts will work on other configurations, this setup provides a reliable baseline for modded Minecraft servers with 8+ concurrent players.

## Workflow

The system operates through a coordinated workflow managed by cron jobs:

1. **Tunnel First**: Cron triggers `cloudflared_tunnel_start.sh` immediately on boot
2. **Delayed Server Start**: After 15 seconds, `start.sh` is executed to launch the Minecraft server
3. **Sequential Execution**: Tunnel establishment precedes server startup to ensure external connectivity is ready
4. **Continuous Operation**: The server runs continuously with automated monitoring and maintenance
5. **Scheduled Tasks**: Regular health checks, log archiving, and performance monitoring via cron

## Scripts Overview

| Script | Purpose | Cron Schedule | Description |
|--------|---------|---------------|-------------|
| `start.sh` | Minecraft Server Launcher | On server boot | Initializes and starts the Minecraft server in a named screen session |
| `cloudflared_tunnel_start.sh` | Tunnel Manager | On server boot | Establishes Cloudflare tunnel for external server access |
| `rcon-spark.sh` | Performance Monitor | Every 5 minutes | Collects server performance metrics and health data |
| `archive-logs.sh` | Log Management | Daily | Archives old log files and maintains backup rotation |
| `mc-restart.sh` | Server Control | Manual/On-demand | Handles graceful server restarts with countdown notifications |

## Dependencies

- **screen**: Terminal multiplexer for background process management
- **cloudflared**: Cloudflare tunnel client for external access
- **mcrcon**: RCON client for Minecraft server communication
- **zip/tar**: Archive utilities for log compression
- **openjdk-21-jdk**

## JVM Configuration

The `user_jvm_args.txt` file contains optimized JVM parameters for modded Minecraft servers:

### Memory Management
- `-Xms10G -Xmx12G`: Sets initial and maximum heap size to 10GB and 12GB respectively
- `-XX:+UseG1GC`: Enables G1 Garbage Collector for better performance
- `-XX:+ParallelRefProcEnabled`: Enables parallel reference processing

### Garbage Collection Tuning
- `-XX:MaxGCPauseMillis=200`: Targets maximum GC pause time of 200ms
- `-XX:G1NewSizePercent=20`: Sets new generation size to 20% of heap
- `-XX:G1MaxNewSizePercent=60`: Limits new generation to 60% of heap
- `-XX:G1ReservePercent=20`: Reserves 20% of heap to prevent allocation failures
- `-XX:InitiatingHeapOccupancyPercent=15`: Triggers GC when 15% of heap is occupied

### Performance Optimizations
- `-XX:+UseStringDeduplication`: Reduces memory usage through string deduplication
- `-XX:+DisableExplicitGC`: Prevents manual garbage collection calls
- `-XX:+UnlockExperimentalVMOptions`: Enables experimental JVM features

### Monitoring and Profiling
- `-Xlog:gc*`: Enables comprehensive garbage collection logging
- `-XX:StartFlightRecording`: Activates Java Flight Recorder for performance analysis
- `-XX:FlightRecorderOptions=stackdepth=128`: Sets stack depth for profiling

## Script Details

### start.sh

**Purpose**: Primary server launcher that initializes the Minecraft server environment.

**Key Features**:
- Creates timestamped log files in `logs/` directory
- Prevents duplicate server instances by checking existing screen sessions
- Uses `stdbuf` for real-time log output buffering
- Launches server in detached screen session named 'mc'

**Cron Integration**: Triggered on server boot to ensure automatic server startup.

**Technical Details**:
- Uses `set -euo pipefail` for strict error handling
- Creates logs directory if it doesn't exist
- Generates unique log filenames with timestamp format: `latest-YYYYMMDD-HHMM.log`
- Implements screen session conflict detection

### cloudflared_tunnel_start.sh

**Purpose**: Establishes and maintains Cloudflare tunnel for external server access.

**Key Features**:
- Creates DNS route for your domain
- Establishes TCP tunnel to local Minecraft server (ex. default port 25565)
- Runs in background screen session named 'tunnel'

**Cron Integration**: Executes on server boot to ensure tunnel availability.

**Technical Details**:
- Single-line script combining DNS routing and tunnel creation
- Uses `screen -dmS` for background execution
- Connects external domain to local server through Cloudflare's infrastructure

### rcon-spark.sh

**Purpose**: Comprehensive server monitoring and performance data collection.

**Key Features**:
- Collects real-time player count and server statistics
- Tracks server properties and view distance settings
- Executes Spark profiling commands for performance analysis
- Monitors JVM memory usage and configuration

**Cron Integration**: Runs every 5 minutes for continuous health monitoring.

**Technical Details**:
- Implements RCON connection with retry logic (6 attempts, 10-second intervals)
- Captures console output changes for Spark command results
- Extracts JVM parameters from running process or command line
- Generates daily log files with timestamped entries
- Uses `dd` command for precise log segment extraction

### archive-logs.sh

**Purpose**: Automated log file management and archival system.

**Key Features**:
- Archives inactive log files older than 5 minutes (prevents compression of actively writing files)
- Maintains backup rotation (keeps last 14 archives - 2 weeks)
- Supports both ZIP and TAR compression formats
- Excludes active console and current day logs

**Cron Integration**: Executes daily to maintain log storage efficiency.

**Technical Details**:
- Uses `find` with `-mmin +5` to identify inactive files (5+ minutes since last modification)
- Implements smart filtering to preserve active logs
- Automatically removes archived files after successful compression
- Falls back to tar.gz if zip utility is unavailable
- Implements backup retention policy to prevent unlimited growth
- **5-minute delay strategy**: Prevents compression of actively writing files like:
  - Current console logs (`latest-*.log`) being written by `tee`
  - Today's Spark logs (`spark-YYYYMMDD.log`) being updated every 5 minutes
  - Active JFR/GC logs being generated by JVM

### mc-restart.sh

**Purpose**: Graceful server restart management with player notifications.

**Key Features**:
- Multiple restart modes (5-minute, 30-second, 15-second, immediate)
- In-game countdown notifications with sound effects
- Single-instance locking to prevent cron conflicts
- Automatic server restart after shutdown
- Built-in help system with `--help` flag
- Input validation and error handling for unknown options

**Cron Integration**: Manual execution or scheduled maintenance windows.

**Technical Details**:
- Uses `flock` for single-instance execution prevention
- Implements RCON-based in-game messaging system
- Supports custom notification prefixes and sound effects
- Handles both restart and shutdown modes
- Automatically executes `start.sh` after server stop
- **Help system**: Provides comprehensive usage information with `--help`, `-h`, `help` flags
- **Input validation**: Detects unknown options and displays help automatically
- **Error handling**: Gracefully handles invalid input with helpful error messages

## Cron Configuration

Recommended cron schedule for automated operation:

```bash
# Server startup (on boot)
@reboot /path/to/cloudflared_tunnel_start.sh
@reboot sleep 15 && /path/to/start.sh

0 */6 * * * /path/to/mc-restart.sh
*/15 * * * * /path/to/rcon-spark.sh

0 4 * * * /path/to/archive-logs.sh
```

**Note**: The 15-second delay between tunnel and server startup ensures:
- Cloudflare tunnel is fully established before Minecraft server begins
- External connectivity is ready when players attempt to connect
- Prevents connection issues during the initial server startup phase

## File Structure

```
yourMCDirectory/
├── start.sh                    # Server launcher
├── cloudflared_tunnel_start.sh # Tunnel manager
├── rcon-spark.sh              # Performance monitor
├── archive-logs.sh            # Log archiver
├── mc-restart.sh              # Server controller
├── user_jvm_args.txt          # JVM optimization parameters
└── README.md                  # This documentation
```

## Troubleshooting

- **Server won't start**: Check screen session conflicts and log file permissions
- **RCON failures**: Ensure server is running and RCON is enabled
- **Log archiving fails**: Check available disk space and compression utilities

## Other Maintenance

### Real-time Log Monitoring
Monitor server logs in real-time using tail:
```bash
tail -f logs/latest-*.log
```

### Check Online Player Count
Query current online players using mcrcon:
```bash
/usr/bin/mcrcon -H 127.0.0.1 -P 25575 -p 'yourPassword' "list"
```

**Note**: Replace `yourPassword` with your actual RCON password. The default mcrcon path is `/usr/bin/mcrcon`, but you can verify the correct path with `which mcrcon`.



