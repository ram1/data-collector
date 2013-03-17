#!/usr/bin/perl
#contour.pl input_file output_file
#orders data by current and frequency

my $file = $ARGV[0];
my %freqs = ();
my %currents = ();
my %freq_mapping = ();
my %i_mapping = ();
my @sorted = ();

open(FILE, "<", $file) or die "could not open file $file: $!\n";
open(OUTPUT, ">", $ARGV[1]) or die "couldn't open output file\n";

my $i = 0;
while(defined(my $line = <FILE>))
{
	#Skip the title headings
	if($i != 0)
	{
		my @csv = split ",",$line;
		my @colonsv = split "_", $csv[0];
		if(!exists($freqs{$colonsv[1]}))
		{
			$freqs{$colonsv[1]} = 1;
		}
		if($colonsv[2] =~ /tec(.+)a/)
		{
			if(!exists($currents{$1}))
			{
				$currents{$1} = 1;
			}
		}
		else
		{
			print @colonsv[1];
			die "no current detected\n";
		}
	}
	else
	{
		$i = 1;
	}
}

my @freq_vals = sort {$a <=> $b} keys %freqs;
my @i_vals =  sort {$a <=> $b} keys %currents;

$i = 0;
foreach my $val (@freq_vals)
{
	$freq_mapping{$val} = $i;
	$i = $i + 1;
}

$i = 0;
foreach my $val (@i_vals)
{
	$i_mapping{$val} = $i;
	$i = $i + 1;
}

close(FILE);

##Process##
open(FILE, "<", $file) or die "could not open file\n";

#Initialize. For some frequencies, data at all currents may not exist.
#Initialize the array of data to NULL. Later on, check whether
#the value is NULL or not to see whether data exists.
for(my $i = 0; $i < (scalar @freq_vals); $i++)
{
	for(my $j = 0; $j < (scalar @i_vals); $j++)
	{
		$sorted[$i][$j] = "NULL";	
	}
}


$i = 0;
while(defined(my $line = <FILE>))
{
	if($i != 0)
	{
		my @csv = split ",",$line;
		my @colonsv = split "_", $csv[0];
		my $freq_num = $freq_mapping{$colonsv[1]};
		my $i_num;	
		if($colonsv[2] =~ /tec(.+)a/)
		{
			$i_num = $i_mapping{$1};
		}
		else
		{
			die "no current detected\n";
		}
		
		$sorted[$freq_num][$i_num] = $line;
	}
	else
	{
		$i = 1;
	}
}

for ($i = 0; $i < (scalar @freq_vals); $i++)
{
	for($j = 0; $j < scalar @i_vals; $j++)
	{
		if($sorted[$i][$j] !~ "NULL")
		{
			my @csv = split(",",$sorted[$i][$j]);
			my @csv = @csv[1 .. $#csv];
			print OUTPUT join ",",$i_vals[$j],$freq_vals[$i],@csv;
		}
	}
}

for ($i = 0; $i < scalar @i_vals; $i++)
{
	for($j = 0; $j < scalar @freq_vals; $j++)
	{
		if($sorted[$j][$i] !~ "NULL")
		{
			my @csv = split(",",$sorted[$j][$i]);
			my @csv = @csv[1 .. $#csv];
			print OUTPUT join ",",$i_vals[$i],$freq_vals[$j],@csv;
		}
	}
}
