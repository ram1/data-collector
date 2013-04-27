% Sriram Jayakumar
% 4/11/2013
% Input
% The output of the data collector software for one trial. The
% data file that shows variation over time.
% Output
% y = [
%     maximum temperature
%     mean error from tmax
%     average frequency
%     average current
%     # current switches
%     # frequency switches
%     runtime
%     pcpu avg
%     ptec avg
%     ptotal
%     % time in violation of constraints
%     % of violations due to temperature
%     % of violations due to power
% ]
    
function y = process_control(filename)


    %Parameters
    NUM_CORES = 4;
    NUM_TEC = 2;
    TMAX = 45;
    PMAX = 40;
    DMM_COL = 5;
    FAN_COL = 7;
    TEC_COL = 8;
    TIME_COL = 12;
    FREQ_COL = 13;
    I_MIN = 0.5;
    I_MAX = 4;

    D = dlmread(filename);
    data_size = size(D);

    t_max = max(D(:,1:NUM_CORES),[],2);
    t_error = max(D(:,1:NUM_CORES),[],2)-TMAX;
    f_avg = mean(D(:,FREQ_COL));
    itec_avg = mean(D(:,TEC_COL+1)); 
    ptec = zeros(data_size(1),1);
    for i=1:NUM_TEC
        ptec = ptec + D(:,TEC_COL+2*(i-1)).*D(:,TEC_COL+2*(i-1)+1);
    end
    pcpu = D(:,DMM_COL)*12000;
    ptotal = pcpu + ptec;
    
    num_i_switches = 0;
    num_f_switches = 0;
    runtime = D(data_size(1),TIME_COL)/1000;
    num_violations = 0;
    num_t_violations = 0;
    num_p_violations = 0;
    for i=1:data_size(1)
       t = t_max(i);
       p = ptotal(i); 
       if t > TMAX || p > PMAX
          num_violations = num_violations+1; 
          if t > TMAX
             num_t_violations = num_t_violations+1; 
          end
          if p > PMAX
                num_p_violations = num_p_violations+1;
          end
       end
       if i~=1 && abs(D(i,TEC_COL+1)-D(i-1,TEC_COL+1))>1e-4
           num_i_switches = num_i_switches+1;
       end
       if i~=1 && abs(D(i,FREQ_COL+1)-D(i-1,FREQ_COL+1))>1e-4
           num_f_switches = num_f_switches+1;
       end
       %assert(D(i,TEC_COL+1)<I_MAX+1e-1 && D(i,TEC_COL+1)>I_MIN-1e-1);
    end
    percent_violation = 100*num_violations/data_size(1);
    percent_t_violation = 100*num_t_violations/num_violations;
    percent_p_violation = 100*num_p_violations/num_violations;
    
    
    y = [max(t_max); mean(abs(t_error)); f_avg; itec_avg; mean(ptec); mean(pcpu);... 
        mean(ptotal);num_i_switches; num_f_switches; runtime;...
        percent_violation; percent_t_violation; percent_p_violation];
    
    %Plotting
    figure;
    time = D(:,TIME_COL)/1000;
    
    subplot(4,1,1);
    hold on;
    plot(time,t_max,'-');
    threshold = zeros(data_size(1),1);
    threshold(:,1) = TMAX;
    plot(time, threshold,':');
    ylabel('Maximum Core T [C]');
    hold off;
    
    subplot(4,1,2);
    hold all;
    plot(time,ptotal);
    plot(time,ptec);
    plot(time,pcpu);
    threshold = zeros(data_size(1),1);
    threshold(:,1) = PMAX;
    plot(time, threshold, ':');
    legend('Total', 'TEC', 'CPU');
    ylabel('Power [W]');
    hold off;
    
    subplot(4,1,3);
    plot(time,D(:,FREQ_COL));
    ylabel('Frequency [GHz]');
    
    subplot(4,1,4);
    plot(time,D(:,TEC_COL+1));
    ylabel('TEC Current [A]');
    xlabel('Time [s]');
    

end