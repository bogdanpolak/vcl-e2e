"""
Scenariusze testowe End-to-End dla aplikacji Delphi VCL w Pythonie.
Kompatybilne zarówno ze standardowym modułem `unittest`, jak i runnerem `pytest`.
"""

import os
import sys
from pathlib import Path
import time
import unittest

_pkg_dir = str(Path(__file__).resolve().parent)
if _pkg_dir not in sys.path:
    sys.path.insert(0, _pkg_dir)

try:
    from vcl_client import VclClient
except ImportError:
    from python.vcl_client import VclClient




class TestVclE2E(unittest.TestCase):
    """Zestaw testów automatycznych E2E weryfikujących zachowanie aplikacji VCL."""

    @classmethod
    def setUpClass(cls):
        cls.client = VclClient(host="127.0.0.1", port=8080)

    def test_01_health_check(self):
        """Scenariusz 1: Handshake i weryfikacja dostępności aplikacji VCL."""
        data = self.client.health()
        self.assertEqual(data.get("status"), "ok")
        self.assertIn("DemoApp", data.get("app", ""))
        self.assertGreaterEqual(data.get("formsCount", 0), 1)
        print(f"  [OK] Health check: app='{data.get('app')}', forms={data.get('formsCount')}")

    def test_02_component_tree_inspection(self):
        """Scenariusz 2: Pobranie i inspekcja hierarchii kontrolek na formatce."""
        tree = self.client.tree()
        forms = tree.get("forms", [])
        self.assertGreaterEqual(len(forms), 1)

        main_form = forms[0]
        self.assertEqual(main_form.get("name"), "frmMain")
        self.assertEqual(main_form.get("class"), "TfrmMain")

        control_names = [ctrl["name"] for ctrl in main_form.get("controls", []) if "name" in ctrl]
        self.assertIn("sbToggleBold", control_names)
        self.assertIn("StatusBar1", control_names)
        self.assertIn("DBGrid1", control_names)
        self.assertIn("edtItemName", control_names)
        self.assertIn("btnAddItem", control_names)
        print(f"  [OK] Tree inspection: {len(control_names)} controls on form '{main_form.get('name')}'")

    def test_03_speed_button_toggle(self):
        """Scenariusz 3: Test kontrolki bezuchwytowej TSpeedButton (TGraphicControl)."""
        # Krok 1: Włączenie pogrubienia
        self.client.click("sbToggleBold")
        ctrl_info = self.client.control("sbToggleBold")
        self.assertTrue(ctrl_info.get("down"))
        self.assertEqual(self.client.get_text("StatusBar1", panel=2), "Bold: ON")

        # Krok 2: Wyłączenie pogrubienia
        self.client.click("sbToggleBold")
        ctrl_info = self.client.control("sbToggleBold")
        self.assertFalse(ctrl_info.get("down"))
        self.assertEqual(self.client.get_text("StatusBar1", panel=2), "Bold: OFF")
        print("  [OK] SpeedButton (TGraphicControl) toggled successfully: ON -> OFF")

    def test_04_edit_and_button_action(self):
        """Scenariusz 4: Wprowadzenie tekstu do TEdit, przełączenie TCheckBox i kliknięcie TButton."""
        test_item_name = f"PyTest-{int(time.time())}"

        # 1. Wpisanie tekstu
        self.client.set_text("edtItemName", test_item_name)

        # 2. Kliknięcie checkboxa Active
        self.client.click("chkActive")

        # 3. Dodanie elementu przyciskiem
        self.client.click("btnAddItem")

        # 4. Weryfikacja reakcji UI w pasku stanu i etykiecie
        status_panel_0 = self.client.get_text("StatusBar1", panel=0)
        lbl_status = self.client.get_text("lblStatus")

        self.assertIn(test_item_name, status_panel_0, f"StatusBar nie zawiera nazwy: '{status_panel_0}'")
        self.assertIn(test_item_name, lbl_status, f"lblStatus nie zawiera nazwy: '{lbl_status}'")
        print(f"  [OK] Edit & Button action verified: item='{test_item_name}', status='{status_panel_0}'")

    def test_05_dbgrid_navigation(self):
        """Scenariusz 5: Nawigacja po wierszach TDBGrid powiązanego z TFDMemTable."""
        # Ustawienie na pierwszym rekordzie
        row1 = self.client.grid("DBGrid1", action="first")
        self.assertEqual(row1.get("recNo"), 1)

        # Przejście do następnego rekordu
        row2 = self.client.grid("DBGrid1", action="next")
        self.assertEqual(row2.get("recNo"), 2)

        # Weryfikacja aktualizacji panelu rekordu w pasku stanu
        status_panel_1 = self.client.get_text("StatusBar1", panel=1)
        self.assertIn("Record 2 of", status_panel_1)

        # Weryfikacja danych kolumn rekordu
        record_data = row2.get("record", {})
        self.assertEqual(record_data.get("Name"), "Gaming Mouse")
        self.assertEqual(record_data.get("Category"), "Hardware")
        print(f"  [OK] DBGrid navigation: record 2 of {row2.get('recordCount')} ('{record_data.get('Name')}')")

    def test_06_automation_coverage_report(self):
        """Scenariusz 6: Pobranie raportu pokrycia automatyzacją UI z agenta."""
        cov = self.client.coverage()
        total_visible = cov.get("totalVisibleControls", 0)
        covered_visible = cov.get("coveredVisibleControls", 0)
        percent = cov.get("coveragePercent", 0.0)

        self.assertGreater(total_visible, 0)
        self.assertGreater(covered_visible, 0)
        self.assertGreater(percent, 0.0)

        covered_names = cov.get("coveredControls", [])
        covered_str = " ".join(covered_names)

        # Sprawdzamy czy dotknięte kontrolki znalazły się na liście pokrytych
        self.assertIn("sbToggleBold", covered_str)
        self.assertIn("edtItemName", covered_str)
        self.assertIn("btnAddItem", covered_str)
        self.assertIn("DBGrid1", covered_str)
        self.assertIn("StatusBar1", covered_str)
        print(f"  [OK] UI Coverage: {percent:.1f}% ({covered_visible}/{total_visible} visible controls covered)")


if __name__ == "__main__":
    unittest.main()
