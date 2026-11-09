program test_tls_runtime;
{$mode objfpc}{$H+}
uses SysUtils, Classes, fphttpclient, ssockets, sslsockets, openssl, opensslsockets;
type THTTPProbe=class(TFPHTTPClient)
  public property AfterSocketHandlerCreate;
end;
TProbe=class
  CertificateSeen:Boolean;
  procedure Created(Sender:TObject; Handler:TSocketHandler);
  procedure Verify(Sender:TObject; var Allow:Boolean);
end;
procedure TProbe.Created(Sender:TObject; Handler:TSocketHandler);
begin if Handler is TOpenSSLSocketHandler then
  TOpenSSLSocketHandler(Handler).OnVerifyCertificate:=@Verify; end;
procedure TProbe.Verify(Sender:TObject; var Allow:Boolean);
begin CertificateSeen:=Assigned(TOpenSSLSocketHandler(Sender).SSL.PeerCertificate);
  Allow:=CertificateSeen; end;
var HTTP:THTTPProbe; Probe:TProbe; Body:string;
begin
  if not InitSSLInterface then raise Exception.Create('TLS runtime did not load');
  WriteLn('TLS version: ',OpenSSLGetVersion(0));
  if Pos('OpenSSL 3.5.9',OpenSSLGetVersion(0))<>1 then raise Exception.Create('Wrong TLS runtime');
  Probe:=TProbe.Create; HTTP:=THTTPProbe.Create(nil);
  try HTTP.AfterSocketHandlerCreate:=@Probe.Created;
    HTTP.ConnectTimeout:=6000; HTTP.IOTimeout:=6000;
    Body:=HTTP.Get('https://www.python.org/');
    if not Probe.CertificateSeen then raise Exception.Create('Peer certificate API missing');
    if Pos('Python',Body)=0 then raise Exception.Create('TLS response invalid');
    WriteLn('PASS private OpenSSL 3.5.9 HTTPS request and peer certificate retrieval');
  finally HTTP.Free; Probe.Free; end;
end.
