program simulador;

{ Simulador Cockpit Drone: segundo executável do projeto cockpit_drone.
  Finge ser o equipamento real (mesmos protocolos), voa sobre imagem de
  satélite (Google) ou mapa do OpenStreetMap e entra no mundo compartilhado.
  Documentação: ../docs/ }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Forms, simprincipal;

{$R *.res}

begin
  RequireDerivedFormResource := False;
  Application.Title := 'Simulador Cockpit Drone';
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TFrmPrincipal, FrmPrincipal);
  Application.Run;
end.
