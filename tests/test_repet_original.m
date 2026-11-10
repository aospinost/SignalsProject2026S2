function test_repet_original()
% TEST_REPET_ORIGINAL Prueba core/repet_mascara.m con señales sintéticas de
% período conocido.
%
%   Señal: un bucle de 2.0 s (ruido de banda ancha + dos tonos) repetido
%   exactamente, más notas cortas que no se repiten, en bandas propias.
%   fs = 16384 Hz, ventana 1024, salto 512: 2.0 s = 64 tramas exactas.
%   Se comprueba:
%     - período detectado = 2.0 s ± un salto (o un múltiplo entero dentro
%       del rango, que se informa);
%     - tamaño nF x nT x C y valores en [0, 1], en mono y en estéreo;
%     - longitud que no es múltiplo del período (19.3 s);
%     - máscara ≈ 1 en el bucle y baja en las notas, en cada canal;
%     - las cuatro combinaciones Sostenido/Percusivo x Repetitivo/No
%       repetitivo suman 1 con el REPET original (mascara_componente).

    fs = 16384;  Nw = 1024;  hop = 512;  T0 = 2.0;
    pasoS = hop / fs;

    for dur = [20 19.3]
        [x, notas] = senal_sintetica(fs, T0, dur);
        for C = [1 2]
            if C == 2
                xs = [0.6*x, 1.0*x];                  % ganancias distintas por canal
            else
                xs = x;
            end
            F = caracteristicas_tf(xs, fs, Nw, hop);
            [M, info] = repet_mascara(F.Vch, fs, hop, [1 10]);

            nF = numel(F.f);  nT = numel(F.t);
            assert(isequal(size(M, [1 2 3]), [nF nT C]), 'Tamaño de Mrep incorrecto');
            assert(all(M(:) >= 0 & M(:) <= 1 + 1e-6), 'Mrep fuera de [0, 1]');

            mult = info.periodoS / T0;
            assert(abs(mult - round(mult)) * T0 <= pasoS + 1e-9 && round(mult) >= 1, ...
                'Período detectado %.3f s no es múltiplo de %.1f s', info.periodoS, T0);
            fprintf('  dur %.1f s, C = %d: período %.4f s (%d tramas, %d x %.1f s), r = %d\n', ...
                dur, C, info.periodoS, info.periodo, round(mult), T0, info.r);

            % Bins de notas y bins solo de fondo (lejos de las notas en t y f)
            [mNota, mFondo] = mascaras_verdad(F, notas);
            for c = 1:C
                Mc = double(M(:, :, c));
                mf = mean(Mc(mFondo));  mn = mean(Mc(mNota));
                fprintf('    canal %d: máscara media fondo %.3f, notas %.3f\n', c, mf, mn);
                assert(mf > 0.9, 'Máscara media en el fondo %.3f <= 0.9', mf);
                assert(mn < 0.3, 'Máscara media en las notas %.3f >= 0.3', mn);
            end
        end
    end

    % Fragmento demasiado corto para 3 repeticiones del período mínimo:
    % no falla, la máscara sigue siendo válida y r < 3 (la interfaz avisa)
    Fc = caracteristicas_tf(x(1:round(4*fs)), fs, Nw, hop);
    [Mc, ic] = repet_mascara(Fc.Vch, fs, hop, [2.5 10]);
    assert(all(Mc(:) >= 0 & Mc(:) <= 1 + 1e-6), 'Mrep fuera de [0, 1] (fragmento corto)');
    assert(ic.r < 3, 'Se esperaba r < 3 con un fragmento de 4 s y p_mín = 2.5 s');
    fprintf('  fragmento de 4 s, p_mín 2.5 s: período %.3f s, r = %d (aviso r < 3)\n', ic.periodoS, ic.r);

    % Las cuatro combinaciones suman 1 con REPET original y HPSS real
    F = caracteristicas_tf([0.6*x, x], fs, Nw, hop);
    F.Marm = hpss_mascara(F.Vch, fs, Nw, hop, 0.4, 180);
    F.Mrep = repet_mascara(F.Vch, fs, hop, [1 10]);
    suma = 0;
    for car = {'sostenido', 'percusivo'}
        for rep = {'repetitivo', 'norepetitivo'}
            c = struct('f1', 0, 'f2', fs/2, 'suavF', 0, 'caracter', car{1}, ...
                'repeticion', rep{1}, 'pan1', -1, 'pan2', 1, 'suavPan', 0.1);
            suma = suma + double(mascara_componente(F, c));
        end
    end
    err = max(abs(suma(:) - 1));
    fprintf('  suma de las 4 combinaciones: error máx. %.2e\n', err);
    assert(err < 1e-5, 'Las 4 combinaciones no suman 1 (error %.2e)', err);
end

function [x, notas] = senal_sintetica(fs, T0, dur)
    rng(1);
    nL = round(T0 * fs);
    t  = (0:nL-1)' / fs;
    % Bucle: ruido suave de banda ancha + dos tonos con envolvente propia
    bucle = 0.02 * randn(nL, 1) ...
          + 0.3 * sin(2*pi*220*t) .* (t < 0.8) ...
          + 0.3 * sin(2*pi*440*t) .* (t >= 1.0 & t < 1.6);
    N = round(dur * fs);
    x = repmat(bucle, ceil(N / nL), 1);
    x = x(1:N);
    % Notas que no se repiten: 0.3 s, frecuencias e instantes distintos
    notas = [1.3 2500; 4.7 3100; 8.2 2800; 12.5 3500; 16.1 2200];
    tn = (0:round(0.3*fs)-1)' / fs;
    for k = 1:size(notas, 1)
        i0 = round(notas(k, 1) * fs);
        if i0 + numel(tn) > N, continue; end
        x(i0 + (1:numel(tn))) = x(i0 + (1:numel(tn))) + 0.5 * sin(2*pi*notas(k, 2)*tn);
    end
end

function [mNota, mFondo] = mascaras_verdad(F, notas)
    [TT, FF] = meshgrid(F.t, F.f);
    mNota  = false(size(TT));
    cerca  = false(size(TT));
    for k = 1:size(notas, 1)
        enT = TT >= notas(k, 1) + 0.05 & TT <= notas(k, 1) + 0.25;
        mNota = mNota | (enT & abs(FF - notas(k, 2)) <= 20);
        cerca = cerca | (TT >= notas(k, 1) - 0.1 & TT <= notas(k, 1) + 0.4 ...
                         & abs(FF - notas(k, 2)) <= 200);
    end
    % Fondo: bins de los tonos del bucle (220/440 Hz) lejos de las notas
    mFondo = (abs(FF - 220) <= 10 | abs(FF - 440) <= 10) & ~cerca;
end
