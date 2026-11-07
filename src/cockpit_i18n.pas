unit cockpit_i18n;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, IniFiles;
procedure AplicarIdioma(AForm: TCustomForm);
function IdiomaAtual: string;
implementation
const
  Idiomas: array[0..9] of string = ('pt-BR','en','es','fr','de','ru','zh-CN','ja','ar','hi');
  // Chaves estaveis em portugues. Campos tecnicos, nomes de marcas e protocolos nao sao traduzidos.
  Chaves: array[0..18] of string = ('Configuração','Configurações','Câmera','Mapa','Equipamento','Conexão','Conectar','Desconectar','Sair','Salvar','Cancelar','Idioma / Language','Visualização da Câmera','OFFLINE','Iniciar reconhecimento (pessoas/poses)','Parar reconhecimento','Teclado','Language','Idioma');
  Valores: array[0..9,0..18] of string = (
    ('Configuração','Configurações','Câmera','Mapa','Equipamento','Conexão','Conectar','Desconectar','Sair','Salvar','Cancelar','Idioma / Language','Visualização da Câmera','OFFLINE','Iniciar reconhecimento (pessoas/poses)','Parar reconhecimento','Teclado','Idioma','Idioma'),
    ('Configuration','Settings','Camera','Map','Equipment','Connection','Connect','Disconnect','Exit','Save','Cancel','Language','Camera view','OFFLINE','Start recognition (people/poses)','Stop recognition','Keyboard','Language','Language'),
    ('Configuración','Configuraciones','Cámara','Mapa','Equipo','Conexión','Conectar','Desconectar','Salir','Guardar','Cancelar','Idioma','Vista de cámara','SIN CONEXIÓN','Iniciar reconhecimento (personas/poses)','Detener reconocimiento','Teclado','Idioma','Idioma'),
    ('Configuration','Paramètres','Caméra','Carte','Équipement','Connexion','Connecter','Déconnecter','Quitter','Enregistrer','Annuler','Langue','Vue caméra','HORS LIGNE','Démarrer reconnaissance (personnes/poses)','Arrêter reconnaissance','Clavier','Langue','Langue'),
    ('Konfiguration','Einstellungen','Kamera','Karte','Gerät','Verbindung','Verbinden','Trennen','Beenden','Speichern','Abbrechen','Sprache','Kameraansicht','OFFLINE','Erkennung starten (Personen/Posen)','Erkennung stoppen','Tastatur','Sprache','Sprache'),
    ('Конфигурация','Настройки','Камера','Карта','Оборудование','Подключение','Подключить','Отключить','Выход','Сохранить','Отмена','Язык','Вид камеры','НЕ В СЕТИ','Начать распознавание (люди/позы)','Остановить распознавание','Клавиатура','Язык','Язык'),
    ('配置','设置','摄像头','地图','设备','连接','连接','断开连接','退出','保存','取消','语言','摄像头画面','离线','开始识别（人物/姿态）','停止识别','键盘','语言','语言'),
    ('設定','環境設定','カメラ','地図','機器','接続','接続する','切断する','終了','保存','キャンセル','言語','カメラ画面','オフライン','認識開始（人物/ポーズ）','認識停止','キーボード','言語','言語'),
    ('التهيئة','الإعدادات','الكاميرا','الخريطة','المعدات','الاتصال','اتصال','قطع الاتصال','خروج','حفظ','إلغاء','اللغة','عرض الكاميرا','غير متصل','بدء التعرف (الأشخاص/الوضعيات)','إيقاف التعرف','لوحة المفاتيح','اللغة','اللغة'),
    ('कॉन्फ़िगरेशन','सेटिंग्स','कैमरा','मानचित्र','उपकरण','कनेक्शन','कनेक्ट करें','डिस्कनेक्ट करें','बाहर जाएँ','सहेजें','रद्द करें','भाषा','कैमरा दृश्य','ऑफ़लाइन','पहचान शुरू करें (व्यक्ति/पोज़)','पहचान बंद करें','कीबोर्ड','भाषा','भाषा')
  );
var
  Originais: TStringList;

function IdiomaAtual: string;
var I: TIniFile;
begin
  Result := 'pt-BR';
  I := TIniFile.Create(GetAppConfigDir(False) + 'cockpit_ui.ini');
  try Result := I.ReadString('interface','language','pt-BR'); finally I.Free end;
end;

function Traduzir(const Texto: string; Indice: Integer): string;
var I: Integer;
begin
  Result := Texto;
  for I := Low(Chaves) to High(Chaves) do
    if SameText(Texto, Chaves[I]) then Exit(Valores[Indice,I]);
end;

procedure AplicarIdioma(AForm: TCustomForm);
var
  Lang, Key, Base: string;
  Index, I, J: Integer;
  C: TComponent;
begin
  if AForm = nil then Exit;
  Lang := IdiomaAtual;
  Index := 0;
  for I := Low(Idiomas) to High(Idiomas) do
    if SameText(Lang, Idiomas[I]) then Index := I;
  if Originais = nil then Originais := TStringList.Create;
  for I := -1 to AForm.ComponentCount - 1 do
  begin
    if I < 0 then C := AForm else C := AForm.Components[I];
    if not (C is TControl) then Continue;
    Key := IntToHex(PtrUInt(C), SizeOf(Pointer)*2);
    J := Originais.IndexOfName(Key);
    if J < 0 then
    begin
      if C is TCustomForm then Base := TCustomForm(C).Caption
      else if C is TLabel then Base := TLabel(C).Caption
      else if C is TButton then Base := TButton(C).Caption
      else if C is TCheckBox then Base := TCheckBox(C).Caption
      else if C is TTabSheet then Base := TTabSheet(C).Caption
      else Continue;
      Originais.Values[Key] := Base;
    end
    else Base := Originais.ValueFromIndex[J];
    if C is TCustomForm then TCustomForm(C).Caption := Traduzir(Base,Index)
    else if C is TLabel then TLabel(C).Caption := Traduzir(Base,Index)
    else if C is TButton then TButton(C).Caption := Traduzir(Base,Index)
    else if C is TCheckBox then TCheckBox(C).Caption := Traduzir(Base,Index)
    else if C is TTabSheet then TTabSheet(C).Caption := Traduzir(Base,Index);
  end;
end;
finalization
  Originais.Free;
end.
