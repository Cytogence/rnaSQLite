#!/usr/bin/perl

# Initialises SQLite database to store reference and sample data

# Kenneth P. Hough
# kenneth AT egtech DOT us
# License: GNU GPL 3.0

use DBI;
use strict;
use warnings;

my ($file) = @ARGV;

if (not defined $file) {
        print "No database file specified.\n", Usage();
	exit();
}

my $driver = "SQLite";
my $database = $file;
my $dsn = "DBI:$driver:$database";
my $dbh = DBI->connect($dsn, {RaiseError => 1}) or die $DBI::errstr;

print "+ successfully connected to db\n";

# initialise DB by creating table if it doesn't exist

# create table for species
my $stmt = qq(CREATE TABLE IF NOT EXISTS species_table(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	short_name CHAR(8) NOT NULL,
	organism TEXT NOT NULL,
	common_name TEXT NOT NULL););
my $r = $dbh->do($stmt);
if ($r < 0) {
	die $DBI::errstr;
} else {
	print "+ successfully created species_table\n";
}

# if the table already existed, empty it
$stmt = qq(DELETE FROM species_table;);
$r = $dbh->do($stmt);
if ($r < 0) {
	die $DBI::errstr;
} else {
	print "* species_table ready to be populated\n";
}

# read species information
open(my $fh, "species_codes.txt") or die "Unable to open species_codes.txt\n";
my @species = <$fh>;
close($fh);

# skip the first two lines in the file
shift @species;
shift @species;

# insert species information into table;
foreach my $specie (@species) {
	# remove windows new line at end
	$specie =~ s/\r\n?//g;
	chomp $specie;
	my ( $organism, $common_name, $short_name ) = split '\t', $specie;

	my $sth = $dbh->prepare('INSERT INTO species_table(short_name, organism, common_name) VALUES(?, ?, ?)');

	$r = $sth->execute($short_name, $organism, $common_name);

	if ($r < 0) {
		print $DBI::errstr;
	} else {
		print "+ $short_name successfully added\n";
	}
}

# create table for the reference table to hold gene and pathway information
$stmt = qq(CREATE TABLE IF NOT EXISTS reference_table(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	accession_id CHAR(16) NOT NULL,
	gene_symbol CHAR(16) NOT NULL,
	gene_name CHAR(64) NOT NULL,
	chromosome char(2) NOT NULL,
	species INTEGER NOT NULL,
	pathway_accession CHAR(16) NOT NULL,
	pathway_name TEXT NOT NULL,
	evidence_id CHAR(16) NOT NULL,
	evidence_type CHAR(16) NOT NULL,
	panther_subfamily_id CHAR(16),
	panther_subfamily_name TEXT););

$r = $dbh->do($stmt);
if ($r < 0) {
	die $DBI::errstr;
} else {
	print "+ successfully created reference_table\n";
}

# create table for sample_table
$stmt = qq(CREATE TABLE IF NOT EXISTS sample_table(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	sample_name TEXT NOT NULL,
	species INTEGER NOT NULL,
	gene_symbol CHAR(16) NOT NULL,
	accession_id CHAR(16) NOT NULL,
	reads INTEGER NOT NULL););
$r = $dbh->do($stmt);
if ($r < 0) {
	die $DBI::errstr;
} else {
	print "+ successfully created species_table\n";
}

# create table for diff_table
$stmt = qq(CREATE TABLE IF NOT EXISTS diff_table(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	sample_id_1 INTEGER NOT NULL,
	sample_id_2 INTEGER NOT NULL,
	diff_status CHAR(8) NOT NULL,
	log2FC REAL NOT NULL,
	test_stat REAL NOT NULL,
	p_value REAL NOT NULL,
	q_value REAL NOT NULL););
$r = $dbh->do($stmt);
if ($r < 0) {
	die $DBI::errstr;
} else {
	print "+ successfully created diff_table\n";
}

$dbh->disconnect();
print "- disconnected from db\n";

sub Usage {
	return "Usage:\ninit_db.pl sqlite_database_file\n";
}
