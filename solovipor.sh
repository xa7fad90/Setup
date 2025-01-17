#!/bin/bash

VERSION=1.0

# Printing greetings
echo "SRBMiner-Multi setup script v$VERSION."
echo "(please report issues to support@example.com with full output of this script with extra \"-x\" \"bash\" option)"
echo

if [ "$(id -u)" == "0" ]; then
  echo "WARNING: Generally, it is not advised to run this script under root."
fi

# Command line arguments
WALLET=$1
EMAIL=$2 # this one is optional

# Checking prerequisites
if [ -z $WALLET ]; then
  echo "Script usage:"
  echo "> setup_srbminer.sh <wallet address> [<your email address>]"
  echo "ERROR: Please specify your wallet address"
  exit 1
fi

if [ -z $HOME ]; then
  echo "ERROR: Please define HOME environment variable to your home directory"
  exit 1
fi

if [ ! -d $HOME ]; then
  echo "ERROR: Please make sure HOME directory $HOME exists or set it yourself using this command:"
  echo '  export HOME=<dir>'
  exit 1
fi

if ! type curl >/dev/null; then
  echo "ERROR: This script requires \"curl\" utility to work correctly"
  exit 1
fi

if ! type lscpu >/dev/null; then
  echo "WARNING: This script requires \"lscpu\" utility to work correctly"
fi

# Start doing stuff: preparing miner
echo "[*] Removing previous SRBMiner-Multi miner (if any)"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop srbminer.service
fi
killall -9 SRBMiner-MULTI 2>/dev/null || echo "killall not installed. Skipping."

echo "[*] Removing $HOME/srbminer directory"
rm -rf $HOME/srbminer

echo "[*] Downloading SRBMiner-Multi to /tmp/srbminer.tar.gz"
if ! curl -L --progress-bar "https://github.com/doktor83/SRBMiner-Multi/releases/download/2.7.2/SRBMiner-Multi-2-7-2-Linux.tar.gz" -o /tmp/srbminer.tar.gz; then
  echo "ERROR: Can't download SRBMiner-Multi file to /tmp/srbminer.tar.gz"
  exit 1
fi

echo "[*] Unpacking /tmp/srbminer.tar.gz to $HOME/srbminer"
[ -d $HOME/srbminer ] || mkdir $HOME/srbminer
if ! tar xf /tmp/srbminer.tar.gz -C $HOME/srbminer --strip-components=1; then
  echo "ERROR: Can't unpack /tmp/srbminer.tar.gz to $HOME/srbminer directory"
  exit 1
fi
rm /tmp/srbminer.tar.gz

echo "[*] Checking if SRBMiner-Multi works fine (and not removed by antivirus software)"
$HOME/srbminer/SRBMiner-MULTI --help >/dev/null
if (test $? -ne 0); then
  if [ -f $HOME/srbminer/SRBMiner-MULTI ]; then
    echo "WARNING: SRBMiner-Multi is not functional"
  else 
    echo "WARNING: SRBMiner-Multi was removed by antivirus (or some other problem)"
  fi
  exit 1
fi

echo "[*] Miner $HOME/srbminer/SRBMiner-MULTI is OK"

PASS=`hostname | cut -f1 -d"." | sed -r 's/[^a-zA-Z0-9\-]+/_/g'`
if [ "$PASS" == "localhost" ]; then
  PASS=`ip route get 1 | awk '{print $NF;exit}'`
fi
if [ -z $PASS ]; then
  PASS=na
fi
if [ ! -z $EMAIL ]; then
  PASS="$PASS:$EMAIL"
fi

# Set CPU_THREADS
CPU_THREADS=$(nproc)

# List of available pools
POOLS=(
  "usw.vipor.net:5045"  # USA (West) California
  "ca.vipor.net:5045"   # Canada Montreal
  "us.vipor.net:5045"   # USA (North East) Ohio
  "usse.vipor.net:5045" # USA (South East) Georgia
  "ussw.vipor.net:5045" # USA (South West) Texas
  "fr.vipor.net:5045"   # France Gravelines
  "cn.vipor.net:5045"   # China Hong Kong
  "fi.vipor.net:5045"   # Finland Helsinki
  "ap.vipor.net:5045"   # Asia Korea
  "de.vipor.net:5045"   # Germany Frankfurt
  "pl.vipor.net:5045"   # Poland Warsaw
  "kz.vipor.net:5045"   # Kazakhstan Almaty
  "ro.vipor.net:5045"   # Romania Bucharest
  "ru.vipor.net:5045"   # Russia Moscow
  "sa.vipor.net:5045"   # South America Brazil
  "tr.vipor.net:5045"   # Turkey Istanbul
  "sg.vipor.net:5045"   # Singapore
  "ua.vipor.net:5045"   # Ukraine Kiev
  "au.vipor.net:5045"   # Australia Sydney
)

# Function to get user's location
get_location() {
  LOCATION=$(curl -s ipinfo.io | grep "country" | cut -d'"' -f4)
  echo "$LOCATION"
}

# Function to select the nearest pool
select_nearest_pool() {
  LOCATION=$(get_location)
  case $LOCATION in
    "US") NEAREST_POOL="us.vipor.net:5045" ;;
    "CA") NEAREST_POOL="ca.vipor.net:5045" ;;
    "FR") NEAREST_POOL="fr.vipor.net:5045" ;;
    "CN") NEAREST_POOL="cn.vipor.net:5045" ;;
    "FI") NEAREST_POOL="fi.vipor.net:5045" ;;
    "DE") NEAREST_POOL="de.vipor.net:5045" ;;
    "PL") NEAREST_POOL="pl.vipor.net:5045" ;;
    "KZ") NEAREST_POOL="kz.vipor.net:5045" ;;
    "RO") NEAREST_POOL="ro.vipor.net:5045" ;;
    "RU") NEAREST_POOL="ru.vipor.net:5045" ;;
    "BR") NEAREST_POOL="sa.vipor.net:5045" ;;
    "TR") NEAREST_POOL="tr.vipor.net:5045" ;;
    "SG") NEAREST_POOL="sg.vipor.net:5045" ;;
    "UA") NEAREST_POOL="ua.vipor.net:5045" ;;
    "AU") NEAREST_POOL="au.vipor.net:5045" ;;
    *) NEAREST_POOL="sg.vipor.net:5045" ;; # Default to Singapore
  esac
  echo "$NEAREST_POOL"
}

# Select the nearest pool
POOL=$(select_nearest_pool)
echo "[*] Selected nearest pool: $POOL"

# Preparing script
echo "[*] Creating $HOME/srbminer/miner.sh script"
cat >$HOME/srbminer/miner.sh <<EOL
#!/bin/bash
if ! pidof SRBMiner-MULTI >/dev/null; then
  nice $HOME/srbminer/SRBMiner-MULTI --algorithm verushash --pool $POOL --wallet $WALLET --worker rig1 --cpu-threads $CPU_THREADS --cpu-affinity 0x7 --cpu-intensity 15 --disable-gpu --give-up-limit 3 --retry-time 10 --max-rejected-shares 15 --max-no-share-sent 300 --log-file $HOME/srbminer/xmrig.log --api-enable --api-port 21550 --api-rig-name rig1
else
  echo "SRBMiner-Multi is already running in the background. Refusing to run another one."
  echo "Run \"killall SRBMiner-MULTI\" or \"sudo killall SRBMiner-MULTI\" if you want to remove background miner first."
fi
EOL

chmod +x $HOME/srbminer/miner.sh

# Preparing script background work and work under reboot
if ! grep srbminer/miner.sh $HOME/.profile >/dev/null; then
  echo "[*] Adding $HOME/srbminer/miner.sh script to $HOME/.profile"
  echo "$HOME/srbminer/miner.sh >/dev/null 2>&1" >> $HOME/.profile
else 
  echo "Looks like $HOME/srbminer/miner.sh script is already in the $HOME/.profile"
fi
echo "[*] Running miner in the background (see logs in $HOME/srbminer/xmrig.log file)"
/bin/bash $HOME/srbminer/miner.sh >/dev/null 2>&1 &

echo ""
echo "NOTE: If you are using shared VPS it is recommended to avoid 100% CPU usage produced by the miner or you will be banned"
if [ "$CPU_THREADS" -lt "4" ]; then
  echo "HINT: Please execute these or similar commands to limit miner to 75% percent CPU usage:"
  echo "cpulimit -e SRBMiner-MULTI -l $((75*$CPU_THREADS)) -b"
else
  echo "HINT: Please execute these commands to limit miner to 75% percent CPU usage:"
  echo "cpulimit -e SRBMiner-MULTI -l $((75*$CPU_THREADS)) -b"
fi
echo ""

echo "[*] Setup complete"
