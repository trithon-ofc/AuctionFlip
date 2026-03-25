local L = LibStub("AceLocale-3.0"):NewLocale("AuctionFlip", "ptBR")

if L then
  L.SCAN_BUTTON = "Escanear CH"
  L.STATUS_SCANNING = "Escaneando..."
  L.STATUS_COMPLETE = "Escaneamento completo"
  L.STATUS_READY = "Pronto"
  
  L.OPP_VENDOR_FLIP = "Revenda ao PN"
  L.OPP_UNDERPRICED = "Abaixo do Preço"
  L.OPP_CRAFTING = "Lucro de Crafting"
  
  L.STATS_TOTAL_PROFIT = "Lucro Total"
  L.STATS_TOTAL_FLIPS = "Total de Operações"
  L.STATS_SUCCESS_RATE = "Taxa de Sucesso"
  L.STATS_AVG_PROFIT = "Lucro Médio"
  
  L.SETTINGS_GENERAL = "Geral"
  L.SETTINGS_SCANNING = "Escaneamento"
  L.SETTINGS_ALERTS = "Alertas"
  
  L.PROFIT_THRESHOLD = "Limite Mínimo de Lucro"
  L.ENABLE_SOUNDS = "Ativar Alertas Sonoros"
  L.ENABLE_NOTIFICATIONS = "Ativar Notificações"
  
  L.TAB_OPPORTUNITIES = "Oportunidades"
  L.TAB_STATS = "Estatísticas"
  L.TAB_SETTINGS = "Configurações"

  -- Advanced metrics columns
  L.COL_DISCOUNT = "Desc%"
  L.COL_NET_PROFIT = "Lucro Líq."
  L.COL_ROI = "ROI%"
  L.COL_LIQUIDITY = "Liq."
  L.COL_CONFIDENCE = "Conf"
  L.COL_MARKET = "Mercado"

  -- Risk profiles
  L.RISK_PROFILE = "Perfil de Risco"
  L.RISK_CONSERVATIVE = "Seguro"
  L.RISK_BALANCED = "Balanceado"
  L.RISK_AGGRESSIVE = "Agressivo"

  -- Tooltip labels
  L.TT_FAIR_PRICE = "Preço Justo"
  L.TT_DISCOUNT = "Desconto"
  L.TT_GROSS_PROFIT = "Lucro Bruto (total)"
  L.TT_AH_FEE = "Taxa do CH"
  L.TT_NET_PROFIT = "Lucro Líquido"
  L.TT_ROI = "Retorno sobre Investimento"
  L.TT_VOLUME = "Volume"
  L.TT_LIQUIDITY = "Liquidez"
  L.TT_CONFIDENCE = "Confiança"
  L.TT_DATA_POINTS = "Pontos de Dados"
  L.TT_PRICE_HISTORY = "Histórico de Preços"
  L.TT_CAPITAL_WARNING = "Aviso: %d%% do ouro disponível"
  L.TT_CAPITAL_NOTE = "Nota: %d%% do ouro disponível"

  -- Settings labels
  L.SET_MIN_ROI = "ROI% Mínimo"
  L.SET_MIN_DISCOUNT = "Desconto% Mínimo"
  L.SET_MIN_VOLUME = "Volume Mín./Dia"
  L.SET_MARKET_WINDOW = "Janela de Mercado"
  L.SET_CATEGORY_FILTER = "Ativar Filtro por Categoria"
  L.SET_CAT_CONSUMABLE = "Consumíveis"
  L.SET_CAT_TRADESKILL = "Materiais de Profissão"
  L.SET_CAT_RECIPE = "Receitas"
  L.SET_CAT_GEM = "Gemas"
  L.SET_CAT_ENHANCEMENT = "Aprimoramentos"
  L.SET_CAT_ARMOR = "Armaduras (Transmog)"
  L.SET_CAT_WEAPON = "Armas (Transmog)"
  L.SET_CAT_MISC = "Diversos"

  -- Liquidity labels
  L.LIQ_HIGH = "Alta"
  L.LIQ_MEDIUM = "Média"
  L.LIQ_LOW = "Baixa"
end
