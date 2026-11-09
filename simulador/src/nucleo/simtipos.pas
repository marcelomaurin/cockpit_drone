unit simtipos;

{ Tipos comuns do simulador: comando de voo (o que o emulador de protocolo
  pede à física), estado do voo (o que a física devolve), parâmetros de cada
  modelo de equipamento e falhas injetáveis. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser;

type
  { Como a física interpreta os eixos horizontais do comando. }
  TModoHorizontal = (
    mhAngulo,      // Rolagem/Arfagem = fração do ângulo máximo (-1..1)
    mhVelocidade,  // Rolagem/Arfagem = fração da velocidade máxima, no corpo
    mhIrPara);     // voa até AlvoX/AlvoY (metros locais) a VelAlvo m/s

  { Como a física interpreta o eixo vertical do comando. }
  TModoVertical = (
    mvEmpuxo,      // Vertical = empuxo 0..1 (sem altura automática)
    mvSubida,      // Vertical = fração da subida máxima (-1..1); 0 = mantém
    mvAltura);     // Vertical = altura alvo em metros

  TComandoVoo = record
    Motores: Boolean;
    ModoH: TModoHorizontal;
    ModoV: TModoVertical;
    Rolagem, Arfagem: Double;   // + direita / + frente
    Guinada: Double;            // -1..1 da taxa máxima (+ horário)
    Vertical: Double;
    AlvoX, AlvoY, VelAlvo: Double;
    RumoAlvo: Double;           // graus; NaN = não controla o rumo
  end;

  TEstadoVoo = record
    X, Y, Z: Double;            // metros: leste, norte, altura
    VX, VY, VZ: Double;         // m/s
    Rolagem, Arfagem: Double;   // graus (+ direita / + nariz para baixo = frente)
    Rumo: Double;               // graus 0..360 (0 = norte)
    Empuxo: Double;             // 0..1
    Motores: Boolean;
    NoChao: Boolean;
    Caiu: Boolean;
    Bateria: Double;            // %
    TempoVooS: Double;
    Lat, Lon: Double;
    DistPartida: Double;        // m
    SinalPerdido: Boolean;      // fora do alcance ou falha injetada
  end;

  TParametrosModelo = record
    Chave: string;
    Nome: string;
    Protocolo: string;
    Classe:string;
    MassaKg: Double;
    VelMaxMS: Double;
    SubidaMaxMS: Double;
    AnguloMaxGraus: Double;
    GuinadaMaxGrausS: Double;
    ConstanteRespostaS: Double;
    AutonomiaMin: Double;
    AlcanceRadioM: Double;
    AlturaDecolagemM: Double;
    TemGPS: Boolean;
    CameraLargura, CameraAltura: Integer;
    CampoVisaoGraus: Double;
    InclinacaoCameraGraus: Double;   // 0 = horizonte; 90 = para baixo
  end;
  TListaModelos = array of TParametrosModelo;

  TFalhas = record
    SinalInfinito: Boolean;         // treinamento: ignora alcance e perda simulada
    PerdaSinal: Boolean;
    PerdaGPS: Boolean;
    VentoMS: Double;
    VentoRumoGraus: Double;          // de onde o vento vem
    AtrasoMs: Integer;
  end;

const
  EMPUXO_PAIRAR = 0.5;
  GRAVIDADE = 9.80665;

function ComandoNeutro: TComandoVoo;
function ModelosPadrao: TListaModelos;
{ Lê config/equipamentos.json; chaves ausentes ficam com o valor padrão. }
function CarregaModelos(const AArquivo: string): TListaModelos;
function IndiceModelo(const AModelos: TListaModelos; const AChave: string): Integer;

implementation

function ComandoNeutro: TComandoVoo;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Motores := False;
  Result.ModoH := mhVelocidade;
  Result.ModoV := mvSubida;
  Result.RumoAlvo := NaN;
end;

function Modelo(const AChave, ANome, AProto: string; AMassa, AVel, ASubida, AAng,
  AGuinada, ATau, AAut, AAlc, ADecol: Double; AGps: Boolean; ACamL, ACamA: Integer;
  AFov, AIncl: Double): TParametrosModelo;
begin
  Result.Chave := AChave;
  Result.Nome := ANome;
  Result.Protocolo := AProto;
  Result.MassaKg := AMassa;
  Result.VelMaxMS := AVel;
  Result.SubidaMaxMS := ASubida;
  Result.AnguloMaxGraus := AAng;
  Result.GuinadaMaxGrausS := AGuinada;
  Result.ConstanteRespostaS := ATau;
  Result.AutonomiaMin := AAut;
  Result.AlcanceRadioM := AAlc;
  Result.AlturaDecolagemM := ADecol;
  Result.TemGPS := AGps;
  Result.CameraLargura := ACamL;
  Result.CameraAltura := ACamA;
  Result.CampoVisaoGraus := AFov;
  Result.InclinacaoCameraGraus := AIncl;
end;

function ModelosPadrao: TListaModelos;
begin
  // Valores iniciais: ajustar pela ficha técnica e voando o equipamento real.
  SetLength(Result, 14);
  Result[0] := Modelo('tello', 'DJI/Ryze Tello', 'tello', 0.087, 8, 2, 25, 100,
    0.25, 13, 100, 1.0, False, 960, 720, 82.6, 0);
  Result[1] := Modelo('ardrone', 'Parrot AR.Drone 2.0', 'ardrone', 0.42, 5, 0.7, 12,
    100, 0.30, 12, 50, 0.8, False, 640, 360, 92, 0);
  Result[2] := Modelo('mavlink', 'MAVLink (ArduCopter)', 'mavlink', 1.5, 12, 2.5, 30,
    90, 0.30, 18, 2000, 0, True, 1280, 720, 80, 20);
  Result[3] := Modelo('cx10w', 'Cheerson CX-10W', 'fq777', 0.016, 3, 1, 30, 180,
    0.15, 4, 30, 0, False, 720, 576, 70, 0);
  Result[4] := Modelo('fq777', 'FQ777-954', 'fq777', 0.025, 3, 1, 30, 180,
    0.15, 5, 30, 0, False, 720, 576, 70, 0);
  Result[5] := Modelo('esp32', 'Drone ESP32 (firmware Cockpit)', 'cdp', 0.08, 5, 1.5,
    25, 150, 0.20, 6, 80, 0, False, 640, 480, 70, 0);
  Result[6] := Modelo('espdrone', 'ESP-Drone / OpenDrone', 'espdrone', 0.035, 4, 1.2,
    20, 150, 0.20, 5, 50, 0, False, 640, 480, 70, 0);
  Result[7] := Modelo('wifi8k','WIFI_8K (experimental)','wifi8k',0.08,4,1.5,25,120,0.25,7,50,1,False,640,360,75,0);
  Result[7].Classe:='drone';
  Result[8] := Modelo('rc_drone','RC generico - drone','rcserial',0.8,8,2,25,120,0.25,15,500,1,False,640,360,75,0);
  Result[8].Classe:='drone';
  Result[9]:=Result[8];Result[9].Chave:='rc_helicopter';Result[9].Nome:='RC generico - helicoptero';Result[9].Classe:='helicopter';
  Result[10]:=Result[8];Result[10].Chave:='rc_airplane';Result[10].Nome:='RC generico - aviao';Result[10].Classe:='airplane';Result[10].VelMaxMS:=25;
  Result[11]:=Result[8];Result[11].Chave:='rc_car';Result[11].Nome:='RC generico - carro';Result[11].Classe:='car';Result[11].VelMaxMS:=10;
  Result[12]:=Result[8];Result[12].Chave:='rc_boat';Result[12].Nome:='RC generico - barco';Result[12].Classe:='boat';Result[12].VelMaxMS:=6;
  Result[13]:=Result[8];Result[13].Chave:='rc_submarine';Result[13].Nome:='RC generico - submarino';Result[13].Classe:='submarine';Result[13].VelMaxMS:=3;

end;

function CarregaModelos(const AArquivo: string): TListaModelos;
var
  Dados: TJSONData;
  Obj, M, Cam: TJSONObject;
  Lista: TStringList;
  I, J: Integer;
  Txt: TStringList;
  P: TParametrosModelo;

  function F(AObj: TJSONObject; const ANome: string; APadrao: Double): Double;
  begin
    Result := AObj.Get(ANome, APadrao);
  end;

begin
  Result := ModelosPadrao;
  if not FileExists(AArquivo) then
    Exit;
  Txt := TStringList.Create;
  try
    Txt.LoadFromFile(AArquivo);
    try
      Dados := GetJSON(Txt.Text);
    except
      Exit; // arquivo inválido: fica com os padrões
    end;
  finally
    Txt.Free;
  end;
  try
    if not (Dados is TJSONObject) then
      Exit;
    Obj := TJSONObject(Dados);
    Lista := TStringList.Create;
    try
      for I := 0 to Obj.Count - 1 do
      begin
        if not (Obj.Items[I] is TJSONObject) then
          Continue;
        M := TJSONObject(Obj.Items[I]);
        J := IndiceModelo(Result, Obj.Names[I]);
        if J < 0 then
        begin
          P := Result[0];
          P.Chave := Obj.Names[I];
          SetLength(Result, Length(Result) + 1);
          J := High(Result);
        end
        else
          P := Result[J];
        P.Nome := M.Get('nome', P.Nome);
        P.Protocolo := M.Get('protocolo', P.Protocolo);
      P.Classe := M.Get('classe', P.Classe);
        P.MassaKg := F(M, 'massa_kg', P.MassaKg);
        P.VelMaxMS := F(M, 'vel_max_ms', P.VelMaxMS);
        P.SubidaMaxMS := F(M, 'subida_max_ms', P.SubidaMaxMS);
        P.AnguloMaxGraus := F(M, 'angulo_max_graus', P.AnguloMaxGraus);
        P.GuinadaMaxGrausS := F(M, 'guinada_max_graus_s', P.GuinadaMaxGrausS);
        P.ConstanteRespostaS := F(M, 'constante_resposta_s', P.ConstanteRespostaS);
        P.AutonomiaMin := F(M, 'autonomia_min', P.AutonomiaMin);
        P.AlcanceRadioM := F(M, 'alcance_radio_m', P.AlcanceRadioM);
        P.AlturaDecolagemM := F(M, 'altura_decolagem_m', P.AlturaDecolagemM);
        P.TemGPS := M.Get('gps', P.TemGPS);
        if M.Find('camera') is TJSONObject then
        begin
          Cam := TJSONObject(M.Find('camera'));
          P.CameraLargura := Cam.Get('largura', P.CameraLargura);
          P.CameraAltura := Cam.Get('altura', P.CameraAltura);
          P.CampoVisaoGraus := F(Cam, 'campo_visao_graus', P.CampoVisaoGraus);
          P.InclinacaoCameraGraus := F(Cam, 'inclinacao_graus', P.InclinacaoCameraGraus);
        end;
        Result[J] := P;
      end;
    finally
      Lista.Free;
    end;
  finally
    Dados.Free;
  end;
end;

function IndiceModelo(const AModelos: TListaModelos; const AChave: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AModelos) do
    if SameText(AModelos[I].Chave, AChave) then
      Exit(I);
  Result := -1;
end;

end.
