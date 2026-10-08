unit MainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.Buttons,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Grids,
  Vcl.DBGrids,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Comp.UI,
  FireDAC.VCLUI.Wait,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf;

type
  TfrmMain = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    sbToggleBold: TSpeedButton;
    sbRefresh: TSpeedButton;
    pnlLeft: TPanel;
    lblItemName: TLabel;
    edtItemName: TEdit;
    chkActive: TCheckBox;
    btnAddItem: TButton;
    btnReset: TButton;
    lblStatus: TLabel;
    pnlCenter: TPanel;
    DBGrid1: TDBGrid;
    StatusBar1: TStatusBar;
    DataSource1: TDataSource;
    memTable: TFDMemTable;
    procedure FormCreate(Sender: TObject);
    procedure sbToggleBoldClick(Sender: TObject);
    procedure sbRefreshClick(Sender: TObject);
    procedure btnAddItemClick(Sender: TObject);
    procedure btnResetClick(Sender: TObject);
    procedure chkActiveClick(Sender: TObject);
    procedure memTableAfterScroll(DataSet: TDataSet);
  private
    procedure InitMemTable;
    procedure PopulateSampleData;
    procedure UpdateStatusBar;
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  InitMemTable;
  PopulateSampleData;
  UpdateStatusBar;
end;

procedure TfrmMain.InitMemTable;
begin
  memTable.Close;
  memTable.FieldDefs.Clear;
  memTable.FieldDefs.Add('ID', ftInteger, 0, True);
  memTable.FieldDefs.Add('Name', ftString, 50, True);
  memTable.FieldDefs.Add('Category', ftString, 30, False);
  memTable.FieldDefs.Add('Price', ftFloat, 0, False);
  memTable.FieldDefs.Add('InStock', ftBoolean, 0, False);
  memTable.CreateDataSet;
  memTable.AfterScroll := memTableAfterScroll;
  DataSource1.DataSet := memTable;
  DBGrid1.DataSource := DataSource1;
end;

procedure TfrmMain.PopulateSampleData;
begin
  memTable.DisableControls;
  try
    memTable.EmptyDataSet;

    memTable.AppendRecord([1, 'Wireless Keyboard', 'Hardware', 149.99, True]);
    memTable.AppendRecord([2, 'Gaming Mouse', 'Hardware', 89.50, True]);
    memTable.AppendRecord([3, 'USB-C Cable 2m', 'Accessories', 19.99, True]);
    memTable.AppendRecord([4, 'Mechanical Switches Pack', 'Components', 35.00, False]);
    memTable.AppendRecord([5, 'Monitor Stand', 'Furniture', 120.00, True]);

    memTable.First;
  finally
    memTable.EnableControls;
  end;
end;

procedure TfrmMain.UpdateStatusBar;
begin
  if (StatusBar1.Panels.Count > 0) and (StatusBar1.Panels[0].Text = '') then
    StatusBar1.Panels[0].Text := 'Ready';

  if StatusBar1.Panels.Count > 1 then
  begin
    if memTable.Active and not memTable.IsEmpty then
      StatusBar1.Panels[1].Text := Format('Record %d of %d', [memTable.RecNo, memTable.RecordCount])
    else
      StatusBar1.Panels[1].Text := 'No Records';
  end;

  if StatusBar1.Panels.Count > 2 then
  begin
    if sbToggleBold.Down then
      StatusBar1.Panels[2].Text := 'Bold: ON'
    else
      StatusBar1.Panels[2].Text := 'Bold: OFF';
  end;
end;

procedure TfrmMain.sbToggleBoldClick(Sender: TObject);
begin
  if sbToggleBold.Down then
  begin
    lblTitle.Font.Style := lblTitle.Font.Style + [fsBold];
    StatusBar1.Panels[2].Text := 'Bold: ON';
  end
  else
  begin
    lblTitle.Font.Style := lblTitle.Font.Style - [fsBold];
    StatusBar1.Panels[2].Text := 'Bold: OFF';
  end;
  StatusBar1.Panels[0].Text := 'Bold toggled';
end;

procedure TfrmMain.sbRefreshClick(Sender: TObject);
begin
  PopulateSampleData;
  StatusBar1.Panels[0].Text := 'Data refreshed';
  lblStatus.Caption := 'Last Action: Data Refreshed';
  UpdateStatusBar;
end;

procedure TfrmMain.btnAddItemClick(Sender: TObject);
var
  LName: string;
  LNewId: Integer;
begin
  LName := Trim(edtItemName.Text);
  if LName = '' then
  begin
    ShowMessage('Item Name cannot be empty');
    Exit;
  end;

  LNewId := memTable.RecordCount + 1;
  memTable.AppendRecord([LNewId, LName, 'Custom', 49.99, chkActive.Checked]);

  StatusBar1.Panels[0].Text := 'Item Added: ' + LName;
  lblStatus.Caption := 'Last Action: Added ' + LName;
  edtItemName.Text := '';
  UpdateStatusBar;
end;

procedure TfrmMain.btnResetClick(Sender: TObject);
begin
  PopulateSampleData;
  edtItemName.Text := '';
  chkActive.Checked := False;
  StatusBar1.Panels[0].Text := 'Reset executed';
  lblStatus.Caption := 'Last Action: Reset';
  UpdateStatusBar;
end;

procedure TfrmMain.chkActiveClick(Sender: TObject);
begin
  if chkActive.Checked then
    lblStatus.Caption := 'Last Action: Checked'
  else
    lblStatus.Caption := 'Last Action: Unchecked';
  StatusBar1.Panels[0].Text := 'Checkbox toggled';
end;

procedure TfrmMain.memTableAfterScroll(DataSet: TDataSet);
begin
  UpdateStatusBar;
end;

end.
