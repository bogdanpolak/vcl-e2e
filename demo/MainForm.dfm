object frmMain: TfrmMain
  Left = 100
  Top = 100
  Caption = 'VCL E2E Demo Application'
  ClientHeight = 480
  ClientWidth = 750
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 750
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 14
      Width = 145
      Height = 17
      Caption = 'E2E Demo Application'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object sbToggleBold: TSpeedButton
      Left = 200
      Top = 10
      Width = 32
      Height = 28
      AllowAllUp = True
      GroupIndex = 1
      Caption = 'B'
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      OnClick = sbToggleBoldClick
    end
    object sbRefresh: TSpeedButton
      Left = 240
      Top = 10
      Width = 75
      Height = 28
      Caption = 'Refresh'
      Flat = True
      OnClick = sbRefreshClick
    end
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 48
    Width = 240
    Height = 413
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object lblItemName: TLabel
      Left = 16
      Top = 16
      Width = 62
      Height = 15
      Caption = 'Item Name:'
    end
    object lblStatus: TLabel
      Left = 16
      Top = 220
      Width = 98
      Height = 15
      Caption = 'Last Action: None'
    end
    object edtItemName: TEdit
      Left = 16
      Top = 36
      Width = 200
      Height = 23
      TabOrder = 0
    end
    object chkActive: TCheckBox
      Left = 16
      Top = 72
      Width = 97
      Height = 17
      Caption = 'Active'
      TabOrder = 1
      OnClick = chkActiveClick
    end
    object btnAddItem: TButton
      Left = 16
      Top = 110
      Width = 200
      Height = 32
      Caption = 'Add Item'
      TabOrder = 2
      OnClick = btnAddItemClick
    end
    object btnReset: TButton
      Left = 16
      Top = 152
      Width = 200
      Height = 32
      Caption = 'Reset Data'
      TabOrder = 3
      OnClick = btnResetClick
    end
  end
  object pnlCenter: TPanel
    Left = 240
    Top = 48
    Width = 510
    Height = 413
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object DBGrid1: TDBGrid
      Left = 0
      Top = 0
      Width = 510
      Height = 413
      Align = alClient
      DataSource = DataSource1
      TabOrder = 0
      TitleFont.Charset = DEFAULT_CHARSET
      TitleFont.Color = clWindowText
      TitleFont.Height = -12
      TitleFont.Name = 'Segoe UI'
      TitleFont.Style = []
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 461
    Width = 750
    Height = 19
    Panels = <
      item
        Text = 'Ready'
        Width = 220
      end
      item
        Text = 'No Records'
        Width = 160
      end
      item
        Text = 'Bold: OFF'
        Width = 120
      end>
  end
  object DataSource1: TDataSource
    DataSet = memTable
    Left = 320
    Top = 120
  end
  object memTable: TFDMemTable
    FetchOptions.AssignedValues = [evMode]
    FetchOptions.Mode = fmAll
    ResourceOptions.AssignedValues = [rvSilentMode]
    ResourceOptions.SilentMode = True
    UpdateOptions.AssignedValues = [uvCheckRequired, uvAutoCommitUpdates]
    UpdateOptions.CheckRequired = False
    UpdateOptions.AutoCommitUpdates = True
    Left = 320
    Top = 180
  end
end
