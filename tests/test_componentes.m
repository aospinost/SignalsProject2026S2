function test_componentes()
% TEST_COMPONENTES Con audio real (5 s de Music/) y máscaras reales de HPSS
% (binaria, por canal) y REPET (ambos métodos, suave, por canal):
%   - las cuatro combinaciones Sostenido/Percusivo x Repetitivo/No
%     repetitivo suman 1 en todo bin (error < 1e-5);
%   - aplicar_componentes con todas las ganancias en 0 dB devuelve el
%     original (error < 1e-6).
%   STFT por defecto de la interfaz (Hann 4096, 75 %).

    raiz = fileparts(fileparts(mfilename('fullpath')));
    [x, fs] = leer_audio(fullfile(raiz, 'Music', 'Feliz Navidad.mp3'));
    x  = double(x(round(30*fs) + (1:round(5*fs)), :));
    Nw = str2double(AnalizadorApp.STFT_VENTANA);
    hop = round(Nw * (1 - AnalizadorApp.STFT_SOLAPE));

    F = caracteristicas_tf(x, fs, Nw, hop);
    F.Marm = hpss_mascara(F.Vch, fs, Nw, hop, AnalizadorApp.HPSS_T, AnalizadorApp.HPSS_F);

    base = struct('id', 0, 'f1', 0, 'f2', fs/2, 'suavF', 0, 'caracter', '', ...
        'repeticion', '', 'pan1', -1, 'pan2', 1, 'suavPan', 0.1, 'g', 0);
    for metodo = {'sim', 'original'}
        if strcmp(metodo{1}, 'sim')
            F.Mrep = repet_sim_mascara(F.Vch, fs, hop, AnalizadorApp.REP_K, ...
                AnalizadorApp.REP_D, AnalizadorApp.REP_U);
        else
            F.Mrep = repet_mascara(F.Vch, fs, hop, [AnalizadorApp.REP_PMIN AnalizadorApp.REP_PMAX]);
        end
        comps = repmat(base, 1, 0);
        suma = 0;
        for car = {'sostenido', 'percusivo'}
            for rep = {'repetitivo', 'norepetitivo'}
                c = base;  c.id = numel(comps) + 1;
                c.caracter = car{1};  c.repeticion = rep{1};
                comps(end+1) = c; %#ok<AGROW>
                suma = suma + double(mascara_componente(F, c));
            end
        end
        err = max(abs(suma(:) - 1));
        fprintf('  %s: suma de las 4 combinaciones, error máx. %.2e\n', metodo{1}, err);
        assert(err < 1e-5, '%s: las 4 combinaciones no suman 1 (error %.2e)', metodo{1}, err);

        res = aplicar_componentes(F, comps, false);
        e0 = max(abs(double(res.y(:)) - x(:)));
        fprintf('  %s: 4 componentes a 0 dB, error máx. frente al original %.2e\n', metodo{1}, e0);
        assert(e0 < 1e-6, '%s: con 0 dB no se recupera el original (error %.2e)', metodo{1}, e0);
    end
end
