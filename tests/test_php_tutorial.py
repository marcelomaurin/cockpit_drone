"""Tests for PHP tutorial, download links, language menu and simulator guide."""
import pathlib
import unittest
import json
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]

class PhpTutorialTest(unittest.TestCase):
    def test_home_html_has_github_download_and_joystick_note(self):
        content = (ROOT / "PHP/home.html").read_text(encoding="utf-8")
        self.assertIn("https://github.com/marcelomaurin/cockpit_drone/tree/master/bin", content)
        self.assertIn("tutorial.php", content)
        self.assertIn("joystick", content.lower())
        self.assertIn("teclado", content.lower())
        self.assertIn('id="download"', content)

    def test_home_html_has_language_menu(self):
        content = (ROOT / "PHP/home.html").read_text(encoding="utf-8")
        self.assertIn('id="lang-select"', content)
        self.assertIn('value="pt-BR" selected', content)
        self.assertIn('value="en"', content)
        self.assertIn('value="ja"', content)
        self.assertIn('value="ar"', content)
        self.assertIn('i18n.js', content)

    def test_index_php_routes_tutorial_and_i18n(self):
        content = (ROOT / "PHP/index.php").read_text(encoding="utf-8")
        self.assertIn("tutorial.php", content)
        self.assertIn("$route === 'tutorial'", content)
        self.assertIn("i18n.js", content)

    def test_i18n_js_covers_all_ten_languages(self):
        i18n_path = ROOT / "PHP/i18n.js"
        self.assertTrue(i18n_path.exists())
        content = i18n_path.read_text(encoding="utf-8")
        match = re.search(r"var\s+translations\s*=\s*", content)
        self.assertIsNotNone(match)
        translations, _ = json.JSONDecoder().raw_decode(content[match.end():])
        for lang in ("pt-BR", "en", "es", "fr", "de", "ru", "zh-CN", "ja", "ar", "hi"):
            self.assertIn(lang, translations, f"Language {lang} missing from i18n.js")
            self.assertTrue(translations[lang])

    def test_tutorial_php_exists_and_covers_requirements(self):
        tutorial_path = ROOT / "PHP/tutorial.php"
        self.assertTrue(tutorial_path.exists(), "PHP/tutorial.php does not exist")
        content = tutorial_path.read_text(encoding="utf-8")

        # Must have language picker
        self.assertIn('id="lang-select"', content)
        self.assertIn('i18n.js', content)

        # Must guide user on where to download
        self.assertIn("https://github.com/marcelomaurin/cockpit_drone/tree/master/bin", content)
        self.assertIn("setup_cockpit_drone_0.41.exe", content)

        # Must teach usage of simulator and cockpit
        self.assertIn("simulador.exe", content)
        self.assertIn("drone.exe", content)

        # Must explain joystick is best, though keyboard is supported
        content_lower = content.lower()
        self.assertIn("joystick", content_lower)
        self.assertIn("teclado", content_lower)
        self.assertIn("melhor rodado com um joystick", content_lower)

        # Must include keyboard map
        self.assertIn("Pitch", content)
        self.assertIn("Roll", content)
        self.assertIn("Throttle", content)
        self.assertIn("Yaw", content)
        self.assertIn("PÂNICO", content)

    def test_htaccess_routes_tutorial(self):
        content = (ROOT / "PHP/.htaccess").read_text(encoding="utf-8")
        self.assertIn("tutorial", content)

if __name__ == "__main__":
    unittest.main()
