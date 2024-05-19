Ext.RegisterNetListener("MCM_Server_Send_Configs_To_Client", function(call, payload)
    Net.Send("Fallen_AutoSell_Checkmark", "ready")
end)
