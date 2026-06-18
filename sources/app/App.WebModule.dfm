object WM: TWM
  OnCreate = WebModuleCreate
  Actions = <
    item
      Name = 'DefaultHandler'
      PathInfo = '/'
      OnAction = WebModule1DefaultHandlerAction
    end
    item
      Name = 'api'
      PathInfo = '/api/v1/*'
      OnAction = WMapiAction
    end
    item
      Name = 'image'
      PathInfo = '/image'
      OnAction = WMimageAction
    end
    item
      Name = 'test'
      PathInfo = '/test'
      OnAction = WMtestAction
    end>
  Height = 230
  Width = 415
  object DSHTTPWebDispatcher1: TDSHTTPWebDispatcher
    Filters = <
      item
        FilterId = 'PC1'
        Properties.Strings = (
          'Key=3Luj6T419!HlU5Mi')
      end
      item
        FilterId = 'RSA'
        Properties.Strings = (
          'UseGlobalKey=true'
          'KeyLength=1024'
          'KeyExponent=3')
      end
      item
        FilterId = 'ZLibCompression'
        Properties.Strings = (
          'CompressMoreThan=1024')
      end>
    WebDispatch.PathInfo = 'datasnap*'
    Left = 96
    Top = 75
  end
  object DSProxyDispatcher1: TDSProxyDispatcher
    DSProxyGenerator = DSProxyGenerator1
    Left = 320
    Top = 80
  end
  object DSProxyGenerator1: TDSProxyGenerator
    MetaDataProvider = DSServerMetaDataProvider1
    Left = 320
    Top = 16
  end
  object DSServerMetaDataProvider1: TDSServerMetaDataProvider
    Left = 320
    Top = 160
  end
end
