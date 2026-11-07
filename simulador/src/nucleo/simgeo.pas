unit simgeo;

{ Conversões geográficas do simulador.

  - Projeção Web Mercator (a mesma dos blocos do Google e do OpenStreetMap):
    latitude/longitude <-> coordenadas de bloco (x, y, z) e pixel global.
  - Plano local em metros a partir do ponto de partida: x = leste, y = norte.
    Para alguns quilômetros a aproximação plana é suficiente.
  - Distância pela fórmula de haversine (a mesma usada pelo servidor). }

{$mode objfpc}{$H+}

interface

uses
  Math;

const
  RAIO_TERRA_M = 6371000.0;
  METROS_POR_GRAU_LAT = 111320.0;
  TAMANHO_BLOCO = 256;
  ZOOM_MIN = 3;
  ZOOM_MAX = 19;

type
  TPontoGeo = record
    Lat, Lon: Double;
  end;

{ Pixel global (zoom Z) de uma latitude/longitude. }
procedure GeoParaPixel(ALat, ALon: Double; AZoom: Integer; out APx, APy: Double);
{ Latitude/longitude de um pixel global (zoom Z). }
procedure PixelParaGeo(APx, APy: Double; AZoom: Integer; out ALat, ALon: Double);
{ Deslocamento local (metros) a partir da origem -> latitude/longitude. }
procedure LocalParaGeo(const AOrigem: TPontoGeo; AX, AY: Double; out ALat, ALon: Double);
{ Latitude/longitude -> deslocamento local (metros) a partir da origem. }
procedure GeoParaLocal(const AOrigem: TPontoGeo; ALat, ALon: Double; out AX, AY: Double);
{ Distância em metros entre dois pontos (haversine). }
function DistanciaM(ALat1, ALon1, ALat2, ALon2: Double): Double;
{ Metros representados por um pixel no zoom Z, na latitude dada. }
function MetrosPorPixel(ALat: Double; AZoom: Integer): Double;
{ Zoom cujo pixel mede aproximadamente AMetros na latitude dada. }
function ZoomParaMetros(ALat, AMetros: Double; AZoomMax: Integer): Integer;
{ Ângulo em graus normalizado para 0..360. }
function NormalizaGraus(AGraus: Double): Double;

implementation

procedure GeoParaPixel(ALat, ALon: Double; AZoom: Integer; out APx, APy: Double);
var
  N, S: Double;
begin
  N := TAMANHO_BLOCO * Power(2, AZoom);
  ALat := EnsureRange(ALat, -85.05112878, 85.05112878);
  S := Sin(DegToRad(ALat));
  APx := (ALon + 180) / 360 * N;
  APy := (0.5 - Ln((1 + S) / (1 - S)) / (4 * Pi)) * N;
end;

procedure PixelParaGeo(APx, APy: Double; AZoom: Integer; out ALat, ALon: Double);
var
  N, Y: Double;
begin
  N := TAMANHO_BLOCO * Power(2, AZoom);
  ALon := APx / N * 360 - 180;
  Y := 0.5 - APy / N;
  ALat := 90 - 360 * ArcTan(Exp(-Y * 2 * Pi)) / Pi;
end;

procedure LocalParaGeo(const AOrigem: TPontoGeo; AX, AY: Double; out ALat, ALon: Double);
begin
  ALat := AOrigem.Lat + AY / METROS_POR_GRAU_LAT;
  ALon := AOrigem.Lon + AX / (METROS_POR_GRAU_LAT * Cos(DegToRad(AOrigem.Lat)));
end;

procedure GeoParaLocal(const AOrigem: TPontoGeo; ALat, ALon: Double; out AX, AY: Double);
begin
  AY := (ALat - AOrigem.Lat) * METROS_POR_GRAU_LAT;
  AX := (ALon - AOrigem.Lon) * METROS_POR_GRAU_LAT * Cos(DegToRad(AOrigem.Lat));
end;

function DistanciaM(ALat1, ALon1, ALat2, ALon2: Double): Double;
var
  F1, F2, DF, DL, A: Double;
begin
  F1 := DegToRad(ALat1);
  F2 := DegToRad(ALat2);
  DF := F2 - F1;
  DL := DegToRad(ALon2 - ALon1);
  A := Sqr(Sin(DF / 2)) + Cos(F1) * Cos(F2) * Sqr(Sin(DL / 2));
  Result := 2 * RAIO_TERRA_M * ArcSin(Min(1, Sqrt(A)));
end;

function MetrosPorPixel(ALat: Double; AZoom: Integer): Double;
begin
  Result := 156543.03392 * Cos(DegToRad(ALat)) / Power(2, AZoom);
end;

function ZoomParaMetros(ALat, AMetros: Double; AZoomMax: Integer): Integer;
var
  Z: Double;
begin
  if AMetros <= 0 then
    Exit(AZoomMax);
  Z := Log2(156543.03392 * Cos(DegToRad(ALat)) / AMetros);
  Result := EnsureRange(Floor(Z + 0.5), ZOOM_MIN, AZoomMax);
end;

function NormalizaGraus(AGraus: Double): Double;
begin
  Result := AGraus - 360 * Floor(AGraus / 360);
end;

end.
