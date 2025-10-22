-- Query: summary_strategies
-- Description: **DeFindex Strategy Overview**  
The query lists all DeFindex strategies, providing their names, addresses, and associated assets. This helps in tracking and managing the performance and allocation of each strategy within the DeFindex platform.
-- Source: https://dune.com/queries/6014850
-- already part of a query repo

-- Query: Summary Strategies
-- Description: Hardcoded table with strategy names, addresses and assets/tokens
-- This table contains all DeFindex strategies and their associated assets

SELECT
    strategy_name,
    strategy_address,
    asset_token
FROM (
    VALUES
        ('usdc_blend_autocompound_fixed_strategy', 'CDB2WMKQQNVZMEBY7Q7GZ5C7E7IAFSNMZ7GGVD6WKTCEWK7XOIAVZSAP', 'USDC'),
        ('eurc_blend_autocompound_fixed_strategy', 'CC5CE6MWISDXT3MLNQ7R3FVILFVFEIH3COWGH45GJKL6BD2ZHF7F7JVI', 'EURC'),
        ('xlm_blend_autocompound_fixed_strategy', 'CDPWNUW7UMCSVO36VAJSQHQECISPJLCVPDASKHRC5SEROAAZDUQ5DG2Z', 'XLM'),
        ('usdc_blend_autocompound_yieldblox_strategy', 'CCSRX5E4337QMCMC3KO3RDFYI57T5NZV5XB3W3TWE4USCASKGL5URKJL', 'USDC'),
        ('eurc_blend_autocompound_yieldblox_strategy', 'CA33NXYN7H3EBDSA3U2FPSULGJTTL3FQRHD2ADAAPTKS3FUJOE73735A', 'EURC'),
        ('xlm_blend_autocompound_yieldblox_strategy', 'CBDOIGFO2QOOZTWQZ7AFPH5JOUS2SBN5CTTXR665NHV6GOCM6OUGI5KP', 'XLM'),
        ('cetes_blend_autocompound_yieldblox_strategy', 'CBTSRJLN5CVVOWLTH2FY5KNQ47KW5KKU3VWGASDN72STGMXLRRNHPRIL', 'CETES'),
        ('aqua_blend_autocompound_yieldblox_strategy', 'CCMJUJW6Z7I3TYDCJFGTI3A7QA3ASMYAZ5PSRRWBBIJQPKI2GXL5DW5D', 'AQUA'),
        ('ustry_blend_autocompound_yieldblox_strategy', 'CDDXPBOF727FDVTNV4I3G4LL4BHTJHE5BBC4W6WZAHMUPFDPBQBL6K7Y', 'USTRY'),
        ('usdglo_blend_autocompound_yieldblox_strategy', 'CCTLQXYSIUN3OSZLZ7O7MIJC6YCU3QLLS6TUM3P2CD6DAVELMWC3QV4E', 'USDGLO')
) AS strategies(strategy_name, strategy_address, asset_token)
ORDER BY asset_token, strategy_name;