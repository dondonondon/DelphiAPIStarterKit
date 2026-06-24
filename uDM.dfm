object DM: TDM
  OnCreate = DataModuleCreate
  Height = 480
  Width = 640
  object Con: TFDConnection
    Params.Strings = (
      'Server='
      'DriverID=MySQL')
    LoginPrompt = False
    Left = 80
    Top = 40
  end
  object FDPhysMySQLDriverLink: TFDPhysMySQLDriverLink
    Left = 232
    Top = 184
  end
end
