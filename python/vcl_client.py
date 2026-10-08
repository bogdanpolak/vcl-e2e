"""
Klient Python dla Agenta Automatyzacji VCL (VclE2E.Agent)
Opiera sie wylacznie na bibliotece standardowej (urllib, json) - zero zaleznosci pip.
"""

import json
import urllib.parse
import urllib.request
from typing import Any, Dict, Optional


class VclClientError(Exception):
    """Wyjatek rzucany w przypadku bledu komunikacji lub odpowiedzi z agenta VCL."""
    pass


class VclClient:
    """Klient REST API dla agenta automatyzacji osadzonego w aplikacji Delphi VCL."""

    def __init__(self, host: str = "127.0.0.1", port: int = 8080, timeout: float = 5.0):
        self.base_url = f"http://{host}:{port}"
        self.timeout = timeout

    def _get(self, endpoint: str) -> Dict[str, Any]:
        url = self.base_url + endpoint
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                data = resp.read().decode("utf-8")
                return json.loads(data)
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8") if e.fp else ""
            raise VclClientError(f"HTTP GET {endpoint} zwrócił kod {e.code}: {err_body}") from e
        except Exception as e:
            raise VclClientError(f"Połączenie z {url} nie powiodło się: {e}") from e

    def _post(self, endpoint: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        url = self.base_url + endpoint
        json_data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=json_data,
            headers={
                "Content-Type": "application/json; charset=utf-8",
                "Accept": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                data = resp.read().decode("utf-8")
                return json.loads(data)
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8") if e.fp else ""
            raise VclClientError(f"HTTP POST {endpoint} zwrócił kod {e.code}: {err_body}") from e
        except Exception as e:
            raise VclClientError(f"Żądanie POST do {url} nie powiodło się: {e}") from e

    def health(self) -> Dict[str, Any]:
        """Pobiera status aplikacji i liczbę otwartych okien."""
        return self._get("/health")

    def tree(self) -> Dict[str, Any]:
        """Pobiera hierarchiczne drzewo kontrolek ze wszystkich aktywnych formularzy."""
        return self._get("/api/tree")

    def coverage(self) -> Dict[str, Any]:
        """Pobiera statystyki pokrycia testami widocznych elementów interfejsu."""
        return self._get("/api/coverage")

    def control(self, name: str) -> Dict[str, Any]:
        """Pobiera szczegółowe właściwości i geometrię kontrolki."""
        encoded_name = urllib.parse.quote(name)
        return self._get(f"/api/control?name={encoded_name}")

    def click(self, name: str) -> Dict[str, Any]:
        """Wykonuje kliknięcie w kontrolkę (obsługuje TWinControl i TGraphicControl)."""
        res = self._post("/api/click", {"name": name})
        if not res.get("success"):
            raise VclClientError(f"Nie udało się kliknąć kontrolki '{name}': {res.get('error')}")
        return res

    def set_text(self, name: str, text: str) -> Dict[str, Any]:
        """Ustawia tekst w polu edycyjnym przez RTTI."""
        res = self._post("/api/set-text", {"name": name, "text": text})
        if not res.get("success"):
            raise VclClientError(f"Nie udało się ustawić tekstu na '{name}': {res.get('error')}")
        return res

    def get_text(self, name: str, panel: Optional[int] = None) -> str:
        """Odczytuje tekst kontrolki lub wybranego panelu paska stanu (TStatusBar)."""
        endpoint = f"/api/get-text?name={urllib.parse.quote(name)}"
        if panel is not None:
            endpoint += f"&panel={panel}"
        data = self._get(endpoint)
        return data.get("text", data.get("simpleText", ""))

    def grid(self, name: str = "DBGrid1", action: str = "next") -> Dict[str, Any]:
        """Nawiguje w siatce TDBGrid (first, next, prior, last) i odczytuje wartości rekordu."""
        res = self._post("/api/grid", {"name": name, "action": action})
        if not res.get("success"):
            raise VclClientError(f"Akcja siatki '{action}' nie powiodła się: {res.get('error')}")
        return res
