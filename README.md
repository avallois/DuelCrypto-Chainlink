# DuelCrypto
Smart contract, duels 1v1 for ETH/BNB with chainlink VRF random number generator

Ex:
- Bob create a duel for 2 BNB and send those
- John join the duel and add the 2 BNB required too
- A request for Random number is asked to Chainlink Coordinator
- Coordinator send the number for the requestId
- Duel is launched
- Winner is established and a fee of < 1% is taken for the SC owner
- Winner win 4BNB(- fee)
- Then winner can claim his reward
- Anyone can join a duel
- Anyone can cancel his own created duel be refunded from his funds


Managed:
- No reentrency
- No overflow
- No call from external contracts

Better run this contract on Matic Network because chainlink fees are lower.
