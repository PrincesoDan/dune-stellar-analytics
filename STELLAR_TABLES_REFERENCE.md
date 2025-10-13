# Referencia de Tablas de Stellar en Dune

## Resumen

Dune Analytics proporciona 3 tablas principales para trabajar con datos de Stellar blockchain. Esta guía documenta campos, tipos de datos y casos de uso para cada tabla.

---

## 1. `stellar.history_contract_events`

### Descripción
Captura todos los eventos de smart contracts en la blockchain Stellar. Proporciona información detallada sobre la ejecución de contratos y transacciones asociadas.

**Cuando usar esta tabla:**
- Tracking de interacciones con smart contracts
- Análisis de eventos específicos (deposits, withdrawals, swaps, etc.)
- Auditoría de llamadas a contratos
- Construcción de índices de eventos

### Campos Principales

#### Identificación de Transacciones
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `transaction_hash` | binary | Hash único de la transacción |
| `transaction_id` | bigint | ID único de la transacción |
| `successful` | boolean | Indica si la transacción fue exitosa |
| `in_successful_contract_call` | boolean | Indica si fue una llamada exitosa al contrato |

#### Información del Contrato
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `contract_id` | varchar | Dirección del smart contract que emitió el evento |
| `type` | int | Código numérico del tipo de evento |
| `type_string` | varchar | Representación textual del tipo de evento |

#### Datos del Evento
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `topics` | varchar | Temas del evento (raw) para categorización y filtrado |
| `topics_decoded` | varchar | Temas decodificados en formato legible |
| `data` | varchar | Payload del evento (raw) |
| `data_decoded` | varchar | Payload decodificado en formato JSON legible |
| `contract_event_xdr` | varchar | Formato XDR raw del evento |

#### Campos Temporales
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `closed_at_date` | date | Fecha de cierre del evento |
| `closed_at` | timestamp | Timestamp preciso de cierre |
| `ledger_sequence` | bigint | Número de ledger que contiene el evento |
| `ingested_at` | timestamp | Timestamp de ingesta por Dune |

### Ejemplo de Uso: Filtrar Eventos de Deposit

```sql
SELECT
    contract_id,
    closed_at,
    transaction_hash,
    topics_decoded,
    data_decoded
FROM stellar.history_contract_events
WHERE contract_id = 'CXXXX...'  -- Tu contrato
  AND topics_decoded LIKE '%deposit%'
  AND successful = true
ORDER BY closed_at DESC
LIMIT 100
```

### Ejemplo de Uso: Contar Eventos por Contrato

```sql
SELECT
    contract_id,
    COUNT(*) AS total_events,
    COUNT(DISTINCT transaction_hash) AS unique_transactions,
    MIN(closed_at) AS first_event,
    MAX(closed_at) AS last_event
FROM stellar.history_contract_events
WHERE successful = true
  AND closed_at >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY contract_id
ORDER BY total_events DESC
```

### Notas Importantes
- **Parsing JSON**: Usa `json_extract()` y `json_parse()` para trabajar con `data_decoded`
- **Filtrado eficiente**: Siempre filtra por `contract_id` primero para mejor performance
- **Eventos fallidos**: Incluye `successful = true` si solo quieres eventos exitosos
- **Topics vs Data**: `topics` contiene metadatos del evento, `data` contiene el payload

---

## 2. `stellar.history_transactions`

### Descripción
Contiene detalles de transacciones en Stellar, vinculando múltiples operaciones dentro de una transacción. Proporciona información completa sobre fees, recursos, y estado de ejecución.

**Cuando usar esta tabla:**
- Análisis de transacciones completas (no solo eventos)
- Tracking de fees y costos de gas
- Análisis de cuentas y sus actividades
- Investigación de transacciones fallidas

### Campos Principales

#### Identificación
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | bigint | ID único de la transacción |
| `transaction_hash` | binary | Hash de la transacción |
| `ledger_sequence` | bigint | Número de ledger que contiene la transacción |

#### Información de la Cuenta
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `account` | varchar | Dirección de la cuenta que originó la transacción |
| `account_muxed` | varchar | Cuenta multiplexada (si aplica) |

#### Fees y Recursos
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `max_fee` | bigint | Fee máximo que el usuario está dispuesto a pagar |
| `fee_charged` | bigint | Fee real cobrado |
| `operation_count` | int | Número de operaciones en la transacción |

#### Estado y Resultado
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `successful` | boolean | Indica si la transacción fue exitosa |
| `result_code` | varchar | Código de resultado de la transacción |
| `result_code_s` | varchar | Descripción textual del código de resultado |

#### Soroban (Smart Contracts)
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `soroban_resources_instructions` | bigint | Instrucciones consumidas |
| `soroban_resources_read_bytes` | bigint | Bytes leídos |
| `soroban_resources_write_bytes` | bigint | Bytes escritos |

#### Timestamps
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `created_at` | timestamp | Momento de creación de la transacción |
| `closed_at` | timestamp | Momento de cierre de la transacción |
| `ingested_at` | timestamp | Timestamp de ingesta por Dune |

#### Metadata Avanzada
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `transaction_envelope_xdr` | varchar | Envelope XDR raw |
| `signatures` | array | Array de firmas de la transacción |
| `memo_type` | varchar | Tipo de memo adjunto |
| `memo` | varchar | Contenido del memo |

### Ejemplo de Uso: Análisis de Fees

```sql
SELECT
    DATE_TRUNC('day', closed_at) AS day,
    COUNT(*) AS num_transactions,
    AVG(fee_charged) AS avg_fee,
    MIN(fee_charged) AS min_fee,
    MAX(fee_charged) AS max_fee,
    SUM(fee_charged) AS total_fees
FROM stellar.history_transactions
WHERE successful = true
  AND closed_at >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY day
ORDER BY day DESC
```

### Ejemplo de Uso: Top Cuentas Más Activas

```sql
SELECT
    account,
    COUNT(*) AS num_transactions,
    SUM(operation_count) AS total_operations,
    SUM(fee_charged) AS total_fees_paid,
    MIN(closed_at) AS first_tx,
    MAX(closed_at) AS last_tx
FROM stellar.history_transactions
WHERE successful = true
  AND closed_at >= CURRENT_DATE - INTERVAL '7' DAY
GROUP BY account
ORDER BY num_transactions DESC
LIMIT 20
```

### Ejemplo de Uso: Análisis de Transacciones Fallidas

```sql
SELECT
    result_code_s,
    COUNT(*) AS failure_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS failure_percentage
FROM stellar.history_transactions
WHERE successful = false
  AND closed_at >= CURRENT_DATE - INTERVAL '7' DAY
GROUP BY result_code_s
ORDER BY failure_count DESC
```

### Notas Importantes
- **Múltiples operaciones**: Una transacción puede contener múltiples operaciones (ver `operation_count`)
- **Recursos Soroban**: Solo disponibles para transacciones de smart contracts
- **XDR Format**: Formato raw de Stellar para debugging avanzado
- **Fee Charged vs Max Fee**: `fee_charged` es el fee real, `max_fee` es el límite establecido

---

## 3. `stellar.contract_data`

### Descripción
Almacena datos de estado de smart contracts, incluyendo tokens soportados y costos de almacenamiento. Representa el estado actual y histórico de los contratos.

**Cuando usar esta tabla:**
- Leer estado actual de contratos
- Extraer metadata de contratos (nombres, símbolos, etc.)
- Tracking de cambios de estado en el tiempo
- Análisis de assets y balances de contratos

### Campos Principales

#### Identificación del Contrato
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `contract_id` | varchar | Dirección única del smart contract |
| `contract_key_type` | varchar | Tipo de clave de almacenamiento |
| `ledger_key_hash` | varchar | Hash de la clave del ledger entry |

#### Datos del Contrato
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `key_decoded` | varchar | Clave decodificada en formato legible |
| `val_decoded` | varchar | Valor decodificado en formato JSON |
| `contract_data_xdr` | varchar | Formato XDR raw del dato |

#### Información de Assets
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `asset_code` | varchar | Código del asset asociado (ej: USDC, XLM) |
| `asset_issuer` | varchar | Emisor del asset |
| `asset_type` | varchar | Tipo de asset (native/issued) |

#### Estado y Modificación
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `last_modified_ledger` | bigint | Número de ledger de última modificación |
| `deleted` | boolean | Indica si el entry fue eliminado |
| `ledger_sequence` | bigint | Número de secuencia del ledger |
| `durability` | varchar | Durabilidad del almacenamiento |

#### Timestamps
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `closed_at` | timestamp | Timestamp de cierre |
| `closed_at_date` | date | Fecha de cierre |
| `updated_at` | timestamp | Última actualización del registro |
| `ingested_at` | timestamp | Timestamp de ingesta por Dune |

### Tipos de Claves de Contrato (contract_key_type)

Los contratos en Stellar usan diferentes tipos de claves para organizar datos:

| Tipo | Uso |
|------|-----|
| `ScValTypeScvVec` | Arrays/Vectores - Usado para listas (ej: lista de vaults) |
| `ScValTypeScvLedgerKeyContractInstance` | Metadata del contrato (nombre, símbolo, configuración) |
| `ScValTypeScvMap` | Mapas clave-valor |
| `ScValTypeScvAddress` | Direcciones |
| Otros tipos | Integers, strings, bytes, etc. |

### Ejemplo de Uso: Extraer Metadata de Contratos

```sql
SELECT
    contract_id,
    key_decoded,
    json_extract_scalar(json_parse(val_decoded), '$.contract_instance.storage[0].val.map[1].val.string') AS name,
    json_extract_scalar(json_parse(val_decoded), '$.contract_instance.storage[0].val.map[2].val.string') AS symbol,
    closed_at
FROM stellar.contract_data
WHERE contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'
  AND contract_id = 'CXXXXX...'  -- Tu contrato
ORDER BY closed_at DESC
LIMIT 1
```

### Ejemplo de Uso: Tracking de Cambios de Estado

```sql
WITH state_history AS (
    SELECT
        contract_id,
        ledger_sequence,
        closed_at,
        val_decoded,
        LAG(val_decoded) OVER (PARTITION BY contract_id ORDER BY ledger_sequence) AS prev_val
    FROM stellar.contract_data
    WHERE contract_id = 'CXXXXX...'
      AND contract_key_type = 'ScValTypeScvVec'
)
SELECT
    ledger_sequence,
    closed_at,
    val_decoded AS current_state,
    prev_val AS previous_state,
    CASE
        WHEN prev_val IS NULL THEN 'CREATED'
        WHEN val_decoded != prev_val THEN 'MODIFIED'
        ELSE 'NO_CHANGE'
    END AS change_type
FROM state_history
WHERE prev_val IS NULL OR val_decoded != prev_val
ORDER BY ledger_sequence DESC
```

### Ejemplo de Uso: Extraer Lista de Items de un Vector

```sql
WITH contract_vector AS (
    SELECT
        contract_id,
        closed_at,
        CAST(JSON_PARSE(val_decoded) AS JSON) AS vector_json
    FROM stellar.contract_data
    WHERE contract_id = 'CXXXXX...'
      AND contract_key_type = 'ScValTypeScvVec'
)
SELECT
    closed_at,
    json_extract_scalar(vector_json, '$.address') AS item_address
FROM contract_vector
ORDER BY closed_at DESC
```

### Notas Importantes
- **State Snapshots**: Cada registro representa el estado en un momento específico
- **Último valor**: Usa `MAX(ledger_sequence)` o `MAX(closed_at)` para obtener estado actual
- **Deleted entries**: Filtra `deleted = false` para ver solo datos activos
- **JSON Parsing**: Estructura de JSON varía según el tipo de contrato - explora primero con `LIMIT 1`
- **Performance**: Siempre filtra por `contract_id` y `contract_key_type` para queries rápidas

---

## Relaciones Entre Tablas

### Joins Comunes

#### 1. Events → Transactions (Información completa de transacciones con eventos)

```sql
SELECT
    e.contract_id,
    e.closed_at,
    e.topics_decoded,
    t.account,
    t.fee_charged,
    t.operation_count
FROM stellar.history_contract_events e
JOIN stellar.history_transactions t
    ON e.transaction_hash = t.transaction_hash
WHERE e.contract_id = 'CXXXXX...'
  AND e.successful = true
ORDER BY e.closed_at DESC
```

#### 2. Events → Contract Data (Eventos con metadata del contrato)

```sql
WITH latest_contract_metadata AS (
    SELECT
        contract_id,
        val_decoded,
        ROW_NUMBER() OVER (PARTITION BY contract_id ORDER BY closed_at DESC) AS rn
    FROM stellar.contract_data
    WHERE contract_key_type = 'ScValTypeScvLedgerKeyContractInstance'
)
SELECT
    e.contract_id,
    e.closed_at,
    e.topics_decoded,
    m.val_decoded AS contract_metadata
FROM stellar.history_contract_events e
JOIN latest_contract_metadata m
    ON e.contract_id = m.contract_id
    AND m.rn = 1
WHERE e.successful = true
```

#### 3. Contract Data → Events (Contratos con sus eventos)

```sql
WITH contracts AS (
    SELECT DISTINCT contract_id
    FROM stellar.contract_data
    WHERE asset_code = 'USDC'
)
SELECT
    c.contract_id,
    COUNT(*) AS num_events,
    COUNT(DISTINCT e.transaction_hash) AS num_transactions,
    MIN(e.closed_at) AS first_event,
    MAX(e.closed_at) AS last_event
FROM contracts c
JOIN stellar.history_contract_events e
    ON e.contract_id = c.contract_id
WHERE e.successful = true
GROUP BY c.contract_id
ORDER BY num_events DESC
```

---

## Patrones de Query Avanzados

### 1. Time-Series con Gaps Rellenos

```sql
WITH time_series AS (
    SELECT
        DATE_TRUNC('hour', closed_at) AS hour,
        COUNT(*) AS events_count
    FROM stellar.history_contract_events
    WHERE contract_id = 'CXXXXX...'
      AND closed_at >= CURRENT_DATE - INTERVAL '7' DAY
    GROUP BY hour
),
all_hours AS (
    SELECT hour_seq AS hour
    FROM UNNEST(
        SEQUENCE(
            DATE_TRUNC('hour', CURRENT_DATE - INTERVAL '7' DAY),
            DATE_TRUNC('hour', CURRENT_TIMESTAMP),
            INTERVAL '1' HOUR
        )
    ) AS t(hour_seq)
)
SELECT
    a.hour,
    COALESCE(t.events_count, 0) AS events_count
FROM all_hours a
LEFT JOIN time_series t ON a.hour = t.hour
ORDER BY a.hour DESC
```

### 2. Window Functions para Análisis Temporal

```sql
SELECT
    closed_at,
    contract_id,
    COUNT(*) AS events,
    -- Moving average (últimas 100 filas)
    AVG(COUNT(*)) OVER (
        PARTITION BY contract_id
        ORDER BY closed_at
        ROWS BETWEEN 99 PRECEDING AND CURRENT ROW
    ) AS moving_avg_100,
    -- Ranking por hora
    DENSE_RANK() OVER (
        PARTITION BY DATE_TRUNC('hour', closed_at)
        ORDER BY COUNT(*) DESC
    ) AS hourly_rank
FROM stellar.history_contract_events
WHERE closed_at >= CURRENT_DATE - INTERVAL '7' DAY
  AND successful = true
GROUP BY closed_at, contract_id
ORDER BY closed_at DESC
```

### 3. Parsing de Números i128 (Stellar BigInt)

```sql
-- Stellar usa i128 para números grandes (balances, amounts)
-- Estructura: {i128: {hi: ..., lo: ...}}

SELECT
    closed_at,
    -- Conversión i128 a decimal
    CAST(
        CAST(json_extract_scalar(data_decoded, '$.amount.i128.hi') AS DECIMAL(38,0)) * DECIMAL '1844674407370.9551616'
        + CAST(json_extract_scalar(data_decoded, '$.amount.i128.lo') AS DECIMAL(38,0)) * DECIMAL '0.0000001'
    AS DECIMAL(38,7)) AS amount
FROM stellar.history_contract_events
WHERE topics_decoded LIKE '%transfer%'
```

---

## Mejores Prácticas

### Performance

1. **Siempre filtra por IDs primero**
   ```sql
   WHERE contract_id IN ('CXXX1...', 'CXXX2...')  -- Índices eficientes
   ```

2. **Usa particiones temporales**
   ```sql
   WHERE closed_at >= CURRENT_DATE - INTERVAL '30' DAY  -- Limita escaneo
   ```

3. **Limita resultados en exploración**
   ```sql
   LIMIT 1000  -- Para queries exploratorias
   ```

### Debugging

1. **Explora estructura JSON primero**
   ```sql
   SELECT val_decoded
   FROM stellar.contract_data
   WHERE contract_id = 'CXXX...'
   LIMIT 1
   ```

2. **Verifica datos decodificados**
   ```sql
   SELECT topics_decoded, data_decoded
   FROM stellar.history_contract_events
   WHERE contract_id = 'CXXX...'
   LIMIT 5
   ```

3. **Compara raw vs decoded**
   ```sql
   SELECT
       topics,         -- Raw
       topics_decoded, -- Decoded
       data,          -- Raw
       data_decoded   -- Decoded
   FROM stellar.history_contract_events
   LIMIT 1
   ```

### Manejo de Datos

1. **Maneja NULLs apropiadamente**
   ```sql
   COALESCE(asset_code, 'UNKNOWN') AS asset_code
   ```

2. **Verifica transacciones exitosas**
   ```sql
   WHERE successful = true  -- Excluye transacciones fallidas
   ```

3. **Usa TRY() para conversiones riesgosas**
   ```sql
   TRY(CAST(json_extract(...) AS DECIMAL(38,7)))
   ```

---

## Casos de Uso por Tabla

### `history_contract_events`
✅ Tracking de eventos específicos (deposits, withdrawals)
✅ Construcción de logs de actividad
✅ Análisis de frecuencia de eventos
✅ Identificación de patrones de uso

### `history_transactions`
✅ Análisis de fees y costos
✅ Identificación de cuentas activas
✅ Debugging de transacciones fallidas
✅ Análisis de recursos consumidos (Soroban)

### `contract_data`
✅ Lectura de estado actual de contratos
✅ Extracción de metadata (nombres, símbolos)
✅ Tracking de cambios de configuración
✅ Análisis de assets y balances

---

## Limitaciones Conocidas

1. **JSON Parsing**: Estructura varía entre contratos - requiere exploración
2. **XDR Format**: Datos raw requieren conocimiento del protocolo Stellar
3. **Números i128**: Requieren conversión manual (ver ejemplos arriba)
4. **Materialización**: Queries complejas pueden requerir tablas intermedias
5. **Timestamps**: `ingested_at` puede diferir de `closed_at` debido a delays de indexación

---

## Recursos Adicionales

- **Dune Docs - Stellar**: https://docs.dune.com/data-catalog/stellar/overview
- **Stellar Protocol**: https://developers.stellar.org/docs
- **XDR Reference**: https://developers.stellar.org/docs/encyclopedia/xdr
- **Soroban (Smart Contracts)**: https://soroban.stellar.org/docs

---

## Actualización del Documento

**Última actualización**: 2025-10-13
**Basado en**: Dune Analytics Stellar Data Catalog

Para sugerencias o correcciones, actualiza este documento y sincroniza con el repo.
