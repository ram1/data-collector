#!/usr/bin/perl
use Carp::Assert;
#Usage
#./statistics.pl [regex] [directory] [num lines to skip]
#Processes data files matching regex in the directory
#@author Sriram Jayakumar
#@date 3/7/2013

#Argument Parsing
tester();
my $num_args = @ARGV;
if ($num_args != 3) { die "3 arguments expected; $num_args: @ARGV provided\n"; }
my $regex = $ARGV[0]; #frequency or benchmark
my $dirname = $ARGV[1];
my $skip_lines = $ARGV[2];

#File Preparation
print "@ARGV\n";
my $output_file = join "","summary_",$regex,".csv";
system("rm -f $dirname\/$output_file");
open(OUTPUT_FILE, ">>", "$dirname\/$output_file") or die "can't open $dirname\/$output_file for writing: $!\n";
print OUTPUT_FILE "benchmark,avg_T[C],min,max,meandev,initial,avg_shunt_v[V],"
	. "avg_fan_rpm, core[i] T, core[i] Tmin, core[i] Tmax, core[i] Tmeandev,"
	. "core[i] Tinitial, tec[i] voltage [V], tec[i] voltage meandev,"
	. "tec[i] current [A], tec[i] current meandev, tec[i] power [W]\n";

opendir(DIR, $dirname) or die "can't opendir $dirname: $!";

my @files = (); 
while (defined($file = readdir(DIR)))
{
	push(@files, $file);
}
my @files_sorted = (sort @files);
closedir(DIR);

#Parameters
my $num_cores = 4;
my $num_tec = 2;

#Data
foreach my $file (@files_sorted)
{
 	if ($file =~ m/\Q$regex/ && $file !~ m/summary/)
	{
		print "$file\n";
		open(FILE, "<", "$dirname\/$file") or die "can't open $file for reading: $!\n";

		my @temperatures = ();		
		my @core_temps = (); 
		my @tec_v = ();
		my @tec_i = ();
		my @voltages = ();
		my @rpms = ();

		my $linenum = 1;
		while (defined(my $line = <FILE>))
		{
			if($linenum > $skip_lines)
			{
				my @columns = split(/\s+/, $line);

				#Average T over all cores
				my $t =($columns[0]+$columns[1]+$columns[2]+$columns[3])/4;
				push @temperatures,$t;
				
				#Per core statistics
				for (my $core=0; $core < $num_cores; $core++) 
				{
					push @{$core_temps[$core]}, $columns[$core];
				}
				
				#Regulator voltage
				push(@voltages, $columns[4]);

				#Fan speed
				push(@rpms, $columns[6]);

				my $tec_start_index = 7;
				for(my $k = 0; $k < $num_tec; $k++)
				{
					push @{$tec_v[$k]},$columns[$tec_start_index+$k*2];
					push @{$tec_i[$k]},$columns[$tec_start_index+$k*2+1];
				}
			}
		
			$linenum++;
		}
		
		print OUTPUT_FILE join ",",$file,compute_avg(@temperatures),
			compute_min(@temperatures),compute_max(@temperatures),
			compute_meandev(@temperatures),$temperatures[0],
			compute_avg(@voltages),compute_avg(@rpms),"";

		for ($core=0; $core < $num_cores; $core++) 
		{
			print OUTPUT_FILE join ",",compute_avg(@{$core_temps[$core]}),
				compute_min(@{$core_temps[$core]}),compute_max(@{$core_temps[$core]}),
				compute_meandev(@{$core_temps[$core]}),$core_temps[$core][0],"";
		}

		#TEC voltage,current,power
		for (my $k=0; $k<$num_tec; $k++)
		{
			my $avg_v, $avg_i;
			$avg_v = compute_avg(@{$tec_v[$k]});
			$avg_i = compute_avg(@{$tec_i[$k]});

			print OUTPUT_FILE join ",", $avg_v,
				compute_meandev(@{$tec_v[$k]}), $avg_i,
				compute_meandev(@{$tec_i[$k]}), $avg_v*$avg_i,"";
		}
		print OUTPUT_FILE "\n";
		close(FILE);
	}

}
close(OUTPUT_FILE);

sub compute_meandev
{
	my $meandev_sum, $meandev, $avg;
	$meandev_sum = 0;
	$meandev = 0;
	$avg = compute_avg(@_);

	foreach my $v (@_)
	{
		$meandev_sum += abs($v - $avg);
	}
	$meandev = $meandev_sum / (scalar @_);
	return $meandev;
}

sub compute_avg
{
	my $sum,$avg;
	$sum = 0;
	$avg = 0;

	foreach my $v (@_)
	{
		$sum += $v;
	}
	$avg = $sum / (scalar @_);
	return $avg;
}

sub compute_max
{
	my $max = -inf;
	foreach my $v (@_)
	{
		if($v > $max)
		{
			$max = $v;
		}
	}
	return $max;
}

sub compute_min
{
	my $min = inf;
	foreach my $v (@_)
	{
		if($v < $min)
		{
			$min = $v;
		}
	}
	return $min;
}

#Test Cases
#Additionally, for a real input file I checked the output
#of this script against results from Excel. The results match.
sub tester
{
	#simple
	my @numbers = (-1..12);
	assert(compute_avg(@numbers)==(77/14));
	assert(compute_min(@numbers)==-1);
	assert(compute_max(@numbers)==12);
	assert(compute_meandev(@numbers)==3.5); #via MS Excel

	#floating point, negative numbers
	@numbers = (1.5,7.24,9.33,2.73,-54,1000);
	assert(abs(compute_avg(@numbers)-161.133)<1e-3);
	assert(compute_min(@numbers)==-54);
	assert(compute_max(@numbers)==1000);
	assert(abs(compute_meandev(@numbers)-279.622)<1e-3); #via MS Excel
}
