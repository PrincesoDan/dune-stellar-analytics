# DeFindex - Documentación Técnica Completa

## Tabla de Contenidos
1. [Introducción y Visión General](#introducción-y-visión-general)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Contrato Factory](#contrato-factory)
4. [Contrato Vault (Core)](#contrato-vault-core)
5. [Sistema de Gestión de Activos](#sistema-de-gestión-de-activos)
6. [Arquitectura de Estrategias](#arquitectura-de-estrategias)
7. [Sistema de Roles y Permisos](#sistema-de-roles-y-permisos)
8. [Flujos Operacionales Detallados](#flujos-operacionales-detallados)
9. [Sistema de Comisiones](#sistema-de-comisiones)
10. [Operaciones de Emergencia](#operaciones-de-emergencia)
11. [Sistema de Rebalanceo](#sistema-de-rebalanceo)
12. [Eventos del Sistema](#eventos-del-sistema)
13. [Constantes y Convenciones](#constantes-y-convenciones)
14. [Estructuras de Datos Clave](#estructuras-de-datos-clave)

---

## 1. Introducción y Visión General

### ¿Qué es DeFindex?

DeFindex es un protocolo de gestión de inversiones descentralizado construido sobre **Soroban**, la plataforma de contratos inteligentes de Stellar. Permite a los usuarios depositar múltiples activos en vaults (bóvedas) que automáticamente distribuyen e invierten estos activos en diferentes estrategias de rendimiento.

### Stack Tecnológico

- **Blockchain:** Stellar (Soroban)
- **Lenguaje:** Rust (con `no_std` para compilación a WASM)
- **SDK:** Soroban SDK
- **Scripts de Deploy:** TypeScript/JavaScript

### Componentes Principales

```
DeFindex Platform
├── Factory Contract (Gestión de Vaults)
├── Vault Contract (Core de Inversión)
├── Strategy Core (Interfaz estándar)
└── Estrategias Concretas
    ├── HODL Strategy (Buy & Hold)
    ├── Unsafe HODL Strategy
    ├── Soroswap Strategy (Liquidez DEX)
    ├── Blend Strategy (Préstamos)
    ├── Fixed APR Strategy
    └── XYCloans Strategy
```

### Filosofía de Diseño

1. **Modularidad:** Estrategias plugueables e intercambiables
2. **Seguridad:** Sistema robusto de roles y permisos
3. **Flexibilidad:** Múltiples activos y estrategias por vault
4. **Transparencia:** Sistema completo de eventos para tracking
5. **Eficiencia:** Gestión optimizada de gas y almacenamiento

---

## 2. Arquitectura del Sistema

### Diagrama de Arquitectura

```
┌──────────────────────────────────────────────────────────┐
│                   FACTORY CONTRACT                       │
│                                                          │
│  - Crear Vaults                                         │
│  - Gestionar WASM Hash                                  │
│  - Configurar Parámetros del Protocolo                 │
│  - Administrar Comisiones del Protocolo                │
└────────────────────┬─────────────────────────────────────┘
                     │
                     │ deploys
                     ↓
┌──────────────────────────────────────────────────────────┐
│              VAULT CONTRACT (Token ERC20-like)           │
│                                                          │
│  Funcionalidad Core:                                    │
│  ├─ Deposit/Withdraw (Interfaz Usuario)                │
│  ├─ Gestión de Activos Múltiples                       │
│  ├─ Orquestación de Estrategias                        │
│  ├─ Sistema de Shares (Tokens del Vault)               │
│  ├─ Gestión de Comisiones                              │
│  ├─ Control de Acceso Basado en Roles                  │
│  ├─ Rebalanceo de Portafolio                           │
│  └─ Operaciones de Emergencia                          │
└──┬───────────────────────────────────────────────────────┘
   │
   │ invests in
   │
   ├─────→ ┌──────────────────────┐
   │       │  HODL STRATEGY       │
   │       │  Asset: Token A      │
   │       └──────────┬───────────┘
   │                  │ holds
   │                  ↓
   │              [Token Balance]
   │
   ├─────→ ┌──────────────────────┐
   │       │  SOROSWAP STRATEGY   │
   │       │  Asset: Token B      │
   │       └──────────┬───────────┘
   │                  │ provides liquidity
   │                  ↓
   │         ┌──────────────────┐
   │         │ Soroswap Protocol│
   │         └──────────────────┘
   │
   ├─────→ ┌──────────────────────┐
   │       │  BLEND STRATEGY      │
   │       │  Asset: Token C      │
   │       └──────────┬───────────┘
   │                  │ lends
   │                  ↓
   │         ┌──────────────────┐
   │         │  Blend Protocol  │
   │         └──────────────────┘
   │
   └─────→ ┌──────────────────────┐
           │  FIXED APR STRATEGY  │
           │  Asset: Token D      │
           └──────────┬───────────┘
                      │ invests
                      ↓
              [Fixed Return Protocol]
```

### Flujo de Datos

```
Usuario
  ↓ (deposit)
Vault Contract
  ↓ (share minting)
Balance de Usuario (shares)

Vault Contract
  ↓ (investment)
Estrategia 1, 2, 3...
  ↓ (deployment)
Protocolos Externos (Soroswap, Blend, etc.)
  ↓ (yields)
Estrategia (harvest)
  ↓ (report gains)
Vault (lock fees)
  ↓ (distribute)
Fee Receivers
```

---

## 3. Contrato Factory

### Ubicación del Código
- **Ruta:** `factory/src/lib.rs`
- **Eventos:** `factory/src/events.rs`

### Propósito

El Factory Contract es el punto de entrada para crear nuevos vaults DeFindex. Gestiona:

1. Despliegue de nuevos vaults
2. Configuración de parámetros del protocolo
3. Gestión del WASM hash de los vaults
4. Administración de comisiones del protocolo

### Interfaz del Contrato

```rust
trait FactoryTrait {
    // Constructor
    fn __constructor(
        env: Env,
        admin: Address,
        defindex_receiver: Address,
        defindex_fee: u32,
        vault_wasm_hash: BytesN<32>
    );

    // Creación de Vaults
    fn create_defindex_vault(
        env: Env,
        roles: Map<u32, Address>,
        vault_fee: u32,
        assets: Vec<AssetStrategySet>,
        soroswap_router: Address,
        name_symbol: (String, String),
        upgradable: bool
    ) -> Address;

    fn create_defindex_vault_deposit(
        env: Env,
        caller: Address,
        roles: Map<u32, Address>,
        vault_fee: u32,
        assets: Vec<AssetStrategySet>,
        soroswap_router: Address,
        name_symbol: (String, String),
        upgradable: bool,
        amounts: Vec<i128>
    ) -> (Address, i128, Vec<i128>);

    // Funciones de Administración
    fn set_new_admin(env: Env, new_admin: Address);
    fn set_defindex_receiver(env: Env, new_fee_receiver: Address);
    fn set_defindex_fee(env: Env, defindex_fee: u32);
    fn set_vault_wasm_hash(env: Env, new_vault_wasm_hash: BytesN<32>);

    // Getters
    fn deployed_defindexes(env: Env) -> Vec<Address>;
    fn get_admin(env: Env) -> Result<Address, FactoryError>;
    fn defindex_receiver(env: Env) -> Result<Address, FactoryError>;
    fn defindex_fee(env: Env) -> Result<u32, FactoryError>;
}
```

### Proceso de Despliegue de Vault

**Paso 1: Preparación**
```
Usuario prepara:
- Roles (Manager, Emergency Manager, Rebalance Manager, Fee Receiver)
- Configuración de assets y estrategias
- Parámetros de comisiones
- Nombre y símbolo del vault
```

**Paso 2: Llamada al Factory**
```rust
let vault_address = factory.create_defindex_vault(
    roles,           // Map<u32, Address>
    vault_fee,       // u32 (basis points)
    assets,          // Vec<AssetStrategySet>
    soroswap_router, // Address
    name_symbol,     // (String, String)
    upgradable       // bool
);
```

**Paso 3: Factory Ejecuta**
1. Valida parámetros (fee < 9000 bps)
2. Despliega nuevo contrato usando WASM hash almacenado
3. Inicializa vault con configuración proporcionada
4. Registra vault en lista de vaults desplegados
5. Emite `CreateDeFindexEvent`
6. Retorna dirección del vault

**Paso 4 (Opcional): Depósito Inicial**
```rust
let (vault_address, shares, amounts) = factory.create_defindex_vault_deposit(
    caller,
    roles,
    vault_fee,
    assets,
    soroswap_router,
    name_symbol,
    upgradable,
    amounts  // Depósito inicial
);
```

### Almacenamiento del Factory

```rust
enum DataKey {
    Admin,                    // Address del administrador
    DeFindexReceiver,        // Address que recibe comisiones del protocolo
    DeFindexFee,             // u32 - Comisión del protocolo (basis points)
    VaultWasmHash,           // BytesN<32> - Hash del WASM del vault
    DeFindexCount,           // u32 - Contador de vaults desplegados
    DeFindexAddress(u32),    // Address - Vault en índice específico
}
```

### Eventos del Factory

#### 1. CreateDeFindexEvent
```rust
pub(crate) fn create_defindex(
    env: &Env,
    roles: Map<u32, Address>,
    vault_fee: u32,
    assets: Vec<AssetStrategySet>
)
```
**Cuándo:** Al crear un nuevo vault
**Propósito:** Registrar la creación del vault con toda su configuración inicial

#### 2. NewAdminEvent
```rust
pub(crate) fn new_admin(env: &Env, new_admin: Address)
```
**Cuándo:** Al cambiar el administrador del factory
**Propósito:** Rastrear cambios administrativos

#### 3. NewDeFindexReceiverEvent
```rust
pub(crate) fn new_defindex_receiver(env: &Env, new_defindex_receiver: Address)
```
**Cuándo:** Al cambiar el receptor de comisiones del protocolo
**Propósito:** Rastrear a dónde van las comisiones del protocolo

#### 4. NewFeeRateEvent
```rust
pub(crate) fn new_fee_rate(env: &Env, new_defindex_fee: u32)
```
**Cuándo:** Al cambiar la tasa de comisión del protocolo
**Propósito:** Rastrear cambios en las comisiones

#### 5. NewVaultWasmHashEvent
```rust
pub(crate) fn new_vault_wasm_hash(env: &Env, new_vault_wasm_hash: BytesN<32>)
```
**Cuándo:** Al actualizar el WASM hash de los vaults
**Propósito:** Rastrear actualizaciones de versiones de vault

---

## 4. Contrato Vault (Core)

### Ubicación del Código
- **Ruta Principal:** `vault/src/lib.rs`
- **Eventos:** `vault/src/events.rs`
- **Gestión de Fondos:** `vault/src/funds.rs`
- **Inversiones:** `vault/src/investment.rs`
- **Acceso:** `vault/src/access.rs`
- **Reportes:** `vault/src/report.rs`
- **Rebalanceo:** `vault/src/rebalance.rs`

### Propósito

El Vault Contract es el corazón de DeFindex. Gestiona:

1. Depósitos y retiros de usuarios
2. Emisión y quema de shares (tokens del vault)
3. Distribución de capital entre estrategias
4. Cálculo y distribución de comisiones
5. Rebalanceo de portafolio
6. Operaciones de emergencia

### Características del Token del Vault

El vault es en sí mismo un token (similar a ERC20):

- **Nombre:** Prefijo "DeFindex-Vault-" + nombre personalizado
- **Símbolo:** Símbolo personalizado
- **Decimales:** 7
- **Supply:** Dinámico (minting/burning según deposits/withdrawals)

### Interfaz Principal del Vault

```rust
trait VaultTrait {
    // Operaciones de Usuario
    fn deposit(
        env: Env,
        amounts_desired: Vec<i128>,
        amounts_min: Vec<i128>,
        from: Address,
        invest: bool
    ) -> Result<(Vec<i128>, i128, Option<Vec<Option<AssetInvestmentAllocation>>>), ContractError>;

    fn withdraw(
        env: Env,
        withdraw_shares: i128,
        min_amounts_out: Vec<i128>,
        from: Address
    ) -> Result<Vec<i128>, ContractError>;

    // Gestión de Estrategias
    fn pause_strategy(
        env: Env,
        strategy_address: Address,
        caller: Address
    ) -> Result<(), ContractError>;

    fn unpause_strategy(
        env: Env,
        strategy_address: Address,
        caller: Address
    ) -> Result<(), ContractError>;

    // Operaciones de Emergencia
    fn rescue(
        env: Env,
        strategy_address: Address,
        caller: Address
    ) -> Result<(), ContractError>;

    // Rebalanceo
    fn rebalance(
        env: Env,
        instructions: Vec<Instruction>,
        caller: Address
    ) -> Result<(), ContractError>;

    // Gestión de Roles
    fn set_manager(env: Env, new_manager: Address);
    fn set_emergency_manager(env: Env, new_emergency_manager: Address);
    fn set_rebalance_manager(env: Env, new_rebalance_manager: Address);
    fn set_fee_receiver(env: Env, new_fee_receiver: Address, caller: Address);

    // Gestión de Comisiones
    fn distribute_fees(
        env: Env,
        caller: Address
    ) -> Result<Vec<(Address, i128)>, ContractError>;

    // Getters
    fn get_total_managed_funds(env: &Env) -> Result<Vec<CurrentAssetInvestmentAllocation>, ContractError>;
    fn balance(env: Env, id: Address) -> i128;
    // ... más getters
}
```

### Sistema de Shares

#### Cálculo de Shares en Depósito

**Primer Depósito (Vault Vacío):**
```rust
if total_shares == 0 {
    shares_to_mint = min(amounts) - MINIMUM_LIQUIDITY;
    // MINIMUM_LIQUIDITY = 1000 (quemado permanentemente)
}
```

**Depósitos Subsecuentes:**
```rust
shares_to_mint = (amount * total_shares) / total_managed_funds[asset]
```

**Ejemplo:**
```
Total Managed Funds: 10,000 tokens
Total Shares: 5,000 shares
Usuario deposita: 2,000 tokens

Shares = (2,000 * 5,000) / 10,000 = 1,000 shares
```

#### Cálculo de Activos en Retiro

```rust
amount_to_withdraw = (asset.total_amount * shares_to_withdraw) / total_shares
```

**Ejemplo:**
```
Asset Total: 10,000 tokens
Total Shares: 5,000 shares
Usuario retira: 1,000 shares

Amount = (10,000 * 1,000) / 5,000 = 2,000 tokens
```

### Eventos del Vault

#### 6. VaultDepositEvent
```rust
pub(crate) fn deposit(
    env: &Env,
    depositor: Address,
    amounts: Vec<i128>,
    df_tokens_minted: i128,
    total_supply_before: i128,
    total_managed_funds_before: Vec<CurrentAssetInvestmentAllocation>
)
```
**Cuándo:** Usuario deposita activos
**Propósito:** Rastrear depósitos, shares emitidos y estado del vault

#### 7. VaultWithdrawEvent
```rust
pub(crate) fn withdraw(
    env: &Env,
    withdrawer: Address,
    df_tokens_burned: i128,
    amounts_withdrawn: Vec<i128>,
    total_supply_before: i128,
    total_managed_funds_before: Vec<CurrentAssetInvestmentAllocation>
)
```
**Cuándo:** Usuario retira activos
**Propósito:** Rastrear retiros, shares quemados y estado del vault

#### 8. EmergencyWithdrawEvent
```rust
pub(crate) fn emergency_withdraw(
    env: &Env,
    caller: Address,
    strategy_address: Address,
    amount_withdrawn: i128
)
```
**Cuándo:** Se ejecuta una operación de rescate
**Propósito:** Rastrear retiros de emergencia desde estrategias

#### 9. StrategyPausedEvent
```rust
pub(crate) fn strategy_paused(
    env: &Env,
    strategy_address: Address,
    caller: Address
)
```
**Cuándo:** Una estrategia se pausa
**Propósito:** Rastrear desactivaciones de estrategias

#### 10. StrategyUnpausedEvent
```rust
pub(crate) fn strategy_unpaused(
    env: &Env,
    strategy_address: Address,
    caller: Address
)
```
**Cuándo:** Una estrategia se despausa
**Propósito:** Rastrear reactivaciones de estrategias

#### 11-14. Eventos de Cambio de Roles
```rust
pub(crate) fn fee_receiver_changed(env: &Env, new_fee_receiver: Address, caller: Address)
pub(crate) fn manager_changed(env: &Env, new_manager: Address)
pub(crate) fn emergency_manager_changed(env: &Env, new_emergency_manager: Address)
pub(crate) fn rebalance_manager_changed(env: &Env, new_rebalance_manager: Address)
```
**Cuándo:** Se cambia un rol
**Propósito:** Auditoría de cambios administrativos

#### 15. FeesDistributedEvent
```rust
pub(crate) fn fees_distributed(
    env: &Env,
    distributed_fees: Vec<(Address, i128)>
)
```
**Cuándo:** Se distribuyen comisiones acumuladas
**Propósito:** Rastrear pagos de comisiones

#### 16-19. Eventos de Rebalanceo
```rust
pub(crate) fn unwind(env: &Env, call_params: Vec<(Address, i128, Address)>, report: Report)
pub(crate) fn invest(env: &Env, asset_investments: Vec<AssetInvestmentAllocation>, report: Report)
pub(crate) fn swap_exact_in(env: &Env, swap_args: Vec<Val>)
pub(crate) fn swap_exact_out(env: &Env, swap_args: Vec<Val>)
```
**Cuándo:** Durante operaciones de rebalanceo
**Propósito:** Rastrear cambios en asignación de capital

---

## 5. Sistema de Gestión de Activos

### Estructura de Datos: CurrentAssetInvestmentAllocation

```rust
pub struct CurrentAssetInvestmentAllocation {
    pub asset: Address,              // Dirección del contrato del token
    pub total_amount: i128,          // idle_amount + invested_amount
    pub idle_amount: i128,           // Fondos no invertidos en el vault
    pub invested_amount: i128,       // Fondos invertidos (neto de comisiones)
    pub strategy_allocations: Vec<StrategyAllocation>,
}
```

### Estructura: StrategyAllocation

```rust
pub struct StrategyAllocation {
    pub strategy_address: Address,   // Dirección del contrato de estrategia
    pub amount: i128,                // Monto invertido (neto de comisiones)
    pub paused: bool,                // Flag de pausa
}
```

### Estructura: AssetStrategySet

```rust
pub struct AssetStrategySet {
    pub address: Address,            // Token del asset
    pub strategies: Vec<Strategy>,   // Estrategias disponibles
}

pub struct Strategy {
    pub address: Address,            // Contrato de estrategia
    pub name: String,                // Nombre descriptivo
    pub paused: bool,                // Estado
}
```

### Flujo de Fondos

```
┌─────────────────────────────────────────────────┐
│            VAULT CONTRACT                       │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  ASSET A (USDC)                          │  │
│  │  ├─ Idle: 1,000 USDC                     │  │
│  │  ├─ Invested: 9,000 USDC                 │  │
│  │  │   ├─ Strategy 1: 4,500 USDC          │  │
│  │  │   └─ Strategy 2: 4,500 USDC          │  │
│  │  └─ Total: 10,000 USDC                   │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  ASSET B (XLM)                           │  │
│  │  ├─ Idle: 500 XLM                        │  │
│  │  ├─ Invested: 4,500 XLM                  │  │
│  │  │   ├─ Strategy 1: 2,000 XLM           │  │
│  │  │   ├─ Strategy 2: 1,500 XLM           │  │
│  │  │   └─ Strategy 3: 1,000 XLM           │  │
│  │  └─ Total: 5,000 XLM                     │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### Gestión de Balance

#### Cálculo de Idle Amount
```rust
fn fetch_current_idle_funds(env: &Env, asset: &Address) -> i128 {
    let token_client = TokenClient::new(env, asset);
    token_client.balance(&env.current_contract_address())
}
```

#### Cálculo de Invested Amount
```rust
fn fetch_current_invested_funds(env: &Env, asset: &Address) -> i128 {
    let mut total_invested = 0;
    for strategy in strategies {
        let strategy_balance = strategy.balance(env.current_contract_address());
        let locked_fee = get_report(env, &strategy.address).locked_fee;
        total_invested += strategy_balance - locked_fee;
    }
    total_invested
}
```

#### Total Managed Funds
```rust
total_managed_funds = idle_amount + invested_amount
```

**IMPORTANTE:** Las comisiones bloqueadas (`locked_fee`) están físicamente en las estrategias pero NO cuentan como "invested_amount" porque están reservadas para distribución.

---

## 6. Arquitectura de Estrategias

### Ubicación del Código
- **Core:** `strategies/core/src/lib.rs`
- **Eventos:** `strategies/core/src/event.rs`
- **Implementaciones:** `strategies/{hodl, blend, soroswap, fixed_apr, xycloans}/`

### Interfaz de Estrategia (DeFindexStrategyTrait)

```rust
pub trait DeFindexStrategyTrait {
    // Constructor
    fn __constructor(
        env: Env,
        asset: Address,
        init_args: Vec<Val>
    );

    // Getter del asset
    fn asset(env: Env) -> Result<Address, StrategyError>;

    // Depositar fondos en la estrategia
    fn deposit(
        env: Env,
        amount: i128,
        from: Address
    ) -> Result<i128, StrategyError>;

    // Cosechar rendimientos
    fn harvest(
        env: Env,
        from: Address,
        data: Option<Bytes>
    ) -> Result<(), StrategyError>;

    // Consultar balance del vault en la estrategia
    fn balance(
        env: Env,
        from: Address
    ) -> Result<i128, StrategyError>;

    // Retirar fondos de la estrategia
    fn withdraw(
        env: Env,
        amount: i128,
        from: Address,
        to: Address
    ) -> Result<i128, StrategyError>;
}
```

### Ciclo de Vida de una Estrategia

#### 1. Deposit Flow

```
VAULT                           STRATEGY                    PROTOCOL
  │                                │                           │
  │ transfer(asset, strategy)      │                           │
  ├───────────────────────────────>│                           │
  │                                │                           │
  │ strategy.deposit(amount, vault)│                           │
  ├───────────────────────────────>│                           │
  │                                │                           │
  │                                │ approve & deposit         │
  │                                ├──────────────────────────>│
  │                                │                           │
  │                                │ receive LP tokens/shares  │
  │                                │<──────────────────────────┤
  │                                │                           │
  │      returns new_balance       │                           │
  │<───────────────────────────────┤                           │
  │                                │                           │
  │ emit DepositEvent              │                           │
```

**Código de Ejemplo (HODL Strategy):**
```rust
fn deposit(env: Env, amount: i128, from: Address) -> Result<i128, StrategyError> {
    from.require_auth();

    let asset = get_asset(&env)?;

    // Transfer tokens from vault to strategy
    let token_client = TokenClient::new(&env, &asset);
    token_client.transfer(&from, &env.current_contract_address(), &amount);

    // Update internal accounting
    let mut total_balance = get_total_balance(&env);
    total_balance += amount;
    put_total_balance(&env, &total_balance);

    // Emit event
    event::deposit(&env, amount, from.clone());

    Ok(total_balance)
}
```

#### 2. Harvest Flow

```
VAULT                           STRATEGY                    PROTOCOL
  │                                │                           │
  │ strategy.harvest(vault, data)  │                           │
  ├───────────────────────────────>│                           │
  │                                │                           │
  │                                │ claim_rewards()           │
  │                                ├──────────────────────────>│
  │                                │                           │
  │                                │ receive rewards           │
  │                                │<──────────────────────────┤
  │                                │                           │
  │                                │ (optional) reinvest       │
  │                                ├──────────────────────────>│
  │                                │                           │
  │         Ok()                   │                           │
  │<───────────────────────────────┤                           │
  │                                │                           │
  │ emit HarvestEvent              │                           │
```

#### 3. Withdraw Flow

```
VAULT                              STRATEGY                    PROTOCOL
  │                                   │                           │
  │ strategy.withdraw(amount, vault, vault)                      │
  ├──────────────────────────────────>│                           │
  │                                   │                           │
  │                                   │ withdraw(amount)          │
  │                                   ├──────────────────────────>│
  │                                   │                           │
  │                                   │ receive tokens            │
  │                                   │<──────────────────────────┤
  │                                   │                           │
  │                                   │ transfer(to_vault, amount)│
  │<──────────────────────────────────┤                           │
  │                                   │                           │
  │      returns remaining_balance    │                           │
  │<──────────────────────────────────┤                           │
  │                                   │                           │
  │ emit WithdrawEvent                │                           │
```

### Estrategias Implementadas

#### 1. HODL Strategy
**Ubicación:** `strategies/hodl/`
**Propósito:** Buy and hold (mantener tokens sin hacer nada)
**Mecanismo:** Almacena tokens en el contrato
**Rendimiento:** No genera rendimiento activo

#### 2. Unsafe HODL Strategy
**Ubicación:** `strategies/unsafe_hodl/`
**Propósito:** Almacenamiento simple sin validaciones extra
**Mecanismo:** Almacena tokens con menos checks
**Rendimiento:** No genera rendimiento

#### 3. Soroswap Strategy
**Ubicación:** `strategies/soroswap/`
**Propósito:** Proveer liquidez en Soroswap DEX
**Mecanismo:** Deposita en pools de liquidez
**Rendimiento:** Comisiones de trading del DEX

#### 4. Blend Strategy
**Ubicación:** `strategies/blend/`
**Propósito:** Préstamos en protocolo Blend
**Mecanismo:** Deposita como prestamista
**Rendimiento:** Intereses de préstamos

#### 5. Fixed APR Strategy
**Ubicación:** `strategies/fixed_apr/`
**Propósito:** Retorno fijo predecible
**Mecanismo:** Invierte en protocolo con APR fijo
**Rendimiento:** APR predefinido

#### 6. XYCloans Strategy
**Ubicación:** `strategies/xycloans/`
**Propósito:** Préstamos en protocolo XYCloans
**Mecanismo:** Similar a Blend
**Rendimiento:** Intereses de préstamos

### Eventos de Estrategias

#### 20. DepositEvent
```rust
pub(crate) fn deposit(env: &Env, amount: i128, from: Address)
```
**Cuándo:** Fondos depositados en estrategia
**Propósito:** Rastrear entradas de capital
**Usado Por:** Todas las estrategias

#### 21. HarvestEvent
```rust
pub(crate) fn harvest(env: &Env, amount: i128, from: Address, price_per_share: i128)
```
**Cuándo:** Rendimientos cosechados
**Propósito:** Rastrear generación de rendimiento y calcular APY
**Usado Por:** Todas las estrategias

#### 22. WithdrawEvent
```rust
pub(crate) fn withdraw(env: &Env, amount: i128, from: Address)
```
**Cuándo:** Fondos retirados de estrategia
**Propósito:** Rastrear salidas de capital
**Usado Por:** Todas las estrategias

### Pausa y Despausa de Estrategias

```rust
fn pause_strategy(env: Env, strategy_address: Address, caller: Address) {
    // Solo Manager o Emergency Manager
    require_any_role(&[RolesDataKey::Manager, RolesDataKey::EmergencyManager], &caller);

    // Marcar estrategia como pausada
    set_strategy_paused(&env, &strategy_address, true);

    // Emitir evento
    event::strategy_paused(&env, strategy_address, caller);
}
```

**Efectos de Pausar:**
- NO se pueden hacer nuevas inversiones en la estrategia
- Las inversiones existentes permanecen activas
- Se puede retirar de la estrategia
- NO afecta a otras estrategias

**Cuándo Pausar:**
- Estrategia tiene comportamiento anómalo
- Protocolo subyacente tiene problemas
- Se detecta vulnerabilidad
- Rebalanceo planificado

---

## 7. Sistema de Roles y Permisos

### Ubicación del Código
- **Ruta:** `vault/src/access.rs`

### Roles Definidos

```rust
pub enum RolesDataKey {
    EmergencyManager,    // Rol 0
    VaultFeeReceiver,    // Rol 1
    Manager,             // Rol 2
    RebalanceManager,    // Rol 3
}
```

### Matriz de Permisos

| Operación | Manager | Emergency Manager | Rebalance Manager | Fee Receiver |
|-----------|---------|-------------------|-------------------|--------------|
| **Operaciones de Estrategia** |
| Pausar Estrategia | ✓ | ✓ | ✗ | ✗ |
| Despausar Estrategia | ✓ | ✓ | ✗ | ✗ |
| Rescue (Emergencia) | ✓ | ✓ | ✗ | ✗ |
| **Rebalanceo** |
| Ejecutar Rebalanceo | ✓ | ✗ | ✓ | ✗ |
| **Gestión de Roles** |
| Cambiar Manager | ✓ | ✗ | ✗ | ✗ |
| Cambiar Emergency Manager | ✓ | ✗ | ✗ | ✗ |
| Cambiar Rebalance Manager | ✓ | ✗ | ✗ | ✗ |
| Cambiar Fee Receiver | ✓ | ✗ | ✗ | ✓ |
| **Gestión de Comisiones** |
| Bloquear Comisiones (lock) | ✓ | ✗ | ✗ | ✗ |
| Liberar Comisiones (release) | ✓ | ✗ | ✗ | ✗ |
| Distribuir Comisiones | ✓ | ✗ | ✗ | ✓ |
| **Upgrades** |
| Actualizar Contrato | ✓ | ✗ | ✗ | ✗ |

### Implementación de Autorización

```rust
pub fn require_any_role(env: &Env, keys: &[RolesDataKey], caller: &Address) {
    caller.require_auth();

    for key in keys {
        if let Some(role_address) = fetch_role(env, key) {
            if &role_address == caller {
                return; // Autorizado
            }
        }
    }

    panic_with_error!(env, ContractError::Unauthorized);
}
```

### Uso en Funciones

```rust
// Solo Manager
fn set_emergency_manager(env: Env, new_emergency_manager: Address) {
    let manager = fetch_manager(&env);
    manager.require_auth();
    // ...
}

// Manager O Emergency Manager
fn pause_strategy(env: Env, strategy_address: Address, caller: Address) {
    require_any_role(
        &env,
        &[RolesDataKey::Manager, RolesDataKey::EmergencyManager],
        &caller
    );
    // ...
}

// Manager O Rebalance Manager
fn rebalance(env: Env, instructions: Vec<Instruction>, caller: Address) {
    require_any_role(
        &env,
        &[RolesDataKey::Manager, RolesDataKey::RebalanceManager],
        &caller
    );
    // ...
}

// Manager O Fee Receiver
fn set_fee_receiver(env: Env, new_fee_receiver: Address, caller: Address) {
    require_any_role(
        &env,
        &[RolesDataKey::Manager, RolesDataKey::VaultFeeReceiver],
        &caller
    );
    // ...
}
```

### Almacenamiento de Roles

```rust
// Guardar rol
pub fn put_role(env: &Env, key: &RolesDataKey, address: &Address) {
    env.storage().instance().set(key, address);
    env.storage().instance().extend_ttl(INSTANCE_BUMP_AMOUNT, INSTANCE_BUMP_AMOUNT);
}

// Recuperar rol
pub fn fetch_role(env: &Env, key: &RolesDataKey) -> Option<Address> {
    env.storage().instance().get(key)
}

// Funciones específicas
pub fn fetch_manager(env: &Env) -> Address {
    fetch_role(env, &RolesDataKey::Manager)
        .expect("Manager not found")
}
```

---

## 8. Flujos Operacionales Detallados

### Flujo Completo de Depósito

```
PASO 1: Usuario Inicia Depósito
────────────────────────────────
Usuario llama:
  vault.deposit(
    amounts_desired: [1000, 500],  // USDC, XLM
    amounts_min: [900, 450],       // Slippage tolerance
    from: user_address,
    invest: true                   // Auto-invest
  )

PASO 2: Autenticación
────────────────────────────────
  - Verificar firma del usuario
  - from.require_auth()

PASO 3: Validación de Parámetros
────────────────────────────────
  - amounts_desired.len() == número de assets
  - amounts_min.len() == número de assets
  - amounts_desired[i] >= amounts_min[i]
  - amounts_desired[i] > 0

PASO 4: Obtener Estado Actual del Vault
────────────────────────────────
  total_managed_funds = []

  Para cada asset:
    idle = token_balance(vault)
    invested = 0

    Para cada estrategia:
      balance = strategy.balance(vault)
      locked_fee = report[strategy].locked_fee
      invested += (balance - locked_fee)

    total_managed_funds.push({
      asset,
      total_amount: idle + invested,
      idle_amount: idle,
      invested_amount: invested,
      strategy_allocations: [...]
    })

PASO 5: Calcular Shares a Emitir
────────────────────────────────
  total_shares = vault.total_supply()

  SI total_shares == 0:
    // Primer depósito
    shares = min(amounts_desired) - MINIMUM_LIQUIDITY
    // MINIMUM_LIQUIDITY (1000) se quema permanentemente
  SINO:
    shares = []
    Para cada asset:
      share = (amounts_desired[i] * total_shares) / total_managed_funds[i].total_amount
      shares.push(share)

    shares_to_mint = min(shares)

PASO 6: Transferir Activos al Vault
────────────────────────────────
  Para cada asset:
    amount = (shares_to_mint * total_managed_funds[i].total_amount) / total_shares

    token_client = TokenClient::new(asset)
    token_client.transfer_from(
      user_address,
      user_address,
      vault_address,
      amount
    )

    amounts_deposited.push(amount)

PASO 7: Emitir Shares al Usuario
────────────────────────────────
  vault.mint(user_address, shares_to_mint)

PASO 8: Invertir en Estrategias (si invest=true)
────────────────────────────────
  allocations = []

  Para cada asset:
    SI asset.invested_amount > 0:
      Para cada strategy en asset.strategies:
        proportion = strategy.amount / asset.invested_amount
        invest_amount = amounts_deposited[i] * proportion

        SI invest_amount > 0:
          // Transfer to strategy
          token_client.transfer(
            vault_address,
            strategy.address,
            invest_amount
          )

          // Call strategy deposit
          new_balance = strategy.deposit(invest_amount, vault_address)

          // Update allocation
          allocations.push({
            strategy_address: strategy.address,
            amount: invest_amount
          })

PASO 9: Emitir Evento
────────────────────────────────
  emit VaultDepositEvent {
    depositor: user_address,
    amounts: amounts_deposited,
    df_tokens_minted: shares_to_mint,
    total_supply_before: total_shares,
    total_managed_funds_before: total_managed_funds
  }

PASO 10: Retornar Resultado
────────────────────────────────
  return (
    amounts_deposited,
    shares_to_mint,
    Some(allocations)
  )
```

### Flujo Completo de Retiro

```
PASO 1: Usuario Inicia Retiro
────────────────────────────────
Usuario llama:
  vault.withdraw(
    withdraw_shares: 1000,
    min_amounts_out: [900, 450],
    from: user_address
  )

PASO 2: Autenticación
────────────────────────────────
  - Verificar firma del usuario
  - from.require_auth()

PASO 3: Validación de Parámetros
────────────────────────────────
  - withdraw_shares > 0
  - user_balance >= withdraw_shares
  - min_amounts_out.len() == número de assets

PASO 4: Obtener Estado Actual
────────────────────────────────
  total_managed_funds = get_total_managed_funds()
  // Incluye actualización de reportes de estrategias

  total_shares = vault.total_supply()

PASO 5: Quemar Shares
────────────────────────────────
  vault.burn(user_address, withdraw_shares)

PASO 6: Calcular y Distribuir Activos
────────────────────────────────
  amounts_withdrawn = []

  Para cada asset:
    requested_amount = (asset.total_amount * withdraw_shares) / total_shares

    SI asset.idle_amount >= requested_amount:
      ┌─ Caso Simple: Suficiente Idle ─┐
      │                                 │
      │ token_client.transfer(          │
      │   vault_address,                │
      │   user_address,                 │
      │   requested_amount              │
      │ )                               │
      │                                 │
      │ amounts_withdrawn.push(         │
      │   requested_amount              │
      │ )                               │
      └─────────────────────────────────┘

    SINO:
      ┌─ Caso Complejo: Necesita Unwind ─┐
      │                                   │
      │ // Transferir idle disponible    │
      │ token_client.transfer(            │
      │   vault_address,                  │
      │   user_address,                   │
      │   asset.idle_amount               │
      │ )                                 │
      │                                   │
      │ remaining = requested_amount      │
      │           - asset.idle_amount     │
      │                                   │
      │ cumulative_unwound = 0            │
      │                                   │
      │ Para cada strategy (con índice):  │
      │   SI es última estrategia:        │
      │     unwind_amount = requested     │
      │       - cumulative_unwound        │
      │   SINO:                           │
      │     proportion = strategy.amount  │
      │       / asset.invested_amount     │
      │     unwind_amount = remaining     │
      │       * proportion                │
      │                                   │
      │   SI unwind_amount > 0:           │
      │     // Withdraw from strategy     │
      │     remaining_in_strategy =       │
      │       strategy.withdraw(          │
      │         unwind_amount,            │
      │         vault_address,            │
      │         vault_address             │
      │       )                           │
      │                                   │
      │     // Transfer to user           │
      │     token_client.transfer(        │
      │       vault_address,              │
      │       user_address,               │
      │       unwind_amount               │
      │     )                             │
      │                                   │
      │     // Update report              │
      │     update_strategy_report(       │
      │       strategy,                   │
      │       remaining_in_strategy       │
      │     )                             │
      │                                   │
      │     cumulative_unwound +=         │
      │       unwind_amount               │
      │                                   │
      │ amounts_withdrawn.push(           │
      │   requested_amount                │
      │ )                                 │
      └───────────────────────────────────┘

PASO 7: Validar Montos Mínimos
────────────────────────────────
  Para cada i en amounts_withdrawn:
    SI amounts_withdrawn[i] < min_amounts_out[i]:
      panic!("Slippage too high")

PASO 8: Emitir Evento
────────────────────────────────
  emit VaultWithdrawEvent {
    withdrawer: user_address,
    df_tokens_burned: withdraw_shares,
    amounts_withdrawn: amounts_withdrawn,
    total_supply_before: total_shares,
    total_managed_funds_before: total_managed_funds
  }

PASO 9: Retornar Resultado
────────────────────────────────
  return amounts_withdrawn
```

### Flujo de Actualización de Reportes

```
PASO 1: Trigger
────────────────────────────────
  - Durante withdraw
  - Durante rebalance
  - Durante distribute_fees
  - Al calcular total_managed_funds

PASO 2: Para Cada Estrategia
────────────────────────────────
  current_balance = strategy.balance(vault_address)
  report = get_report(strategy_address)

  gains_or_losses = current_balance - report.prev_balance

  report.gains_or_losses += gains_or_losses
  report.prev_balance = current_balance

  save_report(strategy_address, report)

PASO 3: Cálculo de Comisiones (cuando se bloquean)
────────────────────────────────
  SI report.gains_or_losses > 0:
    vault_fee = (gains * vault_fee_rate) / 10000
    protocol_fee = (gains * protocol_fee_rate) / 10000

    total_fee = vault_fee + protocol_fee

    report.locked_fee += total_fee
    report.gains_or_losses = 0

    save_report(strategy_address, report)
```

---

## 9. Sistema de Comisiones

### Estructura de Comisiones

**Dos Niveles de Comisiones:**

1. **Vault Fee** (Comisión del Vault)
   - Configurado por vault (0-9000 basis points)
   - Va al `VaultFeeReceiver`
   - Comisión del operador del vault

2. **Protocol Fee** (Comisión del Protocolo)
   - Configurado por Factory (0-9000 basis points)
   - Va al `DeFindexReceiver`
   - Comisión de DeFindex

**Basis Points:**
```
1 bp = 0.01%
100 bps = 1%
10000 bps = 100%

Ejemplos:
- 500 bps = 5%
- 1000 bps = 10%
- 9000 bps = 90% (máximo permitido)
```

### Estructura de Reporte

```rust
pub struct Report {
    pub prev_balance: i128,        // Balance previo de la estrategia
    pub gains_or_losses: i128,     // Ganancias/pérdidas acumuladas
    pub locked_fee: i128,          // Comisiones bloqueadas para distribución
}
```

### Ciclo de Vida de las Comisiones

#### Fase 1: Acumulación

```
Estrategia genera rendimiento:
  prev_balance = 10,000
  current_balance = 11,000

  gains = 11,000 - 10,000 = 1,000

  report.gains_or_losses += 1,000
  report.prev_balance = 11,000
```

#### Fase 2: Bloqueo (Lock)

```rust
fn lock_fees(env: &Env, strategy_address: &Address) {
    let mut report = get_report(env, strategy_address);

    SI report.gains_or_losses > 0:
        let vault_fee_rate = get_vault_fee(env);
        let protocol_fee_rate = get_protocol_fee(env);

        let gains = report.gains_or_losses;

        let vault_fee_amount = (gains * vault_fee_rate) / 10000;
        let protocol_fee_amount = (gains * protocol_fee_rate) / 10000;
        let total_fee = vault_fee_amount + protocol_fee_amount;

        report.locked_fee += total_fee;
        report.gains_or_losses = 0;

        save_report(env, strategy_address, &report);
}
```

**Ejemplo:**
```
gains_or_losses = 1,000 tokens
vault_fee_rate = 1000 bps (10%)
protocol_fee_rate = 500 bps (5%)

vault_fee = (1,000 * 1000) / 10000 = 100 tokens
protocol_fee = (1,000 * 500) / 10000 = 50 tokens
total_locked = 150 tokens

report.locked_fee = 150
report.gains_or_losses = 0
```

#### Fase 3: Distribución

```rust
fn distribute_fees(env: Env, caller: Address) -> Result<Vec<(Address, i128)>, ContractError> {
    require_any_role(&env, &[RolesDataKey::Manager, RolesDataKey::VaultFeeReceiver], &caller);

    let vault_fee_receiver = fetch_vault_fee_receiver(&env);
    let protocol_fee_receiver = fetch_protocol_fee_receiver(&env);
    let vault_fee_rate = get_vault_fee(&env);
    let protocol_fee_rate = get_protocol_fee(&env);

    let mut distributed = Vec::new();

    Para cada asset:
        Para cada strategy en asset:
            let mut report = get_report(&env, &strategy.address);

            SI report.locked_fee > 0:
                let total_fee = report.locked_fee;

                // Calcular proporciones
                let protocol_portion = (total_fee * protocol_fee_rate) / (vault_fee_rate + protocol_fee_rate);
                let vault_portion = total_fee - protocol_portion;

                // Retirar de estrategia
                strategy.withdraw(total_fee, vault_address, vault_address);

                // Distribuir a receptores
                token_client.transfer(vault_address, protocol_fee_receiver, protocol_portion);
                token_client.transfer(vault_address, vault_fee_receiver, vault_portion);

                distributed.push((asset.address, total_fee));

                // Resetear locked_fee
                report.locked_fee = 0;
                save_report(&env, &strategy.address, &report);

    emit FeesDistributedEvent { distributed_fees: distributed };

    Ok(distributed)
}
```

**Ejemplo Completo:**
```
Strategy A:
  locked_fee = 150 tokens
  vault_fee_rate = 1000 bps
  protocol_fee_rate = 500 bps

  protocol_portion = (150 * 500) / (1000 + 500) = 50 tokens
  vault_portion = 150 - 50 = 100 tokens

  Withdraw 150 from strategy
  Transfer 50 to protocol_fee_receiver
  Transfer 100 to vault_fee_receiver

  report.locked_fee = 0
```

### Operaciones Especiales de Comisiones

#### Release Fees (Liberar Comisiones)

```rust
fn release_fees(env: &Env, strategy_address: &Address) {
    let mut report = get_report(env, strategy_address);

    report.gains_or_losses += report.locked_fee;
    report.locked_fee = 0;

    save_report(env, strategy_address, &report);
}
```

**Cuándo usar:**
- Error en cálculo de comisiones
- Decisión de no cobrar comisiones
- Corrección administrativa

#### Reset Report (Durante Rescue)

```rust
fn reset_report(env: &Env, strategy_address: &Address) {
    let report = Report {
        prev_balance: 0,
        gains_or_losses: 0,
        locked_fee: 0,
    };

    save_report(env, strategy_address, &report);
}
```

---

## 10. Operaciones de Emergencia

### Rescue (Retiro de Emergencia)

#### Propósito
Retirar todos los fondos de una estrategia comprometida o que no responde.

#### Código

```rust
fn rescue(
    env: Env,
    strategy_address: Address,
    caller: Address
) -> Result<(), ContractError> {
    // Solo Manager o Emergency Manager
    require_any_role(
        &env,
        &[RolesDataKey::Manager, RolesDataKey::EmergencyManager],
        &caller
    );

    // 1. Encontrar asset y estrategia
    let (asset, strategy_index) = find_strategy(&env, &strategy_address)?;

    // 2. Distribuir comisiones acumuladas
    distribute_fees_for_strategy(&env, &asset, &strategy_address)?;

    // 3. Obtener balance en estrategia
    let strategy_client = StrategyClient::new(&env, &strategy_address);
    let balance = strategy_client.balance(&env.current_contract_address());

    // 4. Retirar TODO de la estrategia
    SI balance > 0:
        strategy_client.withdraw(
            &balance,
            &env.current_contract_address(),
            &env.current_contract_address()
        );

    // 5. Pausar estrategia
    set_strategy_paused(&env, &strategy_address, true);

    // 6. Resetear reporte
    reset_report(&env, &strategy_address);

    // 7. Emitir evento
    emit EmergencyWithdrawEvent {
        caller: caller,
        strategy_address: strategy_address,
        amount_withdrawn: balance
    };

    Ok(())
}
```

#### Flujo Visual

```
┌─────────────────────────────────────────────────────┐
│  SITUACIÓN DE EMERGENCIA DETECTADA                  │
│  - Estrategia comprometida                          │
│  - Protocolo subyacente fallando                    │
│  - Comportamiento anómalo                           │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│  Emergency Manager llama:                           │
│  vault.rescue(strategy_address, caller)             │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│  PASO 1: Verificar Autorización                     │
│  - Verificar que caller es Manager o Emergency Mgr  │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│  PASO 2: Distribuir Comisiones Pendientes           │
│  - Pagar comisiones acumuladas antes de retirar     │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│  PASO 3: Retirar TODOS los Fondos                   │
│  - balance = strategy.balance(vault)                │
│  - strategy.withdraw(balance, vault, vault)         │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│  PASO 4: Almacenar en Idle                          │
│  - Fondos ahora en vault como idle_amount           │
│  - Disponibles para retiros o reinversión           │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│  PASO 5: Pausar Estrategia                          │
│  - Marcar paused = true                             │
│  - Prevenir nuevas inversiones                      │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│  PASO 6: Resetear Reporte                           │
│  - prev_balance = 0                                 │
│  - gains_or_losses = 0                              │
│  - locked_fee = 0                                   │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│  RESULTADO:                                         │
│  ✓ Fondos seguros en el vault                       │
│  ✓ Estrategia pausada                               │
│  ✓ Usuarios pueden retirar normalmente              │
│  ✓ Evento emitido para transparencia                │
└─────────────────────────────────────────────────────┘
```

#### Cuándo Usar Rescue

1. **Compromiso de Seguridad**
   - Vulnerabilidad descubierta en estrategia
   - Ataque en progreso

2. **Fallo del Protocolo**
   - Protocolo subyacente deja de responder
   - Protocolo sufre exploit

3. **Comportamiento Anómalo**
   - Pérdidas inesperadas
   - Transacciones fallando consistentemente

4. **Decisión Administrativa**
   - Deprecación planificada de estrategia
   - Migración a nueva versión

#### Efectos Post-Rescue

```
ANTES del Rescue:
Asset A:
  ├─ idle: 1,000
  ├─ invested: 9,000
  │   ├─ Strategy 1: 4,500
  │   ├─ Strategy 2: 3,000  ← Comprometida
  │   └─ Strategy 3: 1,500
  └─ total: 10,000

DESPUÉS del Rescue (Strategy 2):
Asset A:
  ├─ idle: 4,000           ← +3,000 de rescue
  ├─ invested: 6,000
  │   ├─ Strategy 1: 4,500
  │   ├─ Strategy 2: 0     ← Pausada y vacía
  │   └─ Strategy 3: 1,500
  └─ total: 10,000         ← Sin pérdidas para usuarios
```

---

## 11. Sistema de Rebalanceo

### Ubicación del Código
- **Ruta:** `vault/src/rebalance.rs`
- **Router:** `vault/src/router.rs`
- **Modelos:** `vault/src/models.rs`

### Propósito

Permitir ajustes dinámicos en la asignación de capital entre estrategias, incluyendo:
- Mover fondos entre estrategias
- Intercambiar tokens (swaps)
- Optimizar distribución según rendimiento

### Instrucciones de Rebalanceo

```rust
pub enum Instruction {
    // Retirar de una estrategia
    Unwind {
        strategy_address: Address,
        amount: i128,
    },

    // Invertir en una estrategia
    Invest {
        strategy_address: Address,
        amount: i128,
    },

    // Swap con input exacto
    SwapExactIn {
        token_in: Address,
        token_out: Address,
        amount_in: i128,
        amount_out_min: i128,
        deadline: u64,
    },

    // Swap con output exacto
    SwapExactOut {
        token_in: Address,
        token_out: Address,
        amount_out: i128,
        amount_in_max: i128,
        deadline: u64,
    },
}
```

### Función de Rebalanceo

```rust
fn rebalance(
    env: Env,
    instructions: Vec<Instruction>,
    caller: Address
) -> Result<(), ContractError> {
    // Solo Manager o Rebalance Manager
    require_any_role(
        &env,
        &[RolesDataKey::Manager, RolesDataKey::RebalanceManager],
        &caller
    );

    // Validar todas las instrucciones antes de ejecutar
    validate_instructions(&env, &instructions)?;

    // Ejecutar instrucciones secuencialmente
    for instruction in instructions {
        match instruction {
            Instruction::Unwind { strategy_address, amount } => {
                execute_unwind(&env, &strategy_address, amount)?;
            },
            Instruction::Invest { strategy_address, amount } => {
                execute_invest(&env, &strategy_address, amount)?;
            },
            Instruction::SwapExactIn { token_in, token_out, amount_in, amount_out_min, deadline } => {
                execute_swap_exact_in(&env, &token_in, &token_out, amount_in, amount_out_min, deadline)?;
            },
            Instruction::SwapExactOut { token_in, token_out, amount_out, amount_in_max, deadline } => {
                execute_swap_exact_out(&env, &token_in, &token_out, amount_out, amount_in_max, deadline)?;
            },
        }
    }

    Ok(())
}
```

### Ejemplo de Rebalanceo Completo

**Escenario:** Mover capital de Strategy A (bajo rendimiento) a Strategy B (alto rendimiento)

```
Estado Inicial:
Asset: USDC
  ├─ idle: 1,000 USDC
  ├─ invested: 9,000 USDC
  │   ├─ Strategy A: 6,000 USDC (APY: 5%)
  │   └─ Strategy B: 3,000 USDC (APY: 15%)
  └─ total: 10,000 USDC

Objetivo:
  - Strategy A: 3,000 USDC
  - Strategy B: 6,000 USDC

Instrucciones:
[
  Instruction::Unwind {
    strategy_address: Strategy_A,
    amount: 3,000
  },
  Instruction::Invest {
    strategy_address: Strategy_B,
    amount: 3,000
  }
]
```

**Ejecución:**

```
PASO 1: Unwind de Strategy A
────────────────────────────────
  strategy_a.withdraw(3000, vault, vault)

  Estado:
    idle: 4,000 USDC (+3,000)
    Strategy A: 3,000 USDC (-3,000)
    Strategy B: 3,000 USDC

  Evento: UnwindEvent emitido

PASO 2: Invest en Strategy B
────────────────────────────────
  token_client.transfer(vault, strategy_b, 3000)
  strategy_b.deposit(3000, vault)

  Estado Final:
    idle: 1,000 USDC (-3,000)
    Strategy A: 3,000 USDC
    Strategy B: 6,000 USDC (+3,000)

  Evento: InvestEvent emitido
```

### Rebalanceo con Swaps

**Escenario:** Cambiar exposición de USDC a XLM

```
Estado Inicial:
  USDC idle: 5,000
  XLM idle: 0

Objetivo:
  USDC idle: 2,000
  XLM idle: 3,000 (equivalente)

Instrucciones:
[
  Instruction::SwapExactIn {
    token_in: USDC_ADDRESS,
    token_out: XLM_ADDRESS,
    amount_in: 3,000,
    amount_out_min: 2,900,  // 3.33% slippage tolerance
    deadline: current_time + 300  // 5 minutos
  }
]
```

**Ejecución:**

```
PASO 1: Aprobar Soroswap Router
────────────────────────────────
  usdc_client.approve(vault, soroswap_router, 3000)

PASO 2: Ejecutar Swap
────────────────────────────────
  amounts = soroswap_router.swap_exact_tokens_for_tokens(
    amount_in: 3000,
    amount_out_min: 2900,
    path: [USDC_ADDRESS, XLM_ADDRESS],
    to: vault_address,
    deadline: deadline
  )

  Recibido: 3,050 XLM

PASO 3: Estado Final
────────────────────────────────
  USDC idle: 2,000 (-3,000)
  XLM idle: 3,050 (+3,050)

  Evento: SwapExactInEvent emitido
```

### Validación de Instrucciones

```rust
fn validate_instructions(env: &Env, instructions: &Vec<Instruction>) -> Result<(), ContractError> {
    for instruction in instructions {
        match instruction {
            Instruction::Unwind { strategy_address, amount } => {
                // Verificar que estrategia existe
                let strategy = find_strategy(env, strategy_address)?;

                // Verificar que hay suficiente capital
                let balance = strategy.balance(env.current_contract_address());
                if balance < *amount {
                    return Err(ContractError::InsufficientBalance);
                }
            },

            Instruction::Invest { strategy_address, amount } => {
                // Verificar que estrategia existe y no está pausada
                let strategy = find_strategy(env, strategy_address)?;
                if strategy.paused {
                    return Err(ContractError::StrategyPaused);
                }

                // Verificar que hay suficiente idle
                let asset = strategy.asset;
                let idle = fetch_current_idle_funds(env, &asset);
                if idle < *amount {
                    return Err(ContractError::InsufficientIdleFunds);
                }
            },

            Instruction::SwapExactIn { token_in, amount_in, deadline, .. } => {
                // Verificar deadline
                if *deadline < env.ledger().timestamp() {
                    return Err(ContractError::DeadlineExpired);
                }

                // Verificar balance de token_in
                let idle = fetch_current_idle_funds(env, token_in);
                if idle < *amount_in {
                    return Err(ContractError::InsufficientBalance);
                }
            },

            Instruction::SwapExactOut { token_in, amount_in_max, deadline, .. } => {
                // Similar a SwapExactIn
            },
        }
    }

    Ok(())
}
```

### Eventos de Rebalanceo

#### 16. UnwindEvent
```rust
pub(crate) fn unwind(
    env: &Env,
    call_params: Vec<(Address, i128, Address)>,
    report: Report
)
```
**Cuándo:** Fondos retirados durante rebalanceo
**Propósito:** Rastrear unwinding de estrategias

#### 17. InvestEvent
```rust
pub(crate) fn invest(
    env: &Env,
    asset_investments: Vec<AssetInvestmentAllocation>,
    report: Report
)
```
**Cuándo:** Fondos invertidos durante rebalanceo
**Propósito:** Rastrear deployment de capital

#### 18. SwapExactInEvent
```rust
pub(crate) fn swap_exact_in(env: &Env, swap_args: Vec<Val>)
```
**Cuándo:** Swap con input exacto ejecutado
**Propósito:** Rastrear intercambios de tokens

#### 19. SwapExactOutEvent
```rust
pub(crate) fn swap_exact_out(env: &Env, swap_args: Vec<Val>)
```
**Cuándo:** Swap con output exacto ejecutado
**Propósito:** Rastrear intercambios de tokens

---

## 12. Eventos del Sistema

### Resumen de Eventos por Contrato

#### Factory Contract (5 eventos)
| # | Evento | Trigger | Propósito |
|---|--------|---------|-----------|
| 1 | CreateDeFindexEvent | Creación de vault | Registrar nuevo vault |
| 2 | NewAdminEvent | Cambio de admin | Auditoría administrativa |
| 3 | NewDeFindexReceiverEvent | Cambio de receptor | Rastrear comisiones |
| 4 | NewFeeRateEvent | Cambio de tasa | Rastrear comisiones |
| 5 | NewVaultWasmHashEvent | Upgrade de WASM | Rastrear versiones |

#### Vault Contract (14 eventos)
| # | Evento | Trigger | Propósito |
|---|--------|---------|-----------|
| 6 | VaultDepositEvent | Depósito de usuario | Rastrear depósitos |
| 7 | VaultWithdrawEvent | Retiro de usuario | Rastrear retiros |
| 8 | EmergencyWithdrawEvent | Rescue | Rastrear emergencias |
| 9 | StrategyPausedEvent | Pausa de estrategia | Rastrear desactivaciones |
| 10 | StrategyUnpausedEvent | Despausa de estrategia | Rastrear activaciones |
| 11 | FeeReceiverChangedEvent | Cambio de receptor | Auditoría |
| 12 | ManagerChangedEvent | Cambio de manager | Auditoría |
| 13 | EmergencyManagerChangedEvent | Cambio de emergency mgr | Auditoría |
| 14 | RebalanceManagerChangedEvent | Cambio de rebalance mgr | Auditoría |
| 15 | FeesDistributedEvent | Distribución de comisiones | Rastrear pagos |
| 16 | UnwindEvent | Rebalanceo (unwind) | Rastrear rebalanceos |
| 17 | InvestEvent | Rebalanceo (invest) | Rastrear rebalanceos |
| 18 | SwapExactInEvent | Rebalanceo (swap) | Rastrear swaps |
| 19 | SwapExactOutEvent | Rebalanceo (swap) | Rastrear swaps |

#### Strategy Core (3 eventos, usados por TODAS las estrategias)
| # | Evento | Trigger | Propósito |
|---|--------|---------|-----------|
| 20 | DepositEvent | Depósito en estrategia | Rastrear entradas |
| 21 | HarvestEvent | Harvest de rendimientos | Calcular APY |
| 22 | WithdrawEvent | Retiro de estrategia | Rastrear salidas |

### Uso de Eventos para Tracking

#### Ejemplo: Rastrear APY de una Estrategia

```rust
// Escuchar HarvestEvents
eventos = vault.events().filter(topic == "HarvestEvent")

para cada evento:
    amount = evento.amount
    from = evento.from
    price_per_share = evento.price_per_share
    timestamp = evento.timestamp

    // Calcular APY
    time_diff = timestamp - last_harvest_timestamp
    apy = (price_per_share_now / price_per_share_prev) ^ (YEAR / time_diff) - 1
```

#### Ejemplo: Auditoría de Comisiones

```rust
// Rastrear todas las distribuciones de comisiones
fee_events = vault.events().filter(topic == "FeesDistributedEvent")

total_distributed = 0

para cada evento:
    para cada (asset, amount) en evento.distributed_fees:
        total_distributed += amount

        log(f"{asset}: {amount} tokens distribuidos")

log(f"Total comisiones distribuidas: {total_distributed}")
```

#### Ejemplo: Análisis de Rebalanceos

```rust
// Obtener todos los rebalanceos
rebalance_events = vault.events().filter(
    topic in ["UnwindEvent", "InvestEvent", "SwapExactInEvent", "SwapExactOutEvent"]
)

para cada evento:
    SI evento.topic == "UnwindEvent":
        log(f"Retirado de estrategia: {evento.strategy_address}")
        log(f"  Monto: {evento.amount}")
        log(f"  Report: {evento.report}")

    SI evento.topic == "InvestEvent":
        log(f"Invertido en estrategia: {evento.strategy_address}")
        log(f"  Monto: {evento.amount}")

    SI evento.topic == "SwapExactInEvent":
        log(f"Swap ejecutado:")
        log(f"  In: {evento.amount_in}")
        log(f"  Out Min: {evento.amount_out_min}")
```

---

## 13. Constantes y Convenciones

### Constantes del Sistema

```rust
// De constants.rs
pub const SCALAR_BPS: i128 = 10000;      // Scalar de basis points
pub const MINIMUM_LIQUIDITY: i128 = 1000; // Liquidez mínima inicial

// De storage.rs (Soroban TTL)
pub const DAY_IN_LEDGERS: u32 = 17280;   // ~24 horas en ledgers
pub const INSTANCE_BUMP_AMOUNT: u32 = 30 * DAY_IN_LEDGERS;    // 30 días
pub const PERSISTENT_BUMP_AMOUNT: u32 = 120 * DAY_IN_LEDGERS; // 120 días
```

### Convenciones de Basis Points

```
Conversión:
percentage = (basis_points / 10000) * 100

Ejemplos:
100 bps = 1%
500 bps = 5%
1000 bps = 10%
9000 bps = 90% (máximo)
10000 bps = 100%

Cálculo de comisiones:
fee_amount = (total_amount * fee_bps) / SCALAR_BPS
```

### Convenciones de Naming

**Contratos:**
- Factory: `defindex_factory`
- Vault: `defindex_vault_{hash}`
- Strategy: `{protocol}_strategy`

**Tokens del Vault:**
- Nombre: `DeFindex-Vault-{custom_name}`
- Símbolo: `{custom_symbol}`
- Decimales: 7

**Roles:**
- Manager: Rol 2
- Emergency Manager: Rol 0
- Rebalance Manager: Rol 3
- Fee Receiver: Rol 1

### Time-To-Live (TTL)

**Instance Storage (30 días):**
- Configuración del vault
- Roles
- Asset strategy sets
- Parámetros de comisiones

**Persistent Storage (120 días):**
- Reportes de estrategias
- Datos históricos

**Bump Strategy:**
```rust
// Extender TTL cada vez que se accede
env.storage().instance().extend_ttl(
    INSTANCE_BUMP_AMOUNT,
    INSTANCE_BUMP_AMOUNT
);

env.storage().persistent().extend_ttl(
    &key,
    PERSISTENT_BUMP_AMOUNT,
    PERSISTENT_BUMP_AMOUNT
);
```

---

## 14. Estructuras de Datos Clave

### Almacenamiento del Vault

```rust
pub enum DataKey {
    // Instance Storage (30 días TTL)
    TotalAssets,                           // u32
    AssetStrategySet(u32),                 // AssetStrategySet (indexed)
    DeFindexProtocolFeeReceiver,           // Address
    Upgradable,                            // bool
    VaultFee,                              // u32 (basis points)
    SoroswapRouter,                        // Address
    DeFindexProtocolFeeRate,               // u32 (basis points)
    Factory,                               // Address

    // Persistent Storage (120 días TTL)
    Report(Address),                       // Report (por estrategia)
}
```

### Almacenamiento del Factory

```rust
pub enum DataKey {
    Admin,                    // Address
    DeFindexReceiver,        // Address
    DeFindexFee,             // u32
    VaultWasmHash,           // BytesN<32>
    DeFindexCount,           // u32
    DeFindexAddress(u32),    // Address (indexed)
}
```

### Modelos de Inversión

```rust
// Asignación de inversión por asset
pub struct AssetInvestmentAllocation {
    pub asset: Address,
    pub strategy_investments: Vec<StrategyInvestment>,
}

// Inversión específica en estrategia
pub struct StrategyInvestment {
    pub strategy: Address,
    pub amount: i128,
}

// Estado actual del asset
pub struct CurrentAssetInvestmentAllocation {
    pub asset: Address,
    pub total_amount: i128,
    pub idle_amount: i128,
    pub invested_amount: i128,
    pub strategy_allocations: Vec<StrategyAllocation>,
}

// Asignación en estrategia
pub struct StrategyAllocation {
    pub strategy_address: Address,
    pub amount: i128,
    pub paused: bool,
}

// Configuración de asset y estrategias
pub struct AssetStrategySet {
    pub address: Address,
    pub strategies: Vec<Strategy>,
}

// Definición de estrategia
pub struct Strategy {
    pub address: Address,
    pub name: String,
    pub paused: bool,
}
```

### Modelo de Reporte

```rust
pub struct Report {
    pub prev_balance: i128,        // Balance previo (para calcular gains)
    pub gains_or_losses: i128,     // Ganancias/pérdidas acumuladas
    pub locked_fee: i128,          // Comisiones bloqueadas
}

impl Report {
    // Crear reporte vacío
    pub fn new() -> Self {
        Report {
            prev_balance: 0,
            gains_or_losses: 0,
            locked_fee: 0,
        }
    }

    // Actualizar con nuevo balance
    pub fn report(&mut self, new_balance: i128) {
        let gains = new_balance - self.prev_balance;
        self.gains_or_losses += gains;
        self.prev_balance = new_balance;
    }

    // Bloquear comisiones
    pub fn lock_fee(&mut self, fee_amount: i128) {
        self.locked_fee += fee_amount;
        self.gains_or_losses = 0;
    }

    // Liberar comisiones
    pub fn release_fee(&mut self) {
        self.gains_or_losses += self.locked_fee;
        self.locked_fee = 0;
    }

    // Resetear todo
    pub fn reset(&mut self) {
        self.prev_balance = 0;
        self.gains_or_losses = 0;
        self.locked_fee = 0;
    }
}
```

### Instrucciones de Rebalanceo

```rust
pub enum Instruction {
    Unwind {
        strategy_address: Address,
        amount: i128,
    },
    Invest {
        strategy_address: Address,
        amount: i128,
    },
    SwapExactIn {
        token_in: Address,
        token_out: Address,
        amount_in: i128,
        amount_out_min: i128,
        deadline: u64,
    },
    SwapExactOut {
        token_in: Address,
        token_out: Address,
        amount_out: i128,
        amount_in_max: i128,
        deadline: u64,
    },
}
```

---

## Apéndice: Códigos de Error

### Rangos de Errores

```rust
pub enum ContractError {
    // 100-108: Errores de inicialización
    AlreadyInitialized = 100,
    NotInitialized = 101,
    // ...

    // 110-129: Errores de validación
    WrongAmountsLength = 110,
    AmountOverTotalSupply = 111,
    // ...

    // 120-121: Errores aritméticos
    ArithmeticError = 120,
    // ...

    // 130-134: Errores de autorización
    Unauthorized = 130,
    RoleNotFound = 131,
    // ...

    // 140-144: Errores de estrategia
    StrategyNotFound = 140,
    StrategyPaused = 141,
    StrategyWithdrawFailed = 142,
    // ...

    // 150-151: Errores de asset
    AssetNotFound = 150,
    // ...

    // 160-165: Errores de input/swap
    InvalidInput = 160,
    SwapFailed = 161,
    // ...

    // 190+: Errores de librerías externas
    // ...
}
```

---

## Conclusión

Este documento proporciona una visión completa y detallada de la arquitectura DeFindex, incluyendo:

1. **Arquitectura General:** Factory, Vault, y Estrategias
2. **Flujos Operacionales:** Depósitos, retiros, rebalanceos
3. **Sistema de Comisiones:** Acumulación, bloqueo y distribución
4. **Gestión de Roles:** Sistema de permisos robusto
5. **Operaciones de Emergencia:** Rescue y pausas
6. **Sistema de Eventos:** Tracking completo de operaciones
7. **Estrategias:** Arquitectura plugueable y modular

DeFindex es un protocolo complejo pero bien estructurado que permite gestión sofisticada de inversiones multi-asset y multi-estrategia en Stellar/Soroban, con énfasis en seguridad, flexibilidad y transparencia.
