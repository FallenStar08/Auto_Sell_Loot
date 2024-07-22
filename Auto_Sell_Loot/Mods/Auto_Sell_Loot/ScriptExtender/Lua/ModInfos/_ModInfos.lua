local default_config = {
    SELL_VALUE_PERCENTAGE = 40,
    LOG_ENABLED = 0,
    MOD_ENABLED = 1,
    DEBUG_MESSAGES = 3,
    FIX_MODE = 0,
    GIVE_BAG = 1,
    CUSTOM_LISTS_ONLY = 0,
    BAG_SELL_MODE_ONLY = 0,
    MARK_AS_WARE = 0,
}

RegisterModVariable("Fallen_AutoSellerInfos")

MOD_INFO = ModInfo:new("Fall_AutoSeller", "Fall_AutoSeller", true, default_config)
