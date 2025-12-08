aptos move download \
  --account 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a \
  --bytecode \
  --package Yuzuswap \
  --url https://full.mainnet.movementinfra.xyz/v1 \
  --output-dir ../move/deps/

aptos move decompile --package-path ../move/deps/Yuzuswap/bytecode_modules --output-dir ../move/deps/Yuzuswap/sources/
