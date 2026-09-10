function ca = generate_ca_code(PRN)
% GENERATE_CA_CODE  GPS L1 C/A (Gold) kodu üretir - 1023 chip, +-1 (BPSK)
%
%   ca = generate_ca_code(PRN)
%
%   PRN : Uydu numarasi (1-32)
%   ca  : 1x1023 vektor, degerler +1/-1

    % PRN 1..32 icin G2 kayma yaptiran iki musluk (tap) tablosu
    g2tap = [ 2  6;  3  7;  4  8;  5  9;  1  9;  2 10;  1  8;  2  9; ...
              3 10;  2  3;  3  4;  5  6;  6  7;  7  8;  8  9;  9 10; ...
              1  4;  2  5;  3  6;  4  7;  5  8;  6  9;  1  3;  4  6; ...
              5  7;  6  8;  7  9;  8 10;  1  6;  2  7;  3  8;  4  9];

    if PRN < 1 || PRN > 32
        error('PRN 1 ile 32 arasinda olmalidir.');
    end

    tap1 = g2tap(PRN,1);
    tap2 = g2tap(PRN,2);

    % Kaydirmali kayitlar (shift register), hepsi 1 ile baslar
    g1 = ones(1,10);
    g2 = ones(1,10);

    ca = zeros(1,1023);

    for i = 1:1023
        % Cikis: G1'in son biti XOR G2'nin iki musluk biti
        ca(i) = mod(g1(10) + g2(tap1) + g2(tap2), 2);

        % G1 geri besleme: 3. ve 10. bitler (polinom x^10+x^3+1)
        g1_fb = mod(g1(3) + g1(10), 2);
        g1 = [g1_fb, g1(1:9)];

        % G2 geri besleme: 2,3,6,8,9,10. bitler
        g2_fb = mod(sum(g2([2 3 6 8 9 10])), 2);
        g2 = [g2_fb, g2(1:9)];
    end

    % 0/1 -> +1/-1 (BPSK) donusumu
    ca(ca == 0) = -1;
end
