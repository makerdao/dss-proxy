all    :; dapp --use solc:0.8.14 build
clean  :; dapp clean
test   :; dapp --use solc:0.8.14 test -v ${TEST_FLAGS}
