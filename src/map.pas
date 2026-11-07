unit map;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, BCGameGrid, mvTypes, BGRABitmap, BGRABitmapTypes, Math, mvEngine,
  mvGpsObj, mvDrawingEngine, mvMapViewer, objetos, flightplan, LCLIntf, multiplayer_state;

type

  { TfrmMap }

  TfrmMap = class(TForm)
    gridMAP: TBCGameGrid;
    Label9: TLabel;
    MapView1: TMapView;


    procedure FormClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure gridMAPRenderControl(Sender: TObject; Bitmap: TBGRABitmap;
      r: TRect; n, x, y: integer);
    procedure MapView1Change(Sender: TObject);
    procedure MapView1DrawGpsPoint(Sender: TObject;
      ADrawer: TMvCustomDrawingEngine; APoint: TGpsPoint);
    procedure MapView1Resize(Sender: TObject);
    procedure MapView1ZoomChange(Sender: TObject);
    procedure MapView1ZoomChanging(Sender: TObject; NewZoom: Integer;
      var Allow: Boolean);
    procedure MapView1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure MapView1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GridMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GridMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure GridMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GridMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);

  private
    FParticipantLabels: array of TLabel;
    FMouseIni: TPoint;
    FMousePressionado: Boolean;
    FDroneCol: Integer;
    FDroneRow: Integer;
    FDroneLat: Double;
    FDroneLon: Double;
    FCameraSegueDrone: Boolean;

    FRefCol: Integer;
    FRefRow: Integer;
    FRefLat: Double;
    FRefLon: Double;

    FObjetos: TObjetosMapa;
    FArquivoObjetos: string;

    procedure AjustaCamadas;
    procedure AjustaGrid;
    procedure AtualizaStatus;
    procedure LimpaObjetosGrid;
    procedure ConfiguraMapaInicial;
    procedure ConfiguraGridOverlay;
    procedure AtualizaReferenciaNoGrid;
    procedure AtualizaDroneNoGridPorLatLon;
    procedure AtualizaReferenciaPorObjetoZero;
    procedure AtualizaObjetosNoGrid;
    function PontoTelaParaGrid(const APt: TPoint; out ACol, ARow: Integer): Boolean;
    procedure CliqueNoMapa(Shift: TShiftState; X, Y: Integer);

  public
    procedure SetParticipants(const Items: TParticipants);
    procedure CentralizaMapa(const ALatitude, ALongitude: Double);
    procedure PosicionaDroneNoGrid(ACol, ARow: Integer);
    procedure AtualizaDrone(const ALatitude, ALongitude: Double; ACol, ARow: Integer);
    procedure MostrarGrid;
    procedure OcultarGrid;
    procedure AlternaGrid;
    procedure DefineReferencia(const ALatitude, ALongitude: Double);
    procedure AtualizaPosicaoSimulada(const ALatitude, ALongitude: Double;
      const AAltitudeM, AHeadingDeg: Double; ACentralizar: Boolean = False);
    procedure SelecionaProvedorMapa(const ANome: string);
    procedure DefineCameraSegueDrone(AAtivo: Boolean);
    procedure CapturaImagemMapa(ADestino: TBitmap);
    procedure AbreGoogleMaps;

    property Objetos: TObjetosMapa read FObjetos;
  end;

var
  frmMap: TfrmMap;

implementation

{$R *.lfm}

uses
  rotavoo;

type
  { Acesso aos eventos de mouse protegidos do mapa (para repassá-los da grade). }
  TMapViewAcesso = class(TMapView);

const
  MAPA_INICIAL_ZOOM = 13;

{ TfrmMap }

procedure TfrmMap.SetParticipants(const Items: TParticipants);
var I: Integer; P: TPoint;
begin
  while Length(FParticipantLabels) > Length(Items) do
  begin
    FParticipantLabels[High(FParticipantLabels)].Free;
    SetLength(FParticipantLabels, Length(FParticipantLabels)-1);
  end;
  while Length(FParticipantLabels) < Length(Items) do
  begin
    I := Length(FParticipantLabels);
    SetLength(FParticipantLabels, I+1);
    FParticipantLabels[I] := TLabel.Create(Self);
    FParticipantLabels[I].Parent := Self;
    FParticipantLabels[I].Font.Color := clYellow;
    FParticipantLabels[I].Color := clBlack;
    FParticipantLabels[I].Transparent := False;
  end;
  for I := 0 to High(Items) do
  begin
    P := MapView1.LatLonToScreen(Items[I].Lat, Items[I].Lon);
    with FParticipantLabels[I] do
    begin
      Caption := Format('* %s (%.0f m)', [Items[I].Name, Items[I].Distance]);
      Left := MapView1.Left + P.X; Top := MapView1.Top + P.Y;
      Visible := (P.X >= 0) and (P.Y >= 0) and
        (P.X < MapView1.Width) and (P.Y < MapView1.Height);
      BringToFront;
    end;
  end;
end;

procedure TfrmMap.AtualizaReferenciaPorObjetoZero;
begin
  if Assigned(FObjetos) and (FObjetos.Count > 0) and Assigned(FObjetos[0]) then
  begin
    FRefLat := FObjetos[0].Latitude;
    FRefLon := FObjetos[0].Longitude;
  end
  else
  begin
    FRefLat := -21.0178;  // fallback Jardinópolis/SP
    FRefLon := -47.7639;
  end;
end;

procedure TfrmMap.ConfiguraMapaInicial;
begin
  if not Assigned(MapView1) then
    Exit;

  MapView1.Align := alClient;
  MapView1.SendToBack;

  MapView1.Active := False;
  MapView1.MapProvider := 'OpenStreetMap Standard';
  MapView1.MapCenter.Latitude := FRefLat;
  MapView1.MapCenter.Longitude := FRefLon;
  MapView1.Zoom := MAPA_INICIAL_ZOOM;
  MapView1.Active := True;
  MapView1.Invalidate;
end;

procedure TfrmMap.ConfiguraGridOverlay;
begin
  if not Assigned(gridMAP) then
    Exit;

  gridMAP.Align := alClient;
  gridMAP.Visible := True;
  gridMAP.BringToFront;

  gridMAP.GridWidth := 20;
  gridMAP.GridHeight := 20;

  if gridMAP.Width > 0 then
    gridMAP.BlockWidth := Max(1, gridMAP.Width div gridMAP.GridWidth)
  else
    gridMAP.BlockWidth := 32;

  if gridMAP.Height > 0 then
    gridMAP.BlockHeight := Max(1, gridMAP.Height div gridMAP.GridHeight)
  else
    gridMAP.BlockHeight := 32;

  gridMAP.OnRenderControl := @gridMAPRenderControl;
end;

function TfrmMap.PontoTelaParaGrid(const APt: TPoint; out ACol, ARow: Integer): Boolean;
begin
  Result := False;
  ACol := -1;
  ARow := -1;

  if not Assigned(gridMAP) then
    Exit;

  if (gridMAP.BlockWidth <= 0) or (gridMAP.BlockHeight <= 0) then
    Exit;

  if (APt.X < 0) or (APt.Y < 0) or (APt.X >= gridMAP.Width) or (APt.Y >= gridMAP.Height) then
    Exit;

  ACol := APt.X div gridMAP.BlockWidth;
  ARow := APt.Y div gridMAP.BlockHeight;

  if (ACol < 0) or (ACol >= gridMAP.GridWidth) then
    Exit;

  if (ARow < 0) or (ARow >= gridMAP.GridHeight) then
    Exit;

  Result := True;
end;

procedure TfrmMap.AtualizaReferenciaNoGrid;
var
  Pt: TPoint;
begin
  FRefCol := -1;
  FRefRow := -1;

  if not Assigned(MapView1) then
    Exit;

  Pt := MapView1.LatLonToScreen(FRefLat, FRefLon);

  if not PontoTelaParaGrid(Pt, FRefCol, FRefRow) then
  begin
    FRefCol := -1;
    FRefRow := -1;
  end;
end;

procedure TfrmMap.AtualizaDroneNoGridPorLatLon;
var
  Pt: TPoint;
begin
  FDroneCol := -1;
  FDroneRow := -1;

  if not Assigned(MapView1) then
    Exit;

  Pt := MapView1.LatLonToScreen(FDroneLat, FDroneLon);

  if not PontoTelaParaGrid(Pt, FDroneCol, FDroneRow) then
  begin
    FDroneCol := -1;
    FDroneRow := -1;
  end;
end;

procedure TfrmMap.AtualizaObjetosNoGrid;
begin
  AtualizaReferenciaNoGrid;
  AtualizaDroneNoGridPorLatLon;
end;

procedure TfrmMap.FormCreate(Sender: TObject);
begin
  Caption := 'Mapa';
  DoubleBuffered := True;

  FArquivoObjetos := ExtractFilePath(Application.ExeName) + 'objetos.json';

  FObjetos := TObjetosMapa.Create;
  FObjetos.CarregarArquivo(FArquivoObjetos);
  if FObjetos.Count = 0 then
    FObjetos.CriarPadrao;

  AtualizaReferenciaPorObjetoZero;

  FDroneLat := FRefLat;
  FDroneLon := FRefLon;
  FCameraSegueDrone := False;

  FDroneCol := -1;
  FDroneRow := -1;
  FRefCol := -1;
  FRefRow := -1;

  ConfiguraMapaInicial;
  ConfiguraGridOverlay;

  if Assigned(MapView1) then
  begin
    MapView1.OnChange := @MapView1Change;
    MapView1.OnResize := @MapView1Resize;
    MapView1.OnZoomChange := @MapView1ZoomChange;
    MapView1.OnZoomChanging := @MapView1ZoomChanging;
    MapView1.OnDrawGpsPoint := @MapView1DrawGpsPoint;
    MapView1.OnMouseDown := @MapView1MouseDown;
    MapView1.OnMouseUp := @MapView1MouseUp;
  end;

  // A grade fica sobre o mapa: repassa arrastar e roda do mouse ao mapa e
  // trata os cliques (rota, geocerca).
  if Assigned(gridMAP) then
  begin
    gridMAP.OnMouseDown := @GridMouseDown;
    gridMAP.OnMouseMove := @GridMouseMove;
    gridMAP.OnMouseUp := @GridMouseUp;
    gridMAP.OnMouseWheel := @GridMouseWheel;
  end;

  AjustaGrid;
  AjustaCamadas;
  AtualizaObjetosNoGrid;
  AtualizaStatus;
  gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.FormDestroy(Sender: TObject);
begin
  if Assigned(FObjetos) then
  begin
    try
      FObjetos.SalvarArquivo(FArquivoObjetos);
    except
    end;
    FreeAndNil(FObjetos);
  end;
end;

procedure TfrmMap.FormKeyPress(Sender: TObject; var Key: char);
begin
  if UpCase(Key) = 'G' then
    AlternaGrid;
end;

procedure TfrmMap.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

procedure TfrmMap.FormClick(Sender: TObject);
begin
end;

procedure TfrmMap.FormResize(Sender: TObject);
begin
  AjustaGrid;
  AjustaCamadas;
  AtualizaObjetosNoGrid;
  AtualizaStatus;
  gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.FormShow(Sender: TObject);
begin
  AtualizaReferenciaPorObjetoZero;
  AjustaGrid;
  AjustaCamadas;
  AtualizaObjetosNoGrid;
  AtualizaStatus;
  gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.AjustaCamadas;
begin
  if Assigned(MapView1) then
    MapView1.SendToBack;

  if Assigned(gridMAP) then
    gridMAP.BringToFront;

  if Assigned(Label9) then
    Label9.BringToFront;
end;

procedure TfrmMap.AjustaGrid;
begin
  if not Assigned(gridMAP) then
    Exit;

  gridMAP.Align := alClient;

  if gridMAP.GridWidth > 0 then
    gridMAP.BlockWidth := Max(1, gridMAP.Width div gridMAP.GridWidth);

  if gridMAP.GridHeight > 0 then
    gridMAP.BlockHeight := Max(1, gridMAP.Height div gridMAP.GridHeight);
end;

procedure TfrmMap.AtualizaStatus;
begin
  if not Assigned(Label9) then
    Exit;

  Label9.Caption :=
    'Objetos: ' + IntToStr(FObjetos.Count) +
    '  Ref[0]: Grid(' + IntToStr(FRefCol) + ',' + IntToStr(FRefRow) + ')' +
    '  Drone: Grid(' + IntToStr(FDroneCol) + ',' + IntToStr(FDroneRow) + ')';
end;

procedure TfrmMap.LimpaObjetosGrid;
begin
  if not Assigned(gridMAP) then
    Exit;

  try
    gridMAP.RenderAndDrawControl;
  except
  end;
end;

procedure TfrmMap.CentralizaMapa(const ALatitude, ALongitude: Double);
begin
  if not Assigned(MapView1) then
    Exit;

  MapView1.MapCenter.Latitude := ALatitude;
  MapView1.MapCenter.Longitude := ALongitude;
  MapView1.Invalidate;

  AtualizaObjetosNoGrid;
  AtualizaStatus;
  gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.PosicionaDroneNoGrid(ACol, ARow: Integer);
begin
  FDroneCol := EnsureRange(ACol, 0, gridMAP.GridWidth - 1);
  FDroneRow := EnsureRange(ARow, 0, gridMAP.GridHeight - 1);

  AtualizaStatus;
  gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.AtualizaDrone(const ALatitude, ALongitude: Double; ACol, ARow: Integer);
begin
  FDroneLat := ALatitude;
  FDroneLon := ALongitude;

  AtualizaDroneNoGridPorLatLon;
  AtualizaReferenciaNoGrid;
  AtualizaStatus;
  gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.AtualizaPosicaoSimulada(const ALatitude, ALongitude: Double;
  const AAltitudeM, AHeadingDeg: Double; ACentralizar: Boolean);
begin
  if (ALatitude < -90) or (ALatitude > 90) or
     (ALongitude < -180) or (ALongitude > 180) or
     IsNan(ALatitude) or IsNan(ALongitude) then Exit;
  FDroneLat := ALatitude;
  FDroneLon := ALongitude;
  if (ACentralizar or FCameraSegueDrone) and Assigned(MapView1) then
  begin
    MapView1.MapCenter.Latitude := ALatitude;
    MapView1.MapCenter.Longitude := ALongitude;
    MapView1.Invalidate;
  end;
  AtualizaObjetosNoGrid;
  AtualizaStatus;
  if Assigned(Label9) then
    Label9.Caption := Label9.Caption + '  Alt: ' +
      FormatFloat('0.0', AAltitudeM) + ' m  Rumo: ' +
      FormatFloat('0.0', AHeadingDeg) + '°';
  if Assigned(gridMAP) then gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.AbreGoogleMaps;
var
  BaseURL, APIKey, Lat, Lon: string;
  FS: TFormatSettings;
begin
  // Serve PHP/google_maps_simulator.html over HTTP(S), not file://.
  // Google Maps JavaScript API keys must be restricted to allowed origins.
  BaseURL := Trim(GetEnvironmentVariable('COCKPIT_GOOGLE_MAPS_URL'));
  APIKey := Trim(GetEnvironmentVariable('COCKPIT_GOOGLE_MAPS_API_KEY'));
  if (BaseURL = '') or (APIKey = '') then
  begin
    SelecionaProvedorMapa('OpenStreetMap Standard');
    Exit;
  end;
  if (Pos('https://', LowerCase(BaseURL)) <> 1) and
     (Pos('http://localhost', LowerCase(BaseURL)) <> 1) and
     (Pos('http://127.0.0.1', LowerCase(BaseURL)) <> 1) then
  begin
    SelecionaProvedorMapa('OpenStreetMap Standard');
    Exit;
  end;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Lat := FloatToStr(FDroneLat, FS);
  Lon := FloatToStr(FDroneLon, FS);
  if Pos('?', BaseURL) > 0 then BaseURL := BaseURL + '&'
  else BaseURL := BaseURL + '?';
  OpenURL(BaseURL + 'lat=' + Lat + '&lon=' + Lon +
    '&zoom=' + IntToStr(MapView1.Zoom) + '&key=' + APIKey);
end;

procedure TfrmMap.DefineCameraSegueDrone(AAtivo: Boolean);
begin
  FCameraSegueDrone := AAtivo;
  if AAtivo then CentralizaMapa(FDroneLat, FDroneLon);
end;

procedure TfrmMap.CapturaImagemMapa(ADestino: TBitmap);
begin
  if not Assigned(ADestino) then
    raise EArgumentException.Create('Bitmap de destino nao informado');
  if not Assigned(MapView1) then
    raise Exception.Create('Visualizador de mapa indisponivel');
  if (MapView1.Width <= 0) or (MapView1.Height <= 0) then
    raise Exception.Create('Mapa sem dimensoes para captura');
  // Captures the current map viewport; this is NOT an onboard camera feed.
  // Attribution and provider licensing must be preserved by the caller.
  ADestino.SetSize(MapView1.Width, MapView1.Height);
  MapView1.PaintTo(ADestino.Canvas, 0, 0);
end;

procedure TfrmMap.SelecionaProvedorMapa(const ANome: string);
begin
  if not Assigned(MapView1) then Exit;
  // Only registered providers can be selected; Google Maps requires
  // its own licensed API integration and is not a generic tile endpoint.
  if Trim(ANome) = '' then Exit;
  MapView1.Active := False;
  MapView1.MapProvider := ANome;
  MapView1.Active := True;
  MapView1.Invalidate;
end;

procedure TfrmMap.MostrarGrid;
begin
  if Assigned(gridMAP) then
    gridMAP.Visible := True;

  AjustaCamadas;
end;

procedure TfrmMap.OcultarGrid;
begin
  if Assigned(gridMAP) then
    gridMAP.Visible := False;
end;

procedure TfrmMap.AlternaGrid;
begin
  if not Assigned(gridMAP) then
    Exit;

  gridMAP.Visible := not gridMAP.Visible;

  if gridMAP.Visible then
    AjustaCamadas;
end;

procedure TfrmMap.DefineReferencia(const ALatitude, ALongitude: Double);
begin
  FRefLat := ALatitude;
  FRefLon := ALongitude;

  if Assigned(FObjetos) and (FObjetos.Count > 0) and Assigned(FObjetos[0]) then
  begin
    FObjetos[0].Latitude := ALatitude;
    FObjetos[0].Longitude := ALongitude;
  end;

  if Assigned(MapView1) then
  begin
    MapView1.MapCenter.Latitude := FRefLat;
    MapView1.MapCenter.Longitude := FRefLon;
    MapView1.Invalidate;
  end;

  AtualizaObjetosNoGrid;
  AtualizaStatus;
  gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.gridMAPRenderControl(Sender: TObject; Bitmap: TBGRABitmap;
  r: TRect; n, x, y: integer);
var
  I, Col, Row: Integer;
  Pt: TPoint;
  Obj: TObjetoMapa;
  Pts: array of TPointF;
  C0, C1, C2, C3: TGeofencePoint;
  Pt0, Pt1, Pt2, Pt3: TPoint;
  W, WPrev: TWaypoint;
begin
  if (x = 0) and (y = 0) then
  begin
    // Desenha Geofence Quadrilateral
    if GlobalFlightPlan.GeofenceActive then
    begin
      C0 := GlobalFlightPlan.GetGeofenceCorner(0);
      C1 := GlobalFlightPlan.GetGeofenceCorner(1);
      C2 := GlobalFlightPlan.GetGeofenceCorner(2);
      C3 := GlobalFlightPlan.GetGeofenceCorner(3);

      if (Abs(C0.Latitude) > 0.0001) and (Abs(C1.Latitude) > 0.0001) and
         (Abs(C2.Latitude) > 0.0001) and (Abs(C3.Latitude) > 0.0001) then
      begin
        Pt0 := MapView1.LatLonToScreen(C0.Latitude, C0.Longitude);
        Pt1 := MapView1.LatLonToScreen(C1.Latitude, C1.Longitude);
        Pt2 := MapView1.LatLonToScreen(C2.Latitude, C2.Longitude);
        Pt3 := MapView1.LatLonToScreen(C3.Latitude, C3.Longitude);

        SetLength(Pts, 4);
        Pts[0] := PointF(Pt0.X, Pt0.Y);
        Pts[1] := PointF(Pt1.X, Pt1.Y);
        Pts[2] := PointF(Pt2.X, Pt2.Y);
        Pts[3] := PointF(Pt3.X, Pt3.Y);

        Bitmap.FillPolyAntialias(Pts, BGRA(0, 255, 0, 30));
        Bitmap.DrawPolygonAntialias(Pts, BGRA(0, 255, 0, 160), 2.0);
      end;
    end;

    // Ponto de partida e trechos de ida/volta (tracejados)
    if GlobalFlightPlan.HomeValido then
    begin
      Pt2 := MapView1.LatLonToScreen(GlobalFlightPlan.HomeLat, GlobalFlightPlan.HomeLon);
      if GlobalFlightPlan.WaypointCount > 0 then
      begin
        Bitmap.PenStyle := psDash;
        W := GlobalFlightPlan.Waypoints[0];
        Pt0 := MapView1.LatLonToScreen(W.Latitude, W.Longitude);
        Bitmap.DrawLineAntialias(Pt2.X, Pt2.Y, Pt0.X, Pt0.Y, BGRA(0, 160, 255, 150), 2.0);
        if GlobalFlightPlan.AcaoFinal = afVoltarPartida then
        begin
          W := GlobalFlightPlan.Waypoints[GlobalFlightPlan.WaypointCount - 1];
          Pt0 := MapView1.LatLonToScreen(W.Latitude, W.Longitude);
          Bitmap.DrawLineAntialias(Pt0.X, Pt0.Y, Pt2.X, Pt2.Y, BGRA(80, 80, 80, 170), 2.0);
        end;
        Bitmap.PenStyle := psSolid;
      end;
      Bitmap.FillRectAntialias(Pt2.X - 9, Pt2.Y - 9, Pt2.X + 9, Pt2.Y + 9, BGRA(0, 0, 0, 170));
      Bitmap.RectangleAntialias(Pt2.X - 9, Pt2.Y - 9, Pt2.X + 9, Pt2.Y + 9, BGRA(255, 255, 255, 230), 1.5);
      Bitmap.FontHeight := 14;
      Bitmap.FontStyle := [fsBold];
      Bitmap.TextOut(Pt2.X, Pt2.Y - 8, 'H', BGRA(255, 255, 255, 255), taCenter);
    end;

    // Desenha Rotas e Linhas de Waypoint
    if GlobalFlightPlan.WaypointCount > 0 then
    begin
      Bitmap.FontHeight := 13;
      Bitmap.FontStyle := [fsBold];
      for I := 0 to GlobalFlightPlan.WaypointCount - 1 do
      begin
        W := GlobalFlightPlan.Waypoints[I];
        Pt0 := MapView1.LatLonToScreen(W.Latitude, W.Longitude);

        if I > 0 then
        begin
          WPrev := GlobalFlightPlan.Waypoints[I - 1];
          Pt1 := MapView1.LatLonToScreen(WPrev.Latitude, WPrev.Longitude);
          Bitmap.DrawLineAntialias(Pt1.X, Pt1.Y, Pt0.X, Pt0.Y, BGRA(0, 160, 255, 180), 3.0);
        end;

        if W.Status = 'ACTIVE' then
        begin
          Bitmap.EllipseAntialias(Pt0.X, Pt0.Y, 10, 10, BGRA(255, 165, 0, 255), 2.0);
          Bitmap.FillEllipseAntialias(Pt0.X, Pt0.Y, 5, 5, BGRA(255, 165, 0, 200));
        end
        else if W.Status = 'COMPLETED' then
        begin
          Bitmap.EllipseAntialias(Pt0.X, Pt0.Y, 8, 8, BGRA(0, 255, 0, 255), 2.0);
          Bitmap.FillEllipseAntialias(Pt0.X, Pt0.Y, 4, 4, BGRA(0, 255, 0, 180));
        end
        else
        begin
          Bitmap.EllipseAntialias(Pt0.X, Pt0.Y, 8, 8, BGRA(0, 160, 255, 255), 2.0);
          Bitmap.FillEllipseAntialias(Pt0.X, Pt0.Y, 4, 4, BGRA(0, 160, 255, 180));
        end;
        // Número do ponto (etiqueta escura, legível sobre qualquer fundo)
        Bitmap.FillRoundRectAntialias(Pt0.X + 8, Pt0.Y - 22, Pt0.X + 12 + Bitmap.TextSize(IntToStr(I + 1)).cx,
          Pt0.Y - 6, 4, 4, BGRA(0, 40, 90, 210));
        Bitmap.TextOut(Pt0.X + 10, Pt0.Y - 22, IntToStr(I + 1), BGRA(255, 255, 255, 255));
      end;
    end;
  end;

  if Assigned(FObjetos) and Assigned(MapView1) then
  begin
    for I := 0 to FObjetos.Count - 1 do
    begin
      Obj := FObjetos[I];
      if not Assigned(Obj) then
        Continue;
      if not Obj.Visivel then
        Continue;

      Pt := MapView1.LatLonToScreen(Obj.Latitude, Obj.Longitude);

      if PontoTelaParaGrid(Pt, Col, Row) then
      begin
        if (x = Col) and (y = Row) then
        begin
          if I = 0 then
          begin
            Bitmap.FillEllipseAntialias(
              (r.Left + r.Right) / 2,
              (r.Top + r.Bottom) / 2,
              (r.Right - r.Left) / 4,
              (r.Bottom - r.Top) / 4,
              BGRA(0, 0, 255, 220)
            );
          end
          else
          begin
            Bitmap.FillEllipseAntialias(
              (r.Left + r.Right) / 2,
              (r.Top + r.Bottom) / 2,
              (r.Right - r.Left) / 5,
              (r.Bottom - r.Top) / 5,
              BGRA(0, 180, 0, 220)
            );
          end;
        end;
      end;
    end;
  end;

  if (x = FDroneCol) and (y = FDroneRow) then
  begin
    Bitmap.FillEllipseAntialias(
      (r.Left + r.Right) / 2,
      (r.Top + r.Bottom) / 2,
      (r.Right - r.Left) / 6,
      (r.Bottom - r.Top) / 6,
      BGRA(255, 0, 0, 220)
    );
  end;
end;

procedure TfrmMap.MapView1Change(Sender: TObject);
begin
  AtualizaObjetosNoGrid;
  AtualizaStatus;
  gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.MapView1DrawGpsPoint(Sender: TObject;
  ADrawer: TMvCustomDrawingEngine; APoint: TGpsPoint);
begin
end;

procedure TfrmMap.MapView1Resize(Sender: TObject);
begin
  AjustaGrid;
  AtualizaObjetosNoGrid;
  AtualizaStatus;
  gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.MapView1ZoomChange(Sender: TObject);
begin
  AtualizaObjetosNoGrid;
  AtualizaStatus;
  gridMAP.RenderAndDrawControl;
end;

procedure TfrmMap.MapView1ZoomChanging(Sender: TObject; NewZoom: Integer;
  var Allow: Boolean);
begin
  Allow := True;
end;

procedure TfrmMap.MapView1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FMouseIni := Point(X, Y);
  FMousePressionado := True;
end;

procedure TfrmMap.MapView1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  // Clique sem arrastar: trata como clique no mapa.
  if FMousePressionado and (Button = mbLeft) and
    (Abs(X - FMouseIni.X) <= 4) and (Abs(Y - FMouseIni.Y) <= 4) then
    CliqueNoMapa(Shift, X, Y);
  FMousePressionado := False;
end;

procedure TfrmMap.GridMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FMouseIni := Point(X, Y);
  FMousePressionado := True;
  if Assigned(MapView1) then
    TMapViewAcesso(MapView1).MouseDown(Button, Shift, X, Y);
end;

procedure TfrmMap.GridMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(MapView1) then
    TMapViewAcesso(MapView1).MouseMove(Shift, X, Y);
end;

procedure TfrmMap.GridMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(MapView1) then
    TMapViewAcesso(MapView1).MouseUp(Button, Shift, X, Y);
  if FMousePressionado and (Button = mbLeft) and
    (Abs(X - FMouseIni.X) <= 4) and (Abs(Y - FMouseIni.Y) <= 4) then
    CliqueNoMapa(Shift, X, Y);
  FMousePressionado := False;
end;

procedure TfrmMap.GridMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if Assigned(MapView1) then
    Handled := TMapViewAcesso(MapView1).DoMouseWheel(Shift, WheelDelta, MousePos);
end;

procedure TfrmMap.CliqueNoMapa(Shift: TShiftState; X, Y: Integer);
var
  LatLon: TRealPoint;
  I: Integer;
  Motivo: string;
begin
  if not Assigned(MapView1) then
    Exit;

  LatLon := MapView1.ScreenToLatLon(Point(X, Y));

  if ssAlt in Shift then
  begin
    // Alt+clique: define o próximo canto da geocerca.
    I := 0;
    while (I < 4) and (Abs(GlobalFlightPlan.GetGeofenceCorner(I).Latitude) > 0.0001) do
      Inc(I);
    if I = 4 then
      I := 0;
    GlobalFlightPlan.SetGeofenceCorner(I, LatLon.Lat, LatLon.Lon);
    gridMAP.RenderAndDrawControl;
    ShowMessage(Format('Canto %d da geocerca definido em %.6f, %.6f',
      [I + 1, LatLon.Lat, LatLon.Lon]));
  end
  else if (ssCtrl in Shift) or
    (Assigned(frmRotaVoo) and frmRotaVoo.Visible and frmRotaVoo.ModoAdicionar) then
  begin
    // Ctrl+clique ou modo "adicionar pelo mapa": novo ponto da rota.
    if not RotaDisponivel(Motivo) then
    begin
      ShowMessage(Motivo);
      Exit;
    end;
    if not (Assigned(frmRotaVoo) and frmRotaVoo.Visible) then
      AbreRotaVoo;
    if Assigned(frmRotaVoo) then
      frmRotaVoo.AdicionaPonto(LatLon.Lat, LatLon.Lon);
  end;
end;

end.
