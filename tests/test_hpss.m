function test_hpss()
% TEST_HPSS Prueba core/hpss_mascara.m (FitzGerald 2010, máscara binaria por
% canal) con señales sintéticas.
%
%   Señal: senos sostenidos (440, 880, 1320 Hz) + un tren de clics cada
%   0.5 s, estéreo con ganancias distintas por canal. STFT Hann 4096,
%   salto 1024, fs = 44.1 kHz (la del artículo). Se comprueba:
%     - Marm es nF x nT x C, single, solo 0 o 1;
%     - ≈ 1 en los bins de los senos (lejos de los clics) y ≈ 0 en las
%       tramas de los clics (lejos de los senos), en ambos canales;
%     - empates: un canal en silencio da Marm = 0 (percusivo) y
%       Sostenido + Percusivo = 1 exactamente;
%     - longitudes por defecto: 17 x 17 a 44.1 kHz y 19 x 15 a 48 kHz.

    fs = 44100;  Nw = 4096;  hop = 1024;
    tH = AnalizadorApp.HPSS_T;  fP = AnalizadorApp.HPSS_F;

    % Longitudes por defecto
    [~, Lt, Lf] = hpss_mascara(ones(8, 8, 'single'), 44100, Nw, hop, tH, fP);
    fprintf('  44.1 kHz: %d tramas x %d bins\n', Lt, Lf);
    assert(Lt == 17 && Lf == 17, 'A 44.1 kHz se esperaba 17 x 17');
    [~, Lt, Lf] = hpss_mascara(ones(8, 8, 'single'), 48000, Nw, hop, tH, fP);
    fprintf('  48 kHz:   %d tramas x %d bins\n', Lt, Lf);
    assert(Lt == 19 && Lf == 15, 'A 48 kHz se esperaba 19 x 15');

    % Señal sintética
    dur = 4;  N = round(dur * fs);  t = (0:N-1)' / fs;
    fSen = [440 880 1320];
    x = 0.2 * sum(sin(2*pi*fSen.*t), 2);
    tClic = 0.25:0.5:dur-0.25;
    x(round(tClic * fs) + 1) = x(round(tClic * fs) + 1) + 1;
    xs = [0.5*x, 1.0*x];

    F = caracteristicas_tf(xs, fs, Nw, hop);
    [M, Lt, Lf] = hpss_mascara(F.Vch, fs, Nw, hop, tH, fP);
    nF = numel(F.f);  nT = numel(F.t);
    assert(isequal(size(M, [1 2 3]), [nF nT 2]), 'Tamaño de Marm incorrecto');
    assert(isa(M, 'single'), 'Marm debe ser single');
    assert(all(M(:) == 0 | M(:) == 1), 'Marm debe valer solo 0 o 1');

    % Bins de los senos en tramas lejos de los clics y de los bordes;
    % tramas de los clics en bins lejos de los senos (2-8 kHz)
    [TT, FF] = meshgrid(F.t, F.f);
    dClic = min(abs(TT(:)' - tClic(:)), [], 1);  dClic = reshape(dClic, size(TT));
    enSeno = false(size(TT));
    for f0 = fSen, enSeno = enSeno | abs(FF - f0) <= F.fs/Nw; end
    lejosBorde = TT > (Lt/2 + 2)*hop/fs & TT < dur - (Lt/2 + 2)*hop/fs;
    mSeno = enSeno & dClic > Nw/fs & lejosBorde;
    mClic = dClic <= hop/(2*fs) & FF >= 2000 & FF <= 8000;
    for c = 1:2
        Mc = double(M(:, :, c));
        ms = mean(Mc(mSeno));  mc = mean(Mc(mClic));
        fprintf('  canal %d: Marm medio en senos %.3f, en clics %.3f\n', c, ms, mc);
        assert(ms > 0.95, 'Marm en los senos %.3f <= 0.95', ms);
        assert(mc < 0.05, 'Marm en los clics %.3f >= 0.05', mc);
    end

    % Empates: canal en silencio -> percusivo; sostenido + percusivo = 1 exacto
    F = caracteristicas_tf([x, zeros(N, 1)], fs, Nw, hop);
    F.Marm = hpss_mascara(F.Vch, fs, Nw, hop, tH, fP);
    F.Mrep = ones(size(F.Marm), 'single');
    assert(all(F.Marm(:, :, 2) == 0, 'all'), 'Canal en silencio: Marm debe ser 0 (percusivo)');
    base = struct('f1', 0, 'f2', fs/2, 'suavF', 0, 'repeticion', 'cualquiera', ...
        'pan1', -1, 'pan2', 1, 'suavPan', 0.1);
    cS = base;  cS.caracter = 'sostenido';
    cP = base;  cP.caracter = 'percusivo';
    suma = double(mascara_componente(F, cS)) + double(mascara_componente(F, cP));
    err = max(abs(suma(:) - 1));
    fprintf('  canal en silencio: Marm = 0; Sostenido + Percusivo, error máx. %g\n', err);
    assert(err == 0, 'Sostenido + Percusivo no suma 1 exactamente (error %g)', err);
end
