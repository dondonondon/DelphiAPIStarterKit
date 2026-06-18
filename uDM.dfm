object DM: TDM
  OnCreate = DataModuleCreate
  Height = 480
  Width = 640
  object Con: TFDConnection
    Params.Strings = (
      'Server=192.168.0.250'
      'User_Name=blangkonfa'
      'Password=Dondonondon270994123!@#'
      'Database=pos_nepal'
      'DriverID=MySQL')
    LoginPrompt = False
    Left = 80
    Top = 40
  end
  object FDPhysMySQLDriverLink: TFDPhysMySQLDriverLink
    VendorHome = 'D:\Documentation\DatasnapLinux\Win64\Release\'
    Left = 232
    Top = 184
  end
end
