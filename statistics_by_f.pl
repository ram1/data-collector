#!/usr/bin/perl
#Usage
#./statistics.pl [freq] [directory] [tec]
#./statistics.pl [freq] [directory]
#Processes data by benchmark

$num_args = @ARGV;
if (($num_args != 3) && ($num_args != 2)) { die "2 or 3 arguments expected; $num_args: @ARGV provided\n"; }
$freq = $ARGV[0];
$dirname = $ARGV[1];
if ($num_args == 3) { $tec = $ARGV[2]; } else { $tec = ""; } #"tec_" or ""

print "@ARGV\n";
$output_file = join "","summary_",$tec,$freq,g,".csv";
system("rm -f $dirname\/$output_file");
open(OUTPUT_FILE, ">>", "$dirname\/$output_file") or die "can't open $dirname\/$output_file for writing: $!\n";
print OUTPUT_FILE "benchmark,avg_T[C],min,max,meandev,initial,avg_shunt_v[V],"
	. "avg_fan_rpm, core[i] T, core[i] Tmin, core[i] Tmax, core[i] Tmeandev,"
	. "core[i] Tinitial\n";

opendir(DIR, $dirname) or die "can't opendir $dirname: $!";
$regex = join "","_",$freq;

@files = (); 
while (defined($file = readdir(DIR)))
{
	push(@files, $file);
}
@files_sorted = (sort @files);
closedir(DIR);

$num_cores = 4;

foreach $file (@files_sorted)
{
 	if ($file =~ m/\Q$regex/ && $file !~ m/summary/)
	{
		print "$file\n";
		open(FILE, "<", "$dirname\/$file") or die "can't open $file for reading: $!\n";

		$t_min = inf;
		$t_max = -inf;
		$t_sum = 0;
		@temperatures = ();		
		@core_temps = (); 
		@core_tmin = ();
		@core_tmax = ();
		@core_tsum = ();
		for ($core=0; $core < $num_cores; $core++) 
		{
			@core_tmin[$core] = inf;
			@core_tmax[$core] = -inf;
			@core_tsum[$core] = 0;
		}

		$v_sum = 0;
		@voltages = ();

		$rpm_sum = 0;
		$num_rpm = 0;

		while (defined($line = <FILE>))
		{
			@columns = split(/\s+/, $line);

			#Average T over all cores
			$t =($columns[0]+$columns[1]+$columns[2]+$columns[3])/4;
			
			#Per core statistics
			for ($core=0; $core < $num_cores; $core++) 
			{
				$t_core = $columns[$core];
				push @{$core_temps[$core]}, $t_core;
				if($t_core < $core_tmin[$core])
				{
					$core_tmin[$core] = $t_core;
				}	
				if($t_core > $core_tmax[$core])
				{
					$core_tmax[$core] = $t_core;
				}
				$core_tsum[$core] = $core_tsum[$core] + $t_core;	
			}
			

			push(@temperatures, $t);
			if ($t < $t_min)
			{
				$t_min = $t;
			}
			if ($t > $t_max)
			{
				$t_max = $t;
			}
			$t_sum = $t_sum + $t;
			
			$v = $columns[4];
			$v_sum = $v_sum + $v;
			push(@voltages, $v);

			$rpm_sum = $rpm_sum + $columns[6];
			$num_rpm = $num_rpm + 1;
		}
		
		$t_avg = $t_sum / (scalar @temperatures);
		
		$t_mean_dev_sum = 0;
		foreach $i (@temperatures)
		{
			$t_mean_dev_sum = $t_mean_dev_sum + abs($i - $t_avg);
		}
		$t_mean_dev = $t_mean_dev_sum / (scalar @temperatures);

		$v_avg = $v_sum / (scalar @voltages);
		$rpm_avg = $rpm_sum / $num_rpm;

		@file_parts = split(/_/, $file);
		print OUTPUT_FILE "$file_parts[0] $file_parts[2],$t_avg,$t_min,$t_max,$t_mean_dev,$temperatures[0],$v_avg,$rpm_avg";	

		for ($core=0; $core < $num_cores; $core++) 
		{
			$t_core_avg = $core_tsum[$core] / (scalar @{$core_temps[$core]});
			$core_meandev_sum = 0;
			foreach $ct (@{$core_temps[$core]})
			{
				$core_meandev_sum = $core_meandev_sum 
					+ abs($ct - $t_core_avg);
			}
			$core_meandev = $core_meandev_sum / (scalar @{$core_temps[$core]});
			print OUTPUT_FILE ",$t_core_avg,$core_tmin[$core],$core_tmax[$core]," .
				"$core_meandev, $core_temps[$core][0]";
		}
		print OUTPUT_FILE "\n";
		close(FILE);
	}

}
close(OUTPUT_FILE);

