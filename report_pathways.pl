#!/usr/bin/perl

# Generate a table with genes, their pathways and log2(FC)

# Kenneth P. Hough
# kenneth AT egtech DOT us
# License: GNU GPL 3.0

use DBI;
use strict;
use warnings;

my ($file, $sample1, $sample2, $output) = @ARGV;

if (not defined $file) {
	die "No database file specified.\n";
}

if (not defined $sample1) {
	die "Sample 1 name not specified.\n";
}

if (not defined $sample2) {
	die "Sample 2 name not specified.\n";
}

if (not defined $output) {
	die "Output file name not provided.\n";
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
print "* retrieving reference data for species id $species_id\n";

# get all the data from diff_table
$sth = $dbh->prepare('SELECT * FROM diff_table WHERE p_value <= 0.05');
$r = $sth->execute();

die $DBI::errstr if $r < 0;

my %diff_data = ();

while (my @row = $sth->fetchrow_array) {
	# create hash using diff id as key
	$diff_data{$row[0]} = [@row];
}

die "No significant (p<0.05) comparison found\n" if !keys %diff_data;

$sth->finish();
undef $sth;

print "* loaded ", scalar(keys %diff_data), " diff entries\n";

# open file to output results
open (my $fh, '>', $output) or die "Unable to open $output to write output.\n";

# print header
print $fh "gene\tsubfamily\tpathway\tlog2FC\t$sample1 reads\tlog2FC\t$sample2 reads\n";

foreach my $diff (keys %diff_data) {
	my $sample1_id = $diff_data{$diff}[1];
	my $sample2_id = $diff_data{$diff}[2];
	my $log2fc = $diff_data{$diff}[4];
	my $sample1_reads = $sample1_data{$sample1_id}[5];
	my $sample2_reads = $sample2_data{$sample2_id}[5];
	my $gene_symbol = $sample1_data{$sample1_id}[3];

	# get reference table data
	$sth = $dbh->prepare('SELECT * FROM reference_table WHERE species = ? AND gene_symbol = ? order by gene_symbol,pathway_name');
	$r = $sth->execute($species_id, $gene_symbol);

	die $DBI::errstr if $r < 0;

	my $last = "none";

	while (my @row = $sth->fetchrow_array) {
		next if $last eq $row[7];

		# gene_symbol [2]
		# panther_subfamily_name [11]
		# pathway_name [7]
		# sample 1 log2fc
		# sample 1 reads
		# sample 2 log2fc
		# sample 2 reads

		if ($log2fc < 0) {	
			print $fh "$row[2]\t$row[11]\t$row[7]\t", $log2fc, "\t", $sample1_reads, "\t\t", $sample2_reads, "\n";
		} else {
			print $fh "$row[2]\t$row[11]\t$row[7]\t\t", $sample1_reads, "\t", $log2fc, "\t", $sample2_reads, "\n";
		}

		$last = $row[7];
	}
}

close $fh;

$sth->finish();
undef $sth;

$dbh->disconnect();
print "- disconnected from database\n";
