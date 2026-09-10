function [sig, t] = generate_if_signal(prn, fs, duration, dopplerHz, codePhaseChips, powerDb)
% GENERATE_IF_SIGNAL  Tek bir GPS L1 C/A sinyalini (otantik veya spoofer)
%                      taban-bant (baseband) esdegerinde uretir.
%
%   [sig, t] = generate_if_signal(prn, fs, duration, dopplerHz, codePhaseChips, powerDb)
%
%   prn            : PRN numarasi (1-32)
%   fs             : Ornekleme frekansi [Hz]
%   duration       : Sinyal suresi [s]
%   dopplerHz      : Doppler kaymasi [Hz]
%   codePhaseChips : Baslangic kod fazi [chip]
%   powerDb        : Goreli genlik [dB]
%
%   sig : 1xN kompleks taban-bant sinyali
%   t   : 1xN zaman vektoru [s]

    chipRate = 1.023e6;         % GPS L1 C/A chip hizi [chip/s]
    Tc = 1/chipRate;            % 1 chip suresi [s]

    ca = generate_ca_code(prn); % 1023 chiplik +-1 kod

    N = round(fs*duration);
    t = (0:N-1)/fs;

    % Her ornek icin kod fazini (chip cinsinden) hesapla ve 1023'e gore sar
    codePhaseSamples = mod(codePhaseChips + t/Tc, 1023);
    codeIdx = floor(codePhaseSamples) + 1;   % MATLAB 1-tabanli indeks
    codeSeq = ca(codeIdx);

    % Doppler kaymasi iceren tasiyici (kompleks taban-bant)
    carrier = exp(1j*2*pi*dopplerHz*t);

    amp = 10^(powerDb/20);
    sig = amp * codeSeq .* carrier;
end
