# CLAUDE.md — Signals project (Grupo 1, Ecualizador)

University signal-processing project in MATLAB: attenuate or boost a musical component (voice, percussion, harmonic accompaniment) in a song with STFT masks, and measure the effect. The assignment is in `docs/` and in the professor's PDF; the key constraints:
- FFT/STFT, spectral masks and reconstruction are the core method. No AI models, no ready-made separation tools. No toolboxes in `core/` (STFT, ISTFT, peak finding are our own code).
- 3 Christmas (decembrina) songs, 3 sections each, 4 gain levels → 36 processed results, with A_E = 10·log10(E_after/E_before).
- The UI must show signal, spectrum and spectrogram before/after with correct axes and units.

## Layout
- `main.m` — adds paths, opens `AnalizadorApp`.
- `app/AnalizadorApp.m` — the whole UI (programmatic uifigure, dark theme in the `T` constant struct). Large file: read only the parts you need.
- `core/` — processing: `calcular_stft`/`calcular_istft` (Hann, WOLA, exact reconstruction), `caracteristicas_tf` (STFT per channel + magnitudes, computed once per fragment), `hpss_mascara` (FitzGerald 2010, binary mask per channel), `repet_sim_mascara` (Rafii & Pardo 2012 / Rafii, Liutkus & Pardo 2014 §14.4), `repet_mascara` (original REPET, §14.2), `mascara_componente`, `aplicar_componentes` (gains, ISTFT). The app does not measure energy (A_E was removed at the user's request).
- `docs/FILTROS.md` — what each filter does, parameters, and deviations from the papers. Keep it in sync with the code.
- `Music/` — the songs (`Antón`, `Faltan Cinco Pa Las Doce`, `Feliz Navidad`, `Los Peces En El Río`, `MI FORTUNA`, `Silent Night`).

## Conventions
- Code identifiers, comments, UI text and docs are in **Spanish**. Keep that.
- Every function starts with a help block: purpose, inputs with units, outputs, and the paper/equation it implements.
- Masks are used as the papers define them: HPSS **binary** (FitzGerald eqs. 8–9; ties go to percussive), REPET-SIM and REPET original **soft** (eq. 14.4). No sharpening and no frequency cut-off inside the filters. Band and pan have cosine edges.
- A component mask is `M = banda(f) · carácter(f,t) · repetición(f,t,canal) · paneo(f,t)`, size nF × nT × C. Each filter gives M and 1 − M, so the four Sostenido/Percusivo × Repetitivo/No repetitivo combinations must sum exactly to the original. Do not break this.
- Parameters are expressed in physical units (s, Hz) and converted to frames/bins inside the function.
- Fidelity to the literature matters more than cleverness. Any deviation from a paper or its reference code must be listed in `docs/FILTROS.md` under "Diferencias con la referencia".

- Default STFT: Hann 4096, 75 % overlap (hop 1024), FitzGerald (2010). At 48 kHz: Δf = 11.7 Hz, window 85.3 ms, hop 21.3 ms.

## Running and testing
- Run MATLAB headless: `matlab -batch "addpath('core', 'tests'); run_tests"` (from the repo root). If `matlab` is not on PATH, ask the user for the install path; do not guess.
- The UI cannot be checked headless. For visual changes, construct the app in a script and save figures with `exportapp(app.Fig, 'tests/out/ui.png')`, then read the PNG. Otherwise ask the user to look.
- Tests live in `tests/`. Prefer synthetic signals with known ground truth (e.g. a repeating loop + a non-repeating melody) over listening.
- Never claim something works without having run it.
