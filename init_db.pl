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
        die "No database file specified.\n";
}

my $driver = "SQLite";
my $database = $file;
my $dsn = "DBI:$driver:$database";
my $user = "";
my $password = "";
my $dbh = DBI->connect($dsn, $user, $password, {RaiseError => 1}) or die $DBI::errstr;

print "+ successfully connected to db\n";

# initialise DB by creating table if it doesn't exist
my $stmt = qq(CREATE TABLE IF NOT EXISTS reference_table(
	id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	accession_id CHAR(16) NOT NULL,
	gene_symbol CHAR(16) NOT NULL,
	gene_name CHAR(64) NOT NULL,
	chromosome char(2) NOT NULL,
	species INT NOT NULL,
	pathway_accession CHAR(16) NOT NULL,
	pathway_name TEXT NOT NULL,
	evidence_id CHAR(16) NOT NULL,
	evidence_type CHAR(16) NOT NULL,
	panther_subfamily_id CHAR(16),
	panther_subfamily_name TEXT););

my $r = $dbh->do($stmt);
if ($r < 0) {
	print $DBI::errstr;
} else {
	print "+ successfuly created reference_table\n";
}
$dbh->disconnect();

