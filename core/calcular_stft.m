function [S, f, t, w] = calcular_stft(x, fs, Nw, hop)
% CALCULAR_STFT Transformada de Fourier de tiempo corto (implementación propia).
%
%   [S, f, t, w] = calcular_stft(x, fs, Nw, hop)
%
%   x   : señal (vector)
%   fs  : frecuencia de muestreo [Hz]
%   Nw  : longitud de la ventana = longitud de la FFT [muestras] (par)
%   hop : salto entre tramas [muestras] (hop <= Nw/2)
%
%   S   : STFT unilateral, (Nw/2+1) x nTramas, complejo
%   f   : frecuencias de cada fila [Hz]
%   t   : instante del CENTRO de cada trama [s], relativo a x(1)
%   w   : ventana usada (Hann periódica)
%
%   Las tramas están centradas: la trama k está centrada en la muestra
%   (k-1)*hop de x. Se rellena con ceros para que la última trama quede
%   centrada en o después de la última muestra; así toda muestra queda
%   cubierta por tramas a ambos lados y calcular_istft reconstruye x
%   exactamente (error ~1e-15). No depende del Signal Processing Toolbox.

    if mod(Nw, 2) ~= 0
        error('Nw debe ser par.');
    end

    x   = double(x(:));
    w   = ventana_hann(Nw);
    pad = Nw/2;

    xp = [zeros(pad, 1); x; zeros(pad + Nw, 1)];
    nTramas = ceil((numel(x) - 1)/hop) + 1;

    % Matriz de índices: columna k = muestras de la trama k
    idx = (1:Nw)' + (0:nTramas-1)*hop;
    X   = xp(idx) .* w;

    S = fft(X, Nw);
    S = S(1:Nw/2 + 1, :);

    f = (0:Nw/2)' * fs / Nw;
    t = (0:nTramas-1) * hop / fs;
end
