"""Tests for keyboard navigation, drone flight controls, language tab and configuration tabs."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class KeyboardMappingTest(unittest.TestCase):
    def test_i18n_has_teclado_and_language_in_all_languages(self):
        source = (ROOT / "src/cockpit_i18n.pas").read_text(encoding="utf-8")
        self.assertIn("'Teclado'", source)
        self.assertIn("'Keyboard'", source)
        self.assertIn("'Clavier'", source)
        self.assertIn("'Tastatur'", source)
        self.assertIn("'キーボード'", source)
        self.assertIn("'Language'", source)
        self.assertIn("'Idioma'", source)

    def test_config_has_keyboard_tab(self):
        source = (ROOT / "src/config.pas").read_text(encoding="utf-8")
        self.assertIn("tsTeclado: TTabSheet;", source)
        self.assertIn("sgTeclado: TStringGrid;", source)
        self.assertIn("procedure CriaAbaTeclado;", source)
        self.assertIn("tsTeclado.Caption := 'Teclado';", source)
        self.assertIn("tsTeclado.TabVisible := True;", source)
        self.assertIn("EdTesteTecladoKeyDown", source)

    def test_config_has_language_tab_with_pt_br_default(self):
        source = (ROOT / "src/config.pas").read_text(encoding="utf-8")
        self.assertIn("tsIdioma: TTabSheet;", source)
        self.assertIn("procedure CriaAbaIdioma;", source)
        self.assertIn("tsIdioma.Caption := 'Language';", source)
        self.assertIn("tsIdioma.TabVisible := True;", source)
        self.assertIn("cbIdioma.ItemIndex := 0;", source)
        self.assertIn("'pt-BR'", source)

    def test_config_table_has_all_pilot_commands(self):
        source = (ROOT / "src/config.pas").read_text(encoding="utf-8")
        commands = [
            "Frente (Pitch +)",
            "Trás (Pitch -)",
            "Esquerda (Roll -)",
            "Direita (Roll +)",
            "Subir (Acelerador +)",
            "Descer (Acelerador -)",
            "Girar Esquerda (Guinada -)",
            "Girar Direita (Guinada +)",
            "Decolar / Armar",
            "Pousar / Desarmar",
            "Pairar / Centralizar",
            "Manobra Especial / Flip",
            "PÂNICO / Corte Imediato",
            "Iniciar / Parar Conexão",
            "Alternar HUD Tático",
            "Alternar Janela Câmera",
            "Alternar Janela Mapa",
            "Alternar Janela GPS",
        ]
        for cmd in commands:
            self.assertIn(cmd, source, f"Missing command: {cmd}")

    def test_main_key_handlers_wired(self):
        pas_source = (ROOT / "src/main.pas").read_text(encoding="utf-8")
        lfm_source = (ROOT / "src/main.lfm").read_text(encoding="utf-8")

        self.assertIn("OnKeyDown := @FormKeyDown;", pas_source)
        self.assertIn("OnKeyUp := @FormKeyUp;", pas_source)
        self.assertIn("KeyPreview := True;", pas_source)

        self.assertIn("OnKeyDown = FormKeyDown", lfm_source)
        self.assertIn("OnKeyUp = FormKeyUp", lfm_source)

    def test_main_handles_flight_keys_and_releases(self):
        source = (ROOT / "src/main.pas").read_text(encoding="utf-8")

        # Pitch & Roll
        self.assertIn("VK_UP, VK_W:", source)
        self.assertIn("VK_DOWN, VK_S:", source)
        self.assertIn("VK_LEFT, VK_A:", source)
        self.assertIn("VK_RIGHT, VK_D:", source)

        # Throttle / Altitude
        self.assertIn("VK_E, VK_PRIOR:", source)
        self.assertIn("VK_Q, VK_NEXT:", source)

        # Yaw (Guinada / Botões 1 e 2)
        self.assertIn("VK_1, VK_NUMPAD1, VK_Z:", source)
        self.assertIn("VK_2, VK_NUMPAD2, VK_X:", source)

        # Action Buttons (Decolar, Pousar, Hover, Flip)
        self.assertIn("VK_3, VK_NUMPAD3, VK_INSERT:", source)
        self.assertIn("VK_4, VK_NUMPAD4, VK_DELETE:", source)
        self.assertIn("VK_5, VK_NUMPAD5:", source)
        self.assertIn("VK_6, VK_NUMPAD6, VK_F:", source)

        # Panic & Reset
        self.assertIn("VK_SPACE:", source)
        self.assertIn("VK_R, VK_HOME:", source)

        # Shortcuts (Camera, Map, GPS, HUD, Start/Stop)
        self.assertIn("VK_RETURN:", source)
        self.assertIn("VK_C:", source)
        self.assertIn("VK_M:", source)
        self.assertIn("VK_G:", source)
        self.assertIn("VK_T:", source)

        # KeyUp must release all buttons and directions
        keyup_block = source.split("procedure TfrmMain.FormKeyUp", 1)[-1].split("end;", 1)[0]
        self.assertIn("FKeyUp := False;", keyup_block)
        self.assertIn("FKeyDown := False;", keyup_block)
        self.assertIn("FKeyLeft := False;", keyup_block)
        self.assertIn("FKeyRight := False;", keyup_block)
        self.assertIn("FKeyZUp := False;", keyup_block)
        self.assertIn("FKeyZDown := False;", keyup_block)
        self.assertIn("FKeyB1 := False;", keyup_block)
        self.assertIn("FKeyB2 := False;", keyup_block)
        self.assertIn("FKeyB3 := False;", keyup_block)
        self.assertIn("FKeyB4 := False;", keyup_block)
        self.assertIn("FKeyB5 := False;", keyup_block)
        self.assertIn("FKeyB6 := False;", keyup_block)

    def test_focus_loss_clears_keyboard_and_throttle(self):
        source = (ROOT / "src/main.pas").read_text(encoding="utf-8")
        deact_block = source.split("procedure TfrmMain.FormDeactivate", 1)[-1].split("end;", 1)[0]
        self.assertIn("LimpaTeclado;", deact_block)
        self.assertIn("CentralizaComandos;", deact_block)
        self.assertIn("Z := 128;", deact_block)

if __name__ == "__main__":
    unittest.main()
