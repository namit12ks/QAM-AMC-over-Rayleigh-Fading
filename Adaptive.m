
modelName = 'Adaptive_Final';

if bdIsLoaded(modelName)
    try set_param(modelName, 'SimulationCommand', 'stop'); catch; end
    while ~strcmp(get_param(modelName, 'SimulationStatus'), 'stopped'), pause(0.1); end
end
warning('off', 'all'); 


snr_profile = [40:-2:24, 26:2:38, 36:-2:22];  
time_steps = 1:length(snr_profile); %  each transmission frame

input_length = 2000;             
symbolDelay = 10;               
N_sps = 8;                     


BER_adaptive = zeros(1, length(time_steps));
Throughput_k = zeros(1, length(time_steps));
M_history = zeros(1, length(time_steps));

current_M = 64; 


for i = 1:length(time_steps)
    current_snr = snr_profile(i);
    k = log2(current_M); 
    adjusted_length = floor(input_length / k) * k;
    
                % Calculate delay 
    bitDelay = symbolDelay * k; 
    assignin('base', 'bitDelay', bitDelay);
    
    fprintf('Channel SNR: %2d dB | Transmitting at %2d-QAM ', current_snr, current_M);
    
                        % Update Simulink Blocks
    set_param([modelName '/Source'], 'SetSize', num2str(current_M));
    set_param([modelName '/Source'], 'SamplesPerFrame', num2str(adjusted_length));
    set_param([modelName '/Integer to Bit Converter'], 'nbits', num2str(k)); 
    try set_param([modelName '/Bit to Integer Converter'], 'nbits', num2str(k)); catch; end
    set_param([modelName '/Modulator'], 'M', num2str(current_M));
    set_param([modelName '/Demodulator'], 'M', num2str(current_M));
    
                    % Convert Eb/No to SNR 
    true_snr_dB = current_snr + 10*log10(k) - 10*log10(N_sps);
    assignin('base', 'current_snr', true_snr_dB);
    
                            % Run simulation
    simOut = sim(modelName, 'StopTime', '10000', 'ReturnWorkspaceOutputs', 'on', 'SimulationMode', 'normal');
    
               %  error
    try
        tempData = simOut.get('BER_result'); 
        if isnumeric(tempData)
            measured_BER = tempData(end, 1); 
        else
            measured_BER = tempData.Data(end, 1); 
        end
        if measured_BER <= 0
            measured_BER = 1e-6; 
        end
    catch
        measured_BER = NaN;
    end
    
 
        % results
    BER_adaptive(i) = measured_BER;
    Throughput_k(i) = k;
    M_history(i) = current_M;
    
    % adaptive m-qam (Reactive Decision Making)
    
    if measured_BER < 1e-3 && current_M < 64
        current_M = current_M * 4; 
        fprintf('UPGRADE to %d-QAM!\n', current_M);
        
    elseif measured_BER > 5e-3 && current_M > 4
        current_M = current_M / 4;
        fprintf('DOWNGRADE to %d-QAM!\n', current_M);
        
    else
        fprintf(' Holding .\n');
    end
    
    drawnow;       
end

warning('on', 'all'); 

                % Plotting
figure('Color', 'w', 'Name', '5G Mobility: Adaptive modulation', 'Position', [100, 100, 900, 800]);

                                % graph1
subplot(3,1,1);
plot(time_steps, snr_profile, '-k', 'LineWidth', 2);
hold on;
plot(time_steps, snr_profile, 'o', 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k');
grid on;
set(gca, 'XColor', 'k', 'YColor', 'k');
ylabel('Channel SNR (dB)', 'FontSize', 11, 'FontWeight', 'bold');
title('The Real-World Environment: Fluctuating Signal Strength', 'FontSize', 13, 'FontWeight', 'bold','Color', 'k');
xlim([1 length(time_steps)]);

                                % graph2
subplot(3,1,2);
semilogy(time_steps, BER_adaptive, '-ok', 'MarkerFaceColor', 'r', 'LineWidth', 2);
hold on;
yline(1e-2, '--r', 'Downgrade Threshold', 'LabelHorizontalAlignment', 'left');
yline(1e-3, '--g', 'Upgrade Threshold', 'LabelHorizontalAlignment', 'left');
grid on;
set(gca, 'XColor', 'k', 'YColor', 'k');
ylabel('Bit Error Rate (BER)', 'FontSize', 11, 'FontWeight', 'bold');
title('Staying in the Safe Zone', 'FontSize', 13, 'FontWeight', 'bold','Color', 'k');
ylim([1e-5 1]);
xlim([1 length(time_steps)]);

                                % graph3
subplot(3,1,3);
stairs(time_steps, Throughput_k, '-b', 'LineWidth', 3);
hold on;
plot(time_steps, Throughput_k, 'ob', 'MarkerFaceColor', 'b', 'MarkerSize', 6);
grid on;
set(gca, 'XColor', 'k', 'YColor', 'k');
xlabel('Time -->', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Throughput (Bits/Symbol)', 'FontSize', 11, 'FontWeight', 'bold');
title('Dynamic Shifting', 'FontSize', 13, 'FontWeight', 'bold','Color', 'k');
yticks([2 4 6]);
yticklabels({'2 (4-QAM)', '4 (16-QAM)', '6 (64-QAM)'});
ylim([1 7]);
xlim([1 length(time_steps)]);