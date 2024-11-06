
#!/bin/bash
set -euo pipefail

# Strict mode settings to ensure the script exits on errors, unset variables, or failed pipes

# Flag indicating whether the installation was done automatically to enable snapshot download
from_autoinstall=true

upgrade_height=1325860
STORY_CHAIN_ID=odyssey-0
VER=1.22.3
SEEDS="434af9dae402ab9f1c8a8fc15eae2d68b5be3387@story-testnet-seed.itrocket.net:29656"
PEERS="c5c214377b438742523749bb43a2176ec9ec983c@176.9.54.69:26656,5dec0b793789d85c28b1619bffab30d5668039b7@150.136.113.152:26656,89a07021f98914fbac07aae9fbb12a92c5b6b781@152.53.102.226:26656,443896c7ec4c695234467da5e503c78fcd75c18e@80.241.215.215:26656,2df2b0b66f267939fea7fe098cfee696d6243cec@65.108.193.224:23656,7cc415203fc4c1a6e534e5fed8292467cf14d291@65.21.29.250:3610,fa294c4091379f84d0fc4a27e6163c956fc08e73@65.108.103.184:26656,81eaee3be00b21d0a124016b62fb7176fa05a4f9@185.198.49.133:33556,3508ef280392bd431ea078dec16dcfae89e8eb78@213.239.192.18:26656,b04bae4f88ca12d45fc14be29ce96837b61a72b8@65.109.49.115:26656"

# Function to handle errors gracefully
die() {
  echo "Error: $1" >&2
  exit 1
}

# Function to log messages with timestamp
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to download and verify scripts for safety
download_script() {
  local url="$1"
  local output="$2"
  curl -s "$url" -o "$output" || die "Failed to download $url"
  chmod +x "$output"
}

# Function to set up Story-Geth instance
# Downloads and extracts the Geth binary for the Story blockchain, sets up necessary directories
setup_geth_instance() {
  log "Setting up Story-Geth instance"
  cd "$HOME"
  rm -rf bin
  mkdir bin
  cd bin
  wget https://github.com/piplabs/story-geth/releases/download/v0.10.0/geth-linux-amd64 || die "Failed to download Geth binary"
  mv "$HOME/bin/geth-linux-amd64" "$HOME/go/bin/story-geth" || die "Failed to move Geth binary"
  chmod +x "$HOME/go/bin/story-geth
  mkdir -p "$HOME/.story/story"
  mkdir -p "$HOME/.story/geth"
}

# Function to set up Story instance
# Clones the Story repository, checks out the required version, and builds the Story binary
setup_story_instance() {
  log "Setting up Story instance"
  cd "$HOME"
  rm -rf story
  git clone https://github.com/piplabs/story || die "Failed to clone Story repository"
  cd story
  git checkout v0.12.1 || die "Failed to checkout Story version v0.11.0"
  go build -o story ./client || die "Failed to build Story binary"
  mv "$HOME/story/story" "$HOME/go/bin/" || die "Failed to move Story binary"
}

# Function to prompt user for continuation or exit
# Asks the user if they want to proceed, and exits if the answer is negative
prompt_user_continue() {
  read -p "Do you want to continue? (y/n): " choice
  if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
    log "Exiting script."
    exit 1
  fi
}

# Function to verify node synchronization status
# Periodically checks if the local node is in sync with the network
verify_node_sync() {
  rpc_port=$(grep -m 1 -oP '^laddr = "\K[^"]+' "$HOME/.story/story/config/config.toml" | cut -d ':' -f 3)
  while true; do
    local_height=$(curl -s "localhost:$rpc_port/status" | jq -r '.result.sync_info.latest_block_height')
    network_height=$(curl -s https://t-story.archive.rpc.utsa.tech/status | jq -r '.result.sync_info.latest_block_height')

    if ! [[ "$local_height" =~ ^[0-9]+$ ]] || ! [[ "$network_height" =~ ^[0-9]+$ ]]; then
      log "Invalid block height data. Retrying..."
      sleep 5
      continue
    fi

    blocks_left=$((network_height - local_height))
    if [ "$blocks_left" -lt 0 ]; then
      blocks_left=0
    fi

    log "Your node height: $local_height | Network height: $network_height | Remaining blocks: $blocks_left"

    sleep 5
    if [[ "$blocks_left" -eq 0 ]]; then
      log "Your node is synchronized"
      break
    fi
  done
}

# Function to get the service file name
# Checks if the specified service is running, and prompts the user to enter the service name if it is not found
get_service_name() {
  local service_name="$1"
  local print_name="$2"
  if ! systemctl status "$service_name" > /dev/null 2>&1; then
    read -rp "Enter the service file name for $print_name: " service_name
  fi
  echo "$service_name"
}

# Function to display service logs and handle CTRL+C
# Displays logs from Story and Story-Geth services and allows the user to stop viewing with CTRL+C
display_service_logs() {
  story_name=$(get_service_name "story" "Story")
  geth_name=$(get_service_name "story-geth" "Story-geth")

  trap "return" SIGINT
  journalctl -u "$story_name" -u "$geth_name" -f
  trap - SIGINT
}

# Function to initialize node installation
# Gathers user input for node configuration, installs required software, and sets up the node environment
initialize_node_installation() {
  log "Initializing node installation"

  read -rp "Enter your MONIKER: " MONIKER
  read -rp "Enter your PORT (e.g., 17, default port=26): " PORT

  echo "export MONIKER=$MONIKER" >> "$HOME/.bash_profile"
  echo "export STORY_CHAIN_ID=$STORY_CHAIN_ID" >> "$HOME/.bash_profile"
  echo "export STORY_PORT=$PORT" >> "$HOME/.bash_profile"
  source "$HOME/.bash_profile"

  log "Moniker: $MONIKER, Chain ID: $STORY_CHAIN_ID, Node custom port: $PORT"

  log "Setting up Go environment"
  cd "$HOME"
  wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz" || die "Failed to download Go"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz" || die "Failed to extract Go"
  rm "go$VER.linux-amd64.tar.gz"
  echo "export PATH=\\$PATH:/usr/local/go/bin:\\$HOME/go/bin" >> "$HOME/.bash_profile"
  source "$HOME/.bash_profile"
  mkdir -p "$HOME/go/bin"
  log "Go version: $(go version)"

  log "Updating system packages"
  sudo apt update && sudo apt upgrade -y || die "Failed to update system packages"

  log "Installing necessary dependencies"
  sudo apt install -y curl git wget htop tmux jq make lz4 unzip bc || die "Failed to install dependencies"

  log "Setting up Story-Geth"
  setup_geth_instance

  log "Setting up Story"
  setup_story_instance

  log "Initializing Story node"
  story init --moniker "$MONIKER" --network odyssey || die "Failed to initialize Story node"

  log "Fetching genesis and address book files"

  sha256sum ~/.story/story/config/genesis.json
  log "Genesis hash must be: 18ab598bbaefaa5af5e998abe14e8660ff6fa3c63a9453f5f40f472b213ed091"
  wget -O "$HOME/.story/story/config/addrbook.json" https://share102.utsa.tech/story/addrbook.json || die "Failed to download addrbook file"

  log "Configuring P2P settings"
  sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
         -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" \
         "$HOME/.story/story/config/config.toml"

  sed -i.bak -e "s%:1317%:${STORY_PORT}317%g; s%:8551%:${STORY_PORT}551%g" "$HOME/.story/story/config/story.toml"
  sed -i.bak -e "s%:26658%:${STORY_PORT}658%g; s%:26657%:${STORY_PORT}657%g; s%:26656%:${STORY_PORT}656%g; s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${STORY_PORT}656\"%; s%:26660%:${STORY_PORT}660%g" "$HOME/.story/story/config/config.toml"

  sed -i -e "s/prometheus = false/prometheus = true/" "$HOME/.story/story/config/config.toml"
  sed -i -e "s/^indexer *=.*/indexer = \"null\"/" "$HOME/.story/story/config/config.toml"

  log "Generating systemd service files"
  sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$HOME/go/bin/story-geth --odyssey --syncmode full --http --http.api eth,net,web3,engine --http.vhosts '*' --http.addr 0.0.0.0 --http.port ${STORY_PORT}545 --authrpc.port ${STORY_PORT}551 --ws --ws.api eth,web3,net,txpool --ws.addr 0.0.0.0 --ws.port ${STORY_PORT}546
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

  sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/.story/story
ExecStart=$(which story) run

Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

  log "Enabling Story and Story-Geth services"
  sudo systemctl daemon-reload
  sudo systemctl enable story story-geth || die "Failed to enable services"

  log "Retrieving blockchain snapshot"
  mkdir -p "$HOME/.story/geth/odyssey/geth"
  download_script "https://raw.githubusercontent.com/lesnikutsa/story/refs/heads/main/autosnap_story.sh" "$HOME/autosnap_story.sh"
  source "$HOME/autosnap_story.sh"
}

# Main script execution starts here
log "Story node automatic installation tool"
while true; do
  echo ""
  log "Which action do you want to perform?"
  options=(
    "Install Story node"
    "Download snapshot"
    "Check sync status"
    "Check logs"
    "Exit"
  )
  for i in "${!options[@]}"; do
    printf "%s. %s\n" "$((i + 1))" "${options[$i]}"
  done
  read -rp "Your choice: " action
  echo ""

  case "$action" in
    1)
      initialize_node_installation
      log "Node installation completed successfully!"
      ;;
    2)
      log "Downloading snapshot"
      download_script "https://raw.githubusercontent.com/lesnikutsa/story/refs/heads/main/autosnap_story.sh" "$HOME/autosnap_story.sh"
      source "$HOME/autosnap_story.sh"
      ;;
    3)
      log "Checking node synchronization status"
      verify_node_sync
      ;;
    4)
      log "Showing service logs... Press CTRL+C to return to the main menu."
      display_service_logs
      ;;
    5)
      log "Exiting the script"
      break
      ;;
    *)
      log "Invalid choice. Please try again."
      ;;
  esac
done
