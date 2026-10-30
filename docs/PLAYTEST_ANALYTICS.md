# Studio Playtest Analytics

Studio-only session recorder for real 30-minute playtests. **Never runs in live production.**

Exports:

| File | Purpose |
|------|---------|
| `PLAYTEST_SESSION.json` | Event-level data + snapshots + friction |
| `PLAYTEST_SUMMARY.md` | Human-readable report for Astra |
| `PLAYTEST_PURCHASES.csv` | Spreadsheet purchase timeline |

## Before you play (once per machine)

1. Open a terminal in the repo root.
2. Start the export receiver and leave it running:

```bash
python tools/playtest_export_server.py
```

You should see: `Listening on http://127.0.0.1:19283/export`.

3. In Roblox Studio, **Game Settings → Security → Allow HTTP requests** should be on.
   Export also tries to enable HttpService only at Stop/Save time (Studio-only) — it never changes gameplay.
   The recording HUD sits **bottom-left** so it does not cover Travel (top-right).

## Playtest steps

1. **Start Studio** and open `RelicCollector` (Rojo sync as usual). Confirm the Soft A+C + collection Studio trial is active (default when `BalanceTrials.StudioAutoDisabled` is false).
2. **Press Play** (solo / Play Solo).
3. **Confirm recording** — top-right HUD shows `● RECORDING` with elapsed time and event counts. Output also prints `[PlaytestAnalytics] START pt_…`. Chat: `/analytics status`.
4. **Play normally** for ~30 minutes. Do not wipe data mid-session unless intentional. Rebirth is safe — history is kept.
5. **Stop recording** — click **Stop & Export** on the HUD (or chat `/analytics stop`).
6. **Get the files** — with the Python server running they land in:
   - `docs/playtest/PLAYTEST_SESSION.json`
   - `docs/playtest/PLAYTEST_SUMMARY.md`
   - `docs/playtest/PLAYTEST_PURCHASES.csv`
   - plus a dated copy under `docs/playtest/<SessionId>/`
7. **Send to Astra** — attach those three files (or the whole `docs/playtest/<SessionId>/` folder).

### If HTTP export failed

- Files are still in **ServerStorage → PlaytestExport → \<SessionId\>** (StringValues).
- Start `python tools/playtest_export_server.py`, then either:
  - Click HUD **Save** / chat `/analytics export`, or
  - Use the optional Studio plugin `tools/PlaytestExportPlugin.luau`.

### Chat commands (Studio only)

| Command | Effect |
|---------|--------|
| `/analytics status` | Recording flag, elapsed, counts |
| `/analytics start` | Start (also auto-starts on join when collection trial is on) |
| `/analytics stop` | Stop + export |
| `/analytics export` | Export without stopping |

## Collection HUD funnel events

When recording, Collection UI emits `CollectionFunnel` events (also listed under Major milestones for first open / first fuse-ready / each completed fuse & charm):

| Event | Meaning |
|-------|---------|
| `FusionReady` | Server: first time a fuse recipe becomes affordable |
| `CollectionOpen` / `CollectionClose` | Panel opened / closed (`Close` detail = dwell seconds) |
| `RecipeInspect` | Player viewed fuse-ready list |
| `FuseAttempt` / `FuseComplete` / `FuseFailed` | Fuse invoke / success / failure |
| `CharmEquip` / `CharmFailed` | Charm set / failed |
| *(Friction)* | `CollectionUISec`, `CollectionPanelVisits`, `CollectionFailedAttempts` |

## Safety

- Gated by `RunService:IsStudio()` and collection trial.
- Anonymous session ids (`pt_<userid>_<guid>` + `AnonymousPlayerKey`).
- No DataStores. Server-authoritative purchases/balances.
- Does not change RNG, costs, or progression math.
