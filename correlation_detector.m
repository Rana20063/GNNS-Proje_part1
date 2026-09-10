function [corrMag, codePhaseAxis, peakInfo] = correlation_detector(rxSig, prn, fs, searchChips, dopplerSearchHz)
% CORRELATION_DETECTOR  Alinan sinyali yerel PRN replikasi ile
%                        farkli kod fazlarinda VE Doppler'larinda
%                        korele eder ve birden fazla belirgin tepe
%                        noktasi (peak) olup olmadigini kontrol ederek
%                        basit bir "spoofing var mi?" gostergesi uretir.
%
%   [corrMag, codePhaseAxis, peakInfo] = correlation_detector(rxSig, prn, fs, searchChips, dopplerSearchHz)
%
%   rxSig           : Alinan (otantik + spoofer karisimi) taban-bant sinyali
%   prn             : Yerel replika icin PRN numarasi
%   fs              : Ornekleme frekansi [Hz]
%   searchChips     : Aranacak kod fazi araligi (orn. 0:0.5:1022.5)
%   dopplerSearchHz : Aranacak Doppler araligi (orn. 1400:50:1600) [OPSİYONEL]
%
%   corrMag      : 2D matris: satir=kod fazi, sutun=Doppler
%   codePhaseAxis: searchChips ile ayni, x-ekseni icin
%   peakInfo     : struct - .numPeaks, .peakLocsChips, .peakDopplerHz, .isLikelySpoofed

    if nargin < 5 || isempty(dopplerSearchHz)
        dopplerSearchHz = 1500;  % Varsayilan: tek Doppler değeri
    end

    N = length(rxSig);
    ca = generate_ca_code(prn);
    chipRate = 1.023e6;
    Tc = 1/chipRate;
    t = (0:N-1)/fs;

    % 2D korelasyon: satir=kod fazi, sutun=Doppler
    corrMag = zeros(length(searchChips), length(dopplerSearchHz));

    for kc = 1:length(searchChips)
        phase = searchChips(kc);
        codePhaseSamples = mod(phase + t/Tc, 1023);
        codeIdx = floor(codePhaseSamples) + 1;
        codeSeq = ca(codeIdx);

        for kd = 1:length(dopplerSearchHz)
            doppler = dopplerSearchHz(kd);
            % Yerel replika: kod + Doppler kompanzasyonu
            localCarrier = exp(-1j*2*pi*doppler*t);
            localReplika = codeSeq .* localCarrier;
            corrMag(kc, kd) = abs(sum(rxSig .* localReplika)) / N;
        end
    end

    codePhaseAxis = searchChips;

    % --- DÜZELTILMIŞ: Coklu-tepe (multi-peak) tespiti ---
    % Her kod fazi icin maksimum Doppler'da bulduğu değeri al
    corrMag_maxDoppler = max(corrMag, [], 2);
    
    % KATISIZ THRESHOLD: maxin %70'i (gürültü tepe atlayacak kadar yüksek)
    maxCorr = max(corrMag_maxDoppler);
    threshold = 0.50 * maxCorr;
    
    % MinPeakDistance: kod fazında en az 20 bin (1023 chip'in ~2%)
    % -> gerçek iki tepe (otantik + spoofer) bu kadar uzak olmali
    minDist = 100;
    
    % Şeminence: tepelerin "belginlik"i (yanındaki vadi ile fark)
    minProm = 0.2 * maxCorr;
    
    [pkVals, pkLocs] = findpeaks(corrMag_maxDoppler, ...
        'MinPeakHeight', threshold, ...
        'MinPeakDistance', minDist, ...
        'MinPeakProminence', minProm, ...
        'SortStr', 'descend', ...
        'NPeaks', 2);
    
    peakInfo.numPeaks = numel(pkVals);
    peakInfo.peakLocsChips = codePhaseAxis(pkLocs);
    peakInfo.peakVals = pkVals;
    
    % Her tepe icin maksimum Doppler'i bul
    peakInfo.peakDopplerHz = zeros(1, peakInfo.numPeaks);
    for p = 1:peakInfo.numPeaks
        idx = pkLocs(p);
        [~, dopIdx] = max(corrMag(idx, :));
        peakInfo.peakDopplerHz(p) = dopplerSearchHz(dopIdx);
    end
    
    % Birden fazla guclu, birbirinden ayri tepe -> olasi spoofing isareti
    peakInfo.isLikelySpoofed = peakInfo.numPeaks > 1;
end
