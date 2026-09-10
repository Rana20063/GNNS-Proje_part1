%% main_basic_simulation.m
% ADIM 1 - EN BASIT IMPLEMENTASYON (FİNAL VERSİYON)
% Tek anten, tek otantik uydu sinyali + tek spoofer sinyali
% Amac: GPS L1 C/A sinyalini uretmek, spoofer ile karistirmak ve
%       basit korelasyon analizi ile "iki tepe" (spoofing isareti)
%       gorunumunu ortaya cikarmak.
%
% BU VERSIYON: 2D (Kod Fazi x Doppler) korelasyon tespiti ile geliştirildi.
%
% CIKTISI BEKLENEN:
%   - Komut penceresinde: 2 tepe bulundu, konumları chip cinsinden
%   - 4 grafik: sinyal, genlik, 1D korelasyon, 2D heatmap

clear; clc; close all;

%% 1) PARAMETRELER
fs        = 5e6;       % ornekleme frekansi [Hz]
duration  = 2e-3;      % 2 kod periyodu [s]
prn       = 7;         % uydu PRN numarasi

% Otantik sinyal parametreleri
authDoppler   = 1500;   % [Hz]
authCodePhase = 300;    % [chip]
authPowerDb   = 0;      % referans guc [dB]

% Spoofer sinyali parametreleri
% ONEMLI: spoofDoppler = authDoppler (test kolayligi icin)
% Kod fazinda fark -> tepe ayrismasi
spoofDoppler   = authDoppler;   % [Hz] otantik ile AYNI (kod fazinda fark!)
spoofCodePhase = 300 + 60;      % [chip] otantikten 60 chip kaydirilmis
spoofPowerDb   = 3;             % [dB] otantikten daha guclu

% Gurultu parametresi
noisePowerDb = -30;             % [dB] dusuk gurultu icin temiz tepe

% Doppler arama araligi (korelasyon dedektöründe sweep için)
searchDopplerHz = authDoppler + (-100:25:100);  % ±100 Hz, 25 Hz adimla

%% 2) SINYALLERI URET
[authSig, t] = generate_if_signal(prn, fs, duration, authDoppler, authCodePhase, authPowerDb);
[spoofSig, ~] = generate_if_signal(prn, fs, duration, spoofDoppler, spoofCodePhase, spoofPowerDb);

% AWGN gurultusu
noise = 10^(noisePowerDb/20) * (randn(size(t)) + 1j*randn(size(t)))/sqrt(2);

% Alinan sinyal = otantik + spoofer + gurultu
rxSig = authSig + spoofSig + noise;

%% 3) KORELASYON TABANLI TESPIT
searchChips = 0:0.5:1022.5;   % 0.5 chip cozunurlukte arama

[corrMag, codeAxis, peakInfo] = correlation_detector(rxSig, prn, fs, searchChips, searchDopplerHz);

%% 4) SONUCLARI YAZDIR
fprintf('\n');
fprintf('===== Temel Anti-Spoofing Benzetimi Sonuclari =====\n');
fprintf('PRN: %d\n', prn);
fprintf('Bulunan tepe (peak) sayisi: %d\n', peakInfo.numPeaks);
fprintf('Tepe konumlari [chip]: ');
fprintf('%g  ', peakInfo.peakLocsChips);
fprintf('\n');

if isfield(peakInfo, 'peakDopplerHz')
    fprintf('Tepe Doppler frekanslari [Hz]: ');
    fprintf('%g  ', peakInfo.peakDopplerHz);
    fprintf('\n');
end

fprintf('\n');
if peakInfo.isLikelySpoofed
    fprintf('>>> UYARI: Birden fazla korelasyon tepesi tespit edildi - OLASI SPOOFING!\n');
    for i = 1:peakInfo.numPeaks
        fprintf('    Tepe %d: %.1f chip, %.0f Hz, Genlik: %.3f\n', ...
                i, peakInfo.peakLocsChips(i), peakInfo.peakDopplerHz(i), peakInfo.peakVals(i));
    end
else
    fprintf('>>> Tek tepe tespit edildi - spoofing isareti yok.\n');
end
fprintf('===================================================\n\n');

%% 5) GORSELLESTIRME
figure('Name','Adim 1 - Temel GPS Anti-Spoofing Benzetimi', 'Position', [100 100 1200 700]);

% Sol ust: Zaman-alani sinyali (Real kismi)
subplot(2,2,1);
plot(t*1e3, real(rxSig), 'b', 'LineWidth', 0.5);
xlabel('Zaman [ms]'); 
ylabel('Genlik');
title('Alici Antenine Ulasan Bilesik Sinyal (Otantik + Spoofer + Gurultu)');
grid on;

% Sag ust: Sinyalin Genlik Zarfi
subplot(2,2,2);
plot(t*1e3, abs(rxSig), 'r', 'LineWidth', 0.5);
xlabel('Zaman [ms]'); 
ylabel('Genlik');
title('Alinan Sinyalin Buyuklugu |s(t)|');
grid on;

% Sol alt: 1D Korelasyon (tüm Doppler'larda maksimum)
corrMag_max = max(corrMag, [], 2);
subplot(2,2,3);
plot(codeAxis, corrMag_max, 'b-', 'LineWidth', 1.2);
hold on;
plot(peakInfo.peakLocsChips, peakInfo.peakVals, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
xlabel('Kod Fazi [chip]'); 
ylabel('Korelasyon Buyuklugu (Max over Doppler)');
title(sprintf('1D Korelasyon - %d tepe bulundu', peakInfo.numPeaks));
legend('Korelasyon', 'Tespit edilen tepeler', 'Location', 'best');
grid on;

% Sag alt: 2D Korelasyon Heatmap (Kod Fazi vs Doppler)
subplot(2,2,4);
imagesc(searchDopplerHz, codeAxis, corrMag);
set(gca, 'YDir', 'normal');
xlabel('Doppler [Hz]'); 
ylabel('Kod Fazi [chip]');
title('2D Korelasyon: Kod Fazi vs Doppler');
colorbar;
hold on;
plot(peakInfo.peakDopplerHz, peakInfo.peakLocsChips, 'r*', 'MarkerSize', 15, 'LineWidth', 2);
colormap(gca, 'jet');

fprintf('\nGrafik penceresi acildi.\n');
