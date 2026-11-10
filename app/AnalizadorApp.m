classdef AnalizadorApp < handle
% ANALIZADORAPP Interfaz principal del proyecto.
%
%   app = AnalizadorApp(carpetaMusica)
%
%   Izquierda : archivo, fragmento, reproducción (A/B), análisis STFT
%               (recalcula) y visualización (solo dibujo).
%   Centro    : vista global, señal temporal, espectrograma y espectro.
%   Derecha   : componentes musicales, sus propiedades, filtros de carácter
%               y de repetición, mapa estéreo (paneo vs. frecuencia) y
%               resultados medidos.
%
%   Un COMPONENTE es una máscara que cubre todo el fragmento:
%       M = banda(f) · carácter(t,f) · repetición(t,f,canal) · paneo(t,f)
%   (ver core/mascara_componente.m). Se le aplica una ganancia en dB.
%   Por defecto: banda 0–Nyquist, paneo [-1, 1], carácter "Cualquiera".
%   Dos ejes independientes clasifican cada bin:
%     Carácter   (HPSS, FitzGerald 2010):      sostenido / percusivo
%                (máscara binaria propia de cada canal)
%     Repetición (REPET-SIM, Rafii-Pardo 2012, o REPET original, Rafii-Pardo
%                2013; Rafii-Liutkus-Pardo 2014): repetitivo / no
%                repetitivo (máscara propia de cada canal)
%   La voz solista suele ser Sostenido x No repetitivo. Los parámetros de
%   ambos filtros son globales: así las cuatro combinaciones suman 1.
%
%   Interacción:
%     - Fragmento por defecto: 20 s (enunciado). Cambiar el inicio o hacer
%       clic en la vista global coloca una ventana de 20 s; arrastrar elige
%       un rango libre. Más de 60 s (o "Canción completa") pide confirmación,
%       porque el costo de memoria y tiempo crece con la duración.
%     - Espectrograma / señal: clic = saltar la reproducción.
%     - Exportar WAV: guarda la versión procesada en exports/ junto con un
%       .txt con todos los parámetros (reproducibilidad).
%     - Mapa estéreo: clic = centrar el rango de paneo del componente ahí.
%     - Teclas: espacio = reproducir/pausar, B = alternar original/procesada.
%
%   Procesamiento NO destructivo: la señal original nunca se modifica; la
%   salida se recalcula como f(original, lista de componentes).

    properties (Constant)
        DURACION_MAX = 20      % [s] fragmento por defecto (enunciado: máximo 20 s)
        LIMITE_CONFIRMAR = 60  % [s] fragmentos más largos piden confirmación
        DURACION_MIN = 0.1     % [s]
        EXTENSIONES  = {'*.wav'; '*.mp3'; '*.flac'; '*.m4a'; '*.ogg'}
        % HPSS: filtros de 17 x 17 de FitzGerald (2010) con 4096/1024 a 44.1 kHz,
        % en unidades físicas (a 48 kHz: 19 tramas x 15 bins)
        HPSS_T = 0.40          % [s]  l_harm, mediana en tiempo
        HPSS_F = 180           % [Hz] l_perc, mediana en frecuencia
        % REPET-SIM: valores del código de referencia (Rafii, función sim)
        REP_K  = 100           % máx. tramas repetidas por trama (similarity number)
        REP_D  = 1.0           % distancia mínima entre tramas repetidas [s]
        REP_U  = 0             % similitud mínima (coseno; similarity threshold)
        % REPET original: rango de período del código de referencia (función original)
        REP_PMIN = 1           % [s]
        REP_PMAX = 10          % [s]
        % STFT por defecto: la de FitzGerald (2010), Hann 4096 con 75 % de
        % solapamiento. El salto sigue siendo 1024 (igual que con 2048 / 50 %),
        % así que el número de tramas y todos los parámetros en segundos (HPSS,
        % REPET) no cambian; solo mejora la resolución en frecuencia.
        STFT_VENTANA = '4096'
        STFT_SOLAPE = 0.75
        N_PAN  = 41            % columnas del mapa estéreo
        MAX_HISTORIAL = 100

        T = struct( ...
            'fondo',      [0.106 0.114 0.133], ...
            'panel',      [0.149 0.161 0.188], ...
            'control',    [0.212 0.227 0.263], ...
            'ejes',       [0.078 0.086 0.102], ...
            'texto',      [0.905 0.914 0.933], ...
            'tenue',      [0.580 0.604 0.655], ...
            'rejilla',    [0.420 0.440 0.490], ...
            'acento',     [0.247 0.584 0.965], ...
            'peligro',    [0.788 0.247 0.275], ...
            'onda',       [0.420 0.718 0.988], ...
            'procesada',  [0.463 0.851 0.549], ...
            'seleccion',  [1.000 0.722 0.243], ...
            'cursor',     [1.000 0.310 0.341], ...
            'fuente',     'Segoe UI')
    end

    properties (Access = private)
        % --- Izquierda ---
        Fig
        DdArchivo
        LblInfo
        EdInicio
        EdFin
        LblDuracion
        BtnPlay
        BtnPausa
        BtnStop
        ChkRepetir
        LblPosicion
        BtnVerOrig
        BtnVerProc
        DdVentana
        DdSolape
        DdFmax
        DdRango
        DdColormap
        LblStft
        % --- Filtros (columna derecha) ---
        EdHpssT
        EdHpssF
        LblHpss
        GridRep
        DdRepMetodo
        EdRepK
        EdRepD
        EdRepU
        EdRepPmin
        EdRepPmax
        CtrlRepSim = {}
        CtrlRepOrig = {}
        LblRep
        BtnRestaurarRep
        BtnRitmo
        % --- Centro ---
        AxGlobal
        AxSenal
        AxEspectro
        AxEspec
        LblEstado
        % --- Derecha ---
        BtnNuevo
        BtnEliminar
        LstComp
        BtnDeshacer
        BtnRevertir
        EdF1
        EdF2
        DdCaracter
        DdRepeticion
        EdPan1
        EdPan2
        SpGanancia
        ChkMascara
        LblDerivadas
        ControlesProp = {}
        AxPan
        ChkSilenciar
        LblResultado
        BtnExportar

        % --- Gráficos ---
        hEnvolvente
        hRegion
        hBordes
        hSenal
        hEspOrig
        hEspProc
        hImagen
        hMascara
        hColorbar
        hCursores
        hPanImg
        hPanSel

        % --- Audio ---
        CarpetaMusica
        CarpetaExport
        Ruta = ''
        Audio             % N x C (single), nunca se modifica
        Mono              % N x 1 (single)
        Fs = 44100
        Seleccion = [0 0] % [t_ini t_fin] absolutos [s]
        Feat = []         % caracteristicas_tf del fragmento actual
        SdB = []          % espectrograma original [dBFS]
        HpssT             % [s]  parámetro actual del carácter
        HpssF             % [Hz] parámetro actual del carácter
        Rep               % parámetros de repetición: metodo, k, d, u (SIM), pMin, pMax (original)

        % --- Componentes ---
        Componentes
        CompSel = []
        SigId = 1
        Historial = {}
        Resultado = []
        Vista = 'original'

        % --- Reproducción ---
        Player
        Reloj
        Offset = 0
        Estado = 'detenido'
        Ancla = 0
    end

    % =====================================================================
    methods
        function app = AnalizadorApp(carpetaMusica)
            if nargin < 1, carpetaMusica = pwd; end
            app.CarpetaMusica = carpetaMusica;
            app.CarpetaExport = fullfile(fileparts(carpetaMusica), 'exports');
            app.Componentes = AnalizadorApp.componenteVacio();
            app.HpssT = app.HPSS_T;
            app.HpssF = app.HPSS_F;
            app.Rep = AnalizadorApp.repetPorDefecto('sim');

            app.construirInterfaz();
            app.listarArchivos();
            app.actualizarPropiedades();
            app.actualizarResultado();

            if ~isempty(app.DdArchivo.ItemsData)
                app.cargarArchivo(app.DdArchivo.Value);
            else
                app.mostrarEstado(sprintf(['No se encontraron canciones en "%s". ' ...
                    'Use "Examinar…" para abrir un archivo.'], carpetaMusica));
            end
        end

        function delete(app)
            app.liberarPlayer();
            if ~isempty(app.Fig) && isvalid(app.Fig)
                delete(app.Fig);
            end
        end
    end

    % =====================================================================
    %  CONSTRUCCIÓN DE LA INTERFAZ
    % =====================================================================
    methods (Access = private)

        function construirInterfaz(app)
            T = app.T;
            pantalla = get(groot, 'ScreenSize');
            ancho = min(1680, pantalla(3) - 40);
            alto  = min(900,  pantalla(4) - 80);
            app.Fig = uifigure('Name', 'Analizador espectral — Procesamiento de Señales', ...
                'Position', [20 40 ancho alto], 'Color', T.fondo, ...
                'CloseRequestFcn', @(~,~) delete(app), ...
                'WindowKeyPressFcn', @(~,e) app.teclaPresionada(e));

            raiz = uigridlayout(app.Fig, [2 3], ...
                'ColumnWidth', {290, '1x', 330}, 'RowHeight', {'1x', 26}, ...
                'Padding', [10 10 10 6], 'ColumnSpacing', 10, 'RowSpacing', 6, ...
                'BackgroundColor', T.fondo);

            % Izquierda: señal y STFT (cabe sin desplazamiento en 1080p)
            izq = uigridlayout(raiz, [5 1], ...
                'RowHeight', {102, 152, 132, 165, 126}, 'Padding', [0 0 0 0], ...
                'RowSpacing', 8, 'BackgroundColor', T.fondo, 'Scrollable', 'on');
            izq.Layout.Row = 1; izq.Layout.Column = 1;
            app.construirPanelArchivo(izq);
            app.construirPanelFragmento(izq);
            app.construirPanelReproduccion(izq);
            app.construirPanelAnalisis(izq);
            app.construirPanelVisualizacion(izq);

            cen = uigridlayout(raiz, [4 1], ...
                'RowHeight', {120, '1x', '2x', '1x'}, 'Padding', [0 0 0 0], ...
                'RowSpacing', 8, 'BackgroundColor', T.fondo);
            cen.Layout.Row = 1; cen.Layout.Column = 2;
            app.AxGlobal = app.crearEjes(cen, 1, ...
                'Vista global — arrastre para seleccionar el fragmento', 'Tiempo [s]', 'Amplitud');
            app.AxSenal = app.crearEjes(cen, 2, 'Señal temporal del fragmento', ...
                'Tiempo [s]', 'Amplitud');
            app.AxEspec = app.crearEjes(cen, 3, 'Espectrograma (STFT)', ...
                'Tiempo [s]', 'Frecuencia [kHz]');
            app.AxEspectro = app.crearEjes(cen, 4, 'Espectro del fragmento', ...
                'Frecuencia [kHz]', 'Magnitud [dBFS]');

            % Derecha: componentes y filtros (los parámetros de los filtros
            % son globales: afectan a todos los componentes)
            der = uigridlayout(raiz, [6 1], ...
                'RowHeight', {190, 335, 170, 280, 290, 150}, 'Padding', [0 0 0 0], ...
                'RowSpacing', 8, 'BackgroundColor', T.fondo, 'Scrollable', 'on');
            der.Layout.Row = 1; der.Layout.Column = 3;
            app.construirPanelComponentes(der);
            app.construirPanelPropiedades(der);
            app.construirPanelHpss(der);
            app.construirPanelRepet(der);
            app.construirPanelEstereo(der);
            app.construirPanelResultado(der);

            app.inicializarGraficas();

            app.LblEstado = uilabel(raiz, 'Text', 'Listo.', ...
                'FontColor', T.tenue, 'FontName', T.fuente, 'FontSize', 11);
            app.LblEstado.Layout.Row = 2; app.LblEstado.Layout.Column = [1 3];
        end

        function construirPanelArchivo(app, padre)
            T = app.T;
            g = app.crearPanel(padre, 'Archivo', 2, {'1.7x', '1x'});
            g.RowHeight = {24, '1x'};
            app.DdArchivo = uidropdown(g, 'Items', {'(sin archivos)'}, ...
                'ValueChangedFcn', @(dd,~) app.cargarArchivo(dd.Value));
            app.estiloControl(app.DdArchivo);
            app.DdArchivo.Layout.Row = 1; app.DdArchivo.Layout.Column = 1;
            b = uibutton(g, 'Text', 'Examinar…', 'ButtonPushedFcn', @(~,~) app.examinar());
            app.estiloBoton(b, T.control);
            b.Layout.Row = 1; b.Layout.Column = 2;
            app.LblInfo = uilabel(g, 'Text', '—', 'WordWrap', 'on', ...
                'VerticalAlignment', 'top', ...
                'FontColor', T.tenue, 'FontName', T.fuente, 'FontSize', 11);
            app.LblInfo.Layout.Row = 2; app.LblInfo.Layout.Column = [1 2];
        end

        function construirPanelFragmento(app, padre)
            T = app.T;
            g = app.crearPanel(padre, 'Fragmento', 4);
            g.RowHeight = {24, 24, 18, 26};
            app.etiqueta(g, 'Inicio [s]', 1, 1);
            app.EdInicio = app.campoNumerico(g, 1, 2, '%.2f', @(~,~) app.camposCambiados('inicio'));
            app.etiqueta(g, 'Fin [s]', 2, 1);
            app.EdFin = app.campoNumerico(g, 2, 2, '%.2f', @(~,~) app.camposCambiados('fin'));
            app.LblDuracion = uilabel(g, 'Text', 'Duración: —', ...
                'FontColor', T.seleccion, 'FontName', T.fuente, 'FontWeight', 'bold');
            app.LblDuracion.Layout.Row = 3; app.LblDuracion.Layout.Column = [1 2];
            b = uibutton(g, 'Text', sprintf('Ajustar a %d s', app.DURACION_MAX), ...
                'Tooltip', sprintf('Fragmento de %d s desde el inicio actual (enunciado)', app.DURACION_MAX), ...
                'ButtonPushedFcn', @(~,~) app.camposCambiados('inicio'));
            app.estiloBoton(b, T.control);
            b.Layout.Row = 4; b.Layout.Column = 1;
            b = uibutton(g, 'Text', 'Canción completa', ...
                'ButtonPushedFcn', @(~,~) app.solicitarSeleccion([0 app.duracionTotal()]));
            app.estiloBoton(b, T.control);
            b.Layout.Row = 4; b.Layout.Column = 2;
        end

        function construirPanelReproduccion(app, padre)
            T = app.T;
            p = uipanel(padre, 'Title', 'Reproducción', 'BackgroundColor', T.panel, ...
                'ForegroundColor', T.texto, 'FontName', T.fuente, ...
                'FontWeight', 'bold', 'FontSize', 13, 'BorderType', 'none');
            g = uigridlayout(p, [3 3], 'ColumnWidth', {'1x', '1x', '1x'}, ...
                'RowHeight', {30, 22, 26}, 'Padding', [10 8 10 8], ...
                'RowSpacing', 6, 'ColumnSpacing', 8, 'BackgroundColor', T.panel);

            app.BtnPlay = uibutton(g, 'Text', '▶  Play', 'ButtonPushedFcn', @(~,~) app.reproducir());
            app.estiloBoton(app.BtnPlay, T.acento);
            app.BtnPausa = uibutton(g, 'Text', '❚❚  Pausa', 'ButtonPushedFcn', @(~,~) app.pausar());
            app.estiloBoton(app.BtnPausa, T.control);
            app.BtnStop = uibutton(g, 'Text', '■  Detener', 'ButtonPushedFcn', @(~,~) app.detener());
            app.estiloBoton(app.BtnStop, T.control);

            app.ChkRepetir = uicheckbox(g, 'Text', 'Repetir', 'FontColor', T.texto, 'FontName', T.fuente);
            app.ChkRepetir.Layout.Row = 2; app.ChkRepetir.Layout.Column = 1;
            app.LblPosicion = uilabel(g, 'Text', 't = —', 'HorizontalAlignment', 'right', ...
                'FontColor', T.texto, 'FontName', 'Consolas', 'FontSize', 13);
            app.LblPosicion.Layout.Row = 2; app.LblPosicion.Layout.Column = [2 3];

            l = uilabel(g, 'Text', 'Versión (B):', 'FontColor', T.texto, 'FontName', T.fuente);
            l.Layout.Row = 3; l.Layout.Column = 1;
            app.BtnVerOrig = uibutton(g, 'state', 'Text', 'Original', 'Value', true, ...
                'ValueChangedFcn', @(~,~) app.cambiarVista('original'));
            app.BtnVerOrig.Layout.Row = 3; app.BtnVerOrig.Layout.Column = 2;
            app.BtnVerProc = uibutton(g, 'state', 'Text', 'Procesada', 'Value', false, ...
                'ValueChangedFcn', @(~,~) app.cambiarVista('procesada'));
            app.BtnVerProc.Layout.Row = 3; app.BtnVerProc.Layout.Column = 3;
            app.estiloVista();
            app.actualizarBotones();
        end

        function construirPanelAnalisis(app, padre)
            % Controles que cambian el procesamiento (recalculan todo)
            T = app.T;
            g = app.crearPanel(padre, 'Análisis STFT (afecta el procesamiento)', 3, {'1.35x', '1x'});
            g.RowHeight = {24, 24, '1x'};

            app.etiqueta(g, 'Ventana Hann [muestras]', 1, 1, 'Longitud de la ventana de Hann');
            app.DdVentana = uidropdown(g, 'Items', {'1024', '2048', '4096', '8192', '16384'}, ...
                'Value', app.STFT_VENTANA, 'ValueChangedFcn', @(~,~) app.recalcularEspectrograma());
            app.estiloControl(app.DdVentana);
            app.DdVentana.Layout.Row = 1; app.DdVentana.Layout.Column = 2;

            app.etiqueta(g, 'Solapamiento', 2, 1);
            app.DdSolape = uidropdown(g, 'Items', {'50 %', '75 %', '87.5 %'}, ...
                'ItemsData', [0.5 0.75 0.875], 'Value', app.STFT_SOLAPE, ...
                'ValueChangedFcn', @(~,~) app.recalcularEspectrograma());
            app.estiloControl(app.DdSolape);
            app.DdSolape.Layout.Row = 2; app.DdSolape.Layout.Column = 2;

            app.LblStft = uilabel(g, 'Text', '—', 'WordWrap', 'on', ...
                'VerticalAlignment', 'top', ...
                'FontColor', T.tenue, 'FontName', T.fuente, 'FontSize', 11);
            app.LblStft.Layout.Row = 3; app.LblStft.Layout.Column = [1 2];
        end

        function construirPanelVisualizacion(app, padre)
            % Controles que solo cambian el dibujo (no recalculan nada)
            T = app.T;
            g = app.crearPanel(padre, 'Visualización', 3, {'1.35x', '1x'});
            g.RowHeight = {24, 24, 24};

            app.etiqueta(g, 'Frecuencia máx.', 1, 1);
            app.DdFmax = uidropdown(g, 'Items', {'1 kHz', '2 kHz', '4 kHz', '8 kHz', '12 kHz', 'Nyquist'}, ...
                'ItemsData', [1 2 4 8 12 Inf], 'Value', Inf, ...
                'ValueChangedFcn', @(~,~) app.actualizarVistaEspectrograma());
            app.estiloControl(app.DdFmax);
            app.DdFmax.Layout.Row = 1; app.DdFmax.Layout.Column = 2;

            ayuda = ['Rango de colores bajo el máximo del original. Lo que está más ' ...
                'abajo se ve negro. Use el mismo valor en todas las figuras del informe.'];
            app.etiqueta(g, 'Rango dinámico', 2, 1, ayuda);
            app.DdRango = uidropdown(g, 'Items', {'60 dB', '80 dB', '100 dB'}, ...
                'ItemsData', [60 80 100], 'Value', 80, 'Tooltip', ayuda, ...
                'ValueChangedFcn', @(~,~) app.actualizarVistaEspectrograma());
            app.estiloControl(app.DdRango);
            app.DdRango.Layout.Row = 2; app.DdRango.Layout.Column = 2;

            app.etiqueta(g, 'Mapa de color', 3, 1);
            app.DdColormap = uidropdown(g, 'Items', {'turbo', 'parula', 'hot', 'bone', 'gray'}, ...
                'Value', 'turbo', 'ValueChangedFcn', @(~,~) app.actualizarVistaEspectrograma());
            app.estiloControl(app.DdColormap);
            app.DdColormap.Layout.Row = 3; app.DdColormap.Layout.Column = 2;
        end

        function construirPanelHpss(app, padre)
            T = app.T;
            g = app.crearPanel(padre, 'Filtro de carácter (HPSS)', 4, {'1.35x', '1x'});
            g.RowHeight = {24, 24, '1x', 26};

            app.etiqueta(g, 'Mediana tiempo [ms]', 1, 1, 'Mediana en tiempo [ms]');
            app.EdHpssT = app.campoNumerico(g, 1, 2, '%.0f', ...
                @(c,~) app.cambiarHpss('t', c.Value));
            app.EdHpssT.Value  = 1000 * app.HpssT;
            app.EdHpssT.Limits = [100 1500];

            app.etiqueta(g, 'Mediana frec. [Hz]', 2, 1, 'Mediana en frecuencia [Hz]');
            app.EdHpssF = app.campoNumerico(g, 2, 2, '%.0f', ...
                @(c,~) app.cambiarHpss('f', c.Value));
            app.EdHpssF.Value  = app.HpssF;
            app.EdHpssF.Limits = [50 1000];
            app.ayudaHpss(44100, 4096, 1024);    % se actualiza con el fs real al cargar

            app.LblHpss = uilabel(g, 'Text', '—', 'WordWrap', 'on', ...
                'VerticalAlignment', 'top', 'FontColor', T.tenue, ...
                'FontName', T.fuente, 'FontSize', 11);
            app.LblHpss.Layout.Row = 3; app.LblHpss.Layout.Column = [1 2];

            b = uibutton(g, 'Text', sprintf('Restaurar (%.0f ms, %.0f Hz)', ...
                1000*app.HPSS_T, app.HPSS_F), 'ButtonPushedFcn', @(~,~) app.restaurarHpss());
            app.estiloBoton(b, T.control);
            b.Layout.Row = 4; b.Layout.Column = [1 2];
        end

        function ayudaHpss(app, fs, Nw, hop)
            % Tooltips de los filtros de HPSS: valor del artículo y rango estable
            % (15–30 tramas/bins), con su equivalente para la STFT actual.
            ms  = @(n) 1000 * n * hop / fs;
            hz  = @(n) n * fs / Nw;
            app.EdHpssT.Tooltip = sprintf(['l_harm (mediana en tiempo). FitzGerald (2010): 17 tramas; ' ...
                'calidad estable entre 15 y 30 tramas = %.0f–%.0f ms con la STFT actual. ' ...
                'Eventos más cortos que ~la mitad dejan de contar como "sostenidos".'], ms(15), ms(30));
            app.EdHpssF.Tooltip = sprintf(['l_perc (mediana en frecuencia). FitzGerald (2010): 17 bins; ' ...
                'calidad estable entre 15 y 30 bins = %.0f–%.0f Hz con la STFT actual. ' ...
                'Picos más angostos que ~la mitad dejan de contar como "percusivos".'], hz(15), hz(30));
        end

        function construirPanelRepet(app, padre)
            T = app.T;
            g = app.crearPanel(padre, 'Filtro de repetición (REPET)', 7, {'1.35x', '1x'});
            g.RowHeight = {24, 24, 24, 24, '1x', 26, 26};
            app.GridRep = g;

            app.etiqueta(g, 'Método', 1, 1);
            app.DdRepMetodo = uidropdown(g, 'Items', {'REPET-SIM', 'REPET original'}, ...
                'ItemsData', {'sim', 'original'}, 'Value', app.Rep.metodo, ...
                'Tooltip', ['REPET-SIM: tramas parecidas (fondo no periódico). ' ...
                'REPET original: un período de repetición para todo el fragmento.'], ...
                'ValueChangedFcn', @(c,~) app.cambiarRepet('metodo', c.Value));
            app.estiloControl(app.DdRepMetodo);
            app.DdRepMetodo.Layout.Row = 1; app.DdRepMetodo.Layout.Column = 2;

            % --- REPET-SIM: k, d, t (filas 2-4) ---
            l1 = app.etiqueta(g, 'Tramas máx. (k)', 2, 1, 'Máx. tramas repetidas (k)');
            app.EdRepK = app.campoNumerico(g, 2, 2, '%.0f', @(c,~) app.cambiarRepet('k', c.Value));
            app.EdRepK.Value = app.Rep.k;  app.EdRepK.Limits = [3 500];
            app.EdRepK.RoundFractionalValues = 'on';
            app.EdRepK.Tooltip = ['Máximo de tramas (incluida la propia) en la mediana de cada trama. ' ...
                'Referencia: 100. Con fragmentos cortos el límite real lo pone d (ver diagnóstico).'];

            l2 = app.etiqueta(g, 'Distancia mín. d [s]', 3, 1, 'Distancia mínima d [s]');
            app.EdRepD = app.campoNumerico(g, 3, 2, '%.2f', @(c,~) app.cambiarRepet('d', c.Value));
            app.EdRepD.Value = app.Rep.d;  app.EdRepD.Limits = [0.1 10];
            app.EdRepD.Tooltip = ['Separación mínima entre dos tramas repetidas. Referencia: 1 s. ' ...
                'Debe superar la duración de una nota cantada; si es muy grande caben pocas tramas.'];

            l3 = app.etiqueta(g, 'Similitud mín. t', 4, 1, 'Similitud mínima t');
            app.EdRepU = app.campoNumerico(g, 4, 2, '%.2f', @(c,~) app.cambiarRepet('u', c.Value));
            app.EdRepU.Value = app.Rep.u;  app.EdRepU.Limits = [0 0.99];
            app.EdRepU.Tooltip = ['Coseno mínimo para aceptar una trama como repetición. Referencia: 0. ' ...
                'Subirlo (0.6–0.8) evita usar tramas poco parecidas en fragmentos cortos.'];

            % --- REPET original: período mínimo y máximo (filas 2-3) ---
            l4 = app.etiqueta(g, 'Período mínimo [s]', 2, 1);
            app.EdRepPmin = app.campoNumerico(g, 2, 2, '%.2f', @(c,e) app.cambiarRepet('pMin', c.Value, e.PreviousValue));
            app.EdRepPmin.Value = app.Rep.pMin;  app.EdRepPmin.Limits = [0.1 30];
            app.EdRepPmin.Tooltip = 'Período de repetición más corto que se busca. Referencia: 1 s.';
            l5 = app.etiqueta(g, 'Período máximo [s]', 3, 1);
            app.EdRepPmax = app.campoNumerico(g, 3, 2, '%.2f', @(c,e) app.cambiarRepet('pMax', c.Value, e.PreviousValue));
            app.EdRepPmax.Value = app.Rep.pMax;  app.EdRepPmax.Limits = [0.1 30];
            app.EdRepPmax.Tooltip = ['Período de repetición más largo que se busca. Referencia: 10 s. ' ...
                'Además nunca supera un tercio del fragmento (al menos 3 segmentos).'];

            app.CtrlRepSim  = {l1, app.EdRepK, l2, app.EdRepD, l3, app.EdRepU};
            app.CtrlRepOrig = {l4, app.EdRepPmin, l5, app.EdRepPmax};

            app.LblRep = uilabel(g, 'Text', '—', 'WordWrap', 'on', 'Interpreter', 'html', ...
                'VerticalAlignment', 'top', 'FontColor', T.tenue, ...
                'FontName', T.fuente, 'FontSize', 11);
            app.LblRep.Layout.Row = 5; app.LblRep.Layout.Column = [1 2];

            app.BtnRestaurarRep = uibutton(g, 'Text', 'Restaurar valores por defecto', ...
                'Tooltip', 'Restaura los parámetros de ambos métodos', ...
                'ButtonPushedFcn', @(~,~) app.restaurarRepet());
            app.estiloBoton(app.BtnRestaurarRep, T.control);
            app.BtnRestaurarRep.Layout.Row = 6; app.BtnRestaurarRep.Layout.Column = [1 2];
            app.BtnRitmo = uibutton(g, 'Text', 'Ver espectro de ritmo', ...
                'ButtonPushedFcn', @(~,~) app.verEspectroRitmo());
            app.estiloBoton(app.BtnRitmo, T.control);
            app.BtnRitmo.Layout.Row = 7; app.BtnRitmo.Layout.Column = [1 2];
            app.mostrarControlesRepet();
        end

        function mostrarControlesRepet(app)
            % Muestra solo los parámetros del método de repetición elegido.
            esOrig = strcmp(app.Rep.metodo, 'original');
            cellfun(@(h) set(h, 'Visible', ~esOrig), app.CtrlRepSim);
            cellfun(@(h) set(h, 'Visible', esOrig), app.CtrlRepOrig);
            app.BtnRitmo.Visible = esOrig;
            if esOrig
                app.GridRep.RowHeight([4 7]) = {0, 26};     % sin fila de t; con botón
            else
                app.GridRep.RowHeight([4 7]) = {24, 0};
            end
        end

        function construirPanelComponentes(app, padre)
            T = app.T;
            g = app.crearPanel(padre, 'Componentes musicales', 3);
            g.RowHeight = {26, '1x', 26};

            app.BtnNuevo = uibutton(g, 'Text', '+  Nuevo', 'ButtonPushedFcn', @(~,~) app.nuevoComponente());
            app.estiloBoton(app.BtnNuevo, T.acento);
            app.BtnEliminar = uibutton(g, 'Text', 'Eliminar', 'ButtonPushedFcn', @(~,~) app.eliminarComponente());
            app.estiloBoton(app.BtnEliminar, T.control);

            app.LstComp = uilistbox(g, 'Items', {}, 'BackgroundColor', T.control, ...
                'FontColor', T.texto, 'FontName', T.fuente, ...
                'ValueChangedFcn', @(l,~) app.seleccionarComponente(l.Value));
            app.LstComp.Layout.Row = 2; app.LstComp.Layout.Column = [1 2];

            app.BtnDeshacer = uibutton(g, 'Text', '↶  Deshacer', 'ButtonPushedFcn', @(~,~) app.deshacer());
            app.estiloBoton(app.BtnDeshacer, T.control);
            app.BtnDeshacer.Layout.Row = 3; app.BtnDeshacer.Layout.Column = 1;
            app.BtnRevertir = uibutton(g, 'Text', '⟲  Revertir todo', 'ButtonPushedFcn', @(~,~) app.revertirTodo());
            app.estiloBoton(app.BtnRevertir, T.peligro);
            app.BtnRevertir.Layout.Row = 3; app.BtnRevertir.Layout.Column = 2;
        end

        function construirPanelPropiedades(app, padre)
            T = app.T;
            g = app.crearPanel(padre, 'Propiedades del componente', 9);
            g.RowHeight = {26, 26, 26, 26, 26, 26, 26, 26, '1x'};

            app.etiqueta(g, 'f inferior [Hz]', 1, 1);
            app.EdF1 = app.campoNumerico(g, 1, 2, '%.0f', @(c,~) app.propiedadCambiada('f1', c.Value));
            app.etiqueta(g, 'f superior [Hz]', 2, 1);
            app.EdF2 = app.campoNumerico(g, 2, 2, '%.0f', @(c,~) app.propiedadCambiada('f2', c.Value));

            app.etiqueta(g, 'Carácter', 3, 1);
            app.DdCaracter = uidropdown(g, 'Items', {'Cualquiera', 'Sostenido', 'Percusivo'}, ...
                'ItemsData', {'cualquiera', 'sostenido', 'percusivo'}, 'Value', 'cualquiera', ...
                'ValueChangedFcn', @(c,~) app.propiedadCambiada('caracter', c.Value));
            app.estiloControl(app.DdCaracter);
            app.DdCaracter.Layout.Row = 3; app.DdCaracter.Layout.Column = 2;

            app.etiqueta(g, 'Repetición', 4, 1);
            app.DdRepeticion = uidropdown(g, 'Items', {'Cualquiera', 'Repetitivo', 'No repetitivo'}, ...
                'ItemsData', {'cualquiera', 'repetitivo', 'norepetitivo'}, 'Value', 'cualquiera', ...
                'ValueChangedFcn', @(c,~) app.propiedadCambiada('repeticion', c.Value));
            app.estiloControl(app.DdRepeticion);
            app.DdRepeticion.Layout.Row = 4; app.DdRepeticion.Layout.Column = 2;

            app.etiqueta(g, 'Paneo desde (−1 izq.)', 5, 1);
            app.EdPan1 = app.campoNumerico(g, 5, 2, '%+.2f', @(c,~) app.propiedadCambiada('pan1', c.Value));
            app.EdPan1.Limits = [-1 1];
            app.etiqueta(g, 'Paneo hasta (+1 der.)', 6, 1);
            app.EdPan2 = app.campoNumerico(g, 6, 2, '%+.2f', @(c,~) app.propiedadCambiada('pan2', c.Value));
            app.EdPan2.Limits = [-1 1];

            app.etiqueta(g, 'Ganancia [dB]', 7, 1);
            app.SpGanancia = uispinner(g, 'Limits', [-60 24], 'Step', 1, 'Value', 0, ...
                'ValueDisplayFormat', '%+.0f dB', ...
                'ValueChangedFcn', @(c,~) app.propiedadCambiada('g', c.Value));
            app.estiloControl(app.SpGanancia);
            app.SpGanancia.Layout.Row = 7; app.SpGanancia.Layout.Column = 2;

            app.ChkMascara = uicheckbox(g, 'Text', 'Resaltar máscara', 'Value', true, ...
                'FontColor', T.texto, 'FontName', T.fuente, ...
                'ValueChangedFcn', @(~,~) app.mostrarMascara());
            app.ChkMascara.Layout.Row = 8; app.ChkMascara.Layout.Column = [1 2];

            app.LblDerivadas = uilabel(g, 'Text', '', 'WordWrap', 'on', ...
                'VerticalAlignment', 'top', 'FontColor', T.tenue, ...
                'FontName', T.fuente, 'FontSize', 11);
            app.LblDerivadas.Layout.Row = 9; app.LblDerivadas.Layout.Column = [1 2];

            app.ControlesProp = {app.EdF1, app.EdF2, app.DdCaracter, app.DdRepeticion, ...
                app.EdPan1, app.EdPan2, app.SpGanancia};
        end

        function construirPanelEstereo(app, padre)
            T = app.T;
            p = uipanel(padre, 'Title', 'Mapa estéreo (clic = centrar paneo)', ...
                'BackgroundColor', T.panel, 'ForegroundColor', T.texto, ...
                'FontName', T.fuente, 'FontWeight', 'bold', 'FontSize', 13, 'BorderType', 'none');
            g = uigridlayout(p, [1 1], 'Padding', [4 4 4 4], 'BackgroundColor', T.panel);
            app.AxPan = app.crearEjes(g, 1, '', 'Paneo  (izq. ← 0 → der.)', 'Frecuencia [kHz]');
            app.AxPan.XLim = [-1 1];
            app.AxPan.XTick = -1:0.5:1;
            app.AxPan.Toolbar.Visible = 'off';
        end

        function construirPanelResultado(app, padre)
            T = app.T;
            g = app.crearPanel(padre, 'Resultado', 3);
            g.RowHeight = {24, '1x', 28};
            app.ChkSilenciar = uicheckbox(g, 'Text', 'Solo: silenciar lo demás', ...
                'FontColor', T.seleccion, 'FontName', T.fuente, 'FontWeight', 'bold', ...
                'ValueChangedFcn', @(c,~) app.cambiarSilenciar(c.Value));
            app.ChkSilenciar.Layout.Row = 1; app.ChkSilenciar.Layout.Column = [1 2];
            app.LblResultado = uilabel(g, 'Text', '', 'WordWrap', 'on', ...
                'VerticalAlignment', 'top', 'FontColor', T.texto, ...
                'FontName', T.fuente, 'FontSize', 11);
            app.LblResultado.Layout.Row = 2; app.LblResultado.Layout.Column = [1 2];

            app.BtnExportar = uibutton(g, 'Text', '⭳  Exportar WAV (versión procesada)', ...
                'ButtonPushedFcn', @(~,~) app.exportarWav());
            app.estiloBoton(app.BtnExportar, T.procesada * 0.6);
            app.BtnExportar.Layout.Row = 3; app.BtnExportar.Layout.Column = [1 2];
        end

        function inicializarGraficas(app)
            T = app.T;

            app.hEnvolvente = patch(app.AxGlobal, NaN, NaN, T.onda, ...
                'EdgeColor', 'none', 'FaceAlpha', 0.85, 'HitTest', 'off');
            app.hRegion = patch(app.AxGlobal, [0 0 0 0], [-1 -1 1 1], T.seleccion, ...
                'FaceAlpha', 0.18, 'EdgeColor', 'none', 'HitTest', 'off');
            app.hBordes = [ ...
                xline(app.AxGlobal, 0, '-', 'Color', T.seleccion, 'LineWidth', 1.5, 'HitTest', 'off'), ...
                xline(app.AxGlobal, 0, '-', 'Color', T.seleccion, 'LineWidth', 1.5, 'HitTest', 'off')];
            app.AxGlobal.YLim = [-1.05 1.05];
            app.AxGlobal.ButtonDownFcn = @(~,~) app.iniciarArrastre();
            app.AxGlobal.PickableParts = 'all';
            app.AxGlobal.Toolbar.Visible = 'off';

            app.hSenal = line(app.AxSenal, NaN, NaN, 'Color', T.onda, 'LineWidth', 0.5, 'HitTest', 'off');
            app.AxSenal.YLim = [-1.05 1.05];
            app.AxSenal.ButtonDownFcn = @(ax,~) app.saltarA(ax.CurrentPoint(1,1));

            % Espectro: original y procesada superpuestas en la misma escala
            app.hEspOrig = line(app.AxEspectro, NaN, NaN, 'Color', T.onda, ...
                'LineWidth', 1, 'DisplayName', 'Original', 'HitTest', 'off');
            app.hEspProc = line(app.AxEspectro, NaN, NaN, 'Color', T.procesada, ...
                'LineWidth', 1, 'DisplayName', 'Procesada', 'HitTest', 'off');
            legend(app.AxEspectro, [app.hEspOrig app.hEspProc], 'TextColor', T.texto, ...
                'Color', T.panel, 'EdgeColor', T.rejilla, 'Location', 'southeast');

            app.hImagen = image(app.AxEspec, 'XData', [0 1], 'YData', [0 1], ...
                'CData', NaN, 'CDataMapping', 'scaled', 'HitTest', 'off');
            % "Foco": capa negra semitransparente sobre lo que NO es el componente
            app.hMascara = image(app.AxEspec, 'XData', [0 1], 'YData', [0 1], ...
                'CData', zeros(1, 1, 3, 'uint8'), 'AlphaData', 0, ...
                'AlphaDataMapping', 'none', 'HitTest', 'off');
            app.AxEspec.YDir = 'normal';
            app.AxEspec.Layer = 'top';
            app.AxEspec.ButtonDownFcn = @(~,~) app.clicEspectrograma();
            colormap(app.AxEspec, app.DdColormap.Value);
            app.hColorbar = colorbar(app.AxEspec, 'Color', T.texto);
            % Título horizontal: la etiqueta vertical queda recortada en uiaxes
            app.hColorbar.Title.String = 'dBFS';
            app.hColorbar.Title.Color  = T.texto;
            % Barra invisible en la señal: reserva el mismo ancho para que
            % ambas gráficas (que comparten el eje de tiempo) queden alineadas
            colorbar(app.AxSenal, 'Visible', 'off');

            linkaxes([app.AxSenal app.AxEspec], 'x');

            app.hCursores = [ ...
                xline(app.AxGlobal, 0, '-', 'Color', T.cursor, 'LineWidth', 1.5, 'HitTest', 'off'), ...
                xline(app.AxSenal,  0, '-', 'Color', T.cursor, 'LineWidth', 1.5, 'HitTest', 'off'), ...
                xline(app.AxEspec,  0, '-', 'Color', [1 1 1],  'LineWidth', 1.5, 'HitTest', 'off')];

            % Mapa estéreo
            app.hPanImg = image(app.AxPan, 'XData', [-1 1], 'YData', [0 1], ...
                'CData', NaN, 'CDataMapping', 'scaled', 'HitTest', 'off');
            app.AxPan.YDir = 'normal';
            app.AxPan.Layer = 'top';
            app.AxPan.CLim = [-60 0];
            colormap(app.AxPan, app.DdColormap.Value);
            app.hPanSel = patch(app.AxPan, NaN, NaN, [1 1 1], 'FaceAlpha', 0.12, ...
                'EdgeColor', [1 1 1], 'LineWidth', 1.8, 'HitTest', 'off');
            xline(app.AxPan, 0, ':', 'Color', T.tenue, 'HitTest', 'off');
            app.AxPan.ButtonDownFcn = @(ax,~) app.clicPanorama(ax.CurrentPoint(1,1));
        end

        % ---------------- Ayudantes de estilo ----------------
        function g = crearPanel(app, padre, titulo, nFilas, anchos)
            % anchos: columnas etiqueta/control (por defecto iguales)
            if nargin < 5, anchos = {'1x', '1x'}; end
            T = app.T;
            p = uipanel(padre, 'Title', titulo, 'BackgroundColor', T.panel, ...
                'ForegroundColor', T.texto, 'FontName', T.fuente, ...
                'FontWeight', 'bold', 'FontSize', 13, 'BorderType', 'none');
            g = uigridlayout(p, [nFilas 2], 'ColumnWidth', anchos, ...
                'Padding', [10 8 10 8], 'RowSpacing', 6, 'ColumnSpacing', 8, ...
                'BackgroundColor', T.panel);
        end

        function l = etiqueta(app, g, texto, fila, col, ayuda)
            l = uilabel(g, 'Text', texto, 'FontColor', app.T.texto, 'FontName', app.T.fuente);
            l.Layout.Row = fila; l.Layout.Column = col;
            if nargin >= 6, l.Tooltip = ayuda; end
        end

        function c = campoNumerico(app, g, fila, col, formato, fcn)
            c = uieditfield(g, 'numeric', 'Limits', [0 Inf], ...
                'ValueDisplayFormat', formato, 'ValueChangedFcn', fcn);
            app.estiloControl(c);
            c.Layout.Row = fila; c.Layout.Column = col;
        end

        function estiloControl(app, c)
            c.BackgroundColor = app.T.control;
            c.FontColor = app.T.texto;
            c.FontName = app.T.fuente;
        end

        function estiloBoton(app, b, color)
            b.BackgroundColor = color;
            b.FontColor = app.T.texto;
            b.FontName = app.T.fuente;
            b.FontWeight = 'bold';
        end

        function estiloVista(app)
            T = app.T;
            esProc = strcmp(app.Vista, 'procesada');
            app.BtnVerOrig.Value = ~esProc;
            app.BtnVerProc.Value = esProc;
            app.estiloBoton(app.BtnVerOrig, T.control);
            app.estiloBoton(app.BtnVerProc, T.control);
            if esProc
                app.BtnVerProc.BackgroundColor = T.procesada * 0.7;
            else
                app.BtnVerOrig.BackgroundColor = T.acento;
            end
        end

        function ax = crearEjes(app, padre, fila, titulo, xl, yl)
            T = app.T;
            ax = uiaxes(padre, 'Color', T.ejes, 'BackgroundColor', T.panel, ...
                'XColor', T.tenue, 'YColor', T.tenue, 'GridColor', T.rejilla, ...
                'GridAlpha', 0.35, 'Box', 'on', 'FontName', T.fuente, ...
                'XGrid', 'on', 'YGrid', 'on', 'NextPlot', 'add');
            ax.Layout.Row = fila;
            title(ax, titulo, 'Color', T.texto, 'FontWeight', 'bold');
            xlabel(ax, xl); ylabel(ax, yl);
            disableDefaultInteractivity(ax);
        end
    end

    % =====================================================================
    %  ARCHIVOS
    % =====================================================================
    methods (Access = private)

        function listarArchivos(app)
            rutas = {};
            if isfolder(app.CarpetaMusica)
                for k = 1:numel(app.EXTENSIONES)
                    d = dir(fullfile(app.CarpetaMusica, app.EXTENSIONES{k}));
                    for j = 1:numel(d)
                        rutas{end+1, 1} = fullfile(d(j).folder, d(j).name); %#ok<AGROW>
                    end
                end
            end
            app.fijarListaArchivos(rutas);
        end

        function fijarListaArchivos(app, rutas)
            if isempty(rutas)
                app.DdArchivo.Items = {'(sin archivos)'};
                app.DdArchivo.ItemsData = {};
                return;
            end
            [~, nombres, ext] = cellfun(@fileparts, rutas, 'UniformOutput', false);
            app.DdArchivo.Items = strcat(nombres, ext);
            app.DdArchivo.ItemsData = rutas;
        end

        function examinar(app)
            [nombre, carpeta] = uigetfile({strjoin(app.EXTENSIONES', ';'), 'Audio'}, ...
                'Seleccione una canción', app.CarpetaMusica);
            figure(app.Fig);
            if isequal(nombre, 0), return; end
            ruta = fullfile(carpeta, nombre);
            rutas = app.DdArchivo.ItemsData;
            if ~any(strcmp(rutas, ruta))
                app.fijarListaArchivos([rutas(:); {ruta}]);
            end
            app.DdArchivo.Value = ruta;
            app.cargarArchivo(ruta);
        end

        function cargarArchivo(app, ruta)
            if isempty(ruta) || ~ischar(ruta), return; end
            app.detener();

            dlg = uiprogressdlg(app.Fig, 'Title', 'Cargando', ...
                'Message', 'Leyendo archivo de audio…', 'Indeterminate', 'on');
            limpiar = onCleanup(@() close(dlg)); %#ok<NASGU>

            try
                [x, fs, info] = leer_audio(ruta);
            catch err
                uialert(app.Fig, err.message, 'No se pudo cargar el archivo');
                return;
            end

            app.Ruta  = ruta;
            app.Audio = x;
            app.Mono  = mean(x, 2);
            app.Fs    = fs;

            % Los componentes pertenecen a la canción anterior
            app.Componentes = AnalizadorApp.componenteVacio();
            app.CompSel   = [];
            app.Historial = {};
            app.Resultado = [];
            app.ChkSilenciar.Value = false;

            dur = size(x, 1) / fs;
            app.EdInicio.Value = 0;  app.EdFin.Value = 0;
            app.EdInicio.Limits = [0 dur];
            app.EdFin.Limits    = [0 dur];

            app.LblInfo.Text = sprintf('fs = %d Hz · %d canal(es)\nDuración: %s', ...
                fs, size(x, 2), AnalizadorApp.mmss(dur));

            dlg.Message = 'Dibujando vista global…';
            app.dibujarVistaGlobal();
            dlg.Message = 'Analizando el fragmento (STFT, HPSS, paneo)…';
            app.aplicarSeleccion([0 min(app.DURACION_MAX, dur)]);   % 20 s por defecto

            [~, n, e] = fileparts(ruta);
            app.mostrarEstado(sprintf('Cargado: %s%s', n, e));
        end
    end

    % =====================================================================
    %  SELECCIÓN DEL FRAGMENTO
    % =====================================================================
    methods (Access = private)

        function d = duracionTotal(app)
            d = size(app.Audio, 1) / app.Fs;
        end

        function sel = normalizarSeleccion(app, sel)
            dur = app.duracionTotal();
            sel = sort(min(max(sel, 0), dur));
            if diff(sel) < app.DURACION_MIN
                sel(2) = min(dur, sel(1) + app.DURACION_MIN);
                sel(1) = max(0, sel(2) - app.DURACION_MIN);
            end
        end

        function aplicarSeleccion(app, sel)
            if isempty(app.Audio), return; end
            app.detener();
            app.Seleccion = app.normalizarSeleccion(sel);
            app.dibujarRegion(app.Seleccion);
            app.recalcularEspectrograma();
            app.moverCursor(app.Seleccion(1));
            if diff(app.Seleccion) > app.DURACION_MAX
                app.mostrarEstado(sprintf(['⚠ Fragmento de %.1f s: supera los %d s del ' ...
                    'enunciado. Funciona igual, pero cada cambio tarda más.'], ...
                    diff(app.Seleccion), app.DURACION_MAX));
            end
        end

        function camposCambiados(app, cual)
            % Cambiar el inicio siempre da una ventana de 20 s (desplazada
            % hacia atrás si no cabe antes del final). Cambiar el fin respeta
            % el rango escrito, con confirmación si es muy largo.
            if strcmp(cual, 'inicio')
                app.solicitarSeleccion(app.ventanaDesde(app.EdInicio.Value));
            else
                app.solicitarSeleccion([app.EdInicio.Value, app.EdFin.Value]);
            end
        end

        function sel = ventanaDesde(app, t0)
            dur = app.duracionTotal();
            t0  = min(max(t0, 0), max(0, dur - app.DURACION_MAX));
            sel = [t0, min(dur, t0 + app.DURACION_MAX)];
        end

        function solicitarSeleccion(app, sel)
            % Aplica la selección; si es larga, primero pide confirmación.
            sel = app.normalizarSeleccion(sel);
            if diff(sel) > app.LIMITE_CONFIRMAR
                r = uiconfirm(app.Fig, sprintf(['El fragmento dura %.0f s. Procesarlo puede ' ...
                    'tardar y usar mucha memoria (STFT, HPSS y REPET-SIM crecen con la ' ...
                    'duración; REPET-SIM compara todas las tramas entre sí).\n\n¿Continuar?'], ...
                    diff(sel)), 'Fragmento largo', 'Options', {'Procesar', 'Cancelar'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
                if ~strcmp(r, 'Procesar')
                    app.dibujarRegion(app.Seleccion);     % se restaura la anterior
                    return;
                end
            end
            app.aplicarSeleccion(sel);
        end

        function dibujarRegion(app, sel)
            app.hRegion.XData = sel([1 2 2 1]);
            app.hBordes(1).Value = sel(1);
            app.hBordes(2).Value = sel(2);
            app.EdInicio.Value = sel(1);
            app.EdFin.Value    = sel(2);
            if diff(sel) > app.DURACION_MAX
                app.LblDuracion.Text = sprintf('⚠ %.2f s (> %d s del enunciado)', diff(sel), app.DURACION_MAX);
                app.LblDuracion.FontColor = app.T.cursor;
            else
                app.LblDuracion.Text = sprintf('Duración: %.2f s', diff(sel));
                app.LblDuracion.FontColor = app.T.seleccion;
            end
        end

        function iniciarArrastre(app)
            if isempty(app.Audio), return; end
            app.salirModosFigura();
            app.Ancla = app.puntoTiempo(app.AxGlobal);
            app.Fig.WindowButtonMotionFcn = @(~,~) app.moverArrastre();
            app.Fig.WindowButtonUpFcn     = @(~,~) app.terminarArrastre();
        end

        function salirModosFigura(app)
            % El zoom/desplazamiento de la barra de una gráfica activa un modo
            % de la figura que bloquea WindowButton*Fcn: se desactiva para
            % que el arrastre en la vista global funcione.
            try zoom(app.Fig, 'off'); catch, end
            try pan(app.Fig, 'off'); catch, end
            try datacursormode(app.Fig, 'off'); catch, end
        end

        function sel = seleccionArrastre(app)
            sel = sort([app.Ancla, app.puntoTiempo(app.AxGlobal)]);
        end

        function moverArrastre(app)
            app.dibujarRegion(app.seleccionArrastre());
        end

        function terminarArrastre(app)
            app.Fig.WindowButtonMotionFcn = '';
            app.Fig.WindowButtonUpFcn     = '';
            sel = app.seleccionArrastre();
            if diff(sel) < 0.003 * app.duracionTotal()
                sel = app.ventanaDesde(app.Ancla);        % clic simple: 20 s desde ahí
            end
            app.solicitarSeleccion(sel);
        end

        function t = puntoTiempo(app, ax)
            t = min(max(ax.CurrentPoint(1, 1), 0), app.duracionTotal());
        end
    end

    % =====================================================================
    %  ANÁLISIS Y GRÁFICAS
    % =====================================================================
    methods (Access = private)

        function dibujarVistaGlobal(app)
            [t, lo, hi] = envolvente_minmax(app.Mono, app.Fs, 4000);
            set(app.hEnvolvente, 'XData', [t; flipud(t)], 'YData', double([hi; flipud(lo)]));
            app.AxGlobal.XLim = [0 app.duracionTotal()];
        end

        function [n1, n2] = indicesSeleccion(app)
            n1 = max(1, round(app.Seleccion(1) * app.Fs) + 1);
            n2 = min(size(app.Audio, 1), round(app.Seleccion(2) * app.Fs));
        end

        function [Nw, hop] = parametrosStft(app)
            Nw  = str2double(app.DdVentana.Value);
            hop = round(Nw * (1 - app.DdSolape.Value));
        end

        function recalcularEspectrograma(app)
            % Se ejecuta al cambiar fragmento o parámetros de la STFT: calcula
            % una sola vez la STFT por canal, el HPSS y el paneo (app.Feat).
            if isempty(app.Audio), return; end
            [Nw, hop] = app.parametrosStft();
            [n1, n2]  = app.indicesSeleccion();

            app.mostrarEstado('Analizando el fragmento (STFT, paneo)…'); drawnow;
            F = caracteristicas_tf(app.Audio(n1:n2, :), app.Fs, Nw, hop);
            F.t = F.t + (n1 - 1)/app.Fs;            % tiempos absolutos
            app.Feat = F;
            app.calcularCaracter();
            app.calcularRepeticion();
            app.SdB  = 20*log10(2*sqrt(double(F.P2))/sum(F.w) + eps);

            set(app.hImagen,  'XData', F.t([1 end]), 'YData', F.f([1 end])/1000);
            set(app.hMascara, 'XData', F.t([1 end]), 'YData', F.f([1 end])/1000);
            app.AxSenal.XLim = app.Seleccion;

            app.LblStft.Text = sprintf(['Hann %d (%.1f ms) · salto %d (%.1f ms)\n' ...
                'Δf = %.2f Hz\n' ...
                'Cambiar estos valores recalcula HPSS y REPET.'], ...
                Nw, 1000*Nw/app.Fs, hop, 1000*hop/app.Fs, app.Fs/Nw);

            app.dibujarMapaEstereo();
            app.actualizarVistaEspectrograma();
            app.procesar();
        end

        function calcularCaracter(app)
            % Máscara de carácter (HPSS, binaria, por canal) del fragmento con
            % los parámetros actuales.
            F = app.Feat;
            if isempty(F), return; end
            [Marm, Lt, Lf] = hpss_mascara(F.Vch, F.fs, F.Nw, F.hop, app.HpssT, app.HpssF);
            app.Feat.Marm = Marm;
            app.Feat.Lt = Lt;
            app.Feat.Lf = Lf;
            app.LblHpss.Text = sprintf('Usado: %d tramas (%.0f ms) × %d bins (%.0f Hz)', ...
                Lt, 1000*Lt*F.hop/F.fs, Lf, Lf*F.fs/F.Nw);
            app.ayudaHpss(F.fs, F.Nw, F.hop);
        end

        function cambiarHpss(app, campo, valor)
            if strcmp(campo, 't')
                app.HpssT = valor / 1000;
            else
                app.HpssF = valor;
            end
            if isempty(app.Feat), return; end
            app.mostrarEstado('Recalculando el filtro de carácter…'); drawnow;
            app.calcularCaracter();
            app.procesar();
        end

        function calcularRepeticion(app)
            % Máscara de repetición del fragmento con el método elegido
            % (REPET-SIM o REPET original). Ambos dan Mrep nF x nT x C.
            F = app.Feat;
            if isempty(F), return; end
            r = app.Rep;
            if strcmp(r.metodo, 'original')
                app.mostrarEstado('Calculando repetición (REPET original)…'); drawnow;
                [Mrep, info] = repet_mascara(F.Vch, F.fs, F.hop, [r.pMin r.pMax]);
                % El período suele ser un compás o más: se dan también los BPM
                % si contuviera 2 o 4 pulsos
                txt = sprintf(['Período: %.2f s (%d tramas) · r = %d segmentos<br>' ...
                    '<b>BPM equivalente: %.1f</b> si el período fuera un pulso ' ...
                    '(2 pulsos: %.1f · 4 pulsos: %.1f)'], ...
                    info.periodoS, info.periodo, info.r, info.bpmEquivalente, ...
                    2*info.bpmEquivalente, 4*info.bpmEquivalente);
                if info.r < 3
                    txt = sprintf(['%s<br><span style="color:%s">Menos de 3 repeticiones: la ' ...
                        'mediana casi no puede descartar la voz. Use un fragmento más largo o ' ...
                        'reduzca el período máximo.</span>'], txt, AnalizadorApp.colorHex(app.T.peligro));
                end
            else
                app.mostrarEstado('Calculando repetición (REPET-SIM)…'); drawnow;
                [Mrep, info] = repet_sim_mascara(F.Vch, F.fs, F.hop, r.k, r.d, r.u);
                if info.tramasMaximas <= r.k
                    limite = sprintf('el límite lo pone d: caben %d tramas', info.tramasMaximas);
                else
                    limite = sprintf('k limita en el %.0f %% de las tramas', 100*info.limitaK);
                end
                txt = sprintf(['Mediana de %.1f tramas en promedio (d = %d tramas; %s)<br>' ...
                    'Similitud media de las tramas elegidas: %.2f'], ...
                    info.tramasPromedio, info.D, limite, info.similitudMedia);
            end
            info.metodo = r.metodo;
            app.Feat.Mrep = Mrep;
            app.Feat.RepInfo = info;
            app.LblRep.Text = txt;
            app.mostrarEstado(sprintf('Repetición calculada (%s).', app.DdRepMetodo.Items{ ...
                strcmp(app.DdRepMetodo.ItemsData, r.metodo)}));
        end

        function cambiarRepet(app, campo, valor, anterior)
            % anterior: valor previo del campo (solo pMin / pMax), para
            % revertir si no se cumple pMin < pMax.
            if (strcmp(campo, 'pMin') && valor >= app.Rep.pMax) || ...
               (strcmp(campo, 'pMax') && valor <= app.Rep.pMin)
                if strcmp(campo, 'pMin'), app.EdRepPmin.Value = anterior;
                else,                     app.EdRepPmax.Value = anterior; end
                app.mostrarEstado('⚠ El período mínimo debe ser menor que el máximo.');
                return;
            end
            app.Rep.(campo) = valor;
            if strcmp(campo, 'metodo'), app.mostrarControlesRepet(); end
            if isempty(app.Feat), return; end
            app.calcularRepeticion();
            app.procesar();
        end

        function restaurarRepet(app)
            % Restaura los parámetros de ambos métodos (no cambia el método).
            app.Rep = AnalizadorApp.repetPorDefecto(app.Rep.metodo);
            app.EdRepK.Value = app.REP_K;   app.EdRepD.Value = app.REP_D;
            app.EdRepU.Value = app.REP_U;
            app.EdRepPmin.Value = app.REP_PMIN;  app.EdRepPmax.Value = app.REP_PMAX;
            if isempty(app.Feat), return; end
            app.calcularRepeticion();
            app.procesar();
        end

        function verEspectroRitmo(app)
            % Figura aparte: espectro de ritmo b(lag), rango de búsqueda,
            % período elegido y sus múltiplos (REPET original).
            if isempty(app.Feat) || ~isfield(app.Feat, 'RepInfo') || ...
                    ~strcmp(app.Feat.RepInfo.metodo, 'original')
                return;
            end
            T = app.T;  info = app.Feat.RepInfo;
            paso = app.Feat.hop / app.Feat.fs;
            f = uifigure('Name', 'Espectro de ritmo — REPET original', 'Color', T.fondo, ...
                'Position', [120 160 820 420]);
            g = uigridlayout(f, [1 1], 'Padding', [10 10 10 10], 'BackgroundColor', T.fondo);
            ax = app.crearEjes(g, 1, sprintf(['Espectro de ritmo · período %.2f s (%d tramas) · ' ...
                '%.1f BPM si el período fuera un pulso'], info.periodoS, info.periodo, ...
                info.bpmEquivalente), 'Lag [s]', 'b(lag) / b(0)');
            ax.Toolbar.Visible = 'on';
            rangoS = info.rangoTramas * paso;
            yl = [min(info.b) max(info.b)];  yl = yl + [-0.05 0.05]*max(diff(yl), eps);
            hr = patch(ax, rangoS([1 2 2 1]), yl([1 1 2 2]), T.seleccion, 'FaceAlpha', 0.12, ...
                'EdgeColor', 'none', 'DisplayName', 'Rango de búsqueda');
            h = line(ax, info.lagS, info.b, 'Color', T.onda, 'LineWidth', 1, ...
                'DisplayName', 'b(lag)');
            for q = 2:floor(info.lagS(end) / info.periodoS)
                xline(ax, q * info.periodoS, ':', 'Color', T.tenue, 'HandleVisibility', 'off');
            end
            hp = xline(ax, info.periodoS, '-', 'Color', T.cursor, 'LineWidth', 1.5, ...
                'DisplayName', 'Período elegido');
            ax.XLim = [0 info.lagS(end)];  ax.YLim = yl;
            legend(ax, [h hr hp], 'TextColor', T.texto, 'Color', T.panel, 'EdgeColor', T.rejilla);
        end

        function restaurarHpss(app)
            app.EdHpssT.Value = 1000 * app.HPSS_T;
            app.EdHpssF.Value = app.HPSS_F;
            app.HpssT = app.HPSS_T;
            app.HpssF = app.HPSS_F;
            if isempty(app.Feat), return; end
            app.calcularCaracter();
            app.procesar();
        end

        function dibujarMapaEstereo(app)
            % Energía del fragmento distribuida por (frecuencia, paneo).
            F = app.Feat;
            nB = app.N_PAN;
            nF = numel(F.f);  nT = numel(F.t);
            pb = min(nB, floor((double(F.pan) + 1)/2 * nB) + 1);
            fi = repmat((1:nF)', 1, nT);
            H  = accumarray([fi(:) pb(:)], double(F.P2(:)), [nF nB]);
            HdB = 10*log10(H / max(H(:)) + 1e-12);
            set(app.hPanImg, 'CData', HdB, 'XData', [-1 + 1/nB, 1 - 1/nB], ...
                'YData', F.f([1 end])/1000);
            if F.estereo
                title(app.AxPan, 'Energía por posición estéreo', 'Color', app.T.texto);
            else
                title(app.AxPan, 'Señal mono: sin información estéreo', 'Color', app.T.seleccion);
            end
        end

        function actualizarVistaEspectrograma(app)
            if isempty(app.SdB), return; end
            pico = max(app.SdB(:));          % escala común original/procesada
            app.AxEspec.CLim = [pico - app.DdRango.Value, pico];
            fmax = min(app.DdFmax.Value, app.Fs/2/1000);
            app.AxEspec.YLim = [0 fmax];
            app.AxPan.YLim   = [0 fmax];
            colormap(app.AxEspec, app.DdColormap.Value);
            colormap(app.AxPan, app.DdColormap.Value);
            app.dibujarEspectro();
        end

        function dibujarEspectro(app)
            % Espectro promedio del fragmento (media de |X|^2 sobre las tramas
            % de la STFT), en dBFS con la misma normalización que el
            % espectrograma. Original y procesada comparten ejes y escala.
            F = app.Feat;
            if isempty(F), return; end
            fk = F.f / 1000;
            Eo = 10*log10(4*mean(double(F.P2), 2)/sum(F.w)^2 + eps);
            set(app.hEspOrig, 'XData', fk, 'YData', Eo);
            if isempty(app.Resultado)
                set(app.hEspProc, 'XData', NaN, 'YData', NaN);
                pico = max(Eo);
                estado = 'procesada = original';
            else
                Ep = 10*log10(mean(10.^(double(app.Resultado.SdB)/10), 2) + eps);
                set(app.hEspProc, 'XData', fk, 'YData', Ep);
                pico = max([Eo; Ep]);
                estado = 'original y procesada';
            end
            title(app.AxEspectro, sprintf('Espectro promedio del fragmento (%s)', estado), ...
                'Color', app.T.texto);
            app.AxEspectro.XLim = [0 min(app.DdFmax.Value, app.Fs/2/1000)];
            app.AxEspectro.YLim = [pico - app.DdRango.Value, pico + 6];
        end

        function mostrarVista(app)
            if isempty(app.Audio) || isempty(app.SdB), return; end
            [n1, n2] = app.indicesSeleccion();
            t = (n1 - 1 + (0:n2-n1)') / app.Fs;
            [Nw, hop] = app.parametrosStft();

            if strcmp(app.Vista, 'procesada') && ~isempty(app.Resultado)
                x = mean(app.Resultado.y, 2);  S = app.Resultado.SdB;
                color = app.T.procesada;       etiqueta = 'PROCESADA';
            else
                x = app.Mono(n1:n2);           S = app.SdB;
                color = app.T.onda;
                if strcmp(app.Vista, 'procesada')
                    etiqueta = 'procesada (sin cambios)';
                else
                    etiqueta = 'original';
                end
            end
            if numel(x) > 2e6
                % Fragmento largo: envolvente mín/máx (millones de puntos congelan la gráfica)
                [te, lo, hi] = envolvente_minmax(x, app.Fs, 20000);
                te = te + t(1);
                t = reshape([te te nan(size(te))]', [], 1);
                x = reshape([lo hi nan(size(te))]', [], 1);
            end
            set(app.hSenal, 'XData', t, 'YData', x, 'Color', color);
            app.dibujarEspectro();
            app.hImagen.CData = S;
            title(app.AxSenal, sprintf('Señal temporal (mono, %s) — %.2f s a %.2f s', ...
                etiqueta, app.Seleccion), 'Color', color);
            title(app.AxEspec, sprintf('Espectrograma %s — STFT Hann %d, hop %d (%g %%)', ...
                etiqueta, Nw, hop, 100*app.DdSolape.Value), 'Color', color);
        end

        function mostrarMascara(app)
            k = app.indiceSel();
            if isempty(k) || isempty(app.Feat) || ~app.ChkMascara.Value
                app.hMascara.Visible = 'off';
                set(app.hPanSel, 'XData', NaN, 'YData', NaN);
                return;
            end
            c = app.Componentes(k);
            M = mean(mascara_componente(app.Feat, c), 3);   % promedio de canales
            set(app.hMascara, 'CData', zeros(size(M, 1), size(M, 2), 3, 'uint8'), ...
                'AlphaData', double(0.75 * (1 - M)), 'Visible', 'on');
            set(app.hPanSel, 'XData', [c.pan1 c.pan2 c.pan2 c.pan1], ...
                'YData', [c.f1 c.f1 c.f2 c.f2]/1000);
        end

        function cambiarVista(app, vista)
            app.Vista = vista;
            app.estiloVista();
            app.mostrarVista();
            if strcmp(app.Estado, 'reproduciendo')
                app.iniciarDesde(app.posicionActual());
            end
        end
    end

    % =====================================================================
    %  COMPONENTES
    % =====================================================================
    methods (Access = private)

        function k = indiceSel(app)
            if isempty(app.CompSel) || isempty(app.Componentes)
                k = [];
            else
                k = find([app.Componentes.id] == app.CompSel, 1);
            end
        end

        function c = validarComponente(app, c)
            [Nw, ~] = app.parametrosStft();
            fN = app.Fs/2;  minF = 2*app.Fs/Nw;
            f = sort(min(max([c.f1 c.f2], 0), fN));
            if diff(f) < minF
                f(2) = min(fN, f(1) + minF);  f(1) = f(2) - minF;
            end
            c.f1 = f(1);  c.f2 = f(2);
            p = sort(min(max([c.pan1 c.pan2], -1), 1));
            if diff(p) < 0.05
                p(2) = min(1, p(1) + 0.05);  p(1) = p(2) - 0.05;
            end
            c.pan1 = p(1);  c.pan2 = p(2);
        end

        function c = crearComponente(app)
            % Valores por defecto neutros: todo el espectro, todo el paneo,
            % cualquier carácter, 0 dB. El usuario elige el carácter.
            [Nw, ~] = app.parametrosStft();
            c = AnalizadorApp.componenteVacio();
            c(1).id = app.SigId;
            c.f1 = 0;  c.f2 = app.Fs/2;
            c.suavF = round(2*app.Fs/Nw, 1);
            c.caracter = 'cualquiera';
            c.repeticion = 'cualquiera';
            c.pan1 = -1;  c.pan2 = 1;
            c.suavPan = 0.1;
            c.g = 0;
            c = app.validarComponente(c);
            app.SigId = app.SigId + 1;
        end

        function nuevoComponente(app)
            if isempty(app.Audio), return; end
            app.guardarHistorial();
            c = app.crearComponente();
            app.Componentes(end+1) = c;
            app.CompSel = c.id;
            app.cambiosComponentes();
            app.mostrarEstado(['Nuevo componente (todo el espectro, 0 dB). Elija el ' ...
                'carácter y la ganancia.']);
        end

        function propiedadCambiada(app, campo, valor)
            k = app.indiceSel();
            if isempty(k), return; end
            c = app.Componentes(k);
            switch campo
                case 'f1',           c.f1 = valor;
                case 'f2',           c.f2 = valor;
                case 'caracter',     c.caracter = valor;
                case 'repeticion',   c.repeticion = valor;
                case 'pan1',         c.pan1 = valor;
                case 'pan2',         c.pan2 = valor;
                case 'g',            c.g = valor;
            end
            app.guardarHistorial();
            app.Componentes(k) = app.validarComponente(c);
            app.cambiosComponentes();
        end

        function seleccionarComponente(app, id)
            if isempty(id), return; end
            app.CompSel = id;
            if ~isempty(app.LstComp.ItemsData)
                app.LstComp.Value = id;
            end
            app.actualizarPropiedades();
            app.mostrarMascara();
        end

        function eliminarComponente(app)
            k = app.indiceSel();
            if isempty(k)
                app.mostrarEstado('No hay componente seleccionado.');
                return;
            end
            app.guardarHistorial();
            app.Componentes(k) = [];
            if isempty(app.Componentes)
                app.CompSel = [];
            else
                app.CompSel = app.Componentes(min(k, numel(app.Componentes))).id;
            end
            app.cambiosComponentes();
        end

        function revertirTodo(app)
            if isempty(app.Componentes) && ~app.ChkSilenciar.Value
                app.mostrarEstado('No hay cambios que revertir.');
                return;
            end
            app.guardarHistorial();
            app.Componentes = AnalizadorApp.componenteVacio();
            app.CompSel = [];
            app.ChkSilenciar.Value = false;
            app.cambiosComponentes();
            app.mostrarEstado(['Se revirtieron todos los cambios: la salida es idéntica ' ...
                'a la original. "Deshacer" los recupera.']);
        end

        function cambiarSilenciar(app, valor)
            s = app.estadoActual();
            s.silenciar = ~valor;          % estado anterior al clic
            app.empujarHistorial(s);
            app.cambiosComponentes();
        end

        function clicPanorama(app, pan)
            k = app.indiceSel();
            if isempty(k) || isempty(app.Feat), return; end
            c = app.Componentes(k);
            ancho = c.pan2 - c.pan1;
            app.guardarHistorial();
            c.pan1 = pan - ancho/2;  c.pan2 = pan + ancho/2;
            app.Componentes(k) = app.validarComponente(c);
            app.cambiosComponentes();
        end

        % ---------------- Historial ----------------
        function s = estadoActual(app)
            s = struct('comps', {app.Componentes}, 'silenciar', app.ChkSilenciar.Value, ...
                       'sel', {app.CompSel});
        end

        function guardarHistorial(app)
            app.empujarHistorial(app.estadoActual());
        end

        function empujarHistorial(app, s)
            app.Historial{end+1} = s;
            if numel(app.Historial) > app.MAX_HISTORIAL
                app.Historial(1) = [];
            end
        end

        function deshacer(app)
            if isempty(app.Historial)
                app.mostrarEstado('Nada que deshacer.');
                return;
            end
            s = app.Historial{end};
            app.Historial(end) = [];
            app.Componentes = s.comps;
            app.ChkSilenciar.Value = s.silenciar;
            app.CompSel = s.sel;
            app.cambiosComponentes();
            app.mostrarEstado('Cambio deshecho.');
        end

        % ---------------- Procesado y presentación ----------------
        function cambiosComponentes(app)
            app.procesar();
        end

        function procesar(app)
            if isempty(app.Feat), return; end
            sonando = strcmp(app.Estado, 'reproduciendo');
            pos = app.posicionActual();

            if isempty(app.Componentes) && ~app.ChkSilenciar.Value
                app.Resultado = [];
            else
                app.mostrarEstado('Procesando…'); drawnow;
                app.Resultado = aplicar_componentes(app.Feat, app.Componentes, app.ChkSilenciar.Value);
                [Nw, hop] = app.parametrosStft();
                app.mostrarEstado(sprintf('Procesado: %d componente(s) · STFT Hann %d, hop %d · fs = %d Hz', ...
                    numel(app.Componentes), Nw, hop, app.Fs));
            end

            app.actualizarLista();
            app.mostrarVista();
            app.actualizarPropiedades();
            app.mostrarMascara();
            app.actualizarResultado();
            app.BtnDeshacer.Enable = ~isempty(app.Historial);

            if sonando
                app.iniciarDesde(pos);   % se escucha el cambio sin perder la posición
            end
        end

        function actualizarLista(app)
            if isempty(app.indiceSel()) && ~isempty(app.Componentes)
                app.CompSel = app.Componentes(end).id;
            end
            if isempty(app.Componentes)
                app.LstComp.Items = {};
                app.LstComp.ItemsData = [];
                return;
            end
            items = cell(1, numel(app.Componentes));
            for k = 1:numel(app.Componentes)
                c = app.Componentes(k);
                items{k} = sprintf('C%d · %s · %+g dB', c.id, ...
                    AnalizadorApp.etiquetaComponente(c), c.g);
            end
            app.LstComp.Items = items;
            app.LstComp.ItemsData = [app.Componentes.id];
            app.LstComp.Value = app.CompSel;
        end

        function actualizarPropiedades(app)
            k = app.indiceSel();
            hay = ~isempty(k);
            for j = 1:numel(app.ControlesProp)
                app.ControlesProp{j}.Enable = hay;
            end
            app.BtnEliminar.Enable = hay;
            if ~hay
                app.LblDerivadas.Text = ['Pulse "+ Nuevo" para crear un componente (todo el ' ...
                    'espectro) y elija su carácter.'];
                return;
            end

            c = app.Componentes(k);
            app.EdF1.Value       = c.f1;
            app.EdF2.Value       = c.f2;
            app.DdCaracter.Value = c.caracter;
            app.DdRepeticion.Value = c.repeticion;
            app.EdPan1.Value     = c.pan1;
            app.EdPan2.Value     = c.pan2;
            app.SpGanancia.Value = c.g;

            if ~isempty(app.Feat) && ~app.Feat.estereo
                app.LblDerivadas.Text = '⚠ Señal (casi) mono: el rango de paneo no tiene efecto.';
            else
                app.LblDerivadas.Text = '';
            end
        end

        function actualizarResultado(app)
            if isempty(app.Resultado)
                app.LblResultado.Text = 'Sin procesamiento: la versión procesada es idéntica a la original.';
                return;
            end
            if isempty(app.Componentes)
                app.LblResultado.Text = 'Sin componentes y con "Solo" activo: toda la salida queda en silencio.';
                return;
            end
            e = app.escalaReproduccion();
            if e < 1
                app.LblResultado.Text = sprintf(['⚠ La salida supera 0 dBFS. Para no recortar, ' ...
                    'ambas versiones se reproducen a %.1f dB.'], 20*log10(e));
            else
                app.LblResultado.Text = '';
            end
        end

        % ---------------- Exportación ----------------
        function exportarWav(app)
            % Guarda lo que se escucha como "Procesada" (respeta "Solo") en
            % exports/<canción>_<t1>-<t2>s_<fecha>.wav y un .txt con todos los
            % parámetros necesarios para reproducir el resultado.
            if isempty(app.Audio), return; end
            if ~isfolder(app.CarpetaExport), mkdir(app.CarpetaExport); end

            if isempty(app.Resultado)
                [n1, n2] = app.indicesSeleccion();
                y = double(app.Audio(n1:n2, :));  tipo = 'original';
            else
                y = double(app.Resultado.y);      tipo = 'procesada';
            end
            pico = max(abs(y(:)));
            escala = 1;
            if pico > 1                       % el WAV entero no admite |y| > 1
                escala = 0.999 / pico;
                y = y * escala;
            end

            [~, cancion] = fileparts(app.Ruta);
            marca = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            base  = sprintf('%s_%.0f-%.0fs_%s_%s', cancion, app.Seleccion, tipo, marca);
            rutaWav = fullfile(app.CarpetaExport, [base '.wav']);
            rutaTxt = fullfile(app.CarpetaExport, [base '.txt']);

            try
                audiowrite(rutaWav, y, app.Fs, 'BitsPerSample', 24);
                app.escribirMetadatos(rutaTxt, tipo, pico, escala);
            catch err
                uialert(app.Fig, err.message, 'No se pudo exportar');
                return;
            end
            app.mostrarEstado(sprintf('Exportado: exports/%s.wav (+ .txt con parámetros)', base));
            uialert(app.Fig, sprintf('Se guardó:\n%s\n\ny sus parámetros en:\n%s', ...
                rutaWav, rutaTxt), 'Exportado', 'Icon', 'success');
        end

        function escribirMetadatos(app, ruta, tipo, pico, escala)
            [Nw, hop] = app.parametrosStft();
            F = app.Feat;
            fid = fopen(ruta, 'w', 'n', 'UTF-8');
            cerrar = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, 'Archivo de origen: %s\n', app.Ruta);
            fprintf(fid, 'Fragmento: %.3f s a %.3f s (%.3f s)\n', app.Seleccion, diff(app.Seleccion));
            fprintf(fid, 'Versión exportada: %s\n', tipo);
            fprintf(fid, 'fs = %d Hz · %d canal(es)\n', app.Fs, size(app.Audio, 2));
            fprintf(fid, 'STFT: Hann %d muestras, salto %d (%.1f %% de solapamiento), Δf = %.2f Hz\n', ...
                Nw, hop, 100*(1 - hop/Nw), app.Fs/Nw);
            fprintf(fid, ['HPSS (FitzGerald 2010): l_harm %.0f ms = %d tramas (%.1f ms usados), ' ...
                'l_perc %.0f Hz = %d bins (%.1f Hz usados); máscara binaria, por canal\n'], ...
                1000*app.HpssT, F.Lt, 1000*F.Lt*hop/app.Fs, app.HpssF, F.Lf, F.Lf*app.Fs/Nw);
            I = F.RepInfo;
            if strcmp(I.metodo, 'original')
                fprintf(fid, 'REPET original: rango de período %.2f–%.2f s; máscara por canal\n', ...
                    app.Rep.pMin, app.Rep.pMax);
                fprintf(fid, '  período detectado: %.3f s (%d tramas), r = %d segmentos, BPM equivalente %.1f (si el período fuera un pulso)\n', ...
                    I.periodoS, I.periodo, I.r, I.bpmEquivalente);
            else
                fprintf(fid, 'REPET-SIM: k = %d, distancia mínima %.2f s (%d tramas), similitud mínima %.2f; máscara por canal\n', ...
                    app.Rep.k, app.Rep.d, I.D, app.Rep.u);
                fprintf(fid, '  diagnóstico: %.1f tramas por mediana en promedio (caben %d), similitud media %.2f\n', ...
                    I.tramasPromedio, I.tramasMaximas, I.similitudMedia);
            end
            fprintf(fid, 'Solo (silenciar lo demás): %s\n\n', mat2str(app.ChkSilenciar.Value));
            fprintf(fid, 'Componentes:\n');
            for k = 1:numel(app.Componentes)
                c = app.Componentes(k);
                fprintf(fid, '  C%d: %s | banda %.0f–%.0f Hz | paneo [%+.2f, %+.2f] | ganancia %+g dB\n', ...
                    c.id, AnalizadorApp.etiquetaComponente(c), c.f1, c.f2, c.pan1, c.pan2, c.g);
            end
            fprintf(fid, '\nPico antes de exportar: %.3f · escala aplicada: %.3f (%+.2f dB)\n', ...
                pico, escala, 20*log10(escala));
        end

        % ---------------- Ratón sobre el espectrograma ----------------
        function clicEspectrograma(app)
            if isempty(app.Audio) || isempty(app.Feat), return; end
            cp = app.AxEspec.CurrentPoint;
            t = min(max(cp(1, 1), app.Seleccion(1)), app.Seleccion(2));
            app.saltarA(t);
        end
    end

    % =====================================================================
    %  REPRODUCCIÓN
    % =====================================================================
    methods (Access = private)

        function reproducir(app)
            if isempty(app.Audio) || strcmp(app.Estado, 'reproduciendo'), return; end
            app.iniciarDesde(app.Offset);
        end

        function pausar(app)
            if ~strcmp(app.Estado, 'reproduciendo'), return; end
            pos = app.posicionActual();
            app.liberarPlayer();
            app.Offset = pos;
            app.Estado = 'pausado';
            app.actualizarBotones();
        end

        function detener(app)
            app.liberarPlayer();
            app.Offset = 0;
            app.Estado = 'detenido';
            if ~isempty(app.Audio)
                app.moverCursor(app.Seleccion(1));
            end
            app.actualizarBotones();
        end

        function alternar(app)
            if strcmp(app.Estado, 'reproduciendo')
                app.pausar();
            else
                app.reproducir();
            end
        end

        function saltarA(app, tAbs)
            if isempty(app.Audio), return; end
            off = min(max(tAbs - app.Seleccion(1), 0), diff(app.Seleccion));
            if strcmp(app.Estado, 'reproduciendo')
                app.iniciarDesde(off);
            else
                app.Offset = off;
                app.Estado = 'pausado';
                app.moverCursor(app.Seleccion(1) + off);
                app.actualizarBotones();
            end
        end

        function e = escalaReproduccion(app)
            % Misma escala para ambas versiones: la comparación A/B no se
            % altera y ninguna supera el rango [-1, 1] de la tarjeta de sonido.
            [n1, n2] = app.indicesSeleccion();
            picos = [1, max(abs(app.Audio(n1:n2, :)), [], 'all')];
            if ~isempty(app.Resultado)
                picos(end+1) = app.Resultado.pico;
            end
            e = 1 / max(picos);
        end

        function iniciarDesde(app, offset)
            app.liberarPlayer();
            if strcmp(app.Vista, 'procesada') && ~isempty(app.Resultado)
                x = app.Resultado.y;
            else
                [n1, n2] = app.indicesSeleccion();
                x = app.Audio(n1:n2, :);
            end
            x = x * app.escalaReproduccion();

            nIni = round(offset * app.Fs) + 1;
            if nIni >= size(x, 1)
                nIni = 1; offset = 0;
            end

            p = audioplayer(x, app.Fs);
            p.TimerPeriod = 0.03;
            p.TimerFcn = @(~,~) app.tick();
            p.StopFcn  = @(~,~) app.alTerminar();
            app.Player = p;

            app.Offset = offset;
            app.Estado = 'reproduciendo';
            app.actualizarBotones();
            app.Reloj = tic;            % posición por reloj, no por CurrentSample
            play(p, [nIni size(x, 1)]);
        end

        function pos = posicionActual(app)
            if strcmp(app.Estado, 'reproduciendo')
                pos = min(app.Offset + toc(app.Reloj), diff(app.Seleccion));
            else
                pos = app.Offset;
            end
        end

        function tick(app)
            if ~isvalid(app) || ~isvalid(app.Fig), return; end
            app.moverCursor(app.Seleccion(1) + app.posicionActual());
            drawnow limitrate;
        end

        function alTerminar(app)
            if ~isvalid(app) || ~isvalid(app.Fig), return; end
            if app.ChkRepetir.Value
                app.iniciarDesde(0);
            else
                app.Offset = 0;
                app.Estado = 'detenido';
                app.moverCursor(app.Seleccion(1));
                app.actualizarBotones();
            end
        end

        function liberarPlayer(app)
            if ~isempty(app.Player) && isvalid(app.Player)
                app.Player.StopFcn  = '';
                app.Player.TimerFcn = '';
                stop(app.Player);
            end
            app.Player = [];
        end

        function moverCursor(app, t)
            set(app.hCursores, 'Value', t);
            app.LblPosicion.Text = sprintf('t = %s', AnalizadorApp.mmss(t));
        end

        function actualizarBotones(app)
            hay = ~isempty(app.Audio);
            switch app.Estado
                case 'reproduciendo'
                    app.BtnPlay.Enable = 'off';  app.BtnPausa.Enable = 'on';
                    app.BtnStop.Enable = 'on';   app.BtnPlay.Text = '▶  Play';
                case 'pausado'
                    app.BtnPlay.Enable = hay;    app.BtnPausa.Enable = 'off';
                    app.BtnStop.Enable = 'on';   app.BtnPlay.Text = '▶  Reanudar';
                otherwise
                    app.BtnPlay.Enable = hay;    app.BtnPausa.Enable = 'off';
                    app.BtnStop.Enable = 'off';  app.BtnPlay.Text = '▶  Play';
            end
        end

        function teclaPresionada(app, evento)
            switch evento.Key
                case 'space'
                    app.alternar();
                case 'b'
                    if strcmp(app.Vista, 'original')
                        app.cambiarVista('procesada');
                    else
                        app.cambiarVista('original');
                    end
            end
        end

        function mostrarEstado(app, msg)
            app.LblEstado.Text = msg;
        end
    end

    % =====================================================================
    methods (Static, Access = private)
        function s = mmss(t)
            s = sprintf('%d:%05.2f', floor(t/60), mod(t, 60));
        end

        function c = componenteVacio()
            % Plantilla única de campos (mismo orden siempre)
            c = struct('id', {}, 'f1', {}, 'f2', {}, 'suavF', {}, ...
                'caracter', {}, 'repeticion', {}, 'pan1', {}, 'pan2', {}, 'suavPan', {}, ...
                'g', {});
        end

        function s = etiquetaComponente(c)
            % P. ej. 'Sostenido × No repetitivo', 'Percusivo', 'Todo'
            partes = {};
            switch c.caracter
                case 'sostenido', partes{end+1} = 'Sostenido';
                case 'percusivo', partes{end+1} = 'Percusivo';
            end
            switch c.repeticion
                case 'repetitivo',   partes{end+1} = 'Repetitivo';
                case 'norepetitivo', partes{end+1} = 'No repetitivo';
            end
            if isempty(partes)
                s = 'Todo';
            else
                s = strjoin(partes, ' × ');
            end
        end

        function r = repetPorDefecto(metodo)
            % Parámetros de repetición de los códigos de referencia
            r = struct('metodo', metodo, ...
                'k', AnalizadorApp.REP_K, 'd', AnalizadorApp.REP_D, 'u', AnalizadorApp.REP_U, ...
                'pMin', AnalizadorApp.REP_PMIN, 'pMax', AnalizadorApp.REP_PMAX);
        end

        function s = colorHex(rgb)
            s = sprintf('#%02X%02X%02X', round(255 * rgb));
        end

    end
end
