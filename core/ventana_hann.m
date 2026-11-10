function w = ventana_hann(N)
% VENTANA_HANN Ventana de Hann periódica de longitud N (columna).
%   w[n] = 0.5 - 0.5*cos(2*pi*n/N),  n = 0..N-1
%
%   La versión periódica (y no la simétrica) es la adecuada para STFT:
%   con solapamientos de 50 % o 75 % la suma de ventanas desplazadas es
%   constante (condición COLA), lo que permitirá reconstruir la señal.

    n = (0:N-1)';
    w = 0.5 - 0.5*cos(2*pi*n/N);
end
