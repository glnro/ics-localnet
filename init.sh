source ./vars.sh

# Optionally build provider chain
read -p "Build interchain-security-pd? [y/n]?" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
  git clone -b glnro/ics-v45 git@github.com:cosmos/gaia.git
  cd gaia
  make build
  mv build/gaiad ../interchain-security-pd
  cd ..
  rm -rf gaia
  echo "*******Provider Version*******"
  ./interchain-security-pd version
fi

read -p "Create and run the provider chain? [y/n]?" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
  echo "*****************Creating Provider Chain*****************"

  # Remove all previous directories
  pkill -f interchain-security-pd
  rm -rf ./provider
  mkdir ./provider

  # Init provider chain
  ./interchain-security-pd init $PROV_NODE_MONIKER --chain-id $PROV_CHAIN_ID --home $PROV_NODE_DIR

  # Edit genesis
  jq ".app_state.gov.voting_params.voting_period = \"60s\"" \
      ${PROV_NODE_DIR}/config/genesis.json > ${PROV_NODE_DIR}/edited_genesis.json
  # Configure Staking Params
  sed -i '' 's%"bond_denom": "stake"%"bond_denom": "'${PROV_DENOM}'"%g' ${PROV_NODE_DIR}/edited_genesis.json
  sed -i '' 's%"denom": "stake"%"denom": "'${PROV_DENOM}'"%g' ${PROV_NODE_DIR}/edited_genesis.json

  mv ${PROV_NODE_DIR}/edited_genesis.json ${PROV_NODE_DIR}/config/genesis.json

  # Create provider key

  ./interchain-security-pd keys add $PROV_KEY --home $PROV_NODE_DIR \
      --keyring-backend test --output json > ${PROV_NODE_DIR}/${PROV_KEY}.json 2>&1

  # Fund provider account
  export PROV_ACCOUNT_ADDR=$(jq -r .address ${PROV_NODE_DIR}/${PROV_KEY}.json)
  ./interchain-security-pd add-genesis-account $PROV_ACCOUNT_ADDR 1000000000${PROV_DENOM} \
      --keyring-backend test --home $PROV_NODE_DIR

  # Validate Genesis
  ./interchain-security-pd validate-genesis ${PROV_NODE_DIR}/config/genesis.json

  # Generate validator Tx
  echo "Generating validator tx"
  ./interchain-security-pd gentx $PROV_KEY 100000000${PROV_DENOM} --keyring-backend test --moniker $PROV_NODE_MONIKER --chain-id $PROV_CHAIN_ID --home $PROV_NODE_DIR

  # Build Genesis
  echo "Build genesis"

  ./interchain-security-pd collect-gentxs --home $PROV_NODE_DIR \
      --gentx-dir ${PROV_NODE_DIR}/config/gentx/

  # Setup RPC
  # export CURRENT_IP=$(host -4 myip.opendns.com resolver1.opendns.com | grep "address" | awk '{print $4}')
  # sed -i -r "/node =/ s/= .*/= \"tcp:\/\/${CURRENT_IP}:26658\"/" \
  # ${PROV_NODE_DIR}/config/client.toml

  # Config Chain
  ./interchain-security-pd config chain-id gaia --home $PROV_NODE_DIR
  ./interchain-security-pd config keyring-backend test --home $PROV_NODE_DIR
  ./interchain-security-pd config node "tcp://${CURRENT_IP}:26658" --home $PROV_NODE_DIR

  # Start Provider Chain
  ./interchain-security-pd start --home $PROV_NODE_DIR \
          --rpc.laddr tcp://${CURRENT_IP}:26658 \
          --grpc.address ${CURRENT_IP}:9091 \
          --address tcp://${CURRENT_IP}:26655 \
          --p2p.laddr tcp://${CURRENT_IP}:26656 \
          --grpc-web.enable=false \
          &> ${PROV_NODE_DIR}/logs 2>&1 &
fi

read -p "Submit consumer chain proposal on provider? [y/n]?" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
  echo "*****************Creating Consumer Chain*****************"

  export SPAWN_TIME=$(jq -r .genesis_time ${PROV_NODE_DIR}/config/genesis.json)

  echo "Writing consumer proposal"
  tee ${PROV_NODE_DIR}/consumer-proposal.json<<EOF
{
    "title": "Create consumer chain",
    "description": "First consumer chain",
    "chain_id": "consumer",
    "initial_height": {
        "revision_height": 1
    },
    "genesis_hash": "Z2VuX2hhc2g=",
    "binary_hash": "YmluX2hhc2g=",
    "spawn_time": "${SPAWN_TIME}",
    "deposit": "10000001${PROV_DENOM}"
}
EOF

  echo "Submitting Proposal"
  ./interchain-security-pd tx gov submit-proposal \
       consumer-addition ${PROV_NODE_DIR}/consumer-proposal.json \
       --keyring-backend test \
       --chain-id $PROV_CHAIN_ID \
       --from $PROV_KEY \
       --home $PROV_NODE_DIR \
       -b block -y

  sleep 7

  ./interchain-security-pd tx gov vote 1 yes --from $PROV_KEY \
       --keyring-backend test --chain-id $PROV_CHAIN_ID --home $PROV_NODE_DIR -b block

  echo "Wait 60 seconds for proposal to pass"
  read -p "Query Proposal Status? [y/n]?" response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
    ./interchain-security-pd q gov proposal 1 --home $PROV_NODE_DIR
  fi

fi

# Optionally build provider chain
read -p "Build interchain-security-cd? [y/n]?" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
  git clone https://github.com/cosmos/interchain-security.git
  cd interchain-security
  git checkout goc-december
  make install
  CD=$(which interchain-security-cd)
  mv $CD ../interchain-security-cd
  cd ..
  rm -rf interchain-security
  echo "*******Consumer Version*******"
  ./interchain-security-cd version
fi

# Optionally build provider chain
read -p "Build neutron interchain-security-cd? [y/n]?" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
  git clone https://github.com/neutron-org/neutron.git
  cd neutron
  git checkout v0.1.0
  make install
  CD=$(which neutrond)
  mv $CD ../interchain-security-cd
  cd ..
  rm -rf neutron
  echo "*******Consumer Version*******"
  ./interchain-security-cd version
fi

read -p "Create and run the consumer chain? [y/n]?" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
  # Remove all previous directories
  pkill -f interchain-security-cd
  rm -rf ./consumer
  mkdir ./consumer

  # Initialize consumer
  ./interchain-security-cd init $CONS_NODE_MONIKER --chain-id $CONS_CHAIN_ID --home $CONS_NODE_DIR

  # Create consumer key
  ./interchain-security-cd keys add $CONS_KEY --home $CONS_NODE_DIR \
    --keyring-backend test --output json > ${CONS_NODE_DIR}/${CONS_KEY}.json 2>&1

  # Add account to genesis
  export CONS_ACCOUNT_ADDR=$(jq -r .address ${CONS_NODE_DIR}/${CONS_KEY}.json)
  ./interchain-security-cd add-genesis-account $CONS_ACCOUNT_ADDR 1000000000${CONS_DENOM} \
    --keyring-backend test --home $CONS_NODE_DIR

  # Config Chain
  ./interchain-security-cd config chain-id gaia --home $CONS_NODE_DIR
  ./interchain-security-cd config keyring-backend test --home $CONS_NODE_DIR
  ./interchain-security-cd config node "tcp://${CURRENT_IP}:26648" --home $CONS_NODE_DIR

  # Get consumer chain genesis from provider
  ./interchain-security-pd query provider consumer-genesis $CONS_CHAIN_ID --home $PROV_NODE_DIR -o json > ccvconsumer_genesis.json

  # Replace genesis state
  jq -s '.[0].app_state.ccvconsumer = .[1] | .[0]' ${CONS_NODE_DIR}/config/genesis.json ccvconsumer_genesis.json > \
      ${CONS_NODE_DIR}/edited_genesis.json
  mv ${CONS_NODE_DIR}/edited_genesis.json ${CONS_NODE_DIR}/config/genesis.json && rm ccvconsumer_genesis.json

  # Copy validator key pair
  echo '{"height": "0","round": 0,"step": 0}' > ${CONS_NODE_DIR}/data/priv_validator_state.json
  cp ${PROV_NODE_DIR}/config/priv_validator_key.json ${CONS_NODE_DIR}/config/priv_validator_key.json
  cp ${PROV_NODE_DIR}/config/node_key.json ${CONS_NODE_DIR}/config/node_key.json

  ./interchain-security-cd start --home $CONS_NODE_DIR \
        --rpc.laddr tcp://${CURRENT_IP}:26648 \
        --grpc.address ${CURRENT_IP}:9081 \
        --address tcp://${CURRENT_IP}:26645 \
        --p2p.laddr tcp://${CURRENT_IP}:26646 \
        --grpc-web.enable=false \
        &> ${CONS_NODE_DIR}/logs 2>&1 &
fi

read -p "Setup IBC Relayer? [y/n]?" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
  rm -rf $HERMES_DIR
  mkdir $HERMES_DIR
  tee ${HERMES_DIR}/config.toml<<EOF
[global]
 log_level = "info"

[[chains]]
account_prefix = "cosmos"
clock_drift = "5s"
gas_multiplier = 1.1
grpc_addr = "tcp://${CURRENT_IP}:9081"
id = "$CONS_CHAIN_ID"
key_name = "relayer"
max_gas = 2000000
rpc_addr = "http://${CURRENT_IP}:26648"
rpc_timeout = "10s"
store_prefix = "ibc"
trusting_period = "14days"
websocket_addr = "ws://${CURRENT_IP}:26648/websocket"

[chains.gas_price]
       denom = "${CONS_DENOM}"
       price = 0.00

[chains.trust_threshold]
       denominator = "3"
       numerator = "1"

[[chains]]
account_prefix = "cosmos"
clock_drift = "5s"
gas_multiplier = 1.1
grpc_addr = "tcp://${CURRENT_IP}:9091"
id = "$PROV_CHAIN_ID"
key_name = "relayer"
max_gas = 2000000
rpc_addr = "http://${CURRENT_IP}:26658"
rpc_timeout = "10s"
store_prefix = "ibc"
trusting_period = "14days"
websocket_addr = "ws://${CURRENT_IP}:26658/websocket"

[chains.gas_price]
       denom = "${PROV_DENOM}"
       price = 0.00

[chains.trust_threshold]
       denominator = "3"
       numerator = "1"
EOF

  # Delete any previous keys
  hermes --config $HERMES_CONFIG keys delete --chain $CONS_CHAIN_ID --all
  hermes --config $HERMES_CONFIG keys delete --chain $PROV_CHAIN_ID --all

  # Import accounts key
  hermes --config $HERMES_CONFIG keys add --key-file  ${CONS_NODE_DIR}/${CONS_KEY}.json --chain $CONS_CHAIN_ID
  hermes --config $HERMES_CONFIG keys add --key-file  ${PROV_NODE_DIR}/${PROV_KEY}.json --chain $PROV_CHAIN_ID

  # Create Connection
  hermes --config $HERMES_CONFIG create connection \
     --a-chain consumer \
    --a-client 07-tendermint-0 \
    --b-client 07-tendermint-0

  # Create Channel
  hermes --config $HERMES_CONFIG create channel \
    --a-chain $CONS_CHAIN_ID \
    --a-port consumer \
    --b-port provider \
    --order ordered \
    --channel-version 1 \
    --a-connection connection-0

  # Start Hemres
  pkill -f hermes
  hermes --json start &> ${HERMES_DIR}/logs 2>&1 &
fi
