#!/bin/bash
#
# =============================================================
# sysreport.sh - Script to gather data about the current system
#
# USAGE: $ sysreport.sh
#
# This will gather a selection of info:
## hardware details
## system software info
## drivers
## environment
## running programs
#
# If you're unhappy sharing any of this information then feel
# free to remove it from the output when sending the file over
# =============================================================

# This is to avoid problems with getting paths
CDPATH=

# Force C locale to avoid some odd issues
export LC_ALL_OLD=$LC_ALL
export LC_ALL=C

# Escape the steam runtime library path
export SAVED_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
unset LD_LIBRARY_PATH

OUTFILE="$(pwd)/sysrep.html"
SKIP_CLOSE=$2


# --------------------------------------------------------------------------------
# Helper functions
output_text() {
	echo "$1"
	echo "<h3 id=\"$1\">$1</h3>" >> "$OUTFILE"
}

# --------------------------------------------------------------------------------
# Check we can write to the output
echo "-" > "$OUTFILE"
WRITE_ERROR=$?
if [ $WRITE_ERROR != 0 ] ; then
	exit $WRITE_ERROR
fi

# --------------------------------------------------------------------------------
TEXT_AREA="<textarea rows=\"5\" readonly>"

# --------------------------------------------------------------------------------
# Set up the header
echo "Reporting to $OUTFILE"
echo "<!DOCTYPE html>
<html>
<head>
<title>Domesticated System Report</title>
<style>
textarea {
    width:90%;
    height:100px;
}
</style>
</head>
<body>
<h1>Domesticated System Report</h1>
<p>Generated using '\$ $0 $*' at $(date)</p>
<hr>
<h3>Contents</h3>
<p>
<a href=\"#programs\">Program Outputs</a><br>
<a href=\"#graphics\">Program Outputs</a><br>
<a href=\"#system\">System Files</a><br>" > "$OUTFILE"

# # Add a tag for steam DLC info if we're appending it to the end
# if [ "$PGOW_APPEND" = "1" ]; then
# 	echo "<a href=\"#steamdlc\">Steam DLC Info</a><br>" >> "$OUTFILE"
# fi

echo "</p>" >> "$OUTFILE"

# --------------------------------------------------------------------------------
# System info utilities - native envirnoment
# --------------------------------------------------------------------------------
# "uname -a"               - System and kernel version info
# "lsb_release -a"         - More specific system info
# "lspci -v"               - Info on current hardware
# "lsusb -v"               - Info on USB devices
# "env"                    - Check against steam runtime environment to catch oddities
# "top -b -n 1"            - Running processes (useful to detect CPU/GPU hogs or zombie processes)
# "setxkbmap -query"       - Information on current keyboard map/modes
# "curl-config --ca"       - Location of the certificates bundle
# "pulseaudio --dump-conf" - Audio configuration
# "pulseaudio --check -v"  - Audio state
# "cat $CPUFILES"          - Show CPU governor setting
CPUFILES="/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
echo "<hr><h2 id=\"programs\">Program Outputs</h2>" >> "$OUTFILE"
set -- "uname -a" \
	"lsb_release -a" \
	"xrandr" \
	"lspci -v" \
	"lsusb -v" \
	"env" \
	"top -b -n 1" \
	"mount" \
	"dmesg" \
	"df -h" \
	"setxkbmap -query" \
	"curl-config --ca" \
	"pulseaudio --dump-conf" \
	"pulseaudio --check -v" \
	"cat ${CPUFILES}"
for CMD do
	output_text "$CMD"
	echo "${TEXT_AREA}" >> "$OUTFILE"
	$CMD 2>&1 | tail -n 1000 | tee -a "$OUTFILE" | 
	if [ "$(wc -l)" = "1000" ]; then 
		echo "...truncated to last 1000 lines..." >> "$OUTFILE" 
	fi
	echo "</textarea>" >> "$OUTFILE"
done


# --------------------------------------------------------------------------------
# Graphics info utilities
# --------------------------------------------------------------------------------
# "glxinfo -l"         - Detailed opengl information
# "vulkaninfo"         - Detailed vulkan information
# "nvidia-smi"         - Current GPU stats on nvidia
# "fglrxinfo"          - Current GPU stats on amd
echo "<hr><h2 id=\"graphics\">Graphics Information</h2>" >> "$OUTFILE"
set -- "glxinfo -l" \
	"vulkaninfo" \
	"nvidia-smi" \
	"fglrxinfo"
for CMD do
	output_text "$CMD"
	echo "${TEXT_AREA}" >> "$OUTFILE"
	$CMD 2>&1 | tail -n 10000 | tee -a "$OUTFILE" | 
	if [ "$(wc -l)" = "10000" ]; then 
		echo "...truncated to first 10000 lines..." >> "$OUTFILE" 
	fi
	echo "</textarea>" >> "$OUTFILE"
done


# --------------------------------------------------------------------------------
# System configuration files
# --------------------------------------------------------------------------------
# "/etc/*-release"                   - Info on system release version
# "/etc/X11/default-display-manager" - X11 display manager info
# "/proc/meminfo"                    - Info on current RAM
# "/proc/cpuinfo"                    - Info on current CPU
# "/etc/sysconfig/displaymanager"    - Display manger config
# "/etc/sysconfig/desktop"           - WM config
# "/proc/bus/input/devices"          - input devices (controllers + m/k)
echo "<hr><h2 id=\"system\">System Files</h2>" >> "$OUTFILE"
RELEASE_FILES=(/etc/*-release)
set -- "${RELEASE_FILES[@]}" \
	"/etc/X11/default-display-manager" \
	"/proc/meminfo" \
	"/proc/cpuinfo" \
	"/etc/sysconfig/displaymanager" \
	"/etc/sysconfig/desktop" \
	"/proc/bus/input/devices" 
for FILE do
	if [ -e "$FILE" ] ; then
		output_text "$FILE"
		echo "${TEXT_AREA}" >> "$OUTFILE"
		head "$FILE" -n 500 | tee -a "$OUTFILE" | 
		if [ "$(wc -l)" = "500" ]; 
			then echo "...truncated..." >> "$OUTFILE"; 
		fi
		echo "</textarea>" >> "$OUTFILE"
	else
		output_text "$FILE not found"
	fi
done

# --------------------------------------------------------------------------------
# Attempt to clean out any login commands that contain passwords
sed -i -E 's/-login \w+ \w+/-login <scrubbed> <scrubbed>/g' "$OUTFILE"

# Insert the close tags
if [ "$SKIP_CLOSE" == "1" ]; then
	exit 0
fi

echo "</body>
</html>" >> "$OUTFILE"
