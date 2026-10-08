#!/usr/bin/env python3
"""
Samodzielny runner testów E2E dla aplikacji VCL w Pythonie.
Uruchamia testy, mierzy czas i wyświetla sformatowany raport w konsoli.
Zero zależności zewnętrznych (czysty Python 3).
"""

import argparse
import os
import sys
from pathlib import Path
import time

_pkg_dir = str(Path(__file__).resolve().parent)
if _pkg_dir not in sys.path:
    sys.path.insert(0, _pkg_dir)

try:
    from vcl_client import VclClient, VclClientError
except ImportError:
    from python.vcl_client import VclClient, VclClientError


def print_banner():
    print("=" * 66)
    print("       VCL E2E Test Runner - Python Automation Client")
    print("=" * 66)


def run_scenario(name: str, fn, *args):
    start = time.perf_counter()
    try:
        details = fn(*args)
        elapsed_ms = int((time.perf_counter() - start) * 1000)
        print(f"  [PASS] {name:<32} ({elapsed_ms:4d} ms) : {details}")
        return True
    except Exception as e:
        elapsed_ms = int((time.perf_counter() - start) * 1000)
        print(f"  [FAIL] {name:<32} ({elapsed_ms:4d} ms) : {e}")
        return False


def test_health(client: VclClient) -> str:
    res = client.health()
    if res.get("status") != "ok":
        raise AssertionError(f"Status nie jest 'ok': {res}")
    return f"App: '{res.get('app')}', Aktywne okna: {res.get('formsCount')}"


def test_tree(client: VclClient) -> str:
    tree = client.tree()
    forms = tree.get("forms", [])
    if not forms:
        raise AssertionError("Brak formularzy w drzewie")
    controls_count = len(forms[0].get("controls", []))
    return f"Formularz '{forms[0].get('name')}', Znaleziono {controls_count} kontrolek"


def test_speed_button(client: VclClient) -> str:
    # 1. Włączenie
    client.click("sbToggleBold")
    ctrl1 = client.control("sbToggleBold")
    txt1 = client.get_text("StatusBar1", panel=2)
    if not ctrl1.get("down") or txt1 != "Bold: ON":
        raise AssertionError(f"Błąd włączenia: down={ctrl1.get('down')}, status='{txt1}'")

    # 2. Wyłączenie
    client.click("sbToggleBold")
    ctrl2 = client.control("sbToggleBold")
    txt2 = client.get_text("StatusBar1", panel=2)
    if ctrl2.get("down") or txt2 != "Bold: OFF":
        raise AssertionError(f"Błąd wyłączenia: down={ctrl2.get('down')}, status='{txt2}'")

    return f"Przełączono stan ON ('{txt1}') oraz OFF ('{txt2}')"


def test_edit_and_button(client: VclClient) -> str:
    item_name = f"PyItem-{int(time.time()) % 10000}"
    client.set_text("edtItemName", item_name)
    client.click("chkActive")
    client.click("btnAddItem")

    sb_text = client.get_text("StatusBar1", panel=0)
    lbl_text = client.get_text("lblStatus")
    if item_name not in sb_text:
        raise AssertionError(f"Pasek stanu nie zawiera '{item_name}': '{sb_text}'")
    return f"Dodano element '{item_name}', StatusBar: '{sb_text}', Etykieta: '{lbl_text}'"


def test_dbgrid(client: VclClient) -> str:
    r1 = client.grid("DBGrid1", action="first")
    r2 = client.grid("DBGrid1", action="next")
    sb1 = client.get_text("StatusBar1", panel=1)

    rec_no = r2.get("recNo")
    rec_count = r2.get("recordCount")
    row_name = r2.get("record", {}).get("Name", "")

    if rec_no != 2:
        raise AssertionError(f"Oczekiwano recNo=2, otrzymano {rec_no}")
    return f"Przejście Rec 1 -> Rec {rec_no}/{rec_count} (Produkt: '{row_name}', StatusBar: '{sb1}')"


def test_coverage(client: VclClient) -> str:
    cov = client.coverage()
    total = cov.get("totalControls", 0)
    vis = cov.get("totalVisibleControls", 0)
    covered = cov.get("coveredVisibleControls", 0)
    pct = cov.get("coveragePercent", 0.0)
    return f"Pokrycie UI: {pct:.1f}% ({covered}/{vis} widocznych kontrolek)"


def print_coverage_summary(client: VclClient):
    try:
        cov = client.coverage()
        print("\n" + "-" * 56)
        print("           RAPORT POKRYCIA AUTOMATYZACJĄ UI (PYTHON)")
        print("-" * 56)
        print(f"Liczba kontrolek ogółem:    {cov.get('totalControls')}")
        print(f"Widoczne kontrolki:         {cov.get('totalVisibleControls')}")
        print(f"Dotknięte testami:          {cov.get('coveredVisibleControls')}")
        print(f"Wskaźnik pokrycia:          {cov.get('coveragePercent'):.1f}%\n")

        print("Pokryte kontrolki:")
        for item in cov.get("coveredControls", []):
            print(f"  [+] {item}")

        print("\nNiepokryte kontrolki (widoczne):")
        for item in cov.get("uncoveredControls", []):
            print(f"  [-] {item}")
        print("-" * 56)
    except Exception as e:
        print(f"Błąd pobierania raportu pokrycia: {e}")


def main():
    parser = argparse.ArgumentParser(description="Runner testów E2E w Pythonie dla Delphi VCL")
    parser.add_argument("--host", default="127.0.0.1", help="Host agenta VCL (domyślnie: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8080, help="Port agenta VCL (domyślnie: 8080)")
    parser.add_argument("--coverage", action="store_true", help="Wyświetla szczegółowy raport pokrycia")
    args = parser.parse_args()

    print_banner()
    print(f"Łączenie z agentem pod adresem {args.host}:{args.port} ...\n")

    client = VclClient(host=args.host, port=args.port)

    if args.coverage:
        print_coverage_summary(client)
        sys.exit(0)

    print("Rozpoczęcie wykonywania scenariuszy testowych:")
    print("-" * 66)

    scenarios = [
        ("HealthCheck", test_health),
        ("TreeInspection", test_tree),
        ("SpeedButtonToggle (TGraphicCtrl)", test_speed_button),
        ("EditAndButtonAction", test_edit_and_button),
        ("DBGridNavigation (TFDMemTable)", test_dbgrid),
        ("AutomationCoverage", test_coverage),
    ]

    all_passed = True
    for name, fn in scenarios:
        ok = run_scenario(name, fn, client)
        if not ok:
            all_passed = False

    print("-" * 66)
    if all_passed:
        print("WYNIK: WSZYSTKIE TESTY ZAKOŃCZONE SUKCESEM! [OK]")
        print_coverage_summary(client)
        sys.exit(0)
    else:
        print("WYNIK: CZĘŚĆ TESTÓW ZAKOŃCZONA BŁĘDEM! [FAILED]")
        sys.exit(1)


if __name__ == "__main__":
    main()
