program simulator_cheerson_bridge;

{$mode objfpc}{$H+}

uses
  SysUtils, Sockets, BaseUnix, Unix, fpjson, jsonparser, Math,
  simulator_vehicle_core, simulator_protocol_bridge;

var
  RX, TX: cint;
  BindAddr, DestAddr: TInetSockAddr;
  Buffer: array[0..4095] of Byte;
  N: ssize_t;
  Vehicle: TSimulatorVehicle;
  Bridge: TSimulatorProtocolBridge;
  Incoming: TJSONData;
  Obj: TJSONObject;
  Command, StateJSON: string;
  LastTick, NowTick, Dt: Double;
  ReadSet: TFDSet;
  WaitTime: TTimeVal;
  FormatUS: TFormatSettings;

function TimeSeconds: Double;
begin
  Result := GetTickCount64 / 1000.0;
end;

function NumberOrZero(AObj: TJSONObject; const AKey: string): Double;
var V: TJSONData;
begin
  V := AObj.Find(AKey);
  if (V = nil) or (V.JSONType <> jtNumber) then
    raise Exception.Create('Missing control: ' + AKey);
  Result := V.AsFloat;
end;

begin
  RX := fpSocket(AF_INET, SOCK_DGRAM, 0);
  TX := fpSocket(AF_INET, SOCK_DGRAM, 0);
  if (RX < 0) or (TX < 0) then Halt(1);
  FillChar(BindAddr, SizeOf(BindAddr), 0);
  BindAddr.sin_family := AF_INET;
  BindAddr.sin_port := htons(14563);
  BindAddr.sin_addr.s_addr := htonl($7F000001);
  if fpBind(RX, @BindAddr, SizeOf(BindAddr)) <> 0 then Halt(2);
  FillChar(DestAddr, SizeOf(DestAddr), 0);
  DestAddr.sin_family := AF_INET;
  DestAddr.sin_port := htons(14562);
  DestAddr.sin_addr.s_addr := htonl($7F000001);
  Vehicle := TSimulatorVehicle.Create(vkMultirotor, -21.17, -47.81, 0);
  Bridge := TSimulatorProtocolBridge.Create(Vehicle, 0.5);
  FormatUS := DefaultFormatSettings;
  FormatUS.DecimalSeparator := '.';
  try
    LastTick := TimeSeconds;
    while True do
    begin
      // Nonblocking receive with select, keeping physics running at ~50 Hz.
      // Socket remains local-only and never sends commands to hardware.
      fpFD_ZERO(ReadSet);
      fpFD_SET(RX, ReadSet);
      WaitTime.tv_sec := 0;
      WaitTime.tv_usec := 20000;
      if fpSelect(RX + 1, @ReadSet, nil, nil, @WaitTime) > 0 then
      begin
        N := fpRecv(RX, @Buffer[0], SizeOf(Buffer), 0);
        if N > 0 then
        begin
          SetString(Command, PChar(@Buffer[0]), N);
          try
            Incoming := GetJSON(Command);
            try
              if Incoming.JSONType = jtObject then
              begin
                Obj := TJSONObject(Incoming);
                Command := Format(
                  '{"throttle":%.6f,"turn":%.6f,"climb":%.6f,"brake":0,"roll":%.6f,"pitch":%.6f}',
                  [NumberOrZero(Obj, 'throttle'), NumberOrZero(Obj, 'yaw'),
                   Max(0, (NumberOrZero(Obj, 'throttle') - 0.45) / 0.55),
                   NumberOrZero(Obj, 'roll'), NumberOrZero(Obj, 'pitch')],
                  DefaultFormatSettings);
                Bridge.ApplyCommand(Command);
              end;
            finally
              Incoming.Free;
            end;
          except
            on E: Exception do WriteLn(StdErr, 'Ignored command: ', E.Message);
          end;
        end;
      end;
      NowTick := TimeSeconds;
      Dt := NowTick - LastTick;
      LastTick := NowTick;
      if Dt > 0.1 then Dt := 0.1;
      Bridge.Step(Dt);
      StateJSON := Bridge.TelemetryJSON;
      fpSendTo(TX, @StateJSON[1], Length(StateJSON), 0,
        @DestAddr, SizeOf(DestAddr));
    end;
  finally
    Bridge.Free;
    Vehicle.Free;
    fpClose(TX);
    fpClose(RX);
  end;
end.
