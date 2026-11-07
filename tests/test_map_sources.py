"""Static integration checks: map fallback and official Google Maps API."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class MapSources(unittest.TestCase):
    def test_osm_fallback_when_google_key_missing(self):
        source = (ROOT / 'src/map.pas').read_text(encoding='utf-8')
        self.assertIn("if (BaseURL = '') or (APIKey = '') then", source)
        self.assertIn("SelecionaProvedorMapa('OpenStreetMap Standard');", source)
        self.assertIn("procedure TfrmMap.CapturaImagemMapa", source)
        self.assertIn("procedure TfrmMap.DefineCameraSegueDrone", source)

    def test_google_uses_official_api(self):
        html = (ROOT / 'PHP/google_maps_simulator.html').read_text(encoding='utf-8')
        self.assertIn('maps.googleapis.com/maps/api/js', html)
        self.assertIn("if(!key)", html)
        self.assertIn("new google.maps.Map", html)


if __name__ == '__main__':
    unittest.main()
