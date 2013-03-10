#!/usr/bin/perl
#contour.pl input_file output_file


$file = $ARGV[0];
%freqs = ();
%currents = ();
%freq_mapping = ();
%i_mapping = ();
@sorted = ();

open(FILE, "<", $file) or die "could not open file\n";
open(OUTPUT, ">", $ARGV[1]) or die "couldn't open output file\n";

$i = 0;
while(defined($line = <FILE>))
{
	if($i != 0)
	{
		@csv = split ",",$line;
		@colonsv = split "_", $csv[0];
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

@freq_vals = sort {$a <=> $b} keys %freqs;
@i_vals =  sort {$a <=> $b} keys %currents;

$i = 0;
foreach $val (@freq_vals)
{
	$freq_mapping{$val} = $i;
	$i = $i + 1;
}

$i = 0;
foreach $val (@i_vals)
{
	$i_mapping{$val} = $i;
	$i = $i + 1;
}

close(FILE);

#Process
open(FILE, "<", $file) or die "could not open file\n";

$i = 0;
while(defined($line = <FILE>))
{
	if($i != 0)
	{
		@csv = split ",",$line;
		@colonsv = split "_", $csv[0];
		$freq_num = $freq_mapping{$colonsv[1]};
		$i_num;	
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
		print OUTPUT join ",",$i_vals[$j],$sorted[$i][$j];
	}
}

for ($i = 0; $i < scalar @i_vals; $i++)
{
	for($j = 0; $j < scalar @freq_vals; $j++)
	{
		print OUTPUT join ",",$freq_vals[$j],$sorted[$j][$i];
	}
}
