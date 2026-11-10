function [Mrep, info] = repet_mascara(V, fs, hop, rangoPeriodo)
% REPET_MASCARA Máscara suave del fondo repetitivo por bin tiempo-frecuencia
% y por canal, según el REPET original (período de repetición único).
%
%   [Mrep, info] = repet_mascara(V, fs, hop, rangoPeriodo)
%
%   Referencias:
%     Rafii, Z. y Pardo, B. (2013). REpeating Pattern Extraction Technique
%       (REPET): a simple method for music/voice separation. IEEE TASLP
%       21(1), 71-82.
%     Rafii, Z., Liutkus, A. y Pardo, B. (2014). REPET for background/
%       foreground separation in audio. En Blind Source Separation,
%       Springer, cap. 14, sec. 14.2 (ecs. 14.1 a 14.4).
%     Código de referencia de los autores (REPET-MATLAB, función original):
%       rango de período [1, 10] s.
%
%   Entradas:
%     V            : magnitud de la STFT de CADA canal, nF x nT x C (V = |X_c|)
%     fs           : frecuencia de muestreo [Hz]
%     hop          : salto de la STFT [muestras]
%     rangoPeriodo : [pMin pMax] rango de búsqueda del período [s]
%                    (por defecto [1 10], el del código de referencia)
%
%   Salidas:
%     Mrep : máscara suave en [0, 1], nF x nT x C.  1 = fondo repetitivo,
%            1 - Mrep = primer plano no repetitivo (p. ej. la voz).
%     info : b (espectro de ritmo, lags >= 1, normalizado por b(0)),
%            lagS (lags [s]), periodo [tramas], periodoS [s], r (número de
%            segmentos, incluido el parcial), bpmEquivalente (60/periodoS:
%            los BPM SI el período fuera un pulso; suele ser un compás o más),
%            rangoTramas (lags buscados [tramas]).
%
%   Algoritmo:
%     1. Espectro de ritmo (ec. 14.1): espectrograma de los canales
%        promediados y elevado al cuadrado, mean(V,3).^2 (como el código de
%        referencia); autocorrelación de cada fila en el tiempo, SIN SESGO
%        (el lag l se divide por m - l términos), con la FFT de longitud 2m
%        para que no sea circular; b = media de las filas.
%     2. Período: lag del máximo de b dentro del rango, limitado a m/3
%        tramas (como la referencia: así hay al menos 3 segmentos).
%     3. Modelo del segmento repetitivo (ec. 14.2): V de cada canal en r
%        segmentos de p tramas; S = mediana elemento a elemento. El último
%        segmento incompleto se rellena con NaN y la mediana los ignora
%        (equivale a la referencia).
%     4. Modelo del espectrograma repetitivo (ec. 14.3): W = min(S, V).
%     5. Máscara suave (ec. 14.4): M = (W + eps) ./ (V + eps).
%   Sin corte en frecuencia ni afilado (ver docs/FILTROS.md, Diferencias).
%   Costo: O(m log m) por la autocorrelación con FFT.

    if nargin < 4 || isempty(rangoPeriodo), rangoPeriodo = [1 10]; end
    if ndims(V) > 3
        error('V debe ser nF x nT x C.');
    end
    V = double(V);
    [nF, nT, C] = size(V);

    % 1. Espectro de ritmo
    P = mean(V, 3).^2;                       % nF x nT
    A = abs(fft(P.', 2*nT)).^2;              % FFT por fila (en columnas)
    A = real(ifft(A));
    A = A(1:nT, :) ./ (nT:-1:1)';            % autocorrelación sin sesgo, lags 0..nT-1
    b = mean(A, 2);                          % nT x 1, b(1) = lag 0
    b = b / (b(1) + eps);

    % 2. Período en tramas
    rango = round(rangoPeriodo * fs / hop);
    lo = max(1, rango(1));
    hi = min(rango(2), floor(nT / 3));       % al menos 3 segmentos
    if hi < lo
        % Fragmento demasiado corto para 3 repeticiones del período mínimo:
        % se busca en todos los lags válidos del rango (r puede quedar < 3).
        hi = min(max(rango(2), lo), nT - 1);
        lo = min(lo, hi);
    end
    lags = (lo:hi)';
    [~, i] = max(b(lags + 1));
    p = max(1, lags(i));

    % 3-5. Modelo repetitivo y máscara por canal
    r = ceil(nT / p);
    Mrep = zeros(nF, nT, C, 'single');
    for c = 1:C
        Vc  = [V(:, :, c), nan(nF, r*p - nT)];
        Vc  = reshape(Vc, nF, p, r);
        S   = median(Vc, 3, 'omitnan');                  % nF x p
        W   = min(Vc, S);                                % NaN del relleno se conservan
        M   = (W + eps) ./ (Vc + eps);
        M   = reshape(M, nF, r*p);
        Mrep(:, :, c) = single(M(:, 1:nT));
    end

    % Diagnóstico
    info.b              = b(2:end);
    info.lagS           = (1:nT-1)' * hop / fs;
    info.periodo        = p;
    info.periodoS       = p * hop / fs;
    info.r              = r;
    info.bpmEquivalente = 60 / info.periodoS;
    info.rangoTramas    = [lo hi];
end
