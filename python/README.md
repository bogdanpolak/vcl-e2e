# Testy Automatyczne VCL E2E w Pythonie

Ten katalog zawiera klienta i scenariusze testowe End-to-End dla aplikacji Delphi VCL napisane w języku **Python 3**.

---

## 🚀 Cechy Rozwiązania

1. **Zero zewnętrznych zależności (Zero-dependency):**
   * Moduł `vcl_client.py` korzysta wyłącznie z wbudowanej biblioteki standardowej Pythona (`urllib.request`, `json`).
   * Nie ma potrzeby instalowania żadnych pakietów przez `pip` (np. `requests`), chociaż kod bez problemu współpracuje z `pytest`.
2. **Pełna kompatybilność z frameworkami testowymi:**
   * Działa z wbudowanym `unittest` (`python -m unittest test_e2e.py`).
   * Działa z popularnym runnerem `pytest` (`pytest -v`).
   * Zawiera samodzielny skrypt `run_tests.py` ze sformatowanym wyjściem konsolowym i raportem pokrycia (Coverage).

---

## 📁 Pliki w Katalogu

* **`vcl_client.py`** – lekka klasa `VclClient` obsługująca komunikację REST z agentem VCL (`health()`, `tree()`, `click()`, `set_text()`, `get_text()`, `grid()`, `coverage()`).
* **`test_e2e.py`** – zestaw scenariuszy testowych w formacie `unittest` / `pytest`:
  1. `test_01_health_check` – handshake i dostępność procesu.
  2. `test_02_component_tree_inspection` – inspekcja drzewa kontrolek i ich właściwości.
  3. `test_03_speed_button_toggle` – weryfikacja kontrolki bezuchwytowej `TSpeedButton` (`TGraphicControl`).
  4. `test_04_edit_and_button_action` – wpisanie tekstu, modyfikacja checkboxa i kliknięcie przycisku.
  5. `test_05_dbgrid_navigation` – nawigacja po wierszach tabeli `TDBGrid` (`TFDMemTable`).
  6. `test_06_automation_coverage_report` – weryfikacja raportu pokrycia UI.
* **`run_tests.py`** – samodzielny runner uruchamiany z wiersza poleceń z kolorowym formatowaniem i podsumowaniem czasu wykonania.

---

## 🏃 Jak Uruchomić Testy

### Krok 1: Uruchomienie aplikacji testowanej
W środowisku RAD Studio (F9) lub z poziomu wiersza poleceń uruchom aplikację demonstracyjną:
```cmd
..\bin\DemoApp.exe
```

### Krok 2: Uruchomienie testów w Pythonie

Możesz uruchomić testy na trzy różne sposoby:

#### Opcja A: Samodzielny runner (zalecana – z raportem pokrycia):
```cmd
python run_tests.py
```

#### Opcja B: Wbudowany moduł `unittest`:
```cmd
python -m unittest test_e2e.py
```

#### Opcja C: Framework `pytest` (jeśli jest zainstalowany):
```cmd
pytest -v test_e2e.py
```
