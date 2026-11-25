# Configuração do PZLinux B42.21

As 55 opções aparecem em PZLinux, PZLinux - Módulos, PZLinux - Economia e PZLinux - Mundo. O Sandbox do servidor determina os valores no multiplayer. Os tooltips detalham comportamento e limites.

| Opção `PZLinux.*` | Padrão | Função |
|---|---:|---|
| `Enabled` | `true` | Ativar PZLinux |
| `ATMEnabled` | `true` | Ativar caixas ATM |
| `DarkWebEnabled` | `true` | Ativar Dark Web |
| `LocalMarketEnabled` | `true` | Ativar Mercado Local |
| `VehicleTradingEnabled` | `true` | Permitir venda de veículos |
| `ContractsEnabled` | `true` | Ativar contratos |
| `RequestsEnabled` | `true` | Ativar encomendas |
| `MailEnabled` | `true` | Ativar e-mails |
| `TradingEnabled` | `true` | Ativar bolsa e carteira |
| `BettingEnabled` | `true` | Ativar apostas |
| `HackingEnabled` | `true` | Ativar hacking de cartões |
| `RepairEnabled` | `true` | Ativar reparo de computadores |
| `CurrencyConversionEnabled` | `true` | Ativar conversão de moeda |
| `CurrencyMode` | `1` | Moeda física |
| `AcceptAlternateCurrency` | `true` | Aceitar também a outra moeda |
| `StartingBalanceMin` | `500` | Saldo inicial mínimo |
| `StartingBalanceMax` | `3999` | Saldo inicial máximo |
| `MaxCashTransaction` | `100000` | Limite por saque ou depósito |
| `ComputerRequiresPower` | `true` | Computador exige eletricidade |
| `ATMRequiresPower` | `true` | ATM exige eletricidade |
| `ComputerFuelPerMinute` | `0.0003` | Combustível do computador por minuto do jogo |
| `ATMFuelPerMinute` | `0.0002` | Combustível do ATM por minuto do jogo |
| `ConnectionHours` | `24` | Conexão e cache de boot (horas do jogo) |
| `ComputerWearMultiplier` | `1` | Multiplicador de desgaste do computador |
| `RepairMultiplier` | `1` | Multiplicador de reparo |
| `RepairTime` | `430` | Duração do reparo |
| `RepairXP` | `3` | Experiência por reparo |
| `PurchasePriceMultiplier` | `1` | Multiplicador de preco de compra |
| `SalePriceMultiplier` | `1` | Multiplicador de preco de venda |
| `ContractRewardMultiplier` | `1` | Multiplicador de recompensa dos contratos |
| `ContractRefreshHours` | `168` | Renovação dos contratos (horas do jogo) |
| `ProtectWaveCount` | `30` | Zumbis por defesa de prédio |
| `HackingRewardMultiplier` | `1` | Multiplicador de saldo dos cartões |
| `HackingMinElectricity` | `0` | Eletricidade mínima para hacking |
| `BettingMaxStake` | `100000` | Aposta máxima |
| `BettingPayoutMultiplier` | `1` | Multiplicador de prêmios das apostas |
| `MailMinHours` | `48` | Intervalo mínimo entre e-mails (horas) |
| `MailMaxHours` | `720` | Intervalo máximo entre e-mails (horas) |
| `DarkWebRefreshHours` | `24` | Renovação da Dark Web (horas do jogo) |
| `DarkWebMaxOffers` | `2` | Ofertas por renovação da Dark Web |
| `DarkWebDeliveryTheftChance` | `10` | Chance de roubo da entrega (%) |
| `DarkWebSharedCatalogEnabled` | `true` | Ativar catalogo compartilhado da Dark Web |
| `TradingVolatilityMultiplier` | `1` | Multiplicador de volatilidade da bolsa |
| `ContractTradingImpactEnabled` | `true` | Ativar impacto dos contratos nas acoes |
| `ContractTradingImpactMaxPercent` | `1` | Impacto maximo dos contratos nas acoes (%%) |
| `DemandEnabled` | `true` | Ativar oferta e procura |
| `DemandMinimum` | `0.75` | Multiplicador mínimo da procura |
| `DemandMaximum` | `2.5` | Multiplicador máximo da procura |
| `DemandBuyStep` | `0.02` | Aumento da procura por compra |
| `DemandSellStep` | `0.01` | Redução da procura por venda |
| `DemandDecayPerHour` | `0.005` | Redução da procura por hora |
| `ForceItemZombieSpawn` | `true` | Forcar spawn de item em zumbi |
| `ZombieCardDropChance` | `0.5` | Chance de cartões nos corpos (%) |
| `EnableAutoHack` | `true` | Ativar auto hack |
| `AutoHackAdminOnly` | `false` | Auto hack apenas para admin |

`CurrencyMode=1` mantém o padrão anterior. `CurrencyMode=2` usa cobre (1), prata (100) e ouro (10000). `AcceptAlternateCurrency=true` facilita migrar itens antigos; desative para aceitar apenas a família selecionada. Saques e troco usam sempre a moeda selecionada. Saldos numéricos, preços e inventário existente não são convertidos nem apagados.

Alterações de saldo inicial afetam apenas contas sem saldo salvo. Contratos já aceitos e e-mails já agendados mantêm os valores/prazos salvos. O novo tamanho e prazo de catálogo aplicam na próxima renovação. Reinicie o servidor e reabra as interfaces após editar opções. Faça backup do save antes de atualizar.
