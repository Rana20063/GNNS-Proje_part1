function build_simulink_model()
% BUILD_SIMULINK_MODEL  Adim 1: Tam Fiziksel RF Ortami
% IF Modulasyonu, Doppler Kaymasi, Atmosferik Gecikme ve Dinamik Spoofer.

    modelName = 'adim1_basit_antispoofing';

    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end

    new_system(modelName);
    open_system(modelName);

    fprintf('Fiziksel gerceklige uygun bloklar ekleniyor...\n');
    
    % --- 1. Blok Yerlesimleri ---
    add_block('simulink/User-Defined Functions/MATLAB Function', [modelName '/Otantik_Sinyal_Uretici'], 'Position', [30 30 190 90]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [modelName '/Multipath_Uretici'], 'Position', [30 120 190 180]);
    add_block('simulink/Math Operations/Add', [modelName '/Kanal_Birlestirici'], 'Position', [250 60 290 120]);
    
    add_block('simulink/User-Defined Functions/MATLAB Function', [modelName '/Spoofer_Sinyal_Uretici'], 'Position', [30 210 190 270]);
    add_block('simulink/Math Operations/Add', [modelName '/Anten_Toplayici'], 'Position', [350 120 390 180]);
    add_block('simulink/Sources/Band-Limited White Noise', [modelName '/Alici_Gurultusu'], 'Position', [350 220 490 270]);
    add_block('simulink/Math Operations/Add', [modelName '/Gurultu_Toplayici'], 'Position', [450 150 490 210]);
    
    add_block('simulink/User-Defined Functions/MATLAB Function', [modelName '/Korelasyon_Dedektoru'], 'Position', [550 140 730 220]);
    add_block('simulink/Sinks/Scope', [modelName '/Korelasyon_Scope'], 'Position', [780 110 820 150]);
    add_block('simulink/Sinks/To Workspace', [modelName '/Sonuc_Workspace'], 'Position', [780 200 880 230]);

    % --- 2. Blok Parametre Ayarlari ---
    set_param([modelName '/Kanal_Birlestirici'], 'Inputs', '++');
    set_param([modelName '/Anten_Toplayici'], 'Inputs', '++');
    set_param([modelName '/Gurultu_Toplayici'], 'Inputs', '++');
    set_param([modelName '/Sonuc_Workspace'], 'VariableName', 'corrOut');
    set_param([modelName '/Alici_Gurultusu'], 'Cov', '0', 'Ts', '1/5e6');

    pause(1.5); 

    % --- 3. Guvenli Kablolama ---
    p_auth = get_param([modelName '/Otantik_Sinyal_Uretici'], 'PortHandles');
    p_mp = get_param([modelName '/Multipath_Uretici'], 'PortHandles');
    p_kanal = get_param([modelName '/Kanal_Birlestirici'], 'PortHandles');
    p_spoof = get_param([modelName '/Spoofer_Sinyal_Uretici'], 'PortHandles');
    p_anten = get_param([modelName '/Anten_Toplayici'], 'PortHandles');
    p_noise = get_param([modelName '/Alici_Gurultusu'], 'PortHandles');
    p_gurultu = get_param([modelName '/Gurultu_Toplayici'], 'PortHandles');
    p_corr = get_param([modelName '/Korelasyon_Dedektoru'], 'PortHandles');
    p_scope = get_param([modelName '/Korelasyon_Scope'], 'PortHandles');
    p_work = get_param([modelName '/Sonuc_Workspace'], 'PortHandles');

    add_line(modelName, p_auth.Outport(1), p_kanal.Inport(1), 'autorouting', 'on');
    add_line(modelName, p_mp.Outport(1), p_kanal.Inport(2), 'autorouting', 'on');
    add_line(modelName, p_kanal.Outport(1), p_anten.Inport(1), 'autorouting', 'on');
    add_line(modelName, p_spoof.Outport(1), p_anten.Inport(2), 'autorouting', 'on');
    add_line(modelName, p_anten.Outport(1), p_gurultu.Inport(1), 'autorouting', 'on');
    add_line(modelName, p_noise.Outport(1), p_gurultu.Inport(2), 'autorouting', 'on');
    add_line(modelName, p_gurultu.Outport(1), p_corr.Inport(1), 'autorouting', 'on');
    add_line(modelName, p_corr.Outport(1), p_scope.Inport(1), 'autorouting', 'on');
    add_line(modelName, p_corr.Outport(1), p_work.Inport(1), 'autorouting', 'on');

    % --- 4. MATLAB Function Algoritmalarini Hazirla (IF, Doppler, Atmosfer) ---
    
    % Otantik Sinyal: IF Modulasyonu, Atmosferik Gecikme, Doppler
    authScript = sprintf(['function y = fcn(u)\n%%#codegen\n' ...
        'persistent phase t\n' ...
        'if isempty(phase); phase = 300; end\nif isempty(t); t = 0; end\n' ...
        'Fs = 5e6; f_IF = 1.25e6; doppler = 1500; atmos_delay = 0.5;\n' ...
        'ca = generate_ca_code(7);\n' ...
        'idx = mod(floor(phase + atmos_delay), 1023) + 1;\n' ...
        'baseband = ca(idx);\n' ...
        'y = baseband * cos(2 * pi * (f_IF + doppler) * t);\n' ...
        'phase = phase + 1.023e6/Fs;\nt = t + 1/Fs;\nend']);
    
    % Multipath: Gecikmeli, Zayiflatilmis, Ayni IF ve Doppler
    mpScript = sprintf(['function y = fcn(u)\n%%#codegen\n' ...
        'persistent phase t\n' ...
        'if isempty(phase); phase = 302; end\nif isempty(t); t = 0; end\n' ...
        'Fs = 5e6; f_IF = 1.25e6; doppler = 1500; atmos_delay = 0.5;\n' ...
        'ca = generate_ca_code(7);\n' ...
        'idx = mod(floor(phase + atmos_delay), 1023) + 1;\n' ...
        'baseband = ca(idx);\n' ...
        'y = 0.4 * baseband * cos(2 * pi * (f_IF + doppler) * t);\n' ...
        'phase = phase + 1.023e6/Fs;\nt = t + 1/Fs;\nend']);
    
    % Dinamik Spoofer: Otantik ile baslar, yavasca kayar ve gucu artar
    spoofScript = sprintf(['function y = fcn(u)\n%%#codegen\n' ...
        'persistent phase t genlik drift\n' ...
        'if isempty(phase); phase = 300; end\nif isempty(t); t = 0; end\n' ...
        'if isempty(genlik); genlik = 1.0; end\nif isempty(drift); drift = 0; end\n' ...
        'Fs = 5e6; f_IF = 1.25e6; doppler = 1500; atmos_delay = 0.5;\n' ...
        'ca = generate_ca_code(7);\n' ...
        'drift = drift + 0.002;\n' ...
        'idx = mod(floor(phase + atmos_delay + drift), 1023) + 1;\n' ...
        'baseband = ca(idx);\n' ...
        'genlik = min(genlik + 0.0001, 2.0);\n' ...
        'y = genlik * baseband * cos(2 * pi * (f_IF + doppler) * t);\n' ...
        'phase = phase + 1.023e6/Fs;\nt = t + 1/Fs;\nend']);
    
    % Dedektor (Degisiklik yok)
    corrScript = sprintf(['function peakCount = fcn(u)\n%%#codegen\n' ...
        'coder.extrinsic(''run_simulink_correlation'');\n' ...
        'persistent buf count lastPeaks\n' ...
        'if isempty(buf); buf = zeros(1, 10000); end\n' ...
        'if isempty(count); count = 1; end\n' ...
        'if isempty(lastPeaks); lastPeaks = 0; end\n' ...
        'buf(count) = u;\ncount = count + 1;\n' ...
        'if count > 10000\n' ...
        '    count = 1;\n    tempPeaks = 0;\n' ...
        '    tempPeaks = run_simulink_correlation(buf);\n' ...
        '    lastPeaks = tempPeaks;\nend\n' ...
        'peakCount = lastPeaks;\nend']);

    % --- 5. Scriptleri Bloklara Yaz ---
    rt = sfroot;
    blks = rt.find('-isa', 'Stateflow.EMChart');
    for i = 1:length(blks)
        if contains(blks(i).Path, 'Otantik_Sinyal')
            blks(i).Script = authScript;
        elseif contains(blks(i).Path, 'Multipath_Uretici')
            blks(i).Script = mpScript;
        elseif contains(blks(i).Path, 'Spoofer_Sinyal')
            blks(i).Script = spoofScript;
        elseif contains(blks(i).Path, 'Korelasyon_Dedektoru')
            blks(i).Script = corrScript;
        end
    end

    % --- 6. Simulink Cozucu ve Zaman Ayarlari ---
    set_param(modelName, 'StopTime', '0.006');
    set_param(modelName, 'SolverType', 'Fixed-step');
    set_param(modelName, 'Solver', 'FixedStepDiscrete');
    set_param(modelName, 'FixedStep', '1/5e6');

    % --- 7. Modeli Kaydet ---
    save_system(modelName, fullfile(pwd, [modelName '.slx']));
    fprintf('\n>>> %s.slx | Asama 1 Tum Fiziksel Isterlerle (IF, Doppler, Atmosfer) Olusturuldu.\n', modelName);
end