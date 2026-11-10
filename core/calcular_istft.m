function y = calcular_istft(S, Nw, hop, N)
% CALCULAR_ISTFT STFT inversa por solapamiento y suma ponderado (WOLA).
%
%   y = calcular_istft(S, Nw, hop, N)
%
%   S   : STFT unilateral (Nw/2+1) x nTramas, como la de calcular_stft
%   Nw  : longitud de ventana / FFT
%   hop : salto entre tramas
%   N   : longitud de la señal original (se recorta el relleno)
%
%   Para cada trama: IFFT (simétrica -> señal real), se multiplica otra vez
%   por la ventana de síntesis y se suma en su posición. Al final se divide
%   por la suma de ventanas al cuadrado:
%
%       y[n] = sum_k w[n-k*hop] * ifft(S_k)[n-k*hop] / sum_k w^2[n-k*hop]
%
%   Si S no fue modificada, y = x exactamente. Si S fue modificada (máscara),
%   este es el estimador de mínimos cuadrados de Griffin y Lim (1984): la
%   señal cuya STFT está más cerca de la STFT modificada.

    w  = ventana_hann(Nw);
    nT = size(S, 2);

    % Espectro bilateral a partir del unilateral (simetría hermítica)
    Sfull = [S; conj(S(end-1:-1:2, :))];
    X = ifft(Sfull, Nw, 1, 'symmetric') .* w;

    L   = (nT - 1)*hop + Nw;
    idx = (1:Nw)' + (0:nT-1)*hop;
    y    = accumarray(idx(:), X(:), [L 1]);
    wsum = accumarray(idx(:), repmat(w.^2, nT, 1), [L 1]);

    y = y ./ max(wsum, 1e-12);

    pad = Nw/2;
    y = y(pad + (1:N));
end
