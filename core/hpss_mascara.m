function [Marm, Lt, Lf] = hpss_mascara(V, fs, Nw, hop, tArm, fPerc, tipo)
% HPSS_MASCARA Máscara de carácter sostenido (armónico) / percusivo por bin
% tiempo-frecuencia y por canal, con filtros de mediana (FitzGerald 2010).
%
%   [Marm, Lt, Lf] = hpss_mascara(V, fs, Nw, hop, tArm, fPerc, tipo)
%
%   Referencia:
%     FitzGerald, D. (2010). Harmonic/percussive separation using median
%       filtering. Proc. DAFx-10, Graz (ecs. 5-9, 12-13). En el artículo:
%       FFT 4096, salto 1024 a 44.1 kHz, filtros de 17 x 17.
%
%   Entradas:
%     V     : magnitud de la STFT de CADA canal, nF x nT x C  (V = |X_c|)
%     fs    : frecuencia de muestreo [Hz]
%     Nw    : ventana / FFT [muestras];  hop : salto [muestras]
%     tArm  : longitud de la mediana en tiempo, l_harm [s]
%     fPerc : longitud de la mediana en frecuencia, l_perc [Hz]
%     tipo  : 'binaria' (por defecto, ecs. 8-9)
%
%   Salidas:
%     Marm : máscara sostenida M_H, nF x nT x C, single, valores 0 o 1
%            (1 = sostenido). La máscara percusiva es 1 - Marm en todo bin.
%     Lt   : l_harm usado [tramas];  Lf : l_perc usado [bins] (impares)
%
%   Algoritmo, por canal:
%     1. Mediana (ec. 5) de longitud impar l: y(n) = mediana de x(n-k : n+k),
%        k = (l-1)/2. Con movmedian, en los bordes la ventana se acorta
%        ('shrink'); el artículo no dice qué hacer en los bordes.
%     2. P = mediana de cada trama a lo largo de la frecuencia, l_perc (ec. 6).
%     3. H = mediana de cada bin a lo largo del tiempo, l_harm (ec. 7).
%     4. Máscara binaria (ecs. 8-9): M_H = 1 si H > P, 0 si no.
%        Empates (H = P, en la práctica bins en silencio): el artículo no los
%        asigna a ninguna parte (M_H = M_P = 0); aquí van a percusivo
%        (M_P = 1 - M_H), para que sostenido + percusivo = original exacto.
%     5. Las máscaras se aplican a la STFT compleja de cada canal (ecs. 12-13)
%        en mascara_componente / aplicar_componentes.
%   El artículo encuentra que la máscara suave con p = 2 (ecs. 10-11) da
%   menos artefactos; con la binaria se espera "ruido musical", sobre todo
%   con ganancias de ±18/±20 dB.

    if nargin < 7 || isempty(tipo), tipo = 'binaria'; end
    if ndims(V) > 3
        error('V debe ser nF x nT x C.');
    end

    Lt = impar(max(3, round(tArm * fs / hop)));
    Lf = impar(max(3, round(fPerc * Nw / fs)));

    H = movmedian(V, Lt, 2);        % por fila (tiempo) y por canal
    P = movmedian(V, Lf, 1);        % por columna (frecuencia) y por canal

    switch tipo
        case 'binaria'
            Marm = single(H > P);
        % case 'suave'
        %   Máscara de Wiener con exponente p (ecs. 10-11):
        %   Marm = H.^p ./ (H.^p + P.^p).  Pendiente: no implementada aún.
        otherwise
            error('hpss_mascara: tipo de máscara "%s" no implementado.', tipo);
    end
end

function n = impar(n)
    if mod(n, 2) == 0, n = n + 1; end
end
