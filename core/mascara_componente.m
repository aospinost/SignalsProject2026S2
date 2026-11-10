function M = mascara_componente(F, c)
% MASCARA_COMPONENTE Máscara en [0,1] que define un componente musical
% en todo el fragmento, para cada canal, como producto de pistas independientes:
%
%   M(f,t,ch) = M_banda(f) .* M_caracter(f,t,ch) .* M_repeticion(f,t,ch) .* M_paneo(f,t)
%
%   F : salida de caracteristicas_tf con F.Marm (HPSS, nF x nT x C) y
%       F.Mrep (REPET-SIM o REPET original, nF x nT x C)
%   c : estructura del componente con campos
%         f1, f2, suavF   banda [Hz] y ancho del borde suave [Hz]
%         caracter        'cualquiera' | 'sostenido' | 'percusivo'
%         repeticion      'cualquiera' | 'repetitivo' | 'norepetitivo'
%         pan1, pan2      rango de paneo en [-1, 1];  suavPan: borde suave
%
%   M : nF x nT x C (C = número de canales). Las máscaras de carácter y de
%       repetición son propias de cada canal; la de paneo es común.
%
%   Las máscaras se usan tal como las definen los artículos: HPSS binaria
%   (0 o 1) y REPET suave (entre 0 y 1, ambos métodos). Las de banda y
%   paneo tienen bordes de coseno (suavF, suavPan).
%   Como cada filtro da M y 1 - M, las
%   cuatro combinaciones Sostenido/Percusivo x Repetitivo/No repetitivo
%   suman exactamente 1: juntas reconstruyen la señal original.
%   Ejemplo típico: voz solista = Sostenido x No repetitivo.

    nF = numel(F.f);  nT = numel(F.t);  C = numel(F.S);

    M = single(rampa_coseno(F.f, c.f1, c.f2, c.suavF));     % nF x 1

    switch c.caracter
        case 'sostenido', M = M .* F.Marm;
        case 'percusivo', M = M .* (1 - F.Marm);
    end

    switch c.repeticion
        case 'repetitivo',   M = M .* F.Mrep;
        case 'norepetitivo', M = M .* (1 - F.Mrep);
    end

    if F.estereo && (c.pan1 > -1 || c.pan2 < 1)
        M = M .* single(rampa_coseno(F.pan, c.pan1, c.pan2, c.suavPan));
    end

    if size(M, 2) ~= nT, M = repmat(M, 1, nT, 1); end
    if size(M, 3) ~= C,  M = repmat(M, 1, 1, C);  end
    % size(M, 1:3) y no size(M): MATLAB descarta las dimensiones finales de
    % tamaño 1, así que en mono (C = 1) size(M) da [nF nT] y nunca sería
    % igual a [nF nT 1].
    assert(isequal(size(M, 1:3), [nF nT C]), ...
        'mascara_componente: máscara de %s, se esperaba %d x %d x %d.', ...
        mat2str(size(M)), nF, nT, C);
end
