function F = caracteristicas_tf(x, fs, Nw, hop)
% CARACTERISTICAS_TF Calcula, una sola vez por fragmento, la STFT de cada
% canal y las magnitudes que usan las pistas de los componentes.
%
%   F = caracteristicas_tf(x, fs, Nw, hop)
%
%   x   : fragmento N x C (C = 1 o 2 canales)
%   fs  : frecuencia de muestreo [Hz]
%   Nw  : ventana / FFT [muestras];  hop : salto [muestras]
%
%   Campos de F:
%     S{c}    STFT del canal c (single, complejo)
%     f, t    frecuencias [Hz] (columna) y centros de trama [s] relativos (fila)
%     w       ventana de análisis
%     Vch     magnitud de cada canal |S_c|, nF x nT x C  (entrada de HPSS y REPET)
%     P2      potencia de la mezcla mono |(S1+S2)/2|^2 (espectrograma, espectro
%             y mapa estéreo)
%     pan     índice de paneo por bin en [-1, 1] (-1 izq., 0 centro, +1 der.)
%     estereo true si los canales difieren de verdad (correlación < 0.99)
%   La máscara de carácter (F.Marm) se calcula aparte con hpss_mascara,
%   porque sus parámetros se ajustan sin recalcular la STFT.
%
%   Paneo: p = (|R| - |L|) / (|R| + |L|). Un instrumento mezclado a la
%   derecha tiene |R| > |L| en sus bins. Si dos fuentes comparten un bin,
%   p da un valor intermedio: es una pista, no una separación perfecta.

    [N, C] = size(x);
    x = double(x);

    F.S = cell(1, C);
    for c = 1:C
        [S, f, t, w] = calcular_stft(x(:, c), fs, Nw, hop);
        F.S{c} = single(S);
    end
    F.f = f;  F.t = t;  F.w = w;
    F.N = N;  F.fs = fs;  F.Nw = Nw;  F.hop = hop;

    Sm = F.S{1};
    for c = 2:C, Sm = Sm + F.S{c}; end
    Sm = Sm / C;
    F.P2   = abs(Sm).^2;
    F.Vch  = zeros([size(Sm) C], 'single');
    for c = 1:C, F.Vch(:, :, c) = abs(F.S{c}); end
    F.Marm = [];      % se calcula con hpss_mascara (nF x nT x C)
    F.Mrep = [];      % se calcula con repet_sim_mascara (nF x nT x C)

    if C >= 2
        r = corrcoef(x(:, 1), x(:, 2));
        F.estereo = r(1, 2) < 0.99;
        aL = abs(F.S{1});  aR = abs(F.S{2});
        F.pan = (aR - aL) ./ (aR + aL + eps('single'));
    else
        F.estereo = false;
        F.pan = zeros(size(Sm), 'single');
    end
end
