# PZLinux 0.3.0 — Build 42.21

Revisão da estrutura e das referências à API usando a Umbrella local B42.21, com escolha de moeda e 55 opções Sandbox.

- Mod ID preservado: `B42_PZLinux42`.
- Workshop ID preservado: `3700371875`.
- [Todas as opções Sandbox](SANDBOX_PTBR.md).
- [Notas de atualização](Contents/mods/B42%20PZLinux/UPDATE_NOTES_PTBR.txt).
- [Descrição para Workshop](Contents/mods/B42%20PZLinux/WorkshopDescription_PTBR.txt).

## Instalação

Mantenha a estrutura `Contents/mods/B42 PZLinux/common` e `42`. Em multiplayer, use a mesma versão nos clientes e no servidor, mantenha `B42_PZLinux42` em `Mods=` e `3700371875` em `WorkshopItems=`, preservando os demais IDs. Reinicie após atualizar. Faça backup da pasta do save antes da primeira execução.

## Escolha de moeda

O Sandbox **Moeda física** (`PZLinux.CurrencyMode`) tem duas opções:

1. Dinheiro vanilla: `Base.Money` vale 1; `Base.MoneyBundle` vale 100. É o padrão da versão anterior.
2. Moedas PZLinux: `Base.CobreCoin` vale 1; `Base.SilverCoin` vale 100; `Base.GoldCoin` vale 10000.

`AcceptAlternateCurrency=true` permite depositar/pagar nas duas famílias, reaproveitando itens antigos. Desative para aceitar somente a selecionada. Saques, troco e pilhas de recompensa usam a selecionada. As três moedas reutilizam o ícone existente; seus nomes e valores as distinguem.

Trocar a moeda **não multiplica o saldo**, não altera preços, não apaga itens existentes e não transforma automaticamente itens dentro de inventários. O banco continua armazenando um valor numérico em `PZLinuxBank`. A composição `PZLinuxBankCoins` é uma representação derivada, marcada com o modo da moeda; é recomposta quando necessário sem reiniciar a conta. Conversões de denominações mantêm o mesmo total.

## Sandbox e módulos

Há controles individuais para ATM, Dark Web, Mercado Local, venda de veículos, contratos, encomendas, e-mails, bolsa/carteira, apostas, hacking, reparos e conversões, além do interruptor geral. As interfaces e os comandos dedicados do servidor consultam a configuração. Interações principais também a verificam quando a janela já estava aberta.

Os demais controles abrangem saldo inicial, limite de caixa, preços, recompensas, apostas, procura, volatilidade, catálogo, roubo de entregas elegíveis, eletricidade, combustível extra, desgaste, reparo, experiência, conexão, e-mails e cartões nos corpos. Consulte [a tabela completa](SANDBOX_PTBR.md).

Os padrões existentes foram mantidos, com limite novo de 100000 unidades base por operação física de caixa, ajustável no Sandbox. Saldo inicial só afeta contas sem saldo salvo. Recompensas de contratos já aceitos e prazos de e-mails já agendados são preservados. Quantidade/prazo de catálogo passam a valer na próxima renovação. Para uma alteração consistente, reinicie o servidor e reabra as janelas.

Desativar compras não apaga entregas já pagas. O comando de coleta dessas entregas permanece disponível pelo correio. Anúncios não são descartados ao desativar o mercado; cancelamento e devolução do que está em depósito continuam permitidos pelo servidor.

## Correções de compatibilidade e funcionamento

- O método inexistente `removeTileObject` foi substituído pela API `transmitRemoveItemFromSquare`, declarada na 42.21. Caixas novas também usam replicação explícita no servidor.
- Contratos de alvo, carga e encomendas de veículos mantêm o estado pendente quando a área está descarregada ou a criação falha. O cliente solicita a alteração sem consumir o estado antecipadamente e limita as novas tentativas.
- O servidor confere as coordenadas com o destino salvo e define o tamanho da defesa pelo próprio Sandbox. Uma defesa que não cria nenhum zumbi permanece pendente.
- Encomendas usam `BaseVehicle:createVehicleKey()` em lugar de gerar IDs de chave aleatórios.
- Objetivos pessoais ignoram zumbis cujo atacante identificado é outro sobrevivente.
- Criação de dinheiro, retirada de itens, troco e conversões incluem reposição em falhas parciais. Reparos exigem consumo bem-sucedido da sucata.
- Eletricidade local é reconhecida em ambientes internos após o desligamento da rede. Ambientes externos respeitam `AllowExteriorGenerator`; cada terminal também possui sua opção de exigir energia.
- Consumo extra é configurável, limitado a módulos ativos que exigem energia, e sincroniza o gerador pela API nativa. Os valores anteriores de consumo foram preservados como padrão.
- Auto hack restrito a administradores consulta a API de papel/capacidades disponível na 42.21.
- Traduções ausentes, nomes das moedas, opções e tooltips foram completados em EN/PTBR.

## Integrações e limites da revisão

A venda de veículos do Mercado Local continua usando **JeevesClaims**, como na base recebida. O mod Multi Funções não fornece essa API automaticamente. Sem a integração compatível, use o mercado de itens e desative `VehicleTradingEnabled`. Não foi alterada a implementação externa de reivindicações.

Contratos, apostas, encomendas e hacking ainda possuem partes do fluxo bancário legado, com estado enviado pelo cliente. Esta revisão preserva esses saves e protocolos; ela não migra toda a economia para autoridade exclusiva do servidor. Os comandos dedicados revisados verificam suas configurações, mas isso não equivale a impedir toda alteração por clientes modificados.

As coordenadas dos contratos continuam sendo as do catálogo existente. A Umbrella descreve APIs, não a integridade de cada destino no mapa ou em mapas modificados. Confira os destinos usados pelo servidor no teste de gameplay.

## Evidências e validação

Referência usada: `C:\Users\Malaio\Desktop\Umbrella .21\Umbrella-main\library`. Foram conferidas declarações de remoção/replicação de objetos, criação de veículos/zumbis, chave do veículo, inventários, papéis e ações temporizadas. Uma declaração confirma a assinatura disponível; não reproduz o comportamento do motor.

Execute da pasta Workshop com Python 3, Lua 5.4 e `luac` no PATH:

```powershell
python "B42 PZLinux/tests/validate.py"
```

Outra referência pode ser informada com `--umbrella "C:\caminho\Umbrella-main\library"`.

Em 04/11/2026 passaram:

- Sintaxe dos 52 módulos Lua de produção e dependências locais/nativas.
- Inicialização dos módulos em ambientes simulados de SP, servidor e cliente.
- Correspondência das 55 opções com os padrões do código, traduções, placeholders e definições de moeda.
- 48 regressões com o código de produção, cobrindo moeda, migração de representação, reposição, limites, configurações, contratos, multiplayer, reparos, e-mail e Dark Web.

Os testes simulam fronteiras nativas. O jogo instalado informa **42.20.2**, portanto **não houve teste real do motor 42.21** em single-player, hospedado ou dedicado. Em uma cópia do save, validar:

1. Login em conta antiga e nova, saldos, anúncios, carteira e entregas anteriores.
2. ATM nos dois modos: depósitos, saques, troco, conversões, limite e aceitação exclusiva da moeda.
3. Reabrir cada módulo ativado/desativado e confirmar que opções restritas são negadas também no servidor.
4. Compra/venda de itens com dois jogadores; coleta de entrega paga; reinício e persistência.
5. Contratos de alvo, carga e defesa, além de encomenda de veículo/chave, aproximando-se de áreas descarregadas e relogando.
6. Hacking, apostas, carteira, reparo, desgaste e gerador após o desligamento da rede, em SP e MP.
7. Destinos reais do catálogo no mapa usado e integração JeevesClaims, se habilitada.

Backup anterior à revisão:

`C:\Users\Malaio\AppData\Local\Temp\PZLinux-before-B42_21-20261104-022247.zip`

Nenhum envio à Steam foi realizado. Créditos e autoria original de Raixxar foram preservados.
