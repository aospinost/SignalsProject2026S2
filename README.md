# Analizador espectral — Proyecto de Procesamiento de Señales (Grupo 1)

## Requisitos
- MATLAB R2022a o posterior (interfaz `uifigure`).
- No requiere Signal Processing Toolbox: la STFT y la ventana de Hann están implementadas en `core/`.

## Ejecución
1. Copiar las canciones a la carpeta `Music/` (wav, mp3, flac, m4a u ogg).
2. En MATLAB, situarse en esta carpeta y ejecutar:
   ```matlab
   main
   ```

## Estructura
| Archivo | Función |
|---|---|
| `main.m` | Agrega rutas y abre la interfaz |
| `app/AnalizadorApp.m` | Interfaz (carga, selección, gráficas, reproducción) |
| `core/leer_audio.m` | Lectura del archivo completo (conserva los canales) |
| `core/calcular_stft.m` | STFT propia con tramas centradas |
| `core/ventana_hann.m` | Ventana de Hann periódica |
| `core/envolvente_minmax.m` | Envolvente para dibujar la canción completa rápidamente |
| `core/calcular_istft.m` | STFT inversa por solapamiento y suma ponderado (reconstrucción exacta) |
| `core/rampa_coseno.m` | Bordes suaves (coseno elevado) de la máscara |
| `core/caracteristicas_tf.m` | STFT por canal, magnitud mono y paneo por bin |
| `core/hpss_mascara.m` | Máscara de carácter (sostenido/percusivo) binaria por canal, filtros de mediana (FitzGerald 2010) |
| `core/repet_sim_mascara.m` | Máscara de repetición (repetitivo/no repetitivo), REPET-SIM |
| `core/repet_mascara.m` | Máscara de repetición con un período (REPET original) y espectro de ritmo |
| `tests/run_tests.m` | Ejecuta las pruebas `tests/test_*.m` (señales sintéticas) |
| `core/mascara_componente.m` | Máscara de un componente: banda × carácter × paneo |
| `core/aplicar_componentes.m` | Aplica las ganancias y reconstruye (ISTFT) |

## Pruebas
Desde la raíz del proyecto:
```
matlab -batch "addpath('core', 'tests'); run_tests"
```

## Uso
- **Fragmento:** por defecto 20 s desde el inicio (máximo del enunciado). Cambiar "Inicio" o hacer clic en la vista global coloca una ventana de 20 s desde ese instante; arrastrar en la vista global elige un rango libre. "Canción completa" y cualquier fragmento de más de 60 s piden confirmación (memoria y tiempo crecen con la duración). Más de 20 s se marca en rojo.
- **Inicio / Fin:** ajuste numérico exacto (cambiar el inicio fija 20 s; cambiar el fin respeta el rango escrito).
- **Señal / espectrograma:** clic para mover la reproducción a ese instante. El zoom está en la barra de herramientas de cada gráfica, y ambas gráficas comparten el eje de tiempo.
- **Espectro:** espectro promedio del fragmento (media de |X|² sobre las tramas de la STFT) en dBFS, con la original y la procesada superpuestas en los mismos ejes. Usa la frecuencia máxima y el rango dinámico del panel STFT.
- **Barra espaciadora:** reproducir / pausar.
- **Análisis STFT (afecta el procesamiento):** ventana (1024–16384; por defecto 4096) y solapamiento (50 / 75 / 87.5 %; por defecto 75 %), la STFT de FitzGerald (2010): a 48 kHz, Δf = 11.7 Hz, ventana de 85.3 ms y salto de 1024 muestras (21.3 ms). El salto es el mismo que con la STFT del código de REPET (2048 / 50 %), así que las tramas y los parámetros en segundos no cambian. Cambiarlos recalcula HPSS y REPET.
- **Visualización (solo dibujo):** frecuencia máxima (por defecto Nyquist), rango dinámico (60 / 80 / 100 dB bajo el máximo del original, por defecto 80; la procesada usa la misma escala) y mapa de color (por defecto turbo). Escala en dBFS (una sinusoide de amplitud 1 da 0 dB).

## Selección por componente musical
Un componente es una máscara M(t,f) ∈ [0,1] por canal que cubre TODO el fragmento:

    M = banda(f) · carácter(t,f) · repetición(t,f,canal) · paneo(t,f)

Las máscaras se usan tal como las definen los artículos, sin afilado: HPSS binaria (0 o 1) y REPET suave (entre 0 y 1), ambas propias de cada canal. La banda y el paneo tienen bordes de coseno.

- **Banda:** f inferior–superior con bordes de coseno elevado.
- **Carácter (HPSS, FitzGerald 2010, ecs. 5–9 y 12–13):** por canal, mediana en tiempo (l_harm) → parte sostenida H; mediana en frecuencia (l_perc) → parte percusiva P; máscara binaria M_H = 1 si H > P (empates, es decir silencio, a percusivo). Opciones: Cualquiera (por defecto), Sostenido, Percusivo. Sostenido + Percusivo = original exactamente. Parámetros globales en el panel "Filtro de carácter (HPSS)": por defecto 400 ms y 180 Hz, los filtros de 17 × 17 del artículo (19 × 15 a 48 kHz); límites 100–1500 ms y 50–1000 Hz; botón Restaurar. La máscara binaria puede dar "ruido musical" con ganancias grandes (±18/±20 dB); el artículo prefiere la suave con p = 2, prevista pero aún no implementada.
- **Repetición (panel "Filtro de repetición (REPET)", columna derecha):** dos métodos, a elegir en "Método"; el método y sus parámetros son globales.
  - **REPET-SIM** (por defecto; Rafii y Pardo 2012; Rafii, Liutkus y Pardo 2014, sec. 14.4): similitud coseno entre todas las tramas del espectrograma promediado entre canales; para cada trama, los k picos más altos de su fila de similitud (> t, separados ≥ d s); por canal, mediana de esas tramas = modelo U del fondo repetitivo; W = min(U, V); máscara (W+eps)/(V+eps). Sin corte en frecuencia. Opciones: Cualquiera (por defecto), Repetitivo, No repetitivo. Parámetros globales en el panel "Filtro de repetición" (k = 100, d = 1 s, t = 0, valores del código de referencia), con un diagnóstico (tramas por mediana, cuántas caben, similitud media).
  - **REPET original** (Rafii y Pardo 2013; Rafii, Liutkus y Pardo 2014, sec. 14.2): espectro de ritmo (autocorrelación sin sesgo del espectrograma) → período p en [p_mín, p_máx] (por defecto [1, 10] s, el de la referencia, y como mucho un tercio del fragmento); por canal, mediana entre los r segmentos de p tramas; W = min(S, V); máscara (W+eps)/(V+eps). Diagnóstico: período, r y BPM equivalente (60/período, con ×2 y ×4 por si el período es un compás); aviso si r < 3. "Ver espectro de ritmo" abre b(lag) con el rango y el período elegido.
  - "Restaurar valores por defecto" restaura los parámetros de ambos métodos. Detalles y diferencias con la referencia en `docs/FILTROS.md`.
- **Voz solista ≈ Sostenido × No repetitivo.** Las cuatro combinaciones (Sostenido/Percusivo × Repetitivo/No repetitivo) suman exactamente la señal original.
- **Paneo:** p = (|R|−|L|)/(|R|+|L|) por bin (−1 izq., +1 der.). Sin efecto en señales mono.

Uso:
- **+ Nuevo** crea un componente neutro: banda 0–Nyquist, paneo [−1, 1], carácter y repetición Cualquiera, 0 dB.
- **Mapa estéreo:** energía por (paneo, frecuencia); clic = centrar el rango de paneo ahí. El recuadro blanco es el componente.
- **Resaltar máscara:** oscurece en el espectrograma lo que NO pertenece al componente.
- **Solo: silenciar lo demás** para validar la selección de oído.
- **Versión Original / Procesada (tecla B)**, **Deshacer**, **Revertir todo**: el original nunca se modifica.
- **⭳ Exportar WAV:** guarda la versión procesada (lo que se escucha, incluido "Solo") en `exports/<canción>_<t1>-<t2>s_procesada_<fecha>.wav` (24 bits) y un `.txt` con todos los parámetros (STFT, HPSS —l_harm y l_perc en ms/Hz y en tramas/bins, máscara binaria por canal—, método de repetición y sus parámetros —con REPET original, también el período, r y los BPM equivalentes— y componentes). Si el pico supera 1 se escala y se anota la escala.

Ganancia: G_k = 1 + (10^(g_k/20) − 1)·M_k, G = Π G_k (· max M_k en modo solo); Y = G·X en cada canal; ISTFT.
