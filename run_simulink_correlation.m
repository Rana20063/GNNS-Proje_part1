function peakCount = run_simulink_correlation(rxSig)
% rxSig 1x10000 vektor olarak islenir
rxSig = rxSig(:).';

ca = generate_ca_code(7);
Fs = 5e6;
Fc = 1.023e6;
f_IF = 1.25e6;
doppler_shift = 1500; 

% Tam 1 milisaniyelik (5000 ornek) lokal referans uretimi
local_sig_I = zeros(1, 5000);
local_sig_Q = zeros(1, 5000);

for i = 1:5000
    t = (i-1) / Fs;
    idx = mod(floor((i-1) * Fc/Fs), 1023) + 1;
    baseband = ca(idx);

    % I (In-phase) ve Q (Quadrature) kanallari
    local_sig_I(i) = baseband * cos(2 * pi * (f_IF + doppler_shift) * t);
    local_sig_Q(i) = baseband * sin(2 * pi * (f_IF + doppler_shift) * t);
end

% I ve Q kanallarinda ayri ayri korelasyon
corr_I = xcorr(rxSig, local_sig_I);
corr_Q = xcorr(rxSig, local_sig_Q);

% KUSURSUZ ZARF DEDEKTORU: I^2 + Q^2 (Tasiyici dalga matematiksel olarak yok edilir)
corrResult = sqrt(corr_I.^2 + corr_Q.^2);

% Dinamik esik (threshold) - Ana sinyalin %35'i
threshold = max(corrResult) * 0.35; 

% Sinyal artik kusursuz pürüzsüzlükte oldugu icin minPeakDistance degerini normale (10) cektik
[~, locs] = findpeaks(corrResult, 'MinPeakHeight', threshold, 'MinPeakDistance', 10);

peakCount = length(locs);
end