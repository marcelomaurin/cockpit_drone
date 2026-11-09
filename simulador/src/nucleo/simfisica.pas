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
    procedure PassoVeiculo(ADt:Double;const C:TComandoVoo;const F:TFalhas);
    procedure AlvoPorVelocidade(AVxDes, AVyDes: Double; out ARol, AArf: Double);
  public
    constructor Create(const AParam: TParametrosModelo; const AOrigem: TPontoGeo);
    procedure Reinicia(const AOrigem: TPontoGeo);
    procedure Passo(ADt: Double; const ACmd: TComandoVoo; const AFalhas: TFalhas);
    procedure RecuperaQueda;
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
  if FParam.Classe='submarine' then begin FEstado.Z:=-1;FEstado.NoChao:=False;end;
  FEstado.Lat := AOrigem.Lat;
  FEstado.Lon := AOrigem.Lon;
end;

procedure TSimFisica.RecuperaQueda;
var E:TEstadoVoo;
begin
  E:=FEstado;
  Reinicia(FOrigem);
  FEstado.X:=E.X; FEstado.Y:=E.Y; FEstado.Rumo:=E.Rumo;
  LocalParaGeo(FOrigem,E.X,E.Y,FEstado.Lat,FEstado.Lon);
  FEstado.DistPartida:=Hypot(E.X,E.Y);
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

procedure TSimFisica.PassoVeiculo(ADt:Double;const C:TComandoVoo;const F:TFalhas);
var Powered:Boolean;A,Speed,Target,Turn,Psi,Thrust,Drag,Alpha,Lift,Air,Stall,Pitch,Roll,WX,WY:Double;
begin
 Powered:=C.Motores and not FEstado.Caiu and (FEstado.Bateria>0);
 Psi:=DegToRad(FEstado.Rumo);Thrust:=0;if Powered then Thrust:=EnsureRange(C.Vertical,-1.0,1.0);
 WX:=F.VentoMS*Sin(DegToRad(F.VentoRumoGraus+180));WY:=F.VentoMS*Cos(DegToRad(F.VentoRumoGraus+180));
 if FParam.Classe='airplane' then begin
  Speed:=Hypot(FEstado.VX,FEstado.VY);Air:=Max(0,Hypot(FEstado.VX-WX,FEstado.VY-WY));
  Alpha:=Min(1,ADt/Max(0.1,FParam.ConstanteRespostaS));
  Pitch:=DegToRad(FEstado.Arfagem)+(EnsureRange(C.Arfagem,-1.0,1.0)*DegToRad(18)-DegToRad(FEstado.Arfagem))*Alpha;
  Roll:=DegToRad(FEstado.Rolagem)+(EnsureRange(C.Rolagem,-1.0,1.0)*DegToRad(45)-DegToRad(FEstado.Rolagem))*Alpha;
  if FEstado.NoChao then Roll:=0;
  Turn:=C.Guinada*30;if not FEstado.NoChao then Turn:=Turn+RadToDeg(GRAVIDADE*Tan(Roll)/Max(4,Air));
  FEstado.Rumo:=NormalizaGraus(FEstado.Rumo+Turn*ADt);Psi:=DegToRad(FEstado.Rumo);
  Drag:=8/Max(25,Sqr(FParam.VelMaxMS))*Speed*Speed;
  if FEstado.NoChao then Drag:=Drag+0.5;
  Speed:=EnsureRange(Speed+(Max(0,Thrust)*8-Drag-GRAVIDADE*Sin(-Pitch))*ADt,0.0,FParam.VelMaxMS*1.4);
  FEstado.VX:=Speed*Sin(Psi);FEstado.VY:=Speed*Cos(Psi);
  Stall:=Max(6,FParam.VelMaxMS*0.42);A:=-Pitch-ArcTan2(FEstado.VZ,Max(1,Air));
  Lift:=GRAVIDADE*Sqr(Air/Stall)*EnsureRange(0.6+4*A,-0.3,1.8);
  if Abs(A)>DegToRad(22) then Lift:=Lift*0.35;
  FEstado.VZ:=FEstado.VZ+(Lift*Cos(Roll)-GRAVIDADE-0.12*FEstado.VZ)*ADt;
  FEstado.Z:=FEstado.Z+FEstado.VZ*ADt;
  if FEstado.Z<=0 then begin
   if FEstado.VZ< -4 then FEstado.Caiu:=True;
   FEstado.Z:=0;FEstado.VZ:=0;FEstado.NoChao:=True;
  end else FEstado.NoChao:=False;
  FEstado.Rolagem:=RadToDeg(Roll);FEstado.Arfagem:=RadToDeg(Pitch);
 end else if FParam.Classe='submarine' then begin
  Alpha:=Min(1,ADt/1.2);Target:=0;if Powered then Target:=C.Guinada*FParam.GuinadaMaxGrausS;
  FEstado.Rumo:=NormalizaGraus(FEstado.Rumo+Target*ADt);Psi:=DegToRad(FEstado.Rumo);
  Target:=0;Speed:=0;if Powered then begin Target:=C.Arfagem*FParam.VelMaxMS;Speed:=C.Rolagem*FParam.VelMaxMS;end;
  FEstado.VX:=FEstado.VX+((Target*Sin(Psi)+Speed*Cos(Psi)+WX*0.03)-FEstado.VX)*Alpha;
  FEstado.VY:=FEstado.VY+((Target*Cos(Psi)-Speed*Sin(Psi)+WY*0.03)-FEstado.VY)*Alpha;
  FEstado.VZ:=FEstado.VZ+(Thrust*FParam.SubidaMaxMS-FEstado.VZ)*Alpha;
  FEstado.Z:=EnsureRange(FEstado.Z+FEstado.VZ*ADt,-30.0,0.0);
  if (FEstado.Z=0) or (FEstado.Z= -30) then FEstado.VZ:=0;
  FEstado.NoChao:=False;FEstado.Rolagem:=0;FEstado.Arfagem:=0;
 end else begin
  Speed:=FEstado.VX*Sin(Psi)+FEstado.VY*Cos(Psi);
  if FParam.Classe='boat' then A:=2.0 else A:=0.45;
  Speed:=Speed+(Thrust*FParam.VelMaxMS-Speed)*Min(1,ADt/A);
  Turn:=EnsureRange(C.Rolagem,-1.0,1.0)*65*Speed/Max(1,FParam.VelMaxMS);
  FEstado.Rumo:=NormalizaGraus(FEstado.Rumo+Turn*ADt);Psi:=DegToRad(FEstado.Rumo);
  FEstado.VX:=Speed*Sin(Psi);FEstado.VY:=Speed*Cos(Psi);
  if FParam.Classe='boat' then begin FEstado.VX:=FEstado.VX+WX*0.03;FEstado.VY:=FEstado.VY+WY*0.03;end;
  FEstado.Z:=0;FEstado.VZ:=0;FEstado.NoChao:=True;FEstado.Rolagem:=0;FEstado.Arfagem:=0;
 end;
 FEstado.X:=FEstado.X+FEstado.VX*ADt;FEstado.Y:=FEstado.Y+FEstado.VY*ADt;
 FEstado.Motores:=Powered;FEstado.Empuxo:=Abs(Thrust);
 if Powered then begin FEstado.Bateria:=Max(0,FEstado.Bateria-100*ADt*Max(0.2,Abs(Thrust))/Max(1,FParam.AutonomiaMin*60));
  FEstado.TempoVooS:=FEstado.TempoVooS+ADt;end;
 LocalParaGeo(FOrigem,FEstado.X,FEstado.Y,FEstado.Lat,FEstado.Lon);FEstado.DistPartida:=Hypot(FEstado.X,FEstado.Y);
 FEstado.SinalPerdido:=not F.SinalInfinito and (F.PerdaSinal or ((FParam.AlcanceRadioM>0) and
  (Hypot(FEstado.DistPartida,FEstado.Z)>FParam.AlcanceRadioM)));
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
  if (FParam.Classe='car') or (FParam.Classe='boat') or (FParam.Classe='submarine') or (FParam.Classe='airplane') then begin
    PassoVeiculo(ADt,ACmd,AFalhas);Exit;end;
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
  FEstado.SinalPerdido := not AFalhas.SinalInfinito and
    (AFalhas.PerdaSinal or ((FParam.AlcanceRadioM > 0) and
    (Hypot(FEstado.DistPartida, FEstado.Z) > FParam.AlcanceRadioM)));
end;

end.
