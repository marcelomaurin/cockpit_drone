unit protocols;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  { Índices de Configuração > Protocolo (cbProtocol). }
  PROTOCOLO_CX10W = 0;
  PROTOCOLO_MAVLINK = 1;
  PROTOCOLO_TELLO = 2;
  PROTOCOLO_OPENDRONE = 3;
  PROTOCOLO_FQ777 = 4;
  PROTOCOLO_ARDRONE = 5;
  PROTOCOLO_ESP32DRONE = 6;

{ Nome do drone/protocolo para mensagens. }
function NomeProtocolo(AIndice: Integer): string;
{ True só para drones com GPS e navegação autônoma por pontos (rota de voo).
  Hoje: MAVLink (ArduPilot/PX4). Os demais não têm GPS; o AR.Drone 2.0 só tem
  com o acessório Flight Recorder, cujo protocolo de rota não é público. }
function ProtocoloTemGPS(AIndice: Integer): Boolean;

implementation

function NomeProtocolo(AIndice: Integer): string;
begin
  case AIndice of
    PROTOCOLO_CX10W: Result := 'Cheerson CX-10W';
    PROTOCOLO_MAVLINK: Result := 'MAVLink (ArduPilot/PX4)';
    PROTOCOLO_TELLO: Result := 'DJI Tello';
    PROTOCOLO_OPENDRONE: Result := 'ESP-Drone / OpenDrone';
    PROTOCOLO_FQ777: Result := 'FQ777-954';
    PROTOCOLO_ARDRONE: Result := 'Parrot AR.Drone 2.0';
    PROTOCOLO_ESP32DRONE: Result := 'Drone ESP32 (firmware Cockpit)';
  else
    Result := 'protocolo ' + IntToStr(AIndice);
  end;
end;

function ProtocoloTemGPS(AIndice: Integer): Boolean;
begin
  Result := AIndice = PROTOCOLO_MAVLINK;
end;

end.
