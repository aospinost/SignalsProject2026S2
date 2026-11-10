function [t, lo, hi] = envolvente_minmax(x, fs, nBloques)
% ENVOLVENTE_MINMAX Envolvente mínimo/máximo para dibujar señales largas.
%
%   [t, lo, hi] = envolvente_minmax(x, fs, nBloques)
%
%   Divide x en nBloques bloques y devuelve el mínimo y el máximo de cada
%   uno. Dibujar esta envolvente es visualmente idéntico a dibujar los
%   millones de muestras de una canción completa, pero mucho más rápido.
%   t es el centro de cada bloque [s], relativo a x(1).

    x = x(:);
    N = numel(x);
    B = floor(N / nBloques);

    if B < 2                         % señal corta: se devuelve tal cual
        t  = (0:N-1)' / fs;
        lo = x;  hi = x;
        return;
    end

    M  = reshape(x(1:B*nBloques), B, nBloques);
    lo = min(M, [], 1)';
    hi = max(M, [], 1)';
    t  = ((0:nBloques-1)' * B + B/2) / fs;
end
