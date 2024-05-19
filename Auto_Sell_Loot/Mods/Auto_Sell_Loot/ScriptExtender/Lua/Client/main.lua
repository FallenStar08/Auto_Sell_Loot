Ext.RegisterNetListener("MCM_Server_Send_Configs_To_Client", function(call, payload)
    Net.Send("Fallen_AutoSell_Checkmark", "ready")
end)




Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Features", function(tabHeader)
    local buttonText = GetTranslatedString("h0b6204424dee44c689cf73887a557a2e6d5c") or "Clear List"
    local buttonDesc = GetTranslatedString("ha442f9c2c5bd427bafbbe98bc607fc21570e") or
        "WARNING THIS WILL CLEAR THE LIST IN USE"
    ---@type ExtuiButton
    local ClearButton = tabHeader:AddButton(buttonText)
    ClearButton:SetColor("Text", { 1, 0, 0, 1 })
    ClearButton:Tooltip():AddText(buttonDesc)
    ClearButton.OnClick = function()
        Net.Send("Fallen_Autosell_Button_ClearList", "doot")
    end
end)
