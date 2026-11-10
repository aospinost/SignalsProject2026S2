function [x, fs, info] = leer_audio(ruta)
% LEER_AUDIO Carga un archivo de audio completo.
%
%   [x, fs, info] = leer_audio(ruta)
%
%   x    : muestras, N x C (C = canales), en single para ahorrar memoria.
%          Se conservan los canales originales: la mezcla a mono se hace
%          solo donde haga falta (la información estéreo será útil para
%          aislar la voz más adelante).
%   fs   : frecuencia de muestreo [Hz]
%   info : estructura de audioinfo

    if ~isfile(ruta)
        error('No existe el archivo: %s', ruta);
    end
    info = audioinfo(ruta);
    [x, fs] = audioread(ruta);
    x = single(x);
end
