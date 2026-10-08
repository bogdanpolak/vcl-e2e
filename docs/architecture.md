# Architektura Systemu Automatyzacji VCL E2E

Projekt stanowi lekką architekturę testów End-to-End dla aplikacji Delphi VCL, opartą o wzorzec wbudowanego Agenta REST (koncepcyjnie zbliżonego do WebDriver / Appium).

```
+-------------------------------------------------------------+
|                     CLI Test Runner                         |
|  - Wbudowane scenariusze testowe (VclE2E.Scenarios.pas)     |
|  - Klient HTTP REST (VclE2E.Client.pas)                     |
|  - Raportowanie i analiza pokrycia (Coverage)               |
|  - Zintegrowane testy jednostkowe DUnitX                    |
+-------------------------------------------------------------+
                               |
                               | HTTP / JSON (Port 8080)
                               v
+-------------------------------------------------------------+
|                Aplikacja Testowana (DemoApp)                |
|  +-------------------------------------------------------+  |
|  | TVclE2EAgent (VclE2E.Agent.pas)                       |  |
|  | - Indy TIdHTTPServer                                  |  |
|  | - Synchronizacja wątkowa z UI (RunInUI / Synchronize) |  |
|  | - Rejestr dotkniętych kontrolek (Coverage Tracker)    |  |
|  +-------------------------------------------------------+  |
|                              |                              |
|                              v                              |
|  +-------------------------------------------------------+  |
|  | Formatka VCL (MainForm)                               |  |
|  | - TSpeedButton (TGraphicControl - brak HWND)          |  |
|  | - TStatusBar (Panele statusu i liczników)             |  |
|  | - TDBGrid + TFDMemTable (In-memory dataset)           |  |
|  | - TEdit, TButton, TCheckBox, TLabel                   |  |
|  +-------------------------------------------------------+  |
+-------------------------------------------------------------+
```

---

## Główne Wyzwania i Rozwiązania Architektoniczne

### 1. Obsługa kontrolek bez uchwytu systemowego (`TGraphicControl`)
* **Problem:** Narzędzia bazujące na standardowym Win32 API lub Windows UI Automation (UIA) nie widzą kontrolek takich jak `TSpeedButton`, `TLabel` czy `TShape`, ponieważ nie posiadają one uchwytu `HWND` i są rysowane bezpośrednio na powierzchni rodzica.
* **Rozwiązanie:** Agent działa **wewnątrz procesu aplikacji**, dzięki czemu iteruje po strukturze obiektowej VCL (`Controls[]`, `Components[]`), wywołuje chronione metody `Click` (`TControlAccess = class(TControl)`) oraz odczytuje i modyfikuje stan właściwości specyficznych (`TSpeedButton.Down`, `TSpeedButton.GroupIndex`).

### 2. Bezpieczeństwo wątkowe (Thread Safety)
* **Problem:** `TIdHTTPServer` z pakietu Indy obsługuje przychodzące żądania w osobnych wątkach roboczych (worker threads). Bezpośrednia modyfikacja formularza VCL z innego wątku prowadzi do wyścigów i wyjątków Access Violation.
* **Rozwiązanie:** Agent deleguje wykonanie zapytań do głównego wątku UI za pośrednictwem metody:
  ```pascal
  procedure TVclE2EAgent.RunInUI(AProc: TThreadProcedure);
  begin
    TThread.Synchronize(TThread(nil), AProc);
  end;
  ```

### 3. Śledzenie Pokrycia UI (UI Automation Coverage)
* **Problem:** W automatyzacji testów często trudno ocenić, które elementy interfejsu zostały przetestowane, a które pominięte.
* **Rozwiązanie:** Agent posiada wbudowany `FTouchedControls: TDictionary<string, Integer>`. Każda akcja (`click`, `set-text`, `get-text`, `grid`) rejestruje nazwę kontrolki. Endpoint `/api/coverage` dynamicznie analizuje wszystkie widoczne kontrolki na formatce, oblicza procent pokrycia i zwraca listy kontrolek pokrytych oraz niepokrytych.

### 4. Spójność formatowania danych numerycznych
* W komunikacji JSON wartości zmiennoprzecinkowe (np. `coveragePercent`, pola w siatce) są serializowane i parsowane z użyciem `TFormatSettings.Invariant`, co zapobiega problemom ze znakiem przecinka / kropki dziesiętnej na systemach z polskimi ustawieniami regionalnymi.
