#!/usr/bin/perl

# Reads an output from cuffdiff and populates a SQLite database

# Kenneth P. Hough
# kenneth AT egtech DOT us
# License: GNU GPL 3.0

use DBI;
use strict;
use warnings;

my ($db_file, $diffout, $species_code) = @ARGV;

if (not defined $db_file) {
	die "SQLite database file must be specified.\n";
}

if (not defined $diffout) {
	die "Output file from cuffdiff must be specified.\n";
}

if (not defined $species_code) {
	die "Species short name must be specified, e.g. MOUSE, HUMAN, ECOLI, etc...\n";
}

my $driver = "SQLite";
my $database = $db_file;
my $dsn = "DBI:$driver:$database";
my $user = "";
my $password = "";
my $dbh = DBI->connect($dsn, $user, $password, {RaiseError => 1}) or die $DBI::errstr;

print "+ successfully connected to db\n";

# check the species code
my $sth = $dbh->prepare('SELECT id FROM species_table WHERE short_name = ?');
my $r = $sth->execute($species_code);
if ($r < 0) {
	die $DBI::errstr;
}

my $row = $sth->fetch();
# if no matching short name is found return an error
if (not defined $row) {
	die "No matching species for short name $species_code.\n";
}

my $species_id = $row->[0];

print "* Setting species to $species_code ($species_id)\n";

$sth->finish();

# read cuffdiff output file
open(my $cdfh, $diffout) or die "Unable to open $diffout.\n";

# first slurp to an array for performance, neatly demonstrated by:
# https://stackoverflow.com/questions/14393295/best-way-to-skip-a-header-when-reading-in-from-a-text-file-in-perl
my @diff_array = <$cdfh>;
close($cdfh);

# skip the header
shift @diff_array;

foreach my $diff (@diff_array) {
	# since diffouts are produced on a *nux system we shouldn't have to worry
	# about windows carriage returns but better be safe than sorry
	$diff =~ s/\r\n?//g;
	chomp $diff;

	# split line by tab delimiter
	my @columns = split '\t', $diff;

	# default accession id to unknown
	my $accession_id = '?';
	# look up accession id from table
	$sth = $dbh->prepare('SELECT accession_id FROM reference_table WHERE species = ? AND gene_symbol = ?');
	$r = $sth->execute($species_id, $columns[1]);
	if ($r < 0) {
		die $DBI::errstr;
	}
	
	# check if any results were returned
	$row = $sth->fetch();
	if (defined $row) {
		# if a gene symbol matches, get accession id
		$accession_id = $row->[0];
		print "* $accession_id mapped to $columns[1]\n";
	}

	$sth->finish();

	# insert first sample set into sample_table
	$sth = $dbh->prepare('INSERT INTO sample_table(sample_name, species, gene_symbol, accession_id, reads) VALUES(?, ?, ?, ?, ?)');
	$r = $sth->execute($columns[4], $species_id, $columns[1], $accession_id, $columns[7]);
	if ($r < 0) {
		die $DBI::errstr;
	}
	print "+ $columns[1] for $columns[4] successfully added\n";

	# after the insert we need to get the id of that row
	# this is so that we can use it when inserting into diff_table
	$sth = $dbh->prepare('SELECT last_insert_rowid()');
	$r = $sth->execute();
	if ($r < 0) {
		die $DBI::errstr;
	}

	$row = $sth->fetch();
	my $sample_id_1 = $row->[0];
	print "* Last insert row id: $sample_id_1\n";

	# insert second sample set into sample_table
	$sth = $dbh->prepare('INSERT INTO sample_table(sample_name, species, gene_symbol, accession_id, reads) VALUES(?, ?, ?, ?, ?)'); 
	$r = $sth->execute($columns[5], $species_id, $columns[1], $accession_id, $columns[8]);
	if ($r < 0) {
		die $DBI::errstr;
	}
	print "+ $columns[1] for $columns[5] successfully added\n";

	# again, after the insert we need to get the id of that row
	$sth = $dbh->prepare('SELECT last_insert_rowid()');
	$r = $sth->execute();
	if ($r < 0) {
		die $DBI::errstr;
	}

	$row = $sth->fetch();
	my $sample_id_2 = $row->[0];
	print "* Last insert row id: $sample_id_2\n";

	# next we will insert into the diff_table for comparison
	$sth = $dbh->prepare('INSERT INTO diff_table(sample_id_1, sample_id_2, diff_status, log2FC, test_stat, p_value, q_value) VALUES(?, ?, ?, ?, ?, ?, ?)');
	$r = $sth->execute($sample_id_1, $sample_id_2, $columns[6], $columns[9], $columns[10], $columns[11], $columns[12]);
	if ($r < 0) {
		die $DBI::errstr;
	} else {
		print "+ $columns[1] comparison $columns[4] and $columns[5] successfully added\n";
	}
}

$dbh->disconnect();
print "- disconnected from db\n";
