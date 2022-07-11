# SWAPPER (working prototype) Demonstrates atomic swap of anything

Beta - testing. Don't use with real tokens yet.

Swapper = Reciever = Custodian

Swapper can be immutable and code verified

Maker - someone who has created an order and waits for it to be fulfilled by someone else. That could be a:

- person trying to swap ICP for BTC
- a dex swapping ICP for ICP_BTC_LP
- ICP+BTC for ICP_BTC_LP
- staking ANV for ANV_VLP

![Anvil UI](/img/example.jpg?raw=true)
The UI/design is property of Anvil.

The repo with code is Apache 2.0

Participants put tokens in boxes (accounts controlled by the Swapper) according to order (description of the swap).

Cancelation is available to all participants anytime before the atomic swap.

If all participants placed correct contents in their boxes and nobody canceled, the swap is done.

From there on they can take their contents out.

Note - Swapper is a role, it can be in its own canister (possibly immutable) or inside another canister part of the swap.

![Sequence Diagram Swapper](/img/sd1.png?raw=true)

![State Machine Diagram Swapper](/img/smd.png?raw=true)
