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
end
