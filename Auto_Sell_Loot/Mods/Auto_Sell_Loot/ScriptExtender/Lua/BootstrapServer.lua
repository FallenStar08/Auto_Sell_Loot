Ext.Require("Shared/_Init.lua")
Ext.Require("ModInfos/_ModInfos.lua")

if Mods.BG3MCM then
    Ext.Require("Server/main.lua")
else
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
        DelayedCall(1000,
            function()
                Osi.OpenMessageBox(Osi.GetHostCharacter(),
                    "FallenStar's AutoSeller : You don't have MCM installed you DOOFUS \n THE MOD WILL NOT WORK")
            end)
    end)
end
