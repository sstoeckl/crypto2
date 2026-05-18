utils::globalVariables(c("id","name","symbol","slug","rank","is_active","first_historical_data","last_historical_data","timestamp",
                         "close_ratio","coins","hist_date","history_url","market","Date","Name","Symbol","ref_cur","historyurl","finalWait","interval",
                         "name","name_main","platform_locale","slug","slug_main","symbol","value","volume",".","code","sign",
                         "date_added", "last_updated","tags","platform","out","total_market_cap","total_volume_24h_yesterday_percentage_change","VAR",
                         "ref_cur_id","ref_cur_name","sleep","wait","added_date","endDate","last_update","startDate","platforms","price_change","quotes",
                         "search_interval",
                         # CoinGecko branch additions
                         "id_num","image","market_cap_rank","market_cap","open","high","low","close","close_o",
                         "time_open","time_high","time_low","time_close","date","numeric_id",
                         # PR #25 (Mar 2026, JesseVent) added cmc_rank usage in crypto_history
                         "cmc_rank"))
