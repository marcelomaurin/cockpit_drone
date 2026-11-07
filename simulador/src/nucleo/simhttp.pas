unit simhttp;

{ Cliente HTTP(S) do simulador: TFPHTTPClient com prazos padronizados.

  Limitação conhecida: o TFPHTTPClient do Free Pascal 3.2.2 não abre túnel
  (CONNECT) para HTTPS através de proxy. Em rede que exige proxy, os mapas e
  o mundo compartilhado não funcionam até essa versão do cliente ser trocada. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, opensslsockets;

function NovoClienteHttp(ATimeoutMs: Integer): TFPHTTPClient;

implementation

function NovoClienteHttp(ATimeoutMs: Integer): TFPHTTPClient;
begin
  Result := TFPHTTPClient.Create(nil);
  Result.IOTimeout := ATimeoutMs;
  Result.ConnectTimeout := ATimeoutMs;
  Result.KeepConnection := False;
end;

end.
