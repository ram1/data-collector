% Author Sriram R Jayakumar
% Date 3/15/2013
% Description: TEC experiment data processing

% ##Input File Format##
% <benchmarks ordered by fixed frequency, increasing current>
% <benchmarks ordered by fixed current, increasing frequency>
% contour.pl produces files of this type. A short example:
% i, f
% 0, 1.6
% 1, 1.6
% 0, 1.7
% 1, 1.7
% 0, 1.6
% 0, 1.7
% 1, 1.6
% 1, 1.7
% A special case is when the benchmarks are executed only if f < freq_bound
% || i > i_bound. See run_benchmarks_1. Account for the standard case
% and the special case in computations.
% contour.pl and statistics_by_f.pl specifies the fields 
% (temperature, cpu power supply voltage, fan speed etc.) of the
% input file

% ##Standard System File##
% Each 1.6 to 2.0 range is for a single benchmark.
% Change standard data start based upon the benchmark you are analyzing.
% For the second benchmark it would be (2-1)*...
% You can create this format for one benchmark by running the process_benchmark script.
% You just have to make sure all the files are labeled tec0a. Then put the data
% for all benchmarks in one file
% 0,1.6
% 0,1.7
% 0,1.8
% 0,1.9
% 0,2.0
% 0,1.6
% 0,1.7
% 0,1.8
% 0,1.9
% 0,2.0

% ##TEC System Thermal Resistance File##
% This file lists all the 0 A datapoints for all the benchmarks.
% They can be ordered in any way.
% 0,
% 0,
% 0,
% 0,

% ##Notes##
% Examine ptec_avg, ptec_mad,

%##Parameters##
num_pws = 2; %tec power supplies
num_cores = 4;
spreader_r = 0.71; %[K/W]. Based on standard system results. UNUSED
name = 'gcc'; %benchmark name
num_freq = 13; %e.g. 13 steps, 1.6 to 2.8 GHz in 0.1 GHz steps
num_i = 6; %e.g. 5 steps, 0 to 4 A in 1 A steps
num_i_shortened = 6; %restricted case. DO NOT CHANGE
freq_bound = 2.9; %f above which (inclusive) i floor in effect. DO NOT CHANGE
freq_step = 0.1;
freq_low = 1.6; %minimum frequency
i_bound = 0; %i above which (inclusive) freq restriction not in effect. DO NOT CHANGE.
i_step = 1;
i_low = 0; %minimum current. 
num_freq_shortened = 13; %restricted case. DO NOT CHANGE
last_fixed_extra_col = 9; %non-variable # of extra columns. real extra cols - 1.
extra_columns = last_fixed_extra_col+num_cores; %real extra cols - 1. See note on extra csv below.
start_columns = 2;
columns_per_core = 5;
columns_per_pws = 5;
standard_data_start = (1-1)*(num_freq)+1; %TODO: change num_freq+1 back to num_freq
%TODO: change freq settings back to normal. povray we omitted 1.6 g

%##Computed Parameters##
freq_index_bound = round((freq_bound-freq_low)/freq_step)+1;
i_index_bound = round((i_bound-i_low)/i_step)+1;
power_supply_v_col = start_columns + columns_per_core + 1;
fan_col = start_columns + columns_per_core + 2;
freq_col = 2;
i_col = 1;
core_start_col = fan_col+1;


freq_vals = zeros(num_freq,1);
for i=1:num_freq
    freq_vals(i) = freq_low+(i-1)*freq_step;
end

i_vals = zeros(num_i,1);
for i=1:num_i
    i_vals(i) = i_low+(i-1)*i_step;
end

% ##Read##
%data should be #s only. See contour.pl
data = csvread(...
    'C:\Users\Ram\Documents\Brown\Semester 8\tec\data\4-5-2013\summary_gcc_reordered_averaged.csv');
data_size = size(data);
D = zeros(data_size(1),data_size(2)+extra_columns);
D(1:data_size(1),1:data_size(2)) = data;

standard_data = csvread(...
    'C:\Users\Ram\Documents\Brown\Semester 8\tec\data\4-5-2013\summary_standard_reordered_averaged.csv');


headings = cell(1,data_size(2)+extra_columns);
headings{1} = 'TEC Current [A]';
headings{2} = 'CPU Frequency [GHz]';
headings{3} = 'Average T [C]'; headings{4} = 'Min T [C]'; 
headings{5} = 'Max T [C]'; headings{6} = 'Mean Deviation T [C]';
headings{7} = 'Initial T [C]'; headings{8} = 'CPU Supply Shunt Voltage [V]';
headings{9} = 'Fan Speed [rpm]'; 
for i=1:num_cores
   headings{9+(i-1)*5+1} = sprintf('Core %d Average T [C]',i);
   headings{9+(i-1)*5+2} = sprintf('Core %d Min T [C]',i);
   headings{9+(i-1)*5+3} = sprintf('Core %d Max T [C]',i);
   headings{9+(i-1)*5+4} = sprintf('Core %d Mean Deviation T [C]',i);
   headings{9+(i-1)*5+5} = sprintf('Core %d Initial T [C]',i);
end
for i=1:num_pws
   headings{9+num_cores*5+(i-1)*5+1} = sprintf('TEC %d Average V [V]',i); 
   headings{9+num_cores*5+(i-1)*5+2} = sprintf('TEC %d Mean Deviation V [V]',i);
   headings{9+num_cores*5+(i-1)*5+3} = sprintf('TEC %d Average I [A]',i);
   headings{9+num_cores*5+(i-1)*5+4} = sprintf('TEC %d Mean Deviation I [A]',i);
   headings{9+num_cores*5+(i-1)*5+5} = sprintf('TEC %d Power [W]',i);
end
headings{9+(num_cores+num_pws)*5+1} = 'CPU Power [W]';
headings{9+(num_cores+num_pws)*5+2} = 'Total TEC Power [W]';
headings{9+(num_cores+num_pws)*5+3} = 'Total CPU+TEC Power [W]';
headings{9+(num_cores+num_pws)*5+4} = ...
    'Temperature Drop Relative to Scenario with Lowest TEC I Available [C]';
headings{9+(num_cores+num_pws)*5+5} = 'Simulated Spreader System T [C]';
headings{9+(num_cores+num_pws)*5+6} = 'T Drop vs. Spreader System [C]';
headings{9+(num_cores+num_pws)*5+7} = 'Frequency/Total Power';
headings{9+(num_cores+num_pws)*5+8} = 'Max Core T';
headings{9+(num_cores+num_pws)*5+9} = 'Standard System Max Core T';
headings{9+(num_cores+num_pws)*5+10} = 'Frequency^2/Total Power';
for i=1:num_cores
    headings{9+(num_cores+num_pws)*5+1+last_fixed_extra_col+i} = ...
        sprintf('Core %d Percent Temperature Difference to Adjacent Cores',i);
end


% ##Compute##
% The last column of data is 0, since all lines end with a comma
% in the summary files. Hence, write data over this column.
%Columns
% 0 cpu power
% 1 total tec power
% 2 cpu + total tec power
% 3 temperature drop (average temperature)
% 4 spreader system T (computed)
% 5 T difference vs spreader (maximum)
% 6 metric: f/total_power
% 7 max core T
% last_col_index+1...last_col_index+1+num_core-1: % T difference against adjacent cores
for i=1:data_size(1)
    %cpu power [w]
    D(i,data_size(2)+0) = 12000*D(i,power_supply_v_col);
    
    %total tec power [w]
    for j=1:num_pws
        D(i,data_size(2)+1) = D(i,fan_col+num_cores*columns_per_core+...
            (j-1)*columns_per_pws+5) + D(i,data_size(2)+1);
    end
    
    %total power [w] -- tec, cpu
    D(i,data_size(2)+2) = D(i,data_size(2)+0)+D(i,data_size(2)+1);
    
    %Max Core T. Out of all the cores, what is the maximum temperature
    %reached by any of the cores?
%     Checked by hand on omnetpp
    core_t_max = zeros(1,num_cores);
    for j=1:num_cores
       core_t_max(j) = D(i,core_start_col+(j-1)*5+2);
    end
    D(i,data_size(2)+7) = max(core_t_max);
    
%     checked
    standard_core_t_max = zeros(1,num_cores);
    for j=1:num_cores
       standard_core_t_max(j) = standard_data(...
           round((D(i,freq_col)-freq_low)/freq_step)+standard_data_start,...
           core_start_col+(j-1)*5+2);
    end
    D(i,data_size(2)+8) = max(standard_core_t_max);
    
    %DT := T difference compared to lowest applied TEC current case
    %Examine difference in avg. T. E.g. is @ 2.8g start at 1a, Dt computed
    %relative to 1a
    f = D(i,freq_col);
    if f>freq_bound
        index = ((f - freq_bound)/freq_step)*num_i_shortened +...
            ((freq_bound - freq_low)/freq_step)*num_i + 1;
    else
        index = ((f - freq_low)/freq_step)*num_i + 1;
    end
    D(i,data_size(2)+3) = D(i,start_columns+1)...
        - D(round(index),start_columns+1);
    
    %spreader system T
    D(i,data_size(2)+4) = D(i,data_size(2))*spreader_r + 20; %[c]
    
    %spreader system T difference vs. max T
    D(i,data_size(2)+5) = D(i,data_size(2)+7)-D(i,data_size(2)+8);
    
    %Performance Metric: frequency/watt
    %To verify, I checked a few calculations by hand.
    D(i,data_size(2)+6) = D(i,freq_col)/D(i,data_size(2)+2);
    D(i,data_size(2)+9) = D(i,freq_col)^2/D(i,data_size(2)+2);
    
    
    
    %Core Percent Differences
    %For a given core, compute the percent temperature difference with
    %neighboring cores. The computation assumes the cores are laid out
    %linearly in a row. If there are two neighbors, average the neighboring
    %temperatures first, and then compute a % difference. This is useful
    %for checking that applications are running on the right cores, given
    %the affinities set.
    %To verify the computations, I did a few by hand and compared.
    if num_cores>1
        core_ts = zeros(num_cores,1);
        for j=1:num_cores
           core_ts(j) = D(i,core_start_col+5*(j-1)); 
        end

        for j=1:num_cores
           if j==1
              pdiff = (core_ts(1)-core_ts(2))/mean(core_ts(1:2)); 
           elseif j==num_cores
                pdiff = (core_ts(num_cores)-core_ts(num_cores-1))/...
                    mean(core_ts(num_cores-1:num_cores));
           else
               avg_sides = mean([core_ts(j-1),core_ts(j+1)]);
               pdiff = (core_ts(j)-avg_sides)/mean([core_ts(j),avg_sides]);
           end
           pdiff=pdiff*100;
           D(i,data_size(2)+last_fixed_extra_col+j)=pdiff;
        end
    end
end

% Fixed Current
% -tec power average and mean deviation.
% -system thermal resistance
ordered_by_freq_end = (num_i-i_index_bound+1)*num_freq+...
    (i_index_bound-1)*num_freq_shortened;%line where fixed freq. block ends
ptec_avg = zeros(num_i,1);
ptec_mad = zeros(num_i,1);
for i=1:num_i
   if i < i_index_bound 
       start = ordered_by_freq_end+(i-1)*num_freq_shortened + 1;
       range_end = start+num_freq_shortened-1;
   else
       start=ordered_by_freq_end+(i_index_bound-1)*num_freq_shortened+1+...
           (i-i_index_bound)*num_freq;
       range_end = start+num_freq-1;
   end
   
   ptec_avg(i) = mean(D(start:range_end,data_size(2)+1));
   ptec_mad(i) = mad(D(start:range_end,data_size(2)+1));
   
%    tec effectiveness
   if i==num_i
      figure;
      plot(D(start:range_end,data_size(2)),...
          D(start:range_end,data_size(2)+5),'-o','LineWidth',2);
      title(sprintf('%s TEC Effectiveness at %0.2f [A] TEC Current',...
          name,i_vals(i)));
      xlabel('CPU Power [W]'); 
      ylabel('Difference (Max. T) Between Standard and TEC System [C]');
   end
   
%    thermal resistance
   if i_vals(i)==0
      [p,S] = polyfit(D(start:range_end,data_size(2)),...
        D(start:range_end,start_columns+1),1);
      fit_x = D(start,data_size(2)):0.01:D(range_end,data_size(2));
      fit_y = polyval(p,fit_x);
      
      figure; hold on;
      plot(D(start:range_end,data_size(2)+0),...
          D(start:range_end,start_columns+1),'-o','LineWidth',2);
      plot(fit_x,fit_y,':','LineWidth',2);
      title(sprintf('%s System Thermal Resistance',name)); 
      xlabel('CPU Power [W]');
      ylabel('CPU Junction Temperature [C]');
      legend('Data','Linear Fit','Location','NorthWest');
      annotation('textbox',[.15 .6 .1 .1],'String',...
        {'--fit--',sprintf('norm residues: %0.3f',S.normr),...
        sprintf('%0.3fx+%0.3f',p(1),p(2))});
      hold off;
   end
end

%Tec power consumption vs. current. Average tec power over DVFS settings. 
%The DVFS setting does affect tec power consumption, so we're plotting the
%average power consumption in the range of cpu power represented by the
%DVFS settings.
%Do a quadratic fit, since the function is analytically known to be
%quadratic.
[p,S] = polyfit(i_vals,ptec_avg,2);
fit_x = (i_low:i_step/4:i_vals(num_i))';
fit_y = polyval(p,fit_x);

figure; hold on; plot(i_vals,ptec_avg,'-o','LineWidth',2);
plot(fit_x,fit_y,':','LineWidth',2);
hold off;
legend('Data','Quadratic Fit','Location','NorthWest');
xlabel('TEC Current [A]'); ylabel('TEC Power Consumption [W]');
title(sprintf('%s Average TEC Power Consumption',name));
annotation('textbox',[.15 .6 .1 .1],'String',...
    {'--fit--',sprintf('norm residues: %0.3f',S.normr),...
    sprintf('%0.3fx^2+%0.3fx+%0.3f',p(1),p(2),p(3))});

disp('TEC Power Deviations Over Frequency as a Function of TEC Current');
disp(ptec_mad);




%Fixed Frequency
% -avg. junction t vs. tec i. Compute spreader system t with average cpu
% power over all runs.
% -cpu power variations
% -At maximum frequency, tec power required to cool to spreader system
% levels.
% -dvfs plots: cpu [w] vs. frequency
% -contour plot i vs. f
% -data fitting parameters
contour_t_vals = 75:-5:10;
contour_i = zeros(num_freq,length(contour_t_vals));
contour_f = zeros(num_freq,length(contour_t_vals));
contour_t = zeros(num_freq,length(contour_t_vals));

p_cpu_avg = zeros(num_freq,1);
p_cpu_mad = zeros(num_freq,1);
spreader_ts = zeros(num_freq,1);
spreader_ts_max = zeros(num_freq,1);

%Plot every third spreader system temperature to make the graph readable
% For the T vs I plots, make plots of both average benchmark temperature and
% maximum core temperature
%1 average temperature graph; 2 max temperature graph
t_axes = cell(1,2);
t_figures = cell(1,2);
for i=1:2
   figure; t_axes{i} = gca; t_figures{i} = gcf;
   hold(t_axes{i});
end


labels = cell(num_freq+floor(num_freq/3),1);
labelnum = 1;

% Data Fitting. Two datapoints (I1, I2) are required to determine Re and S.
% 0 current doesn't provide useful data. With currents from 0 to 4 [A] for
% each frequency, 2 fits can be done per frequency. This methodology uses
% the equation Ptec = S*DT*I + Re*I^2. Since there are two TECs, do the 
% transformation I --> 2*I, Re --> Re/2, K --> 2K.
% r_silicon and r_system (thermal resistances) are known parameters, in [K/W]
% re_alternative is another estimate of re. It comes from the quadratic fit
% of the average ptec curve as a function of I. The first division by 2 gives
% re for one TEC. The second division is the transformation described above.
% 
% fitted_alternative determines s using the same ptec equation, but using
% re_alternative as a known parameter. Only one datapoint is required to 
% find s. Omit the 0 current datapoint.
fits_per_freq = floor((num_i-1)/2);
fitted = zeros(num_freq*fits_per_freq,2); %re = (:,1), s = (:,2)
r_silicon = 1e-3/(156*8*19*1e-6);
r_spreader = .254e-2/(3e-2*3e-2*391) + 2.54e-5/(3e-2*3e-2*8.9); %spreader + tim
r_system = .709;
re_alternative = (2.857/2)/2;
fitted_alternative = zeros(num_freq*(num_i-1),1);

%Prediction
re_predicted = 0.46; %transformed.
k_predicted = 0.6; %[w/k]; based on playing with #s
r_predicted = 0.4; %[k/w]
s_predicted = 0.021; %[v/k]
ta_predicted = 273 + 30; %[k]
errors_predicted = zeros(num_i,1);
tj_predicted = zeros(num_i,1);
tc_predicted = zeros(num_i,1);
meanerror_predicted = zeros(num_freq,1);
iopt_predicted = zeros(num_freq,4);
figure; axis_predicted = gca; hold(axis_predicted);

for i=1:num_freq
    f = freq_low + (i-1)*freq_step;
    if i >= freq_index_bound
        start = 1+(freq_index_bound-1)*num_i+...
            (i-freq_index_bound)*num_i_shortened;
        range = start+num_i_shortened-1;
    else
        start = 1+(i-1)*num_i;
        range = start+num_i-1;
    end
    
    %For the fixed frequency, grab the relevant data. The data will
    %typically vary as a function of current.
    curr = D(start:range,1);
    t = D(start:range,start_columns+1);
    tcore_max = D(start:range,data_size(2)+7);
    p_cpu = D(start:range,data_size(2)+0);
    p_cpu_avg(i) = mean(p_cpu);
    p_cpu_mad(i) = mad(p_cpu);
    p_tec = D(start:range,data_size(2)+1);
    p_total = D(start:range,data_size(2)+2);
    
    %T vs. I plots
    colorOrder = get(t_axes{1},'ColorOrder');
    plot(t_axes{1},curr,t,'-o',...
        'Color',colorOrder(mod(labelnum,length(colorOrder))+1,:));
    colorOrder = get(t_axes{2},'ColorOrder');
    plot(t_axes{2},curr,tcore_max,'-o',...
        'Color',colorOrder(mod(labelnum,length(colorOrder))+1,:));
    labels{labelnum} = sprintf('%0.1f GHz',f);
    labelnum = labelnum + 1;

    %spreader_ts(i) = 20+spreader_r*p_cpu_avg(i);
    spreader_ts(i) = standard_data(standard_data_start+i-1,3);
    spreader_ts_max(i) = D(start,data_size(2)+8);
    if mod(i,3)==0
         spreader_t = zeros(num_i,1);
         spreader_t_max = zeros(num_i,1);
         for j=1:num_i
            spreader_t(j) = spreader_ts(i);
            spreader_t_max(j) = spreader_ts_max(i);
         end
         colorOrder = get(t_axes{1},'ColorOrder'); 
         plot(t_axes{1},curr,spreader_t,':',...
             'Color',colorOrder(mod(labelnum,length(colorOrder))+1,:));
         colorOrder = get(t_axes{2},'ColorOrder'); 
         plot(t_axes{2},curr,spreader_t_max,':',...
             'Color',colorOrder(mod(labelnum,length(colorOrder))+1,:));
         labels{labelnum} = sprintf('%0.1f Standard System',f);
         
         labelnum = labelnum + 1;
    end
    
    
%     Contour plot
        for j=1:length(contour_t_vals)
            goal = contour_t_vals(j);
            contour_t(i,j) = goal;
            contour_i(i,j) = -1;
            contour_f(i,j) = freq_vals(i);
            
            for k=1:(size(curr)-1)
                if (goal>=tcore_max(k)&&goal<=tcore_max(k+1)) || (goal<=tcore_max(k)&&goal>=tcore_max(k+1))
                    req_curr = curr(k)+i_step*(goal-tcore_max(k))/(tcore_max(k+1)-tcore_max(k));
                    contour_i(i,j) = req_curr;
                    break;
                end
            end
        end
    
%     Cooling to spreader system levels
%     If the data suggests cooling to a certain level 
%     Isn't possible, that data
%     point is marked as 0. Compute using average temperature over all
%     cores. Use linear interpolation. 
%     Checked by hand for omnetpp
    if i==num_freq
        p = polyfit(curr,D(start:range,data_size(2)+1),2);
        pwr_to_spr_lev = zeros(num_freq,1);
        
        for j=1:num_freq
            goal = spreader_ts_max(j);
            
            for k=1:(size(curr)-1)
                if (goal>=tcore_max(k)&&goal<=tcore_max(k+1)) || (goal<=tcore_max(k)&&goal>=tcore_max(k+1))
                    req_curr = curr(k)+i_step*(goal-tcore_max(k))/(tcore_max(k+1)-tcore_max(k));
                    pwr_to_spr_lev(j) = polyval(p,req_curr);
                    break;
                end
            end
        end
    end
    
    %Data Fitting
    for j=1:fits_per_freq
        tec_power_pair = p_tec(2+(j-1)*2:3+(j-1)*2);
        tec_current_pair = 2*curr(2+(j-1)*2:3+(j-1)*2);
        total_power_pair = p_total(2+(j-1)*2:3+(j-1)*2);
        cpu_power_pair = p_cpu(2+(j-1)*2:3+(j-1)*2);
        tj_pair = t(2+(j-1)*2:3+(j-1)*2)+273.15;
        
%         Using [K] is not strictly necessary since we end up using a
%         temeperature difference. Th = Ta + q_total*r_fan+spreader. 
%         Tc = Tj - q_cpu*r_silicon. The equations to solve are linear.
        th_pair = (273.15+24)+(r_system-r_silicon)*total_power_pair;
        tc_pair = tj_pair - cpu_power_pair*r_silicon;
        dt_pair = th_pair-tc_pair;
        M = [tec_current_pair.^2, dt_pair.*tec_current_pair];
        fitted((i-1)*fits_per_freq+1+(j-1),:) = (M\tec_power_pair)';
        
    end
    
    %         Alternative Method
    for j=2:num_i
       curr_transformed = 2*curr(j);
        th_alt = (273.15+24)+(r_system-r_silicon)*p_total(j);
        tc_alt = t(j) + 273.15 - p_cpu(j)*r_silicon;
        dt_alt = th_alt-tc_alt;
        fitted_alternative((i-1)*(num_i-1)+(j-1)) =...
            (p_tec(j)-re_alternative*curr_transformed.^2)/...
            (dt_alt*curr_transformed);
    end
    
    
    %Prediction
    tc_predicted = analytical_tc(p_cpu_avg(i),k_predicted,...
        re_predicted,r_predicted,2*curr,s_predicted,ta_predicted);
    tj_predicted = tc_predicted + (r_silicon+r_spreader)*p_cpu_avg(i) - 273.15;
    meanerror_predicted(i) = mean(abs(tj_predicted-t));
    iopt_predicted(i,:) = analytical_i_opt(p_cpu_avg(i),s_predicted,...
        k_predicted,r_predicted,ta_predicted,re_predicted)/2;
    if i==num_freq
       plot(axis_predicted,curr,tj_predicted,':*','LineWidth',2);
       plot(axis_predicted,curr,t,'-o','LineWidth',2);
       title(axis_predicted,...
           sprintf('%0.1f %s Analytical and Experimental Plots',f,name));
       legend(axis_predicted,{'Predicted','Actual'});
       xlabel('TEC Current [A]');
       ylabel('Average Junction Temperature [C]');
    end
    
end

%Prediction
disp('Prediction: mean errors, optimal currents');
disp(meanerror_predicted);
disp(iopt_predicted);

%Data Fitting
disp('Data Fitting: mean/mad for re,s,s_alternative');
disp(mean(fitted(:,1))); disp(mad(fitted(:,1)));
disp(mean(fitted(:,2))); disp(mad(fitted(:,2)));
disp(mean(fitted_alternative)); disp(mad(fitted_alternative));


%T vs. I plots
%Label the x axis with both tec current and the average tec power
%consumption over all runs (fixed current).
xlabels = cell(num_i,1);
for i=1:num_i
    xlabels{i} = sprintf('%0.1f, %0.1f',i_vals(i),ptec_avg(i));
end

for i=1:length(t_axes)
    legend(t_axes{i},labels);
    annotation(t_figures{i},'textbox','Position',[0.4,0.85,0.1,0.1],...
        'String',{'Dashed - Standard System','Solid - TEC System'});
    title(t_axes{i},sprintf('%s TEC Cooling at Varied CPU Frequencies',name));
    xlabel(t_axes{i},'TEC Current [A], TEC Power Consumption [W]'); 
    set(t_axes{i},'XTick',i_vals,'XTickLabel',xlabels);
    annotation(t_figures{i},'textarrow','Position',[0.95,0.2,0.001,0.2],...
        'String','Increasing Frequency',...
        'HorizontalAlignment','left','VerticalAlignment','top',...
        'TextRotation',90);
end
ylabel(t_axes{1},'Average Junction Temperature Over All Cores[C]'); 
ylabel(t_axes{2},'Max Junction Temperature Over All Cores[C]'); 
hold off;

% cpu power, averaged over all currents steps, vs. dvfs setting. Averaging
% over current steps is like averaging over multiple trials, since
% tec current doesn't affect cpu power consumption
figure; plot(freq_vals,p_cpu_avg,'-o','LineWidth',2);
xlabel('CPU Frequency [GHz]'); ylabel('CPU Power [W]');
title(sprintf('Average %s CPU Power vs. DVFS Setting',...
    name));
set(gca, 'XScale', 'linear', 'YScale', 'linear', 'XTick', freq_vals);

% cooling to spreader levels
figure;
plot(freq_vals,pwr_to_spr_lev,'o','LineWidth',2);
xlabel('DVFS Setting'); ylabel('TEC Power Consumption');
title(sprintf('%s Cooling to Spreader Levels at %0.2f GHz',name,...
    freq_vals(num_freq)));

%contour plot
min_index = 0;
max_index = length(contour_t_vals);
for i=1:length(contour_t_vals)
   if max(contour_i(:,i)) ~= -1 && ismember(-1,contour_i(:,i))
       if min_index == 0
           min_index = i;
       end
       
       if contour_i(1,i)==-1
           for j=1:num_freq
              if contour_i(j,i) ~= -1
                 good_i = contour_i(j,i);
                 good_f = contour_f(j,i);
                 break;
              end
           end
       else
           for j=num_freq:-1:1
               if contour_i(j,i) ~= -1
                 good_i = contour_i(j,i);
                 good_f = contour_f(j,i);
                 break;
              end
           end
       end
       
       for j=1:num_freq
          if contour_i(j,i) == -1
             contour_i(j,i) = good_i;
             contour_f(j,i) = good_f;
          end
       end
   end
   
   if max(contour_i(:,i))==-1 && min_index~=0 && max_index==length(contour_t_vals)
      max_index = i-1; 
   end
end
contour_freq_labels = cell(1,num_freq);
for i=1:num_freq
   contour_freq_labels{i} = sprintf('%0.1f, %0.1f', freq_vals(i), p_cpu_avg(i)); 
end

if min_index ~= 0
    figure;
    [C,h] = contour(contour_i(:,min_index:max_index),...
        contour_f(:,min_index:max_index),...
        contour_t(:,min_index:max_index),...
        fliplr(contour_t_vals(min_index:max_index)),'LineWidth',2);
    clabel(C,h);
    title(sprintf('%s Max. Core T Isotherms',name));
    xlabel('TEC Current [A],TEC Power Consumption [W]');
    ylabel('CPU Frequency [GHz], CPU Power [W]');
    set(gca,'XTick',i_vals,'XTickLabel',xlabels,...
        'YTick', freq_vals, 'YTickLabel', contour_freq_labels);
end


% ##Standard System##
spreader_data = csvread('C:\Users\Ram\Documents\Brown\Semester 8\tec\data\4-5-2013\summary_standard_reordered_averaged.csv');
[p,S] = polyfit(12000*spreader_data(:,power_supply_v_col),spreader_data(:,3),1);
figure; hold on;
plot(12000*spreader_data(:,power_supply_v_col),spreader_data(:,3),'o');
plot(12000*spreader_data(:,power_supply_v_col),polyval(p,12000*spreader_data(:,power_supply_v_col)),':','LineWidth',2);
title('Standard System Thermal Resistance');
xlabel('CPU Power [W]'); ylabel('Average Junction Temperature [C]');
legend('Data','Linear Fit','Location','NorthWest');
annotation('textbox',[.15 .6 .1 .1],'String',...
    {'--fit--',sprintf('norm residues: %0.3f',S.normr),...
    sprintf('%0.3fx+%0.3f',p(1),p(2))});
hold off;

% ##TEC System##
% To construct this file, take the 0 [A] data from each of the average
% benchmark files. The format of the file is the style generated by the
% reordering script.
tec_data = csvread('C:\Users\Ram\Documents\Brown\Semester 8\tec\data\4-5-2013\tec system thermal resistance.csv');
[p,S] = polyfit(12000*tec_data(:,8),tec_data(:,3),1);
figure; hold on;
plot(12000*tec_data(:,8),tec_data(:,3),'o');
plot(12000*tec_data(:,8),polyval(p,12000*tec_data(:,8)),':','LineWidth',2);
title('TEC System Thermal Resistance');
xlabel('CPU Power [W]'); ylabel('Average Junction Temperature [C]');
legend('Data','Linear Fit','Location','NorthWest');
annotation('textbox',[.15 .6 .1 .1],'String',...
    {'--fit--',sprintf('norm residues: %0.3f',S.normr),...
    sprintf('%0.3fx+%0.3f',p(1),p(2))});
hold off;

%###Output###
xlswrite(...
    'C:\Users\Ram\Documents\Brown\Semester 8\tec\data\4-5-2013\output.xlsx',...
    headings,name,'A1');
xlswrite(...
    'C:\Users\Ram\Documents\Brown\Semester 8\tec\data\4-5-2013\output.xlsx',...
    D,name,'A2');

