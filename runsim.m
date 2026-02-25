
modelName = 'Adaptive_Final';


if bdIsLoaded(modelName)
    try set_param(modelName, 'SimulationCommand', 'stop'); catch; end
    while ~strcmp(get_param(modelName, 'SimulationStatus'), 'stopped'), pause(0.1); end
end
warning('off', 'all'); 

  %  Parameters
snr_dB = 44:-2:14;              
M_values = [4, 16, 64];        
input_length = 2000;             % Base frame size
symbolDelay = 10;               % 5 (Tx RRC) + 5 (Rx RRC)
N_sps = 8;                     % Upsampling factor from RRC filters

BER_results = zeros(length(M_values), length(snr_dB));


for m = 1:length(M_values)
    M = M_values(m);
    k = log2(M); 
    
    
    adjusted_length = floor(input_length / k) * k;
    
     % Calculate delay and push to workspace 
    bitDelay = symbolDelay * k; 
    assignin('base', 'bitDelay', bitDelay);
    
    fprintf('Simulating %d-QAM...\n', M);
    
           % Update Simulink Blocks
       set_param([modelName '/Source'], 'SetSize', num2str(M));
      set_param([modelName '/Source'], 'SamplesPerFrame', num2str(adjusted_length));
        set_param([modelName '/Integer to Bit Converter'], 'nbits', num2str(k)); 
     try set_param([modelName '/Bit to Integer Converter'], 'nbits', num2str(k)); catch; end
       set_param([modelName '/Modulator'], 'M', num2str(M));
        set_param([modelName '/Demodulator'], 'M', num2str(M));
    
    for i = 1:length(snr_dB)
       
                  % Convert Eb/No to SNR for AWGN block
        true_snr_dB = snr_dB(i) + 10*log10(k) - 10*log10(N_sps);
        assignin('base', 'current_snr', true_snr_dB);
        
        simOut = sim(modelName, 'StopTime', '10000', 'ReturnWorkspaceOutputs', 'on', 'SimulationMode', 'normal');
        
                    % Extracting the error
        try
            tempData = simOut.get('BER_result'); 
            if isnumeric(tempData)
                BER_results(m, i) = tempData(end, 1); 
            else
                BER_results(m, i) = tempData.Data(end, 1); 
            end
            
                    % Failsafe for 0 error
            if BER_results(m, i) <= 0
                BER_results(m, i) = 1e-6; 
            end
        catch
            BER_results(m, i) = NaN;
        end
        
        drawnow;       % Flush memory
    end
    fprintf('  Done with %d-QAM.\n', M);
end

warning('on', 'all'); 

                           % plots
figure('Color', 'w', 'Name', ' Rayleigh Fading BER'); 
colors = {'b', 'r', 'g'};

for m = 1:length(M_values)
                  
    semilogy(snr_dB, BER_results(m, :), '-o', 'MarkerEdgeColor', colors{m}, ...
        'MarkerFaceColor', colors{m}, 'Color', colors{m}, 'LineWidth', 2, ...
        'DisplayName', sprintf('Sim %d-QAM', M_values(m)));
    hold on;
    
    try
        theoretical_ber = berfading(snr_dB, 'qam', M_values(m), 1);
        semilogy(snr_dB, theoretical_ber, '--', 'Color', colors{m}, 'LineWidth', 1.5, ...
            'DisplayName', sprintf('Theory %d-QAM', M_values(m)));
    catch
    end
end

grid on; 
xlabel('SNR (Eb/No) (dB)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k'); 
ylabel('Bit Error Rate (BER)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
title('Adaptive M-QAM over Rayleigh Fading (RRC + ZF Equalization)','FontSize', 14, 'FontWeight', 'bold', 'Color', 'k'); 
legend('Location', 'southwest');

set(gca, 'XColor', 'k', 'YColor', 'k');


ylim([1e-5 1]); 
xlim([14 44]);