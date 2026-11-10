function res = aplicar_componentes(F, comps, silenciarResto)
% APLICAR_COMPONENTES Aplica la ganancia de cada componente y reconstruye la
% señal.
%
%   res = aplicar_componentes(F, comps, silenciarResto)
%
%   F              : salida de caracteristicas_tf (STFT por canal + pistas)
%   comps          : arreglo de componentes (ver mascara_componente) + campo g [dB]
%   silenciarResto : true -> se anula todo lo que no pertenece a ningún componente
%
%   Ganancia por bin y por canal (las máscaras son nF x nT x C):
%     G_k = 1 + (10^(g_k/20) - 1) * M_k ,   G = prod_k G_k
%     si silenciarResto:  G = G .* max_k M_k
%   Y_c = G(:,:,c) .* X_c en cada canal -> calcular_istft.
%
%   res.y    : señal procesada N x C (single)
%   res.pico : valor absoluto máximo de res.y
%   res.SdB  : espectrograma de la mezcla mono procesada [dB]

    nF = numel(F.f);  nT = numel(F.t);  C = numel(F.S);

    G  = ones(nF, nT, C, 'single');
    Mu = zeros(nF, nT, C, 'single');
    for k = 1:numel(comps)
        Mk = mascara_componente(F, comps(k));
        G  = G .* (1 + (10^(comps(k).g/20) - 1) * Mk);
        Mu = max(Mu, Mk);
    end
    if silenciarResto
        G = G .* Mu;
    end

    y = zeros(F.N, C);
    for c = 1:C
        y(:, c) = calcular_istft(double(F.S{c}) .* double(G(:, :, c)), F.Nw, F.hop, F.N);
    end
    res.y    = single(y);
    res.pico = max(abs(y(:)));

    % Espectrograma de la mezcla mono procesada (solo para visualizar, con
    % la misma escala que el de la original, que también es mono)
    Ym = calcular_stft(mean(y, 2), F.fs, F.Nw, F.hop);
    res.SdB = 20*log10(2*abs(Ym)/sum(F.w) + eps);
end
