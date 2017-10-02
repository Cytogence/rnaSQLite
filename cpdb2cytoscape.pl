#!/usr/bin/perl

# Add log2(FC) to the CPDB table

# Kenneth P. Hough
# kenneth AT egtech DOT us
# License: GNU GPL 3.0

use DBI;
use strict;
use warnings;

my ($file, $sample1, $sample2, $cpdb_IM, $output) = @ARGV;

if (not defined $file) {
	print "No database file specified.\n", Usage();
	exit();
}

if (not defined $sample1) {
	print "Sample 1 name not specified.\n", Usage();
	exit();
}

if (not defined $sample2) {
	print "Sample 2 name not specified.\n", Usage();
	exit();
}

if (not defined $cpdb_IM) {
	print "CPDB_inducedModules.txt file not provided.\n", Usage();
	exit();
}

if (not defined $output) {
	print "Output file name not provided.\n", Usage();
	exit();
}

my $driver = "SQLite";
my $database = $file;
my $dsn = "DBI:$driver:$database";
my $dbh = DBI->connect($dsn, {RaiseError => 1}) or die $DBI::errstr;

print "+ successfully connected to db\n";

# check if the sample names provided exist
my $sth = $dbh->prepare('SELECT * FROM sample_table WHERE sample_name = ?');
my $r = $sth->execute($sample1);
if ($r < 0) {
	die $DBI::errstr;
}

my %sample1_data = ();
my $species_id;

while (my @row = $sth->fetchrow_array) {
	$species_id = $row[2] if not defined $species_id;
	# create hash using sample ID as key
	$sample1_data{$row[0]} = [@row];
}

die "Unknown sample name $sample1\n" if !keys %sample1_data;

$sth->finish();
undef $sth;

$sth = $dbh->prepare('SELECT * FROM sample_table WHERE sample_name = ?');
$r = $sth->execute($sample2);

die $DBI::errstr if $r < 0;

my %sample2_data = ();

while (my @row = $sth->fetchrow_array) {
	# create hash using sample_id as key
	$sample2_data{$row[0]} = [@row];
}

die "Unknown sample anme $sample2\n" if !keys %sample2_data;

$sth->finish();
undef $sth;

print "* found ", scalar(keys %sample1_data), " entries for $sample1\n";
print "* found ", scalar(keys %sample2_data), " entries for $sample2\n";
print "* retrieving differential data.\n";

# get all the data from diff_table
$sth = $dbh->prepare('SELECT * FROM diff_table');
$r = $sth->execute();

die $DBI::errstr if $r < 0;

my %diff_data = ();

while (my @row = $sth->fetchrow_array) {
	# create hash using diff id as key
	$diff_data{$row[0]} = [@row];
}

die "No differentials found\n" if !keys %diff_data;

$sth->finish();
undef $sth;

print "* loaded ", scalar(keys %diff_data), " diff entries\n";

my %logFC = ();

foreach my $diff (keys %diff_data) {
	my $sample1_id = $diff_data{$diff}[1];
	my $sample2_id = $diff_data{$diff}[2];
	my $log2fc = $diff_data{$diff}[4];
	my $gene_symbol = $sample1_data{$sample1_id}[3];
	
	$logFC{$gene_symbol} = $log2fc;
}

# open the CPDB induced network modules file
open (my $cpdbfh, '<', $cpdb_IM) or die "Unable to open $cpdb_IM.\n";

# usurp it into an array
my @cpdb_lines = <$cpdbfh>;
close $cpdbfh;

# open file to output results
open (my $fh, '>', $output) or die "Unable to open $output to write output.\n";

my $interactorA_name = -1;

foreach my $line (@cpdb_lines) {
	# incase...somehow...the file gets carriage returns added
	$line =~ s/\r//g;
	$line =~ s/\n//g;

	my @row = split "\t", $line;
	
	if ($interactorA_name < 0) {
		# find the column # for interactorA_name
		( $interactorA_name ) = grep { $row[$_] eq "interactorA_name" } 0..$#row;

		# print header
		print $fh "$line\tlog2FC\n";
	} else {	
		if (exists $logFC{$row[$interactorA_name]}) {
			# merge the row with FC data
			print $fh "$line\t".$logFC{$row[$interactorA_name]}."\n";
		} else {
			print $fh "$line\t\n";
		}
	}

	die "Unable to find interactorA_name column in $cpdb_IM.\n" if ($interactorA_name < 0);
}

close $fh;

$dbh->disconnect();
print "- disconnected from database\n";

sub Usage {
	return "Usage:\ncpdb2cytoscape.pl sqlite_db sample1_name sample2_name CPDB_inducedModules.txt output_file_path\n\n";
}
