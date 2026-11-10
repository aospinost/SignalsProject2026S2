function m = rampa_coseno(v, a, b, ancho)
% RAMPA_COSENO Ventana 1-D: 1 en [a, b] y transición de coseno elevado
% hacia 0 en un ancho 'ancho' por fuera de cada borde.
%
%   m = rampa_coseno(v, a, b, ancho)
%
%   v     : vector de coordenadas (frecuencias [Hz] o tiempos [s])
%   a, b  : límites de la región (a < b)
%   ancho : ancho de la transición (misma unidad que v); 0 = borde abrupto
%
%   Los bordes suaves evitan el "ringing" (artefactos audibles) que
%   produce una máscara rectangular abrupta: multiplicar en frecuencia
%   por un escalón equivale a convolucionar en tiempo con un sinc.

    m = double(v >= a & v <= b);
    if ancho > 0
        i = v < a & v > a - ancho;
        m(i) = 0.5 + 0.5*cos(pi*(a - v(i))/ancho);
        i = v > b & v < b + ancho;
        m(i) = 0.5 + 0.5*cos(pi*(v(i) - b)/ancho);
    end
end
