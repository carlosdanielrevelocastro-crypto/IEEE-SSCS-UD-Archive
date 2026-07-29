% ============================================================================
% INTERFAZ PARA SENSOR DE GASES CONTAMINANTES EN CMOS 180nm
% Concurso de Circuitos Estudiantiles IEEE SSCS 2026
% ============================================================================
% Simulación analítica completa ajustada al Netlist Real de LTspice
% Parámetros extraídos directamente del modelo PTM 180nm (BSIM4)
% ============================================================================
clc; clear; close all;
fprintf('=============================================================\n');
fprintf('  SENSOR DE GASES CONTAMINANTES — CMOS 180nm (PTM)\n');
fprintf('  IEEE SSCS Student Circuit Contest 2026 — Sincronizado\n');
fprintf('=============================================================\n\n');

% ============================================================================
% PARÁMETROS DE PROCESO — REALES PTM 180nm (Extraídos de cmos180nm.lib)
% ============================================================================
p.VDD    = 1.8;          % [V]  Alimentación
p.Vtn    = 0.3999;       % [V]  Umbral NMOS (Vth0 NMOS_VTH)
p.Vtp    = 0.4039;       % [V]  Umbral PMOS (Absoluto Vth0 PMOS_VTH)
p.unCox  = 578.4e-6;     % [A/V²] µn·Cox NMOS Real (BSIM4)
p.upCox  = 138.1e-6;     % [A/V²] µp·Cox PMOS Real (BSIM4)
p.VAn    = 15;           % [V]  Tensión de Early NMOS (Estimada para ro)
p.VAp    = 12.5;         % [V]  Tensión de Early PMOS (Estimada para ro)
p.L      = 180e-9;       % [m]  Longitud de canal mínima

fprintf('[PROCESO] PTM 180nm: µnCox=%.1f µA/V² | µpCox=%.1f µA/V²\n', p.unCox*1e6, p.upCox*1e6);
fprintf('[PROCESO] Voltajes de Umbral: Vtn = +%.4f V | Vtp = -%.4f V\n\n', p.Vtn, p.Vtp);

% ============================================================================
% BLOQUE 1: BETA-MULTIPLIER (M1, M2, M3, M4, R1)
% ============================================================================
fprintf('-------------------------------------------------------------\n');
fprintf('  BLOQUE 1: BETA-MULTIPLIER (Referencia de Corriente)\n');
fprintf('-------------------------------------------------------------\n');
b1.WL1 = 1.8 / 0.18;     % M1: W=1.8u, L=180n -> W/L = 10
b1.WL2 = 7.2 / 0.18;     % M2: W=7.2u, L=180n -> W/L = 40
b1.K   = b1.WL2 / b1.WL1; % Factor multiplicador geométrico (K = 4)
b1.R1  = 3.2e3;          %

% Ecuación cuadrática clásica del BMR
b1.Iref = (2 / (p.unCox * b1.WL1 * b1.R1^2)) * (1 - 1/sqrt(b1.K))^2;

% Voltajes de operación de compuerta
b1.VGS2 = p.Vtn + sqrt(2 * b1.Iref / (p.unCox * b1.WL2));
b1.VGS1 = p.Vtn + sqrt(2 * b1.Iref / (p.unCox * b1.WL1));
b1.VR1  = b1.Iref * b1.R1;

fprintf('  Dimensiones: (W/L)_1 = %.0f | (W/L)_2 = %.0f (Factor K = %.0f)\n', b1.WL1, b1.WL2, b1.K);
fprintf('  Resistencia R1 elegida = %.1f kΩ\n', b1.R1/1e3);
fprintf('  I_REF Calculada Teórica = %.2f µA\n', b1.Iref*1e6);
fprintf('  VGS_M1 = %.1f mV | VGS_M2 = %.1f mV | Caída en R1 = %.1f mV\n\n', ...
    b1.VGS1*1e3, b1.VGS2*1e3, b1.VR1*1e3);

% ============================================================================
% BLOQUE 2: ESPEJO DE CORRIENTE PMOS (Polarización M6, M7, M8, M9)
% ============================================================================
fprintf('-------------------------------------------------------------\n');
fprintf('  BLOQUE 2: RED DE INYECCIÓN PMOS\n');
fprintf('-------------------------------------------------------------\n');
b2.WL_ref = 7.2 / 0.18;      % M3 y M4 tienen W/L = 40
b2.WL_inj = 4 * (1.8 / 0.18); % M6+M7+M8+M9 en paralelo = 4 * 10 = 40
b2.M      = b2.WL_inj / b2.WL_ref; % Relación de espejo = 1:1

b2.Iinj   = b2.M * b1.Iref;
b2.Vov    = sqrt(2 * b2.Iinj / (p.upCox * b2.WL_inj));
b2.VSG    = p.Vtp + b2.Vov;

fprintf('  Ancho total de inyección (4 transistores en paralelo) = %.1f\n', b2.WL_inj);
fprintf('  Relación de Espejo Real = %.0f:1\n', b2.M);
fprintf('  I_inyección Nominal Teórica = %.2f µA\n\n', b2.Iinj*1e6);

% ============================================================================
% BLOQUE 3: INVERSOR CMOS COMO TIA (M10, M11, M12 + R2)
% ============================================================================
fprintf('-------------------------------------------------------------\n');
fprintf('  BLOQUE 3: AMPLIFICADOR DE TRANSIMPEDANCIA (TIA)\n');
fprintf('-------------------------------------------------------------\n');
b3.WLn = 1.8 / 0.18;         % M12 -> W/L = 10
b3.WLp = 2 * (1.8 / 0.18);   % M10 + M11 en paralelo -> W/L = 20
b3.Rf  = 20e3;               % Resistencia R2 = 20k
b3.Cf  = 1e-12;              % Capacitor C1 = 1pF

% Punto de conmutación real del inversor del TIA
r_ratio  = sqrt(p.upCox * b3.WLp / (p.unCox * b3.WLn));
b3.Vtrip = (p.Vtn + (p.VDD - p.Vtp) * r_ratio) / (1 + r_ratio);

% Umbral crítico de resistencia del sensor para disparar el sistema
% V_N001 = V_trip cuando R_sensor = V_trip / I_inj
R_critical = b3.Vtrip / b2.Iinj;

fprintf('  Inversor TIA: (W/L)_N = %.0f | (W/L)_P = %.0f\n', b3.WLn, b3.WLp);
fprintf('  Tensión de Conmutación (Tierra Virtual) V_trip = %.3f V\n', b3.Vtrip);
fprintf('  UMBRAL CRÍTICO TEÓRICO DE R_sensor = %.2f kΩ\n\n', R_critical/1e3);

% ============================================================================
% BLOQUE 4: FILTRO PASO BAJO (Efecto Miller en Lazo Cerrado)
% ============================================================================
fprintf('-------------------------------------------------------------\n');
fprintf('  BLOQUE 4: FILTRO DE TIEMPO CONTINUO\n');
fprintf('-------------------------------------------------------------\n');
b4.f3dB = 1 / (2 * pi * b3.Rf * b3.Cf);
fprintf('  Frecuencia de corte pasiva del lazo (f_-3dB) = %.2f MHz\n\n', b4.f3dB/1e6);

% ============================================================================
% BLOQUE 5: BUFFER DIGITAL DE SALIDA (Inversor M13, M14)
% ============================================================================
fprintf('-------------------------------------------------------------\n');
fprintf('  BLOQUE 5: BUFFER INVERSOR DE SALIDA\n');
fprintf('-------------------------------------------------------------\n');
b5.WLn = 1.8 / 0.18; % M13 -> W/L = 10
b5.WLp = 1.8 / 0.18; % M14 -> W/L = 10
r_ratio_buf = sqrt(p.upCox * b5.WLp / (p.unCox * b5.WLn));
b5.Vtrip_buf = (p.Vtn + (p.VDD - p.Vtp) * r_ratio_buf) / (1 + r_ratio_buf);
fprintf('  Punto de disparo del Buffer final = %.3f V\n\n', b5.Vtrip_buf);

% ============================================================================
% GENERACIÓN DE VECTORES Y SIMULACIÓN COMPORTAMENTAL
% ============================================================================
Rs_vec = logspace(log10(500), log10(150e3), 1000);
Is_vec = b3.Vtrip ./ Rs_vec;
V_N002 = b3.Vtrip + b3.Rf * (b2.Iinj - Is_vec);
V_N002 = max(0, min(p.VDD, V_N002)); % Clamping a los rieles de tensión
V_OUT  = (V_N002 < b5.Vtrip_buf) * p.VDD; % Comportamiento del buffer inversor

% Respuesta Temporal Sincronizada con el transitorio de LTspice
t_vec = linspace(0, 5e-3, 2000); % 5 ms de simulación
Rs_t  = 1e3 + t_vec * 20e6;      % R3 del netlist: R={1k + time*20Meg}
Is_t  = b2.Iinj;                 % Corriente constante inyectada
V_N001_t = Is_t * Rs_t;          % Ley de Ohm en el nodo del sensor
V_N001_t = max(0, min(p.VDD, V_N001_t));

% Respuesta del amplificador inversor y buffer
V_N002_t = b3.Vtrip - (V_N001_t - b3.Vtrip) * 15; % Ganancia Open-Loop estimada
V_N002_t = max(0, min(p.VDD, V_N002_t));
V_OUT_t  = (V_N002_t < b5.Vtrip_buf) * p.VDD;

% Encontrar el tiempo exacto de conmutación teórica
[~, idx] = min(abs(Rs_t - R_critical));
t_disparo = t_vec(idx);

% ============================================================================
% VISUALIZACIÓN GRÁFICA (Digna de reporte IEEE)
% ============================================================================
fig = figure('Name','Sensor de Gases CMOS 180nm — Sincronizado', 'Color','white', 'Position',[100 100 1100 750]);
c_azul = [0.216 0.494 0.722]; c_verde = [0.114 0.620 0.459]; c_rojo = [0.733 0.180 0.180];

% --- Subplot 1: Voltajes de Estado Estacionario vs R_sensor ---
subplot(2,2,1);
semilogx(Rs_vec/1e3, V_N002*1e3, 'Color', c_verde, 'LineWidth', 2); hold on;
semilogx(Rs_vec/1e3, V_OUT*1e3, 'Color', c_azul, 'LineWidth', 2);
xline(R_critical/1e3, '--r', 'LineWidth', 1.2, 'Label', sprintf('R_{crit}=%.1fkΩ', R_critical/1e3));
xlabel('Resistencia del Sensor R_3 [kΩ]'); ylabel('Voltaje de Nodos [mV]');
title('Estática: Voltajes de Control vs R_{sensor}');
legend('V(N002) - Salida TIA', 'V_{OUT} Chip Digital', 'Location', 'west');
grid on; box on;

% --- Subplot 2: Respuesta Temporal - Transitorio de Detección ---
subplot(2,2,2);
plot(t_vec*1e3, V_N001_t, 'Color', 'k', 'LineWidth', 1.8); hold on;
plot(t_vec*1e3, V_N002_t, 'Color', c_verde, 'LineWidth', 1.8);
plot(t_vec*1e3, V_OUT_t, 'Color', c_azul, 'LineWidth', 2);
xline(t_disparo*1e3, '--r', 'LineWidth', 1.2, 'Label', sprintf('Disparo: %.2f ms', t_disparo*1e3));
xlabel('Tiempo [ms]'); ylabel('Voltaje de los Nodos [V]');
title('Dinámica: Transitorio Temporal Simulado (R = 1k + time \times 20M)');
legend('V(N001) Sensor', 'V(N002) TIA', 'V_{OUT} Buffer', 'Location', 'northwest');
grid on; box on;

% --- Subplot 3: Barrido de Estabilidad de la Fuente de Alimentación ---
subplot(2,2,3);
VDD_sweep = linspace(1.0, 2.5, 200);
Iref_sweep = b1.Iref * (1 + (VDD_sweep - p.VDD)/p.VAn);
plot(VDD_sweep, Iref_sweep*1e6, 'Color', c_rojo, 'LineWidth', 2); hold on;
xline(p.VDD, ':k', 'LineWidth', 1.2, 'Label', 'V_{DD} Nominal = 1.8V');
xlabel('Voltaje de Fuente V_{DD} [V]'); ylabel('I_{REF} [µA]');
title('Regulación: I_{REF} vs Tensión de Alimentación');
grid on; box on;

% --- Subplot 4: Tabla Resumen Matemática ---
subplot(2,2,4); axis off;
res_data = {
    'I_REF (Bloque 1)',       sprintf('%.2f µA',  b1.Iref*1e6),       'R1 = 3.2 kΩ';
    'I_inj (Bloque 2)',       sprintf('%.2f µA',  b2.Iinj*1e6),       'Espejo 1:1';
    'V_trip TIA (Bloque 3)',   sprintf('%.1f mV',  b3.Vtrip*1e3),      '(W/L)_P = 20';
    'R_critica Umbral',       sprintf('%.2f kΩ',  R_critical/1e3),    'Punto de Disparo';
    'f_-3dB Filtro',          sprintf('%.2f MHz', b4.f3dB/1e6),       'R2 = 20kΩ, C1 = 1pF';
    'V_trip Buffer Output',   sprintf('%.1f mV',  b5.Vtrip_buf*1e3),  'M13/M14 (1:1)'
};
colnames = {'Parámetro', 'Valor Analítico', 'Condición de Red'};
uitable(fig, 'Data', res_data, 'ColumnName', colnames, ...
    'Units', 'normalized', 'Position', [0.55, 0.08, 0.38, 0.35], ...
    'FontSize', 9, 'ColumnWidth', {140, 100, 110}, 'RowName', {});

sgtitle('Memoria de Cálculo de la Interfaz del Sensor CMOS 180nm', 'FontWeight', 'bold', 'FontSize', 12);