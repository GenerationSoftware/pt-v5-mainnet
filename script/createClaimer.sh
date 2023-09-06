forge create \
    --rpc-url $OPTIMISM_RPC_URL \
    --constructor-args 0x8CFFFfFa42407DB9DCB974C2C744425c3e58d832 100000000000000 10000000000000000000000 43200 100000000000000000 \
    --private-key $PRIVATE_KEY \
    --etherscan-api-key $OPTIMISM_ETHERSCAN_API_KEY \
    --verify \
    lib/pt-v5-claimer/src/Claimer.sol:Claimer