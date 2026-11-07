unit simfisica;

{ Física simplificada de multirrotor (passo fixo, chamado a 50 Hz).

  Não simula hélice por hélice: o comando vira ângulo-alvo e empuxo, a atitude
  segue o alvo com resposta de primeira ordem (ConstanteRespostaS) e a
  aceleração sai do empuxo inclinado menos gravidade e arrasto:

    a_horizontal = T * sen(ângulo) - k * (v - v_vento)
    a_vertical   = T * cos(rolagem) * cos(arfagem) - g - k_z * v_z

  T = g * empuxo / EMPUXO_PAIRAR (empuxo 0,5 sustenta o drone parado).
  k é escolhido para que, no ângulo máximo, a velocidade final seja VelMaxMS.

  Contato com o chão: toque acima de 2 m/s conta como queda (motores param). }

{$mode objfpc}{$H+}

interface

uses
  Math, simtipos, simgeo;

const
  VELOCIDADE_QUEDA_MS = 2.0;

type

  { TSimFisica }

  TSimFisica = class
  private
    FParam: TParametrosModelo;
    FEstado: TEstadoVoo;
    FOrigem: TPontoGeo;
    FKArrasto: Double;
    procedure AlvoPorVelocidade(AVxDes, AVyDes: Double; out ARol, AArf: Double);
  public
    constructor Create(const AParam: TParametrosModelo; const AOrigem: TPontoGeo);
    procedure Reinicia(const AOrigem: TPontoGeo);
    procedure Passo(ADt: Double; const ACmd: TComandoVoo; const AFalhas: TFalhas);
    procedure DefineBateria(APct: Double);
    property Estado: TEstadoVoo read FEstado;
    property Param: TParametrosModelo read FParam;
    property Origem: TPontoGeo read FOrigem;
  end;

implementation

constructor TSimFisica.Create(const AParam: TParametrosModelo; const AOrigem: TPontoGeo);
begin
  inherited Create;
  FParam := AParam;
  if FParam.VelMaxMS <= 0 then
    FParam.VelMaxMS := 5;
  if FParam.ConstanteRespostaS <= 0.01 then
    FParam.ConstanteRespostaS := 0.2;
  FKArrasto := GRAVIDADE * Tan(DegToRad(EnsureRange(FParam.AnguloMaxGraus, 5, 60))) /
    FParam.VelMaxMS;
  Reinicia(AOrigem);
end;

procedure TSimFisica.Reinicia(const AOrigem: TPontoGeo);
begin
  FOrigem := AOrigem;
  FillChar(FEstado, SizeOf(FEstado), 0);
  FEstado.NoChao := True;
  FEstado.Bateria := 100;
  FEstado.Lat := AOrigem.Lat;
  FEstado.Lon := AOrigem.Lon;
end;

procedure TSimFisica.DefineBateria(APct: Double);
begin
  FEstado.Bateria := EnsureRange(APct, 0, 100);
end;

procedure TSimFisica.AlvoPorVelocidade(AVxDes, AVyDes: Double; out ARol, AArf: Double);
var
  Ex, Ey, EFrente, EDireita, Psi, AngMax, Kv: Double;
begin
  // Erro de velocidade no mundo -> corpo -> ângulo necessário.
  Ex := AVxDes - FEstado.VX;
  Ey := AVyDes - FEstado.VY;
  Psi := DegToRad(FEstado.Rumo);
  EFrente := Ex * Sin(Psi) + Ey * Cos(Psi);
  EDireita := Ex * Cos(Psi) - Ey * Sin(Psi);
  AngMax := DegToRad(FParam.AnguloMaxGraus);
  Kv := 1.5;
  // Parte que mantém a velocidade contra o arrasto + parte que corrige o erro.
  AArf := ArcTan((FKArrasto * (AVxDes * Sin(Psi) + AVyDes * Cos(Psi)) + Kv * EFrente) / GRAVIDADE);
  ARol := ArcTan((FKArrasto * (AVxDes * Cos(Psi) - AVyDes * Sin(Psi)) + Kv * EDireita) / GRAVIDADE);
  AArf := EnsureRange(AArf, -AngMax, AngMax);
  ARol := EnsureRange(ARol, -AngMax, AngMax);
end;

procedure TSimFisica.Passo(ADt: Double; const ACmd: TComandoVoo; const AFalhas: TFalhas);
var
  RolAlvo, ArfAlvo, Psi, Vf, Vr, VxDes, VyDes, Dx, Dy, Dist, Vel: Double;
  Rol, Arf, Empuxo, VzDes, T, Ax, Ay, Az, Af, Ar, Alfa: Double;
  VentoX, VentoY, VentoRad, DifRumo, TaxaGuinada: Double;
  Motores: Boolean;
begin
  if ADt <= 0 then
    Exit;
  Motores := ACmd.Motores and not FEstado.Caiu and (FEstado.Bateria > 0);
  Alfa := Min(1, ADt / FParam.ConstanteRespostaS);
  Psi := DegToRad(FEstado.Rumo);

  // ---- Ângulo-alvo ----
  RolAlvo := 0;
  ArfAlvo := 0;
  case ACmd.ModoH of
    mhAngulo:
      begin
        RolAlvo := EnsureRange(ACmd.Rolagem, -1, 1) * DegToRad(FParam.AnguloMaxGraus);
        ArfAlvo := EnsureRange(ACmd.Arfagem, -1, 1) * DegToRad(FParam.AnguloMaxGraus);
      end;
    mhVelocidade:
      begin
        Vf := EnsureRange(ACmd.Arfagem, -1, 1) * FParam.VelMaxMS;
        Vr := EnsureRange(ACmd.Rolagem, -1, 1) * FParam.VelMaxMS;
        VxDes := Vf * Sin(Psi) + Vr * Cos(Psi);
        VyDes := Vf * Cos(Psi) - Vr * Sin(Psi);
        AlvoPorVelocidade(VxDes, VyDes, RolAlvo, ArfAlvo);
      end;
    mhIrPara:
      begin
        Dx := ACmd.AlvoX - FEstado.X;
        Dy := ACmd.AlvoY - FEstado.Y;
        Dist := Hypot(Dx, Dy);
        Vel := Min(Min(ACmd.VelAlvo, FParam.VelMaxMS), Dist * 0.8);
        if Dist > 0.01 then
        begin
          VxDes := Dx / Dist * Vel;
          VyDes := Dy / Dist * Vel;
        end
        else
        begin
          VxDes := 0;
          VyDes := 0;
        end;
        AlvoPorVelocidade(VxDes, VyDes, RolAlvo, ArfAlvo);
      end;
  end;
  if FEstado.NoChao then
  begin
    RolAlvo := 0;
    ArfAlvo := 0;
  end;
  Rol := DegToRad(FEstado.Rolagem) + (RolAlvo - DegToRad(FEstado.Rolagem)) * Alfa;
  Arf := DegToRad(FEstado.Arfagem) + (ArfAlvo - DegToRad(FEstado.Arfagem)) * Alfa;

  // ---- Rumo ----
  if Motores and not FEstado.NoChao then
  begin
    TaxaGuinada := EnsureRange(ACmd.Guinada, -1, 1) * FParam.GuinadaMaxGrausS;
    if not IsNan(ACmd.RumoAlvo) then
    begin
      DifRumo := NormalizaGraus(ACmd.RumoAlvo - FEstado.Rumo + 180) - 180;
      TaxaGuinada := EnsureRange(DifRumo * 2, -FParam.GuinadaMaxGrausS, FParam.GuinadaMaxGrausS);
    end;
    FEstado.Rumo := NormalizaGraus(FEstado.Rumo + TaxaGuinada * ADt);
  end;

  // ---- Empuxo ----
  Empuxo := 0;
  if Motores then
    case ACmd.ModoV of
      mvEmpuxo:
        Empuxo := EnsureRange(ACmd.Vertical, 0, 1);
      mvSubida, mvAltura:
        begin
          if ACmd.ModoV = mvSubida then
            VzDes := EnsureRange(ACmd.Vertical, -1, 1) * FParam.SubidaMaxMS
          else
            VzDes := EnsureRange((ACmd.Vertical - FEstado.Z) * 1.2,
              -FParam.SubidaMaxMS, FParam.SubidaMaxMS);
          Empuxo := EMPUXO_PAIRAR * (1 + 0.6 * (VzDes - FEstado.VZ)) /
            Max(0.3, Cos(Rol) * Cos(Arf));
          Empuxo := EnsureRange(Empuxo, 0, 1);
          // No chão, sem pedido de subida, não sai do lugar.
          if FEstado.NoChao and (VzDes <= 0) then
            Empuxo := Min(Empuxo, EMPUXO_PAIRAR * 0.9);
        end;
    end;
  // Bateria no fim: o empuxo cai.
  if FEstado.Bateria < 5 then
    Empuxo := Empuxo * FEstado.Bateria / 5;
  FEstado.Empuxo := Empuxo;

  // ---- Acelerações ----
  VentoRad := DegToRad(AFalhas.VentoRumoGraus + 180); // o vento sopra PARA este rumo
  VentoX := AFalhas.VentoMS * Sin(VentoRad);
  VentoY := AFalhas.VentoMS * Cos(VentoRad);
  T := GRAVIDADE * Empuxo / EMPUXO_PAIRAR;
  Af := T * Sin(Arf);
  Ar := T * Sin(Rol);
  Ax := Af * Sin(Psi) + Ar * Cos(Psi) - FKArrasto * (FEstado.VX - VentoX);
  Ay := Af * Cos(Psi) - Ar * Sin(Psi) - FKArrasto * (FEstado.VY - VentoY);
  Az := T * Cos(Rol) * Cos(Arf) - GRAVIDADE - 0.5 * FEstado.VZ;

  if FEstado.NoChao and (Az <= 0) then
  begin
    // Apoiado: sem deriva nem afundamento.
    FEstado.VX := 0;
    FEstado.VY := 0;
    FEstado.VZ := 0;
    Rol := 0;
    Arf := 0;
  end
  else
  begin
    FEstado.NoChao := False;
    FEstado.VX := FEstado.VX + Ax * ADt;
    FEstado.VY := FEstado.VY + Ay * ADt;
    FEstado.VZ := FEstado.VZ + Az * ADt;
    FEstado.X := FEstado.X + FEstado.VX * ADt;
    FEstado.Y := FEstado.Y + FEstado.VY * ADt;
    FEstado.Z := FEstado.Z + FEstado.VZ * ADt;
    if FEstado.Z <= 0 then
    begin
      if FEstado.VZ < -VELOCIDADE_QUEDA_MS then
        FEstado.Caiu := True;
      FEstado.Z := 0;
      FEstado.VZ := 0;
      FEstado.VX := 0;
      FEstado.VY := 0;
      FEstado.NoChao := True;
    end;
  end;
  FEstado.Rolagem := RadToDeg(Rol);
  FEstado.Arfagem := RadToDeg(Arf);
  FEstado.Motores := Motores;

  // ---- Bateria e tempo ----
  if Motores then
  begin
    FEstado.Bateria := Max(0, FEstado.Bateria -
      100 * ADt * Max(0.2, Empuxo / EMPUXO_PAIRAR) / Max(1, FParam.AutonomiaMin * 60));
    if not FEstado.NoChao then
      FEstado.TempoVooS := FEstado.TempoVooS + ADt;
  end;

  LocalParaGeo(FOrigem, FEstado.X, FEstado.Y, FEstado.Lat, FEstado.Lon);
  FEstado.DistPartida := Hypot(FEstado.X, FEstado.Y);
  FEstado.SinalPerdido := AFalhas.PerdaSinal or
    ((FParam.AlcanceRadioM > 0) and (Hypot(FEstado.DistPartida, FEstado.Z) > FParam.AlcanceRadioM));
end;

end.
