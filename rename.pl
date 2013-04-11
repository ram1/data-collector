#!/usr/bin/perl
#rename.pl directory suffix
#Adds suffix to every file in the directory
my $dirname = $ARGV[0];
my $suffix = $ARGV[1];

opendir(DIR, $dirname) or die "can't opendir $dirname: $!";
my @files = ();
while (defined($file = readdir(DIR)))
{
	push @files,$file; 
}
closedir(DIR);

foreach my $file (@files)
{
	if($file !~ m/^\.$/ && $file !~ m/^\.\.$/ && $file =~ m/tr/)
	{
		my @usv = split "_",$file;
		my $newname = join "_",@usv[0..1],$suffix,$usv[2];
		print "mv $dirname\/$file $dirname\/$newname\n";
		system("mv $dirname\/$file $dirname\/$newname");
	}
}
