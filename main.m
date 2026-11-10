function app = main()
% MAIN Punto de entrada del proyecto.
%   Agrega las carpetas del proyecto al path y abre la interfaz.
%   Las canciones se buscan en la carpeta Music/ junto a este archivo.

    raiz = fileparts(mfilename('fullpath'));
    addpath(fullfile(raiz, 'app'), fullfile(raiz, 'core'));

    app = AnalizadorApp(fullfile(raiz, 'Music'));

    if nargout == 0
        clear app;   % la interfaz sigue viva: la figura guarda la referencia
    end
end
