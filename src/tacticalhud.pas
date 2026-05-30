unit tacticalhud;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  flightplan, GPS;

type

  { TfrmTacticalHUD }

  TfrmTacticalHUD = class(TForm)
    btnStartRoute: TButton;
    btnClearWaypoints: TButton;
    btnSimulation: TButton;
    ckGeofenceActive: TCheckBox;
    ckAltitudeActive: TCheckBox;
    ckSimulationActive: TCheckBox;
    edMaxAltitude: TEdit;
    edMinAltitude: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    lblLat: TLabel;
    lblLon: TLabel;
    lblAlt: TLabel;
    lblSpeed: TLabel;
    lblAlarms: TLabel;
    lblStatus: TLabel;
    lstWaypoints: TListBox;
    pnHUD: TPanel;
    pnControls: TPanel;
    pnWaypoints: TPanel;
    tmHUDUpdate: TTimer;

    procedure btnClearWaypointsClick(Sender: TObject);
    procedure btnSimulationClick(Sender: TObject);
    procedure btnStartRouteClick(Sender: TObject);
    procedure ckAltitudeActiveChange(Sender: TObject);
    procedure ckGeofenceActiveChange(Sender: TObject);
    procedure ckSimulationActiveChange(Sender: TObject);
    procedure edMaxAltitudeChange(Sender: TObject);
    procedure edMinAltitudeChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure tmHUDUpdateTimer(Sender: TObject);

  private
    FBlinkState: Boolean;
    procedure StyleMilitaryHUD;
    procedure StyleControl(AControl: TControl; AFore, ABack: TColor);
    procedure RefreshWaypointList;
  public
    procedure UpdateDroneData(ALat, ALon, AAlt, ASpeed: Double);
  end;

var
  frmTacticalHUD: TfrmTacticalHUD;

implementation

{$R *.lfm}

uses
  main, map;

{ TfrmTacticalHUD }

procedure TfrmTacticalHUD.FormCreate(Sender: TObject);
begin
  StyleMilitaryHUD;
  FBlinkState := False;
end;

procedure TfrmTacticalHUD.FormShow(Sender: TObject);
begin
  // Initialize values from GlobalFlightPlan
  ckGeofenceActive.Checked := GlobalFlightPlan.GeofenceActive;
  ckAltitudeActive.Checked := GlobalFlightPlan.AltitudeActive;
  ckSimulationActive.Checked := GlobalFlightPlan.SimulationActive;

  edMaxAltitude.Text := FormatFloat('0.0', GlobalFlightPlan.MaxAltitude);
  edMinAltitude.Text := FormatFloat('0.0', GlobalFlightPlan.MinAltitude);

  RefreshWaypointList;
  tmHUDUpdate.Enabled := True;
end;

procedure TfrmTacticalHUD.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  tmHUDUpdate.Enabled := False;
  CloseAction := caHide;
end;

procedure TfrmTacticalHUD.StyleControl(AControl: TControl; AFore, ABack: TColor);
var
  I: Integer;
begin
  AControl.Color := ABack;
  AControl.Font.Color := AFore;
  AControl.Font.Name := 'Consolas';
  AControl.Font.Style := [fsBold];

  if AControl is TWinControl then
  begin
    for I := 0 to TWinControl(AControl).ControlCount - 1 do
      StyleControl(TWinControl(AControl).Controls[I], AFore, ABack);
  end;
end;

procedure TfrmTacticalHUD.StyleMilitaryHUD;
var
  DarkGrey, NeonGreen: TColor;
begin
  Color := clBlack;
  DarkGrey := $001F1F1F;
  NeonGreen := $0039FF14; // Vibrant tactical HUD green

  StyleControl(Self, NeonGreen, clBlack);

  // Custom visual adjustments for panels
  pnHUD.Color := DarkGrey;
  pnControls.Color := DarkGrey;
  pnWaypoints.Color := DarkGrey;

  lstWaypoints.Color := clBlack;
  lstWaypoints.Font.Color := NeonGreen;

  lblAlarms.Color := clBlack;
  lblAlarms.Font.Color := NeonGreen;
end;

procedure TfrmTacticalHUD.RefreshWaypointList;
var
  I: Integer;
  W: TWaypoint;
begin
  lstWaypoints.Items.BeginUpdate;
  try
    lstWaypoints.Items.Clear;
    for I := 0 to GlobalFlightPlan.WaypointCount - 1 do
    begin
      W := GlobalFlightPlan.Waypoints[I];
      if Assigned(W) then
      begin
        lstWaypoints.Items.Add(Format('WP%.2d [%s] Lat: %.5f Lon: %.5f Alt: %.1fm',
          [I + 1, W.Status, W.Latitude, W.Longitude, W.Altitude]));
      end;
    end;
  finally
    lstWaypoints.Items.EndUpdate;
  end;
end;

procedure TfrmTacticalHUD.UpdateDroneData(ALat, ALon, AAlt, ASpeed: Double);
begin
  lblLat.Caption := FormatFloat('0.000000', ALat);
  lblLon.Caption := FormatFloat('0.000000', ALon);
  lblAlt.Caption := FormatFloat('0.0', AAlt) + ' m';
  lblSpeed.Caption := FormatFloat('0.1', ASpeed) + ' m/s';
end;

procedure TfrmTacticalHUD.tmHUDUpdateTimer(Sender: TObject);
var
  DLat, DLon, DAlt, DSpeed: Double;
  WarnMsg, FinalAlarmMsg: string;
  InFence, InAlt: Boolean;
  NextWpMsg: string;
begin
  FBlinkState := not FBlinkState;

  // Retrieve current coordinates (Simulation vs. GPS)
  if GlobalFlightPlan.SimulationActive then
  begin
    // Run simulation tick (assume 100ms interval)
    GlobalFlightPlan.SimulateStep(0.1);

    DLat := GlobalFlightPlan.SimulatedDroneLat;
    DLon := GlobalFlightPlan.SimulatedDroneLon;
    DAlt := GlobalFlightPlan.SimulatedDroneAlt;
    DSpeed := 8.0; // Simulated speed (m/s)

    lblStatus.Caption := 'SISTEMA OPERANDO EM MODO SIMULAÇÃO TÁTICA';
    lblStatus.Font.Color := $0000A5FF; // Orange
  end
  else
  begin
    // Check if real GPS position is available
    if Assigned(frmGPS) and frmGPS.TemPosicao then
    begin
      DLat := frmGPS.Latitude;
      DLon := frmGPS.Longitude;
      DAlt := frmGPS.Altitude;
      DSpeed := frmGPS.Velocidade;
      lblStatus.Caption := 'TELEMETRIA GPS EM TEMPO REAL ATIVA';
      lblStatus.Font.Color := $0039FF14; // Tactical Green
    end
    else
    begin
      DLat := -21.0178; // Fallback
      DLon := -47.7639;
      DAlt := 0.0;
      DSpeed := 0.0;
      lblStatus.Caption := 'SINAL GPS AUSENTE - AGUARDANDO FIX';
      lblStatus.Font.Color := clRed;
    end;
  end;

  // Update UI values
  UpdateDroneData(DLat, DLon, DAlt, DSpeed);

  // Update Flight Plan route tracking (waypoint sequencing)
  if GlobalFlightPlan.CurrentIndex >= 0 then
  begin
    GlobalFlightPlan.UpdateRouteTracking(DLat, DLon, NextWpMsg);
    if NextWpMsg <> '' then
      RefreshWaypointList;
  end;

  // Run Safety Checks (Geofence & Altitude Bounds)
  InFence := GlobalFlightPlan.IsWithinGeofence(DLat, DLon);
  InAlt := GlobalFlightPlan.CheckAltitudeLimits(DAlt, WarnMsg);

  FinalAlarmMsg := '';
  if not InFence then
    FinalAlarmMsg := '*** VIOLAÇÃO GEOFENCE: FORA DO QUADRILÁTERO ***'
  else if not InAlt then
    FinalAlarmMsg := '*** VIOLAÇÃO ALTITUDE: ' + WarnMsg + ' ***';

  if FinalAlarmMsg <> '' then
  begin
    lblAlarms.Caption := FinalAlarmMsg;
    if FBlinkState then
    begin
      lblAlarms.Color := clRed;
      lblAlarms.Font.Color := clWhite;
    end
    else
    begin
      lblAlarms.Color := clBlack;
      lblAlarms.Font.Color := clRed;
    end;
  end;

  // Inactive / Normal state
  if FinalAlarmMsg = '' then
  begin
    lblAlarms.Caption := 'SISTEMA DE SEGURANÇA OPERANDO DENTRO DOS PARÂMETROS';
    lblAlarms.Color := clBlack;
    lblAlarms.Font.Color := $0039FF14;
  end;
end;

procedure TfrmTacticalHUD.btnClearWaypointsClick(Sender: TObject);
begin
  GlobalFlightPlan.ClearWaypoints;
  RefreshWaypointList;
  if Assigned(frmMap) then
    frmMap.gridMAP.RenderAndDrawControl;
  ShowMessage('Missão apagada. Waypoints de rota zerados.');
end;

procedure TfrmTacticalHUD.btnSimulationClick(Sender: TObject);
begin
  if GlobalFlightPlan.WaypointCount = 0 then
  begin
    ShowMessage('Defina pelo menos 1 waypoint no mapa antes de simular.');
    Exit;
  end;

  GlobalFlightPlan.SimulationActive := True;
  ckSimulationActive.Checked := True;
  GlobalFlightPlan.StartRoute;
  RefreshWaypointList;
  ShowMessage('Simulação de missão por waypoints inicializada.');
end;

procedure TfrmTacticalHUD.btnStartRouteClick(Sender: TObject);
begin
  if GlobalFlightPlan.WaypointCount = 0 then
  begin
    ShowMessage('Adicione waypoints clicando no mapa antes de decolar.');
    Exit;
  end;

  GlobalFlightPlan.StartRoute;
  RefreshWaypointList;
  ShowMessage('Rota programada iniciada e armada.');
end;

procedure TfrmTacticalHUD.ckAltitudeActiveChange(Sender: TObject);
begin
  GlobalFlightPlan.AltitudeActive := ckAltitudeActive.Checked;
end;

procedure TfrmTacticalHUD.ckGeofenceActiveChange(Sender: TObject);
begin
  GlobalFlightPlan.GeofenceActive := ckGeofenceActive.Checked;
end;

procedure TfrmTacticalHUD.ckSimulationActiveChange(Sender: TObject);
begin
  GlobalFlightPlan.SimulationActive := ckSimulationActive.Checked;
end;

procedure TfrmTacticalHUD.edMaxAltitudeChange(Sender: TObject);
var
  Val: Double;
begin
  if TryStrToFloat(Trim(edMaxAltitude.Text), Val) then
    GlobalFlightPlan.MaxAltitude := Val;
end;

procedure TfrmTacticalHUD.edMinAltitudeChange(Sender: TObject);
var
  Val: Double;
begin
  if TryStrToFloat(Trim(edMinAltitude.Text), Val) then
    GlobalFlightPlan.MinAltitude := Val;
end;

end.
