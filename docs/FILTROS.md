# Filtros usados: HPSS, REPET-SIM y REPET original

Los filtros trabajan sobre la magnitud de la STFT de cada canal, V(f,t) = |X_c(f,t)|, y producen una máscara por canal para cada punto tiempo-frecuencia: **binaria** (0 o 1) en HPSS y **suave** (entre 0 y 1) en los dos REPET. Las máscaras se usan tal como las definen los artículos, sin afilado. Ninguno usa aprendizaje automático: todos se construyen con medianas.

La máscara se multiplica por la STFT de cada canal y la señal se reconstruye con la ISTFT. Cada filtro divide la señal en dos partes complementarias, que suman exactamente el original:

| | Repetitivo | No repetitivo |
|---|---|---|
| **Sostenido** | acompañamiento armónico | **voz / melodía principal** |
| **Percusivo** | patrón rítmico | golpes aislados |

Valores de referencia usados abajo (STFT por defecto): Hann de 4096 muestras con salto de 1024 (75 %) a 48 kHz, es decir Δf = 11.7 Hz por bin, ventana de 85.3 ms y salto de 21.3 ms. Es la STFT de FitzGerald (2010). Todos los filtros comparten la misma STFT porque las máscaras se multiplican bin a bin.

---

## 1. HPSS: carácter sostenido / percusivo
*FitzGerald (2010), "Harmonic/percussive separation using median filtering", DAFx-10. Código: `core/hpss_mascara.m`*

### Idea
En el espectrograma, un sonido **sostenido** (una nota, una vocal) es una línea **horizontal**: la misma frecuencia se mantiene en el tiempo. Un **golpe** es una línea **vertical**: muchas frecuencias a la vez durante un instante.

### Cómo funciona (por canal, sobre V = |X_c|)
1. **Filtro de mediana** de longitud impar l (ec. 5): y(n) = mediana{x(n−k : n+k)}, k = (l−1)/2.
2. **P = mediana de cada trama a lo largo de la frecuencia**, longitud l_perc (ec. 6). Conserva lo vertical; un armónico es un pico angosto, es atípico y desaparece.
3. **H = mediana de cada bin a lo largo del tiempo**, longitud l_harm (ec. 7). Conserva lo horizontal; un golpe dura pocas tramas, es atípico y desaparece.
4. **Máscara binaria** (ecs. 8–9): M_H = 1 si H > P, 0 si no. La máscara percusiva es M_P = 1 − M_H.
5. Las máscaras multiplican la STFT compleja de cada canal (ecs. 12–13) y se invierte con la ISTFT.

Regla de la mediana: conserva lo que ocupa **más de la mitad** de su ventana. La máscara es **propia de cada canal** (igual que REPET), en single y con valores exactamente 0 o 1.

### Parámetros
| Parámetro | Defecto | Límites en la interfaz | Qué controla | Si se sube | Si se baja |
|---|---|---|---|---|---|
| **Mediana en tiempo** (l_harm) | 400 ms (17 tramas a 44.1 kHz; 19 a 48 kHz) | 100–1500 ms | Cuánto debe durar algo para contar como sostenido (≈ más de la mitad) | Solo las notas largas son sostenidas; sílabas cortas y vibrato pasan a percusivo | Colas de platillos y golpes resonantes pasan a sostenido |
| **Mediana en frecuencia** (l_perc) | 180 Hz (17 bins a 44.1 kHz; 15 a 48 kHz) | 50–1000 Hz | Qué tan ancho debe ser algo para contar como percusivo | Estimación percusiva más suave | Armónicos anchos (vibrato, coros) pasan a percusivo |

**Por qué esos valores:** el artículo usa filtros de 17 × 17 con FFT 4096 y salto 1024 a 44.1 kHz, e informa que la calidad casi no cambia entre 15 y 30 tramas/bins (≈ 320–640 ms y ≈ 176–352 Hz a 48 kHz). Se expresan en segundos y Hz, no en tramas y bins, para que su sentido físico no cambie con la STFT; los tooltips muestran el rango estable para la STFT actual.

### Diferencias con el artículo (para el informe)
- **Empates (H = P), en la práctica bins en silencio:** el artículo no los asigna a ninguna parte (M_H = M_P = 0, ecs. 8–9). Aquí van a percusivo (M_P = 1 − M_H), para que sostenido + percusivo reconstruya exactamente el original.
- **Bordes del filtro de mediana:** `movmedian` acorta la ventana en los bordes ('shrink'); el artículo no especifica qué hacer ahí.
- **Estéreo:** el artículo trata señales mono y dice que el método se extiende fácilmente a estéreo; aquí se aplica a cada canal por separado.
- **Máscara binaria en lugar de la suave:** el artículo encuentra que la máscara suave con p = 2 (ecs. 10–11) da menos artefactos, a costa de algo más de interferencia. Con la binaria se espera "ruido musical", sobre todo con ganancias de ±18/±20 dB. La suave queda prevista en `hpss_mascara` (argumento `tipo`), aún sin implementar.

**Limitación:** con 4096 muestras a 48 kHz el lóbulo principal de un armónico mide ≈ 4 bins (≈ 47 Hz). Si los armónicos están a menos de ≈ 2 lóbulos (f0 ≲ 95 Hz) llenan más de la mitad de la ventana de frecuencia y parte del sonido se clasifica como percusivo: afecta al bajo y a las notas más graves.

---

## 2. REPET-SIM: repetitivo / no repetitivo
*Rafii y Pardo (2012); Rafii, Liutkus y Pardo (2014), cap. 14, sec. 14.4. Código: `core/repet_sim_mascara.m`*

### Idea
El fondo (acompañamiento) **se repite**, aunque no necesariamente con un período fijo; el primer plano (voz) **cambia**. Si para cada trama se juntan las tramas que más se le parecen y se toma la mediana, sobrevive lo que está en todas (fondo) y desaparece lo que está en pocas (voz).

**Ejemplo,** un bin de 440 Hz en 5 tramas repetidas: [0.30, 0.31, 0.29, **0.90**, 0.30]. La voz suena solo en la 4.ª. La mediana es 0.30, así que en la 4.ª trama 0.30 / 0.90 = 0.33: el 33 % es fondo y el **67 % es voz**.

### Cómo funciona (igual que el artículo y el código de referencia)
1. **Matriz de similitud** (ec. 14.8): coseno entre todas las tramas del espectrograma promediado entre canales, S = Vnᵀ·Vn.
2. **Tramas repetidas** de cada trama j: los picos (máximos locales) de la columna j de S con similitud > t, separados al menos d, y como mucho los k más altos. Es lo que hace `findpeaks` en el código de referencia; aquí se implementa sin toolbox. La propia trama (S(j,j) = 1) es un pico y queda incluida.
3. **Modelo inicial, por canal** (ec. 14.9): U(:,j) = mediana, bin a bin, de las tramas repetidas.
4. **Modelo refinado** (ec. 14.7): W = min(U, V). El fondo no puede tener más energía que la mezcla.
5. **Máscara suave** (ec. 14.4): M_rep = (W + eps)/(V + eps) ∈ [0, 1]. El primer plano es 1 − M_rep (en el artículo, mezcla − fondo, que es lo mismo porque la ISTFT es lineal).

No hay corte en frecuencia ni afilado: el artículo no los define. (El corte de 100 Hz del código de referencia, que fuerza el fondo debajo de 100 Hz, se eliminó a propósito; ver Diferencias.)

### Parámetros
| Parámetro | Defecto (referencia) | Límites en la interfaz | Qué controla | Si se sube | Si se baja |
|---|---|---|---|---|---|
| **k**, máx. tramas repetidas | 100 | 3–500 | Cuántas tramas (incluida la propia) entran en la mediana. La voz desaparece del modelo si está en menos de la mitad | Modelo más robusto si hay tantas repeticiones reales; si no, entran tramas poco parecidas y se sobre-extrae | Modelo ruidoso; la voz puede quedar dentro del fondo. Con k < 3 la mediana no descarta nada |
| **d**, distancia mínima | 1 s | 0.1–10 s | Separación mínima entre dos tramas repetidas. Evita elegir vecinas que se parecen solo porque la nota (incluida la voz) aún no cambió | Caben menos tramas: como mucho ⌊duración/d⌋ + 1 | Una nota cantada larga se cuela como "repetitiva" |
| **t**, similitud mínima | 0 | 0–0.99 | Coseno mínimo para aceptar una trama | En pasajes que no se repiten quedan pocas tramas → W ≈ V → casi todo "repetitivo" (no extrae ahí) | Con 0 se acepta cualquier pico, aunque se parezca poco |

**Diagnóstico en el panel:** tramas por mediana en promedio, cuántas caben con esa d (⌊(m−1)/D⌋ + 1) y similitud media de las tramas elegidas.
- Si "caben" ≤ k, el límite real lo pone d, no k. Con un fragmento de 20 s y d = 1 s caben ≈ 20 tramas: k = 100 no tiene efecto y casi todas las regiones del fragmento entran en la mediana.
- Si la similitud media es baja (≈ 0.5–0.7), la mediana usa tramas que no son repeticiones reales. En ese caso conviene subir t (0.6–0.8) o analizar la canción completa.

### Diferencias con la referencia (para el informe)
- **STFT:** el código de referencia usa 2^nextpow2(40 ms) = 2048 con 50 % de solapamiento (y ventana de Hamming); aquí se usa Hann 4096 / 75 % porque es la de FitzGerald (2010), que informa mejor separación con FFT más largas. Los artículos de REPET no fijan la ventana. El salto (1024) es el mismo, así que las tramas y los parámetros en segundos no cambian. Si se cambia la STFT en la interfaz, REPET-SIM la usa también.
- **Sin corte de 100 Hz:** la referencia fuerza la máscara de fondo a 1 por debajo de 100 Hz (la voz rara vez tiene energía ahí). Aquí no: lo que haya bajo 100 Hz se clasifica solo por repetición. Si el bajo varía, parte se irá al lado "no repetitivo"; si se quiere excluir, se hace con la banda del componente (f inferior), que es explícita y se reporta.
- **Trama sin picos** (fragmento demasiado corto o t muy alto): se usa solo la propia trama → M_rep = 1 (no se extrae nada). La referencia daría una mediana vacía.
- **Mesetas** en la fila de similitud: se toma su primera muestra, como `findpeaks`.

**Limitaciones:**
- Una frase vocal repetida (un estribillo) se clasifica como fondo.
- Adornos instrumentales que no se repiten caen del lado "no repetitivo".
- Memoria y tiempo O(m²): una canción de 3 min a 48 kHz con salto 1024 tiene ≈ 8400 tramas → S ocupa ≈ 280 MB en single.

---

## 3. REPET original: repetitivo / no repetitivo con un período
*Rafii y Pardo (2013); Rafii, Liutkus y Pardo (2014), cap. 14, sec. 14.2. Código: `core/repet_mascara.m`*

Se elige en el panel "Filtro de repetición (REPET)" → Método: REPET original. El método es **global** (como los demás parámetros), así que las cuatro combinaciones Sostenido/Percusivo × Repetitivo/No repetitivo siguen sumando exactamente el original.

### Idea
Si el acompañamiento repite un patrón con un **período fijo** (un compás, una frase de batería), basta con encontrar ese período, cortar el espectrograma en segmentos de esa longitud y tomar la mediana entre segmentos: sobrevive lo que está en todos (fondo) y desaparece lo que está en pocos (voz).

### Cómo funciona (artículo y código de referencia, función `original`)
1. **Espectro de ritmo** (ec. 14.1): espectrograma de los canales promediados y elevado al cuadrado, `mean(V,3).^2` (así lo hace el código de referencia). Autocorrelación en el tiempo de cada fila de frecuencia, **sin sesgo** (el lag l se divide por el número de términos, m − l), con la FFT de longitud 2m para que no sea circular. b(l) = media de las filas, normalizado por b(0).
2. **Período p:** el lag del máximo de b dentro del rango [p_mín, p_máx], que además se limita a m/3 tramas (como la referencia: así hay al menos 3 segmentos para la mediana).
3. **Segmento repetitivo** (ec. 14.2): por canal, V se corta en r = ⌈m/p⌉ segmentos de p tramas; S = mediana elemento a elemento entre segmentos. El último segmento incompleto se rellena con NaN y la mediana los ignora (idéntico a la referencia).
4. **Espectrograma repetitivo** (ec. 14.3): W = min(S, V) en cada segmento.
5. **Máscara suave** (ec. 14.4): M_rep = (W + eps)/(V + eps) ∈ [0, 1]. Sin corte en frecuencia ni afilado.

### Parámetros
| Parámetro | Defecto (referencia) | Límites en la interfaz | Qué controla | Si se sube | Si se baja |
|---|---|---|---|---|---|
| **Período mínimo** | 1 s | 0.1–30 s (< máximo) | Lag más corto que puede ser el período | Se ignoran repeticiones cortas (un pulso) y se elige un compás o una frase | Puede elegir el pulso o una subdivisión: el modelo copia también la voz si dura más que el pulso |
| **Período máximo** | 10 s | 0.1–30 s (> mínimo); además ≤ m/3 | Lag más largo que puede ser el período | Puede elegir una frase larga: menos segmentos r para la mediana | Fuerza períodos cortos; si el patrón real es más largo, el modelo mezcla partes distintas |

**Diagnóstico en el panel:** período en s y tramas, r (segmentos, incluido el parcial), **BPM equivalente** (60/período, y también ×2 y ×4 por si el período es un compás de 2 o 4 pulsos). El botón **"Ver espectro de ritmo"** abre b(lag) con el rango de búsqueda sombreado, el período elegido y sus múltiplos. En el `.txt` exportado se anotan el período, r y los BPM equivalentes (60/período: los BPM *si* el período fuera un pulso; normalmente es un compás o más).

**REPET-SIM no tiene BPM:** no estima ningún período; elige, para cada trama, las tramas más parecidas estén donde estén. Un BPM ahí sería un cálculo aparte que el filtro no usa.

**r ≥ 3:** la mediana descarta lo que aparece en menos de la mitad de los segmentos. Con r < 3 casi no puede descartar la voz; la interfaz lo avisa. Un fragmento de 20 s con período de 2 s da r ≈ 10.

### Diferencias con la referencia (para el informe)
- **STFT:** el código de referencia usa 2^nextpow2(40 ms) = 2048 con 50 % de solapamiento (y ventana de Hamming); aquí se usa Hann 4096 / 75 % porque es la de FitzGerald (2010), que informa mejor separación con FFT más largas. Los artículos de REPET no fijan la ventana. El salto (1024) coincide con el de la referencia.
- **Sin corte de 100 Hz:** igual que en REPET-SIM (ver arriba).- **Período = lag del máximo.** El código MATLAB de referencia (`repet.periods`) devuelve el índice del máximo + p_mín, que es el lag + 1 (una trama de más); aquí se usa el lag exacto. La búsqueda incluye el lag ⌊m/3⌋ (la referencia lo excluye).
- **b normalizado por b(0):** solo para dibujarlo; no cambia el período elegido.
- **Fragmento demasiado corto** (3·p_mín > m): la referencia daría un rango vacío; aquí se busca en todo el rango válido y el panel avisa si r < 3.

**Limitaciones:**
- Supone un único período para todo el fragmento: cambios de tempo o de sección lo rompen (para eso está REPET-SIM).
- En la autocorrelación sin sesgo los múltiplos del período tienen alturas parecidas: puede elegir 2p o 3p (un compás doble). La separación sigue siendo válida mientras r ≥ 3; conviene revisar el espectro de ritmo.

### REPET original frente a REPET-SIM
| | REPET original | REPET-SIM |
|---|---|---|
| Supuesto sobre el fondo | Se repite con un período fijo | Se repite, no necesariamente periódico |
| Qué tramas entran en la mediana | Las que están a múltiplos de p (una por segmento) | Las k más parecidas (coseno), separadas ≥ d |
| Costo | O(m log m) (autocorrelación con FFT) | O(m²) (matriz de similitud) |
| Qué se muestra para el informe | Espectro de ritmo, período, r | Tramas por mediana, cuántas caben, similitud media |
