# Referencia Rápida - DeFindex Queries

## Jerarquía de Queries (5 Niveles)

### 📊 NIVEL 1: Base
| ID | Nombre | Fuente | Output |
|----|--------|--------|--------|
| 5268612 | Vaults | `stellar.contract_data` | Lista de vaults |

### 🔍 NIVEL 2: Enriquecimiento
| ID | Nombre | Depende de | Output |
|----|--------|-----------|--------|
| 5782251 | Vaults + Metadata | 5268612 + `stellar.contract_data` | Vault name, symbol, asset |
| 5900680 | Vaults Events | 5782251 + `stellar.history_contract_events` | Deposits/withdrawals |

### ⏰ NIVEL 3: Temporal
| ID | Nombre | Depende de | Output |
|----|--------|-----------|--------|
| 5901637 | TVL Hours | 5782251 + 5900680 + Soroswap | TVL por hora en USD |

### 📈 NIVEL 4: Agregación
| ID | Nombre | Depende de | Output |
|----|--------|-----------|--------|
| 5906479 | TVL Filled Days | 5901637 | TVL diario continuo (forward-fill) |
| 5576346 | Aggregated Stats | 5900680 | Usuarios y transacciones |

### 🎯 NIVEL 5: Dashboard
| ID | Nombre | Depende de | Output |
|----|--------|-----------|--------|
| 5926821 | Latest Vaults | 5906479 | Snapshot actual de cada vault |
| 5926839 | Latest USD TVL | 5926821 | TVL total del protocolo |

---

## Tablas Stellar Principales

### `stellar.contract_data`
Estado de contratos inteligentes

**Campos clave:**
- `contract_id`: Dirección del contrato
- `contract_key_type`: Tipo de dato
  - `ScValTypeScvVec`: Arrays
  - `ScValTypeScvLedgerKeyContractInstance`: Metadata
- `val_decoded`: JSON con datos
- `closed_at`: Timestamp
- `ledger_sequence`: Número de bloque

### `stellar.history_contract_events`
Log de eventos de contratos

**Campos clave:**
- `contract_id`: Contrato emisor
- `topics_decoded`: Nombre del evento
- `data_decoded`: Payload JSON
- `closed_at`: Timestamp
- `transaction_hash`: Hash de TX

---

## Patrones Comunes

### 1. Parsing de i128 (números grandes)
```sql
CAST(
  CAST(json_extract_scalar(a, '$.i128.hi') AS DECIMAL(38,0)) * DECIMAL '1844674407370.9551616'
  + CAST(json_extract_scalar(a, '$.i128.lo') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
AS DECIMAL(38,7))
```

### 2. Latest Record por Grupo
```sql
WITH ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY vault ORDER BY day DESC) AS rn
  FROM data
)
SELECT * FROM ranked WHERE rn = 1
```

### 3. Forward Fill (rellenar gaps)
```sql
FIRST_VALUE(asset_tvl) OVER (
  PARTITION BY vault, tvl_group
  ORDER BY day
  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
```

### 4. Time Bucketing
```sql
DATE_TRUNC('hour', closed_at) AS hour  -- Por hora
DATE_TRUNC('day', closed_at) AS day    -- Por día
```

---

## Queries Útiles para Crear

### Análisis de Usuarios
```sql
-- Top usuarios por volumen
SELECT "to", SUM(amount) AS total_volume
FROM dune.paltalabs.result_de_findex_vaults_events
WHERE event = 'deposit'
GROUP BY "to"
ORDER BY total_volume DESC
LIMIT 10
```

### Net Flow Diario
```sql
SELECT
  DATE_TRUNC('day', closed_at) AS day,
  SUM(CASE WHEN event = 'deposit' THEN amount ELSE -amount END) AS net_flow
FROM dune.paltalabs.result_de_findex_vaults_events
GROUP BY day
ORDER BY day DESC
```

### TVL por Asset
```sql
SELECT
  m.asset_code,
  SUM(t.usd_tvl) AS total_tvl
FROM dune.paltalabs.result_de_findex_vaults_with_more_info_name_assets_symbol m
JOIN (
  SELECT vault, usd_tvl
  FROM dune.paltalabs.query_5906479
  WHERE day = (SELECT MAX(day) FROM dune.paltalabs.query_5906479)
) t ON t.vault = m.vault
GROUP BY m.asset_code
ORDER BY total_tvl DESC
```

### Crecimiento de TVL (30 días)
```sql
WITH today AS (
  SELECT vault, usd_tvl AS tvl_today
  FROM dune.paltalabs.query_5906479
  WHERE day = CURRENT_DATE
),
thirty_days_ago AS (
  SELECT vault, usd_tvl AS tvl_30d
  FROM dune.paltalabs.query_5906479
  WHERE day = CURRENT_DATE - INTERVAL '30' DAY
)
SELECT
  t.vault,
  ((t.tvl_today - f.tvl_30d) / NULLIF(f.tvl_30d, 0)) * 100 AS growth_pct
FROM today t
JOIN thirty_days_ago f ON f.vault = t.vault
ORDER BY growth_pct DESC
```

---

## Tablas Materializadas

Usar estas tablas en tus queries:

| Query Original | Tabla Materializada |
|---------------|-------------------|
| 5268612 | `query_5268612` |
| 5782251 | `dune.paltalabs.result_de_findex_vaults_with_more_info_name_assets_symbol` |
| 5900680 | `dune.paltalabs.result_de_findex_vaults_events` |
| 5901637 | `dune.paltalabs.query_5901637` |
| 5906479 | `dune.paltalabs.query_5906479` |
| 5926821 | `dune.paltalabs.query_5926821` |

---

## Limitaciones Conocidas

1. **Solo 1 asset por vault** - Query 5782251 no soporta multi-asset
2. **Precios limitados** - Solo assets en Soroswap (USDC hardcoded = $1)
3. **Forward-fill en Query 5906479** - Asume TVL constante entre eventos
4. **Materialización** - Queries derivadas deben re-ejecutarse si cambias las base

---

## Comandos Útiles

```bash
# Ver una query específica
python scripts/run_any_query.py 5926839

# Descargar cambios desde Dune
python scripts/pull_from_dune.py

# Subir cambios locales a Dune
python scripts/push_to_dune.py
```

---

## Tablas Base de Stellar

| Tabla | Uso Principal |
|-------|---------------|
| `stellar.history_contract_events` | Eventos de contratos (deposits, withdrawals) |
| `stellar.history_transactions` | Transacciones completas con fees |
| `stellar.contract_data` | Estado de contratos (metadata, balances) |

**Ver:** `STELLAR_TABLES_REFERENCE.md` para documentación completa con ejemplos

## Recursos

- **Documentación completa:** `DATA_FLOW.md`
- **Tablas Stellar:** `STELLAR_TABLES_REFERENCE.md`
- **Dashboard:** https://dune.com/paltalabs/defindex-queries
- **Stellar Data Catalog:** https://docs.dune.com/data-catalog/stellar
