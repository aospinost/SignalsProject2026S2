function run_tests()
% RUN_TESTS Ejecuta todas las pruebas tests/test_*.m e imprime PASS/FAIL.
%
%   Desde la raíz del proyecto:
%       matlab -batch "addpath('core', 'tests'); run_tests"
%
%   Cada prueba es una función sin argumentos que lanza un error si falla.
%   Al final se lanza un error si alguna prueba falló.

    raiz = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(raiz, 'core'), fullfile(raiz, 'tests'), fullfile(raiz, 'app'));

    d = dir(fullfile(raiz, 'tests', 'test_*.m'));
    fallos = {};
    for k = 1:numel(d)
        [~, nombre] = fileparts(d(k).name);
        fprintf('--- %s\n', nombre);
        try
            feval(nombre);
            fprintf('PASS %s\n', nombre);
        catch err
            fprintf('FAIL %s: %s\n', nombre, err.message);
            fallos{end+1} = nombre; %#ok<AGROW>
        end
    end

    fprintf('\n%d prueba(s), %d fallo(s)\n', numel(d), numel(fallos));
    if ~isempty(fallos)
        error('Fallaron: %s', strjoin(fallos, ', '));
    end
end
