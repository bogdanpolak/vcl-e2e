# VCL-E2E: Automatyzacja Testów End-to-End dla Aplikacji Delphi VCL

Lekki framework i system testowania End-to-End dla aplikacji Delphi VCL, wykorzystujący wbudowanego agenta HTTP REST (`TIdHTTPServer`) oraz klienta konsolowego CLI (`Delphi Win32 Console`).

---

## 📁 Struktura Projektu

```
vcl-e2e/
├── bin/                       # Skompilowane pliki binarne (.exe)
│   ├── dcu/                   # Pliki skompilowanych modułów (.dcu)
│   ├── DemoApp.exe            # Aplikacja demonstracyjna VCL z wbudowanym Agentem
│   └── cli.exe                # Klient CLI (Test Runner + Unit Tests)
├── demo/                      # Kod źródłowy aplikacji demonstracyjnej VCL
│   ├── DemoApp.dpr / .dproj   # Projekt aplikacji demonstracyjnej
│   ├── MainForm.pas / .dfm    # Formatka VCL z TSpeedButton, TStatusBar, TDBGrid
│   └── VclE2E.Agent.pas       # Moduł serwera HTTP REST (TIdHTTPServer)
├── cli/                       # Kod źródłowy klienta sterującego CLI
│   ├── cli.dpr / .dproj       # Projekt konsolowy CLI
│   ├── VclE2E.Client.pas      # Klient HTTP REST API
│   ├── VclE2E.Scenarios.pas   # Wbudowane scenariusze testowe (Wariant A)
│   └── tests/                 # Testy jednostkowe DUnitX dla CLI
│       ├── clitests.dpr / .dproj
│       └── TestVclE2EClient.pas
├── docs/                      # Dokumentacja projektu
│   ├── api.md                 # Specyfikacja endpointów REST API
│   └── architecture.md        # Opis architektury, synchronizacji i coverage
├── VclE2E.groupproj           # Grupa projektowa RAD Studio (otwiera wszystko w IDE)
├── build.bat                  # Skrypt kompilacji i uruchomienia testów
└── README.md
```

---

## 🚀 Szybki Start

### 1. Kompilacja całego projektu (jeden krok)

W wierszu poleceń uruchom:
```cmd
build.bat
```
Skrypt automatycznie:
1. Kompiluje wszystkie projekty (`DemoApp`, `cli`, `clitests`) za pomocą MSBuild do katalogu `bin\`.
2. Uruchamia zintegrowane testy jednostkowe DUnitX.

Możesz także otworzyć plik `VclE2E.groupproj` bezpośrednio w środowisku **RAD Studio** i nacisnąć *Project -> Build All Projects*.

---

### 2. Uruchomienie testów jednostkowych CLI

```cmd
bin\cli.exe --unit-tests
```
Uruchamia 5 testów jednostkowych DUnitX weryfikujących parsowanie drzewa JSON, obliczanie pokrycia, kodowanie URL oraz odczyt stanów kontrolek.

---

### 3. Uruchomienie testów End-to-End (E2E)

1. Uruchom aplikację demonstracyjną:
   ```cmd
   bin\DemoApp.exe
   ```
   *(Aplikacja uruchamia automatycznie Agenta E2E na porcie 8080)*

2. W osobnym oknie konsoli uruchom testy E2E:
   ```cmd
   bin\cli.exe --run-all
   ```

---

## 🎯 Możliwości CLI Runnera

| Komenda | Opis |
|---------|------|
| `cli.exe --run-all` | Uruchamia cały zestaw testów E2E oraz wyświetla raport pokrycia |
| `cli.exe --unit-tests` | Uruchamia testy jednostkowe DUnitX dla CLI |
| `cli.exe --tree` | Pobiera i wyświetla hierarchię komponentów na formatce |
| `cli.exe --coverage` | Wyświetla raport pokrycia kontrolerów (dotknięte vs niedotknięte) |
| `cli.exe --scenario speedbutton` | Uruchamia test przełączania stanu `TSpeedButton` |
| `cli.exe --scenario edit` | Uruchamia test wprowadzania tekstu w `TEdit` i kliknięcia `TButton` |
| `cli.exe --scenario grid` | Uruchamia test nawigacji po wierszach `TDBGrid` (`TFDMemTable`) |
| `cli.exe --click <nazwa>` | Atomowe kliknięcie w wybraną kontrolkę |
| `cli.exe --set-text <nazwa> <tekst>` | Atomowe wpisanie tekstu w kontrolkę |
| `cli.exe --get-text <nazwa> [panel]` | Odczyt tekstu kontrolki lub konkretnego panelu `TStatusBar` |
| `cli.exe --grid next` | Przejście do następnego rekordu w tabeli |

---

## 📊 Raport Pokrycia (UI Automation Coverage)

Agent na bieżąco monitoruje interakcje z kontrolkami. Polecenie `cli.exe --coverage` lub zakończenie testu `--run-all` prezentuje czytelny raport:

```text
----------------------------------------------------
             VCL E2E COVERAGE REPORT                
----------------------------------------------------
Total controls found:       14
Visible controls:           12
Automated (Touched):        5
Coverage:                   41.7%

Covered controls:
  [+] sbToggleBold (TSpeedButton)
  [+] edtItemName (TEdit)
  [+] btnAddItem (TButton)
  [+] DBGrid1 (TDBGrid)
  [+] StatusBar1 (TStatusBar)

Uncovered (Visible but not touched):
  [-] lblTitle (TLabel)
  [-] sbRefresh (TSpeedButton)
  [-] lblItemName (TLabel)
  [-] chkActive (TCheckBox)
  [-] btnReset (TButton)
----------------------------------------------------
```
Szczegółową specyfikację API znajdziesz w pliku [docs/api.md](docs/api.md).
Opis architektury i synchronizacji znajdziesz w pliku [docs/architecture.md](docs/architecture.md).