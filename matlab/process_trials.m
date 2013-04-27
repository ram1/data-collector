% ##Parameters##
num_cores = 4;
num_pws = 2;
files = {'C:\Users\Ram\Documents\Brown\Semester 8\tec\data\4-5-2013\standard_setup\summary_tr1.csv',...
    'C:\Users\Ram\Documents\Brown\Semester 8\tec\data\4-5-2013\standard_setup\summary_tr2.csv'};
output_directory = 'C:\Users\Ram\Documents\Brown\Semester 8\tec\data\4-5-2013'; %no trailing \
name = 'standard';

% Computed Parameters
files_size = size(files);
num_files = files_size(2);
data = csvread(files{1});
data_size = size(data);

headings = cell(1,data_size(2));
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

% ##Computation##
% The matrix D is indexed as (trial,row,column)
D = zeros(num_files,data_size(1),data_size(2));
averaged = zeros(data_size(1),data_size(2));
meandev = zeros(data_size(1),data_size(2));
percent_meandev = zeros(data_size(1),data_size(2));

for i=1:num_files
   D(i,:,:) = csvread(files{i}); 
end

for j=1:data_size(1)
   for k=1:data_size(2)
      averaged(j,k) = mean(D(:,j,k));
      meandev(j,k) = mad(D(:,j,k));
      percent_meandev(j,k) = 100*meandev(j,k)/averaged(j,k);
   end
end

figure; hist(meandev(1:data_size(1)/2,3)); %vary columns,rows as necessary
title(sprintf('%s Average Benchmark Temperature: Deviation over Multiple Trials',name));
xlabel('Mean Deviation over Multiple Trials [C]');
ylabel('Number of Occurrences');

figure; hist(percent_meandev(1:data_size(1)/2,3));
title(sprintf('%s Average Benchmark Temperature: Relative Deviation over Multiple Trials',name));
xlabel('Relative Mean Deviation over Multiple Trials [%]');
ylabel('Number of Occurrences');

% ##Output##
csvwrite(sprintf('%s\\summary_%s_reordered_averaged.csv',output_directory,name),...
    averaged);

xlswrite(sprintf('%s\\errors.xlsx',output_directory),headings,...
    sprintf('%s averaged',name),'A1');
xlswrite(sprintf('%s\\errors.xlsx',output_directory),averaged,...
    sprintf('%s averaged',name),'A2');
xlswrite(sprintf('%s\\errors.xlsx',output_directory),headings,...
    sprintf('%s meandev',name),'A1');
xlswrite(sprintf('%s\\errors.xlsx',output_directory),meandev,...
    sprintf('%s meandev',name),'A2');
xlswrite(sprintf('%s\\errors.xlsx',output_directory),headings,...
    sprintf('%s percent meandev',name),'A1');
xlswrite(sprintf('%s\\errors.xlsx',output_directory),percent_meandev,...
    sprintf('%s percent meandev',name),'A2');