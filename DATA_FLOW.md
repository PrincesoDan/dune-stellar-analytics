# Arquitectura de Datos - DeFindex Dashboard

## Resumen Ejecutivo

El dashboard DeFindex utiliza un sistema de queries en capas (5 niveles) que transforma datos en bruto de la blockchain Stellar en métricas analíticas de alto nivel. Los datos fluyen desde las tablas base de Stellar hacia queries derivadas que se construyen unas sobre otras.

---

## Fuentes de Datos Base (Nivel 0)

### 1. `stellar.contract_data`
**Tabla principal de estado de contratos**

Almacena el estado completo de los contratos inteligentes en Stellar.

**Campos clave:**
- `contract_id`: Dirección del contrato
- `contract_key_type`: Tipo de clave de almacenamiento
  - `'ScValTypeScvVec'`: Arrays/vectores (usado para listas de vaults)
  - `'ScValTypeScvLedgerKeyContractInstance'`: Instancia del contrato (metadata)
- `val_decoded`: Datos JSON decodificados del contrato
- `closed_at`: Timestamp del bloque
- `ledger_sequence`: Número de secuencia del ledger

**Uso en DeFindex:**
- Extraer lista de vaults del contrato principal
- Obtener metadata de vaults (nombre, símbolo, assets)
- Leer configuración de assets por vault

### 2. `stellar.history_contract_events`
**Log de eventos de contratos**

Registra todos los eventos emitidos por contratos inteligentes.

**Campos clave:**
- `contract_id`: Contrato que emitió el evento
- `topics_decoded`: Temas del evento (incluyendo nombre del evento)
- `data_decoded`: Payload JSON del evento
- `closed_at`: Timestamp del evento
- `transaction_hash`: Hash de la transacción
- `transaction_id`: ID único de la transacción

**Uso en DeFindex:**
- Detectar eventos de `deposit` y `withdraw`
- Extraer montos de transacciones
- Identificar usuarios que interactúan con vaults
- Calcular TVL en tiempo real

### 3. `dune.paltalabs.result_soroswap_tokens_sdex_prices_daily_since_march_2024`
**Precios históricos de tokens** (Tabla externa - Soroswap)

Precios diarios de tokens en Stellar DEX.

**Campos clave:**
- `contract_id`: Dirección del token
- `price`: Precio en USD
- `closed_at_day`: Fecha del precio

**Uso en DeFindex:**
- Convertir TVL de assets a USD
- Calcular valor total del protocolo

---

## Flujo de Datos por Niveles

### NIVEL 1: Queries Base (Extracción Directa)

#### Query 5268612: DeFindex Vaults
**Función:** Extrae la lista de todos los vaults DeFindex

**Fuente de datos:**
```sql
FROM stellar.contract_data
WHERE contract_id = 'CDKFHFJIET3A73A2YN4KV7NSV32S6YGQMUFH3DNJXLBWL4SKEGVRNFKI'
  AND contract_key_type = 'ScValTypeScvVec'
```

**Output:**
- `closed_at`: Fecha de creación del vault
- `vault`: Dirección del contrato del vault

**Lógica:**
1. Lee el contrato principal de DeFindex
2. Extrae el array de vaults almacenado como `ScValTypeScvVec`
3. Parsea JSON para obtener direcciones de vaults

**Dependencias:** Ninguna (query base)

---

### NIVEL 2: Queries de Enriquecimiento

#### Query 5782251: DeFindex Vaults with More Info
**Función:** Añade metadata a los vaults (nombre, símbolo, assets)

**Fuente de datos:**
```sql
FROM query_5268612 v  -- Lista de vaults
JOIN stellar.contract_data cd ON cd.contract_id = v.vault
WHERE cd.contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'
```

**Output:**
- `vault`: Dirección del vault
- `vault_name`: Nombre limpio del vault
- `vault_symbol`: Símbolo del vault
- `asset`: Dirección del asset principal
- `asset_code`: Código del asset (USDC, XLM, etc.)

**Lógica:**
1. Toma la lista de vaults de Query 5268612
2. Para cada vault, lee su instancia del contrato
3. Extrae metadata del JSON:
   - Nombre del vault
   - Símbolo del vault
   - Asset principal (solo soporta vaults de 1 asset)
4. Cruza con `stellar.contract_data` para obtener `asset_code`
5. Formatea nombre: "BeansUsdcVault - CBN..2S3"

**Limitación importante:** Solo soporta vaults con **UN solo asset**. Toma solo el primer asset si hay múltiples.

**Dependencias:**
- Query 5268612 (vaults base)
- `stellar.contract_data` (metadata)

---

#### Query 5900680: DeFindex Vaults Events
**Función:** Extrae todos los eventos de deposit y withdraw con sus detalles

**Fuente de datos:**
```sql
FROM stellar.history_contract_events he
WHERE he.contract_id IN (SELECT vault FROM query_5782251)
  AND he.topics_decoded LIKE '%DeFindexVault%'
  AND (he.topics_decoded LIKE '%withdraw%' OR he.topics_decoded LIKE '%deposit%')
```

**Output:**
- `closed_at`: Timestamp del evento
- `vault`: Vault donde ocurrió
- `vault_name`: Nombre del vault
- `asset` / `asset_code`: Asset del vault
- `event`: 'deposit' o 'withdraw'
- `to`: Usuario que ejecutó la acción
- `amount`: Cantidad depositada/retirada
- `total_amount`: TVL total del vault después del evento
- `tx_hash`: Hash de la transacción

**Lógica compleja:**
1. Filtra eventos de vaults DeFindex que sean deposit o withdraw
2. **Extrae montos** del JSON usando lógica i128 (enteros de 128 bits):
   - Maneja números grandes con campos `hi` y `lo`
   - Aplica conversión decimal: `hi * 1844674407370.9551616 + lo * 0.0000001`
3. **Extrae dirección de usuario** desde campos `depositor` o `withdrawer`
4. **Calcula TVL post-evento** desde `total_managed_funds_before`
5. Cruza con metadata de vaults para contexto

**Campos JSON parseados:**
- `amounts` / `amounts_withdrawn`: Array de montos
- `depositor` / `withdrawer`: Dirección del usuario
- `total_managed_funds_before`: TVL antes del evento

**Dependencias:**
- Query 5782251 (vault metadata)
- `stellar.history_contract_events`

---

### NIVEL 3: Queries de Análisis Temporal

#### Query 5901637: DeFindex TVL Only Hours with Events
**Función:** Calcula TVL en USD por vault por hora, solo en horas con actividad

**Fuente de datos:**
```sql
FROM dune.paltalabs.result_de_findex_vaults_events ve  -- Query 5900680
JOIN vault_to_token m  -- Query 5782251
LEFT JOIN prices p  -- Soroswap prices
```

**Output:**
- `hour`: Hora del evento (truncada)
- `vault` / `vault_name`: Identificación del vault
- `asset` / `asset_code`: Asset del vault
- `asset_tvl`: TVL en unidades del asset
- `asset_price`: Precio USD del asset
- `usd_tvl`: TVL en USD (`asset_tvl * asset_price`)

**Lógica:**
1. Agrupa eventos por hora usando `DATE_TRUNC('hour', closed_at)`
2. Toma el **MAX** de `total_amount` por hora (TVL más alto de esa hora)
3. Cruza con precios diarios de Soroswap
4. Para USDC, usa precio fijo = 1.0
5. Calcula TVL en USD: `asset_tvl * asset_price`
6. **Solo incluye horas con eventos** (no gaps)

**Manejo de precios:**
- USDC siempre = $1.00
- Otros tokens: busca precio del mismo día en tabla de Soroswap
- Si no hay precio, el vault se excluye de ese período

**Dependencias:**
- Query 5900680 (eventos, via `dune.paltalabs.result_de_findex_vaults_events`)
- Query 5782251 (metadata, via `dune.paltalabs.result_de_findex_vaults_with_more_info_name_assets_symbol`)
- Soroswap prices (externa)

---

### NIVEL 4: Queries de Agregación Temporal

#### Query 5906479: DeFindex Vaults TVL, Filled Days
**Función:** TVL diario con gaps rellenados (forward-fill) para series continuas

**Fuente de datos:**
```sql
FROM dune.paltalabs.query_5901637  -- Query 5901637 (TVL por hora)
```

**Output:**
- `day`: Fecha (granularidad diaria)
- `vault` / `vault_name`: Identificación del vault
- `asset` / `asset_code`: Asset del vault
- `asset_tvl`: TVL en unidades del asset
- `usd_tvl`: TVL en USD

**Lógica (10 pasos):**
1. **Agregación diaria:** Toma MAX de `asset_tvl` y `usd_tvl` por día
2. **Filtra vaults activos:** Solo vaults con TVL > 0 al menos una vez
3. **Define rango temporal:** MIN y MAX fecha de todos los datos
4. **Genera calendario:** Crea secuencia de días continuos
5. **Grid completo:** Cruza calendario x vaults activos
6. **Join con datos reales:** LEFT JOIN para preservar días sin datos
7. **Agrupa para forward-fill:** Usa SUM acumulativa para identificar bloques de datos
8. **Forward-fill:** Usa `FIRST_VALUE()` para propagar último valor conocido
9. **Limpieza:** Remueve filas con NULL
10. **Output:** Serie temporal continua sin gaps

**Técnica de forward-fill:**
```sql
FIRST_VALUE(asset_tvl) OVER (
    PARTITION BY vault, tvl_group
    ORDER BY day
)
```

**Por qué forward-fill?**
- Vaults sin actividad mantienen su TVL
- Permite visualizar TVL continuo en gráficos
- Evita "huecos" en series temporales

**Dependencias:**
- Query 5901637 (TVL por hora)

---

#### Query 5576346: DeFindex Aggregated Stats
**Función:** Estadísticas agregadas de usuarios y transacciones

**Fuente de datos:**
```sql
FROM dune.paltalabs.result_de_findex_vaults_events  -- Query 5900680
```

**Output:**
- `vault` / `vault_name`: Identificación del vault
- `total_accounts`: Usuarios únicos del vault
- `total_txs`: Transacciones totales del vault
- `total_accounts_all`: Usuarios únicos del protocolo
- `total_txs_all`: Transacciones totales del protocolo

**Lógica:**
1. **Por vault:** `COUNT(DISTINCT account)` y `COUNT(DISTINCT tx_hash)`
2. **Global:** Same counts sin agrupar por vault
3. **Join:** CROSS JOIN para añadir totales globales a cada fila

**Métricas clave:**
- Usuarios únicos por vault vs protocolo
- Actividad de transacciones por vault
- Distribución de usuarios entre vaults

**Dependencias:**
- Query 5900680 (eventos)

---

### NIVEL 5: Queries de Dashboard (Vistas Finales)

#### Query 5926821: DeFindex Latest Vaults Data
**Función:** Snapshot más reciente de cada vault

**Fuente de datos:**
```sql
FROM dune.paltalabs.query_5906479  -- Query 5906479 (TVL daily filled)
```

**Output:**
- `latest_day`: Fecha más reciente con datos
- `vault` / `vault_name`: Identificación del vault
- `asset` / `asset_code`: Asset del vault
- `asset_tvl`: TVL actual en asset
- `usd_tvl`: TVL actual en USD

**Lógica:**
1. Ordena por fecha DESC para cada vault
2. Usa `ROW_NUMBER()` para identificar fila más reciente
3. Filtra `WHERE rn = 1` para quedarse solo con última fecha
4. Ordena por `usd_tvl DESC` para ranking

**Uso:** Tabla actual de vaults para dashboard

**Dependencias:**
- Query 5906479 (TVL filled days)

---

#### Query 5926839: DeFindex Latest USD TVL
**Función:** TVL total del protocolo (single metric)

**Fuente de datos:**
```sql
FROM dune.paltalabs.query_5926821  -- Query 5926821 (Latest vaults)
```

**Output:**
- `total_usd_tvl`: TVL total en USD de todos los vaults

**Lógica:**
```sql
SELECT SUM(usd_tvl) AS total_usd_tvl
FROM latest_vaults
```

**Uso:** Métrica principal del dashboard (headline number)

**Dependencias:**
- Query 5926821 (latest vaults)

---

## Diagrama de Dependencias

```
┌─────────────────────────────────────────────────────────────┐
│                    NIVEL 0: FUENTES BASE                    │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│stellar.contract_ │  │stellar.history_  │  │soroswap.prices   │
│      data        │  │contract_events   │  │    (externa)     │
└──────────────────┘  └──────────────────┘  └──────────────────┘
        │                     │                     │
        │                     │                     │
┌─────────────────────────────────────────────────────────────┐
│                    NIVEL 1: QUERIES BASE                    │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────┐
│  5268612         │  Lista de vaults
│  Vaults          │
└──────────────────┘
        │
        │
┌─────────────────────────────────────────────────────────────┐
│                 NIVEL 2: ENRIQUECIMIENTO                    │
└─────────────────────────────────────────────────────────────┘
        │
        ├──────────────────┐
        ▼                  ▼
┌──────────────────┐  ┌──────────────────┐
│  5782251         │  │  5900680         │
│  Vaults +        │──▶│  Vaults Events  │
│  Metadata        │  └──────────────────┘
└──────────────────┘         │
        │                    │
        │                    │
┌─────────────────────────────────────────────────────────────┐
│                NIVEL 3: ANÁLISIS TEMPORAL                   │
└─────────────────────────────────────────────────────────────┘
        │                    │
        └────────┬───────────┘
                 ▼
        ┌──────────────────┐
        │  5901637         │  TVL por hora (con precios)
        │  TVL Hours       │
        │  with Events     │
        └──────────────────┘
                 │
                 │
┌─────────────────────────────────────────────────────────────┐
│               NIVEL 4: AGREGACIÓN TEMPORAL                  │
└─────────────────────────────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌──────────────────┐  ┌──────────────────┐
│  5906479         │  │  5576346         │
│  TVL Filled Days │  │  Aggregated Stats│
└──────────────────┘  └──────────────────┘
        │
        │
┌─────────────────────────────────────────────────────────────┐
│                 NIVEL 5: DASHBOARD VIEWS                    │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────┐
│  5926821         │  Latest snapshot
│  Latest Vaults   │
│  Data            │
└──────────────────┘
        │
        ▼
┌──────────────────┐
│  5926839         │  Single metric
│  Latest USD TVL  │  $724,592.87
└──────────────────┘
```

---

## Tablas Intermedias en Dune

Dune materializa resultados de queries como tablas para reutilización:

| Query ID | Tabla Materializada | Uso |
|----------|---------------------|-----|
| 5268612 | `query_5268612` | Referenciada directamente en SQL |
| 5782251 | `dune.paltalabs.result_de_findex_vaults_with_more_info_name_assets_symbol` | Usada en queries 5900680, 5901637 |
| 5900680 | `dune.paltalabs.result_de_findex_vaults_events` | Usada en queries 5576346, 5901637 |
| 5901637 | `dune.paltalabs.query_5901637` | Usada en query 5906479 |
| 5906479 | `dune.paltalabs.query_5906479` | Usada en query 5926821 |
| 5926821 | `dune.paltalabs.query_5926821` | Usada en query 5926839 |

---

## Conceptos Clave de Stellar en el Código

### 1. Tipos de Almacenamiento de Contratos

```sql
contract_key_type = 'ScValTypeScvVec'  -- Arrays/Listas
contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'  -- Metadata del contrato
```

### 2. Parsing de Números i128 (128-bit integers)

Stellar usa enteros de 128 bits para representar montos. Se codifican como:
- `i128.hi`: 64 bits altos
- `i128.lo`: 64 bits bajos

Conversión a decimal:
```sql
CAST(hi AS DECIMAL(38,0)) * 1844674407370.9551616 +
CAST(lo AS DECIMAL(38,0)) * 0.0000001
```

División por 10^7 para ajustar decimales del asset.

### 3. Estructura de Eventos

Eventos tienen dos componentes principales:
- **topics_decoded**: Identificador del evento (nombre)
- **data_decoded**: Payload JSON con datos del evento

Estructura típica:
```json
{
  "map": [
    {"key": {"symbol": "depositor"}, "val": {"address": "G..."}},
    {"key": {"symbol": "amounts"}, "val": {"vec": [...]}}
  ]
}
```

---

## Limitaciones y Consideraciones

### 1. **Vaults Multi-Asset**
Query 5782251 solo soporta vaults con **UN asset**. Para multi-asset:
- Necesitarás `UNNEST` el array de assets
- Calcular TVL por cada asset
- Sumar TVLs convertidos a USD

### 2. **Precios de Assets**
- USDC tiene precio hardcoded = $1.00
- Otros assets dependen de Soroswap
- Assets sin precio en Soroswap se excluyen

### 3. **Gaps Temporales**
- Query 5901637: Solo horas con eventos (tiene gaps)
- Query 5906479: Forward-fill para eliminar gaps
- Elige según necesidad de visualización

### 4. **Materialización**
- Queries derivadas usan tablas materializadas (`result_*` o `query_*`)
- Si cambias una query base, debes re-ejecutar todas las derivadas
- Orden de ejecución importa

---

## Casos de Uso para Nuevas Queries

### 1. **Análisis de Usuarios**
**Fuente:** Query 5900680 (events)

Ejemplos:
- Top 10 depositantes por volumen
- Usuarios más activos (frecuencia de transacciones)
- Tasa de retención de usuarios
- Análisis de cohorts

```sql
SELECT
  "to" AS user,
  COUNT(*) AS num_transactions,
  SUM(CASE WHEN event = 'deposit' THEN amount ELSE 0 END) AS total_deposited,
  SUM(CASE WHEN event = 'withdraw' THEN amount ELSE 0 END) AS total_withdrawn
FROM dune.paltalabs.result_de_findex_vaults_events
GROUP BY "to"
ORDER BY total_deposited DESC
LIMIT 10
```

### 2. **Rendimiento de Vaults**
**Fuente:** Query 5906479 (TVL daily)

Ejemplos:
- Crecimiento de TVL en últimos 30 días
- Volatilidad de TVL por vault
- Vaults con mayor crecimiento

```sql
WITH daily_change AS (
  SELECT
    vault,
    vault_name,
    day,
    usd_tvl,
    LAG(usd_tvl) OVER (PARTITION BY vault ORDER BY day) AS prev_tvl
  FROM dune.paltalabs.query_5906479
)
SELECT
  vault,
  vault_name,
  ((usd_tvl - prev_tvl) / NULLIF(prev_tvl, 0)) * 100 AS tvl_change_pct
FROM daily_change
WHERE day = CURRENT_DATE
ORDER BY tvl_change_pct DESC
```

### 3. **Análisis de Assets**
**Fuente:** Query 5782251 (metadata) + Query 5906479 (TVL)

Ejemplos:
- Distribución de TVL por asset
- Dominancia de USDC vs otros assets
- Correlación entre precio de asset y TVL

```sql
SELECT
  m.asset_code,
  COUNT(DISTINCT m.vault) AS num_vaults,
  SUM(t.usd_tvl) AS total_tvl
FROM dune.paltalabs.result_de_findex_vaults_with_more_info_name_assets_symbol m
JOIN dune.paltalabs.query_5906479 t ON t.vault = m.vault
WHERE t.day = (SELECT MAX(day) FROM dune.paltalabs.query_5906479)
GROUP BY m.asset_code
ORDER BY total_tvl DESC
```

### 4. **Análisis de Flujos (Flow Analysis)**
**Fuente:** Query 5900680 (events)

Ejemplos:
- Net flow diario (deposits - withdrawals)
- Identificar días con mayor actividad
- Detectar eventos de liquidez

```sql
SELECT
  DATE_TRUNC('day', closed_at) AS day,
  vault_name,
  SUM(CASE WHEN event = 'deposit' THEN amount ELSE 0 END) AS deposits,
  SUM(CASE WHEN event = 'withdraw' THEN amount ELSE 0 END) AS withdrawals,
  SUM(CASE WHEN event = 'deposit' THEN amount ELSE -amount END) AS net_flow
FROM dune.paltalabs.result_de_findex_vaults_events
GROUP BY day, vault_name
ORDER BY day DESC, net_flow DESC
```

### 5. **Comparación Cross-Vault**
**Fuente:** Múltiples queries

Ejemplos:
- Ranking de vaults por múltiples métricas
- Identificar vaults outliers
- Eficiencia por vault (TVL / num_users)

```sql
WITH metrics AS (
  SELECT
    v.vault,
    v.vault_name,
    v.asset_code,
    t.usd_tvl,
    s.total_accounts,
    s.total_txs
  FROM dune.paltalabs.result_de_findex_vaults_with_more_info_name_assets_symbol v
  JOIN dune.paltalabs.query_5906479 t
    ON t.vault = v.vault
    AND t.day = (SELECT MAX(day) FROM dune.paltalabs.query_5906479)
  JOIN query_5576346 s
    ON s.vault = v.vault
)
SELECT
  vault_name,
  asset_code,
  usd_tvl,
  total_accounts,
  usd_tvl / NULLIF(total_accounts, 0) AS tvl_per_user,
  total_txs / NULLIF(total_accounts, 0) AS txs_per_user
FROM metrics
ORDER BY usd_tvl DESC
```

---

## Próximos Pasos Sugeridos

Para extender el análisis, considera crear queries para:

1. **Análisis de Tiempo:**
   - Hora del día más activa
   - Día de la semana con mayor volumen
   - Estacionalidad

2. **Análisis de Red:**
   - Grafo de flujo de usuarios entre vaults
   - Usuarios que usan múltiples vaults
   - Patrones de migración

3. **Alertas y Anomalías:**
   - Detección de withdrawals masivos
   - Caídas súbitas de TVL
   - Nuevos vaults

4. **Proyecciones:**
   - Forecast de TVL usando regresión
   - Predicción de crecimiento de usuarios
   - Estacionalidad histórica

5. **Composición:**
   - TVL histórico total del protocolo
   - Comparación con otros protocolos DeFi en Stellar
   - Market share

---

## Preguntas Frecuentes

**Q: ¿Por qué algunas queries usan `query_XXXXX` y otras `result_*`?**
A: Dune tiene dos formas de referenciar queries:
- `query_XXXXX`: Referencia directa por ID
- `dune.paltalabs.result_*`: Tabla materializada con nombre personalizado

Ambas son equivalentes pero los resultados materializados permiten nombres más descriptivos.

**Q: ¿Cómo añado soporte para vaults multi-asset?**
A: Modifica Query 5782251 para usar `UNNEST` en el array de assets:
```sql
CROSS JOIN UNNEST(
  CAST(json_extract(instance_json, '$.contract_instance.storage[1].val.map') AS array(json))
) AS t(asset_map)
```

**Q: ¿Puedo acceder a datos de transacciones individuales?**
A: Sí, usa `stellar.history_transactions` y cruza con eventos usando `transaction_hash`.

**Q: ¿Cómo obtengo datos históricos de precios más antiguos?**
A: Necesitas otra fuente de precios o extender la tabla de Soroswap. Considera APIs externas o indexadores.

---

## Contacto y Contribución

Para añadir nuevas queries o modificar existentes:
1. Crea/modifica el SQL localmente
2. Prueba en Dune web interface
3. Usa `push_to_dune.py` para sincronizar
4. Actualiza este documento con la nueva query
