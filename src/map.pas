unit map;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, BCGameGrid, mvTypes, BGRABitmap, BGRABitmapTypes, Math, mvEngine,
  mvGpsObj, mvDrawingEngine, mvMapViewer, objetos;

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

  private
    FDroneCol: Integer;
    FDroneRow: Integer;
    FDroneLat: Double;
    FDroneLon: Double;

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

  public
    procedure CentralizaMapa(const ALatitude, ALongitude: Double);
    procedure PosicionaDroneNoGrid(ACol, ARow: Integer);
    procedure AtualizaDrone(const ALatitude, ALongitude: Double; ACol, ARow: Integer);
    procedure MostrarGrid;
    procedure OcultarGrid;
    procedure AlternaGrid;
    procedure DefineReferencia(const ALatitude, ALongitude: Double);

    property Objetos: TObjetosMapa read FObjetos;
  end;

var
  frmMap: TfrmMap;

implementation

{$R *.lfm}

const
  MAPA_INICIAL_ZOOM = 13;

{ TfrmMap }

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
begin
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

end.
