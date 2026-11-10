function [Mrep, info] = repet_sim_mascara(V, fs, hop, k, d, t)
% REPET_SIM_MASCARA Máscara suave de "lo que se repite" (fondo repetitivo)
% por bin tiempo-frecuencia y por canal, según REPET-SIM.
%
%   [Mrep, info] = repet_sim_mascara(V, fs, hop, k, d, t)
%
%   Referencias:
%     Rafii, Z. y Pardo, B. (2012). Music/voice separation using the
%       similarity matrix. ISMIR, Porto.
%     Rafii, Z., Liutkus, A. y Pardo, B. (2014). REPET for background/
%       foreground separation in audio. En Blind Source Separation,
%       Springer, cap. 14, sec. 14.4 (ecs. 14.4, 14.7, 14.8 y 14.9).
%     Código de referencia de los autores (REPET-MATLAB, función sim):
%       t = 0, d = 1 s, k = 100.
%
%   Entradas:
%     V   : magnitud de la STFT de CADA canal, nF x nT x C  (V = |X_c|)
%     fs  : frecuencia de muestreo [Hz];  hop : salto de la STFT [muestras]
%     k   : máximo de tramas repetidas por trama ("similarity number")
%     d   : distancia mínima entre dos tramas repetidas [s] ("similarity distance")
%     t   : similitud mínima, coseno en [0, 1) ("similarity threshold")
%
%   Salidas:
%     Mrep : máscara suave en [0, 1], nF x nT x C.  1 = fondo repetitivo,
%            1 - Mrep = primer plano no repetitivo (p. ej. la voz).
%     info : diagnóstico (ver al final)
%
%   Algoritmo (igual que el artículo y el código de referencia):
%     1. Matriz de similitud (ec. 14.8): coseno entre las tramas del
%        espectrograma PROMEDIADO entre canales,  S = Vn' * Vn.
%     2. Tramas repetidas de la trama j: picos (máximos locales) de la
%        columna j de S, más altos que t, separados al menos d, los k más
%        altos. Equivale a findpeaks(S(:,j), 'MinPeakHeight', t,
%        'MinPeakDistance', D, 'SortStr', 'descend', 'NPeaks', k), que es
%        lo que usa el código de referencia; aquí se implementa sin el
%        Signal Processing Toolbox. La propia trama j (S(j,j) = 1) es un
%        pico y queda incluida, igual que en la referencia.
%     3. Por CANAL: modelo inicial U(:,j) = mediana de V(:, J_j)  (ec. 14.9).
%     4. Modelo refinado W = min(U, V)                            (ec. 14.7).
%     5. Máscara suave M = (W + eps) ./ (V + eps)                  (ec. 14.4;
%        el eps es el del código de referencia: un bin en silencio da M = 1).
%   El primer plano es la mezcla menos el fondo; con la máscara, 1 - M.
%
%   No se aplica ningún corte en frecuencia ni ningún afilado de la máscara.
%   Costo: O(m^2) en memoria y tiempo (m = número de tramas), por la matriz S.

    if ndims(V) > 3
        error('V debe ser nF x nT x C.');
    end
    V  = double(V);
    [nF, nT, C] = size(V);
    k  = max(1, round(k));
    D  = max(1, round(d * fs / hop));          % distancia mínima en tramas

    % 1. Matriz de similitud sobre el promedio de canales (single: con una
    %    canción completa S puede tener ~10^4 x 10^4 elementos).
    Vm = mean(V, 3);
    Vn = single(Vm ./ (sqrt(sum(Vm.^2, 1)) + eps));
    S  = Vn' * Vn;

    % 2. Tramas repetidas de cada trama
    J = cell(1, nT);
    usadas = zeros(1, nT);
    simMedia = nan(1, nT);
    for j = 1:nT
        J{j} = picos_columna(double(S(:, j)), t, D, k);
        if isempty(J{j})
            % Sin picos válidos (fragmento demasiado corto, umbral muy alto):
            % la mediana de la propia trama da W = V -> M = 1 (no se extrae nada).
            J{j} = j;
        end
        usadas(j) = numel(J{j});
        otras = J{j}(J{j} ~= j);
        if ~isempty(otras)
            simMedia(j) = mean(S(otras, j));
        end
    end

    % 3-5. Modelo y máscara por canal
    Mrep = zeros(nF, nT, C, 'single');
    for c = 1:C
        Vc = V(:, :, c);
        U  = zeros(nF, nT);
        for j = 1:nT
            U(:, j) = median(Vc(:, J{j}), 2);
        end
        W = min(U, Vc);
        Mrep(:, :, c) = single((W + eps) ./ (Vc + eps));
    end

    % Diagnóstico
    info.D              = D;                          % distancia mínima [tramas]
    info.tramasPromedio = mean(usadas);               % tramas por mediana (incluye la propia)
    info.tramasMaximas  = floor((nT - 1) / D) + 1;    % las que caben con esa distancia
    info.limitaK        = mean(usadas >= k);          % fracción de tramas en que k fue el límite
    info.similitudMedia = mean(simMedia, 'omitnan');  % coseno medio de las tramas elegidas (sin la propia)
end

function idx = picos_columna(s, t, D, k)
% Picos de s al estilo de findpeaks (Signal Processing Toolbox):
%   - pico = muestra mayor que sus dos vecinas; en una meseta cuenta solo
%     su primera muestra; los extremos de la señal nunca son picos;
%   - solo picos con altura > t ('MinPeakHeight');
%   - de mayor a menor, se descartan los que estén a menos de D muestras de
%     un pico ya aceptado ('MinPeakDistance', |i - i_aceptado| < D);
%   - se devuelven como mucho los k más altos ('NPeaks', 'SortStr').
    idx = zeros(0, 1);
    if numel(s) < 3, return; end

    % Colapsar mesetas: inicio de cada tramo de valores iguales
    r  = [1; find(diff(s) ~= 0) + 1];
    sv = s(r);
    q  = 2:numel(r) - 1;
    q  = q(sv(q) > sv(q - 1) & sv(q) > sv(q + 1));
    cand = r(q);
    cand = cand(s(cand) > t);
    if isempty(cand), return; end

    [~, orden] = sort(s(cand), 'descend');
    cand = cand(orden);

    acept   = zeros(min(k, numel(cand)), 1);
    borrado = false(size(cand));
    n = 0;
    for q = 1:numel(cand)
        if borrado(q), continue; end
        n = n + 1;
        acept(n) = cand(q);
        if n == k, break; end
        borrado = borrado | abs(cand - cand(q)) < D;
    end
    idx = acept(1:n);
end
