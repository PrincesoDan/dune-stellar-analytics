# Dune Stellar Analytics

This repository manages SQL queries and AI prompts for analyzing data from the Stellar blockchain using Dune Analytics. It integrates with [DuneQueryRepo](https://github.com/duneanalytics/DuneQueryRepo) for version control and synchronization with Dune's platform.

## Prerequisites

- Python 3.8+
- Dune Analytics account with Plus plan (for API access)
- Dune API key ([generate here](https://dune.com/settings/api))

## Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

Or manually:
```bash
pip install dune-client python-dotenv pyyaml
```

### 2. Configure API Key

Copy the example `.env` file and add your Dune API key:

```bash
cp configs/dune.env.example configs/.env
```

Edit `configs/.env`:
```bash
DUNE_API_KEY=your_api_key_here
```

### 3. Configure Queries

Add your query IDs to `configs/queries.yml`:

```yaml
queries:
  - 5268612  # Defindex Vaults
  - 5268613  # Add more query IDs here
```

## Project Structure

```
dune-stellar-analytics/
├── configs/
│   ├── .env              # API credentials (git-ignored)
│   ├── dune.env.example  # Example environment file
│   └── queries.yml       # Query ID configuration
├── queries/
│   └── 5268612_vaults.sql   # SQL query files (ID_name.sql format)
├── scripts/
│   └── run_query.py      # Execute queries and display results
└── prompts/              # AI prompts for analysis
```

## Using DuneQueryRepo Integration

This project follows the [DuneQueryRepo](https://github.com/duneanalytics/DuneQueryRepo) pattern for managing Dune queries with version control.

### Pulling Queries from Dune

Download queries from Dune to your local repository:

```bash
python scripts/pull_from_dune.py
```

This creates/updates SQL files in `queries/` with the format `{query_id}_{query_name}.sql`.

### Pushing Queries to Dune

Upload local query changes back to Dune:

```bash
python scripts/push_to_dune.py
```

**Important:**
- You must own the queries or be part of the team that owns them
- Keep the `{query_id}_` prefix in filenames
- Add `-- already part of a query repo` comment to managed queries

### Running Queries

#### Run Specific Query (Original Script)

```bash
python scripts/run_query.py
```

Runs the first query in `queries.yml` (5268612 - DeFindex Vaults).

#### Run Any Query (Interactive Menu)

```bash
python scripts/run_any_query.py
```

Shows an interactive menu to select and run any query from the dashboard.

Or run directly by query ID:

```bash
# Run query 5926839 (Latest USD TVL), show 5 results
python scripts/run_any_query.py 5926839 5

# Run query 5576346 (Aggregated Stats), show 10 results (default)
python scripts/run_any_query.py 5576346
```

## Available Queries

This repository includes all queries from the [DeFindex Dashboard](https://dune.com/paltalabs/defindex-queries):

### Core Vault Queries

#### 5268612: DeFindex Vaults
Extracts vault contract addresses over time from the Stellar network.

**File:** `queries/5268612_defindex_vaults.sql`

**Returns:** `closed_at`, `vault`

#### 5782251: DeFindex Vaults with More Info
Extended vault information including names, assets, and symbols.

**File:** `queries/5782251_defindex_vaults_with_more_info_(name,_assets,_symbol).sql`

**Returns:** Vault metadata with asset details

### TVL (Total Value Locked) Queries

#### 5906479: DeFindex Vaults TVL, Filled Days
Historical TVL data with daily granularity, filling gaps for continuous time series.

**File:** `queries/5906479_defindex_vaults_tvl,_filled_days.sql`

**Returns:** Daily TVL per vault with USD values

#### 5926821: DeFindex Latest Vaults Data
Most recent TVL data for each vault.

**File:** `queries/5926821_defindex_latest_vaults_data.sql`

**Returns:** Latest snapshot of vault TVL data

#### 5926839: DeFindex Latest USD TVL
Aggregated total USD TVL across all vaults.

**File:** `queries/5926839_defindex_latest_usd_tvl.sql`

**Returns:** Single value - total protocol TVL in USD

#### 5901637: DeFindex TVL Only Hours with Events
Hourly TVL data filtered to show only periods with deposit/withdraw activity.

**File:** `queries/5901637_defindex_tvl_only_hours_with_events.sql`

**Returns:** Hourly TVL data with event timestamps

### Analytics Queries

#### 5900680: DeFindex Vaults Events
All deposit and withdraw events across DeFindex vaults.

**File:** `queries/5900680_defindex_vaults_events.sql`

**Returns:** Event log with vault, user, amount, and transaction details

#### 5576346: DeFindex Aggregated Stats
Summary statistics including unique accounts and transaction counts per vault.

**File:** `queries/5576346_defindex_aggregated_stats.sql`

**Returns:** Per-vault and protocol-wide user and transaction metrics

## Stellar Datasets

📊 **[STELLAR_TABLES_REFERENCE.md](STELLAR_TABLES_REFERENCE.md)** - Referencia completa de tablas
- Campos detallados y tipos de datos
- Ejemplos de queries por tabla
- Patrones de JOIN entre tablas
- Mejores prácticas y casos de uso

### Tablas Principales

- [stellar.contract_data](https://docs.dune.com/data-catalog/stellar/contract_data) - Smart contract state data
- [stellar.history_contract_events](https://docs.dune.com/data-catalog/stellar/history_contract_events) - Contract event logs
- [stellar.history_transactions](https://docs.dune.com/data-catalog/stellar/history_transactions) - Transaction history
- [stellar.history_operations](https://docs.dune.com/data-catalog/stellar/history_operations) - Operation history

## Workflow

1. **Create Query on Dune:** Build and test your query in the Dune web interface
2. **Add Query ID:** Add the query ID to `configs/queries.yml`
3. **Pull Query:** Run `pull_from_dune.py` to download the SQL
4. **Version Control:** Commit the SQL file to git
5. **Iterate Locally:** Edit SQL files locally
6. **Push Updates:** Run `push_to_dune.py` to sync changes back to Dune
7. **Run Analysis:** Execute queries via `run_query.py` or use AI to generate insights

## AI-Assisted Analysis

Use prompts in the `prompts/` directory with GPT or Claude to:
- Generate visualizations from query results
- Identify trends and patterns
- Create dashboards and reports
- Optimize query performance

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add/modify queries
4. Submit a pull request

## Data Architecture

📘 **[DATA_FLOW.md](DATA_FLOW.md)** - Documentación completa del flujo de datos
- Arquitectura de 5 niveles de queries
- Explicación detallada de cada query
- Dependencias y tablas materializadas
- Casos de uso y ejemplos de queries

⚡ **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Referencia rápida
- Jerarquía de queries en una tabla
- Patrones SQL comunes
- Snippets útiles para análisis
- Limitaciones conocidas

## Resources

- [Dune Analytics Docs](https://docs.dune.com/)
- [Stellar Data Catalog](https://docs.dune.com/data-catalog/stellar)
- [DuneQueryRepo Template](https://github.com/duneanalytics/DuneQueryRepo)
- [Dune API Documentation](https://docs.dune.com/api-reference/)
