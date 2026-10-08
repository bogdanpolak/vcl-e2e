# Specyfikacja REST API Agenta Automatyzacji VCL (VclE2E.Agent)

Agent automatyzacji osadzony w aplikacji VCL nasłuchuje domyślnie na porcie `8080` (protokół HTTP, format JSON, kodowanie UTF-8).
Wszystkie operacje modyfikujące i inspekcyjne na kontrolkach VCL są bezpiecznie synchronizowane z głównym wątkiem aplikacji (`RunInUI` / `TThread.Synchronize`).

---

## 1. Endpointy Informacyjne i Statusowe

### `GET /health` lub `GET /api/health`
Sprawdza dostępność agenta i zwraca podstawowe informacje o aplikacji.
* **Odpowiedź (200 OK):**
```json
{
  "status": "ok",
  "app": "DemoApp.exe",
  "formsCount": 1
}
```

### `GET /api/tree` lub `GET /api/inspect`
Zwraca pełne drzewo hierarchii komponentów i kontrolek na wszystkich aktywnych formatkach VCL.
* **Odpowiedź (200 OK):**
```json
{
  "forms": [
    {
      "name": "frmMain",
      "class": "TfrmMain",
      "caption": "VCL E2E Demo Application",
      "visible": true,
      "controls": [
        {
          "name": "sbToggleBold",
          "class": "TSpeedButton",
          "visible": true,
          "enabled": true,
          "isGraphicControl": true,
          "touched": false,
          "left": 200,
          "top": 10,
          "width": 32,
          "height": 28,
          "text": "B"
        }
      ]
    }
  ]
}
```

### `GET /api/coverage`
Zwraca raport pokrycia automatyzacją – zestawienie wszystkich widocznych kontrolek z podziałem na te, które zostały dotknięte akcjami testowymi (`touched`), oraz te jeszcze niepokryte.
* **Odpowiedź (200 OK):**
```json
{
  "totalControls": 14,
  "totalVisibleControls": 12,
  "coveredVisibleControls": 5,
  "coveragePercent": 41.7,
  "coveredControls": [
    "sbToggleBold (TSpeedButton)",
    "edtItemName (TEdit)",
    "btnAddItem (TButton)",
    "DBGrid1 (TDBGrid)",
    "StatusBar1 (TStatusBar)"
  ],
  "uncoveredControls": [
    "lblTitle (TLabel)",
    "sbRefresh (TSpeedButton)",
    "lblItemName (TLabel)",
    "lblStatus (TLabel)",
    "chkActive (TCheckBox)",
    "btnReset (TButton)",
    "pnlTop (TPanel)"
  ]
}
```

---

## 2. Inspekcja Kontrolki

### `GET /api/control?name={controlName}`
Zwraca szczegółowe właściwości pojedynczego komponentu (w tym stan specyficzny: `down` dla `TSpeedButton`, `checked` dla `TCheckBox`, `caption`, `text`, współrzędne, flagę `isGraphicControl`).
* **Przykładowe żądanie:** `GET /api/control?name=sbToggleBold`
* **Odpowiedź (200 OK):**
```json
{
  "name": "sbToggleBold",
  "class": "TSpeedButton",
  "isControl": true,
  "visible": true,
  "enabled": true,
  "left": 200,
  "top": 10,
  "width": 32,
  "height": 28,
  "isGraphicControl": true,
  "down": false,
  "caption": "B"
}
```

---

## 3. Akcje na Kontrolkach

### `POST /api/click`
Wykonuje akcję kliknięcia na wskazanej kontrolce. Obsługuje zarówno okna z uchwytem `HWND` (`TWinControl`, np. `TButton`, `TCheckBox`), jak i kontrolki bezuchwytowe (`TGraphicControl`, np. `TSpeedButton`). W przypadku `TSpeedButton` z `GroupIndex > 0` automatycznie przełącza stan `Down`.
* **Payload:**
```json
{
  "name": "sbToggleBold"
}
```
* **Odpowiedź (200 OK):**
```json
{
  "success": true,
  "action": "click",
  "target": "sbToggleBold"
}
```

### `POST /api/set-text`
Ustawia tekst w polu edycyjnym (`TEdit`, `TCustomEdit`) lub dowolnej kontrolce posiadającej zapisywalną właściwość `Text` lub `Caption` przez RTTI.
* **Payload:**
```json
{
  "name": "edtItemName",
  "text": "Produkt Testowy 123"
}
```
* **Odpowiedź (200 OK):**
```json
{
  "success": true,
  "target": "edtItemName",
  "text": "Produkt Testowy 123"
}
```

### `GET /api/get-text?name={controlName}&panel={index}`
Odczytuje tekst z kontrolki.
* Dla `TStatusBar` parametr opcjonalny `panel={index}` pozwala odczytać tekst konkretnego panelu:
  * `GET /api/get-text?name=StatusBar1&panel=0` -> tekst panelu statusu
  * `GET /api/get-text?name=StatusBar1&panel=1` -> tekst panelu licznika rekordów
  * `GET /api/get-text?name=StatusBar1&panel=2` -> tekst panelu flagi pogrubienia
* Bez parametru `panel` zwraca `simpleText` oraz tablicę wszystkich paneli `panels`.
* Dla standardowych kontrolek zwraca `text` lub `caption`.
* **Odpowiedź (200 OK):**
```json
{
  "name": "StatusBar1",
  "panelIndex": 2,
  "text": "Bold: ON"
}
```

### `POST /api/grid`
Nawiguje i odczytuje dane w siatce `TDBGrid` (powiązanej z dowolnym `TDataSet`, w tym `TFDMemTable`).
* **Akcje:** `first`, `next`, `prior`, `last`, `locate`, `current`
* **Payload:**
```json
{
  "name": "DBGrid1",
  "action": "next"
}
```
* **Odpowiedź (200 OK):**
```json
{
  "success": true,
  "action": "next",
  "recNo": 2,
  "recordCount": 5,
  "bof": false,
  "eof": false,
  "record": {
    "ID": "2",
    "Name": "Gaming Mouse",
    "Category": "Hardware",
    "Price": "89.5",
    "InStock": "True"
  }
}
```
