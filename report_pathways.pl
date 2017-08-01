#!/usr/bin/perl

# Generate a table with genes, their pathways and log2(FC)

# Kenneth P. Hough
# kenneth AT egtech DOT us
# License: GNU GPL 3.0

use DBI;
use strict;
use warnings;

my ($file, $sample1, $sample2, $output, $flag1, $option1, $flag2, $option2) = @ARGV;

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

if (not defined $output) {
	print "Output file name not provided.\n", Usage();
	exit();
}

my $pval_limit = 0.05;
my $read_limit = 1;

# check for options
if (defined $flag1 && defined $option1) {
	$pval_limit = $option1 if ($flag1 =~ /-p/);
	$read_limit = $option1 if ($flag1 =~ /-r/);
}
if (defined $flag2 && defined $option2) {
	$pval_limit = $option2 if ($flag2 =~ /-p/);
	$read_limit = $option2 if ($flag2 =~ /-r/);
}

print "* p-value cutoff set to $pval_limit\n", "* read cutoff set to $read_limit\n";

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
$sth = $dbh->prepare('SELECT * FROM diff_table WHERE p_value <= ?');
$r = $sth->execute($pval_limit);

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
print $fh "gene\tsubfamily\tpathway\t$sample1 FC\t$sample1 reads\tlog2FC\t$sample2 FC\t$sample2 reads\n";

foreach my $diff (keys %diff_data) {
	my $sample1_id = $diff_data{$diff}[1];
	my $sample2_id = $diff_data{$diff}[2];
	my $log2fc = $diff_data{$diff}[4];
	my $sample1_reads = $sample1_data{$sample1_id}[5];
	my $sample2_reads = $sample2_data{$sample2_id}[5];
	my $gene_symbol = $sample1_data{$sample1_id}[3];

	next if $sample1_reads < $read_limit && $sample2_reads < $read_limit;

	my $sample1_v2_FC = 0;
	$sample1_v2_FC = $sample1_reads / $sample2_reads if $sample2_reads != 0;
	my $sample2_v1_FC = 0;
	$sample2_v1_FC = $sample2_reads / $sample1_reads if $sample1_reads != 0;

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
		# sample 1 fc
		# sample 1 reads
		# log2fc
		# sample 2 fc
		# sample 2 reads

		if ($log2fc < 0) {	
			print $fh "$row[2]\t$row[11]\t$row[7]\t", $sample1_v2_FC, "\t", $sample1_reads, "\t", $log2fc, "\t\t", $sample2_reads, "\n";
		} else {
			print $fh "$row[2]\t$row[11]\t$row[7]\t\t", $sample1_reads, "\t", $log2fc, "\t", $sample2_v1_FC, "\t", $sample2_reads, "\n";
		}

		$last = $row[7];
	}
}

close $fh;

$sth->finish();
undef $sth;

$dbh->disconnect();
print "- disconnected from database\n";

sub Usage {
	return "Usage:\nreport_pathways.pl sqlite_db sample1_name sample2_name output_file_path [-p value_cutoff -r read_cutoff]\n\n-p\tp-value cutoff. A value that will be used as a cutoff for p-value.\n\tAnything above the specified value will not be included.\n-r\tRead value cutoff. A value that will be used as a cutoff for reads\n\tfor both samples being compared. A value less than the\n\tspecified value will be excluded if present in both samples.";
}
