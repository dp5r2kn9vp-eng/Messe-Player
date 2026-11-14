# Fernsteuer-Schnittstelle (API-Version 1)

CueView lässt sich im lokalen Netz fernsteuern, z. B. von der iPad-App „CueView Remote“. Die Schnittstelle ist standardmäßig **aus**. Ist sie aus, ist kein Port offen.

## Finden

- Bonjour-Dienst `_cueview._tcp`. Der Name ist der Rechnername.
- Der Port des Dienstes ist der HTTP-Port (Standard 7520).
- TXT-Record: `v` = API-Version, `ws` = WebSocket-Port (Standard 7521).

## Kopplung

CueView zeigt eine 4-stellige PIN.

```
POST /pair            {"pin": "1234", "deviceName": "iPad Stand"}
200                   {"token": "<64 hex>", "deviceID": "<UUID>", "apiVersion": 1}
403                   falsche PIN
429                   nach 5 Fehlversuchen 60 s gesperrt
```

Nach einer erfolgreichen Kopplung gilt eine neue PIN. Jede weitere Anfrage braucht `Authorization: Bearer <token>`, sonst antwortet CueView mit `401`. Wird ein Gerät in CueView entfernt, verliert es den Zugang und alle WebSocket-Verbindungen werden getrennt.

## Befehle (HTTP, Port 7520)

Antworten sind JSON. Befehle antworten mit dem neuen Zustand (`RemoteState`). Die Verbindung schließt nach jeder Antwort.

| Methode | Pfad | Body | Wirkung |
|---|---|---|---|
| GET | `/state` | – | Zustand |
| GET | `/cues` | – | Cue-Liste: `[{id, number, title, kind, groupID}]`, `kind` = `image`/`video`/`audio`/`control` |
| POST | `/go` | – | GO (Cue am Abspielkopf) |
| POST | `/stop` | – | Stopp alle |
| POST | `/emergency` | – | Notfall-Stopp (⌘.) |
| POST | `/pause` | – | Pause/Fortsetzen |
| POST | `/black` | – | Black alle umschalten |
| POST | `/black/{outputID}` | – | Black eines Ausgangs umschalten |
| POST | `/end-loop` | `{"after": "pass"}` oder `{"after": "cue"}` | Loop beenden (L / ⇧L) |
| POST | `/playhead` | `{"cueID": "<UUID>"}` oder `{"offset": 1}` | Abspielkopf setzen bzw. bewegen |

Befehle wirken wie in CueView selbst, auch im Messe-Modus. Fehler kommen als `{"error": "…"}` mit 400, 404 oder 405.

## Live-Zustand (WebSocket, Port 7521)

```
ws://<host>:7521/events     Header: Authorization: Bearer <token>
```

Direkt nach dem Verbinden und danach bei jeder Änderung (geprüft alle 100 ms) kommt eine Textnachricht mit `RemoteState`. Nachrichten vom Gerät werden ignoriert.

```json
{
  "apiVersion": 1,
  "playhead": {"id": "…", "number": "3", "title": "Präsentation"},
  "running": [{"cue": {"id": "…", "number": "2", "title": "Loop Bild 1"},
               "phase": "running", "startedAt": "2026-11-14T13:00:00Z", "duration": 5, "pausedAt": null}],
  "isPaused": false,
  "isBlack": false,
  "outputs": [{"id": "…", "name": "Ausgang 1", "isBlack": false}],
  "canEndLoop": true,
  "isTradeShowMode": true,
  "nextScheduledStart": {"cue": {"id": "…", "number": "7", "title": "Präsentation"}, "date": "2026-11-14T13:00:00Z"},
  "notice": null
}
```

- Zeiten sind ISO 8601 (UTC). Restzeit = `duration − ((pausedAt ?? jetzt) − startedAt)`. Die Uhrzeit des Geräts sollte stimmen.
- `phase`: `waiting` (Warten läuft) oder `running`.
- Felder mit `null` fehlen eventuell ganz. Unbekannte Felder bitte ignorieren, denn neue kommen ohne Versionswechsel dazu.

## Sicherheit

- Nur im lokalen Netz, ohne TLS. Die PIN-Kopplung schützt vor versehentlicher Bedienung, nicht vor Angreifern im selben WLAN. Auf der Messe deshalb ein eigenes WLAN oder einen eigenen Hotspot nutzen.
- macOS fragt beim ersten Einschalten nach dem Zugriff auf das lokale Netzwerk bzw. nach eingehenden Verbindungen (Firewall). Beides muss erlaubt sein.
