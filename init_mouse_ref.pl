#!/usr/bin/perl

# Reads the PANTHER's SequenceAssociationPathway file and
# MGI's MRK_List to generate a reference table for mice.
# At the time of writing, PANTHER's SequenceAssociationPathway
# file was at verion 3.5 (SequenceAssociationPathway3.5.txt).
#
# PANTHER's SequenceAssociationPathway at the time of writing:
# ftp://ftp.pantherdb.org/pathway/current_release/SequenceAssociationPathway3.5.txt
# ftp://ftp.pantherdb.org/pathway/current_release/README
# ftp://ftp.pantherdb.org/pathway/current_release/LICENSE
#
# MRK_List2.rpt at the time of writing:
# http://www.informatics.jax.org/downloads/reports/MRK_List2.rpt

# Kenneth P. Hough
# kenneth AT egtech DOT us
# License: GNU GPL 3.0

use DBI;
use strict;
use warnings;

my ($db_file, $sap_file, $mrk_list) = @ARGV;

if (not defined $db_file) {
	die "SQLite database file must be specified.\n";
}

if (not defined $sap_file) {
        die "PANTHER's SequenceAssociationPathway file must be specified.\n";
}

if (not defined $mrk_list) {
	die "MGI's Mouse Genetic Markers list file (MRK_List2.rpt) must be specified.\n";
}

my $driver = "SQLite";
my $database = $db_file;
my $dsn = "DBI:$driver:$database";
my $dbh = DBI->connect($dsn, {RaiseError => 1}) or die $DBI::errstr;

print "+ successfully connected to db\n";

# get MOUSE specied id #
my $sth = $dbh->prepare('SELECT id FROM species_table WHERE short_name = ?');
my $r = $sth->execute('MOUSE');
if ($r < 0) {
	die $DBI::errstr;
}

my $row = $sth->fetch();
if ($row == 0) {
	die "Unable to find specied ID for short name MOUSE\n";
}

my $species_id = $row->[0];

print "* Setting species to MOUSE ($species_id)\n";
$sth->finish();

# read MGI MRK_list2 file
# first slurp to an array for performance, neatly demonstrated by:
# https://stackoverflow.com/questions/14393295/best-way-to-skip-a-header-when-reading-in-from-a-text-file-in-perl

open(my $mrk_fh, $mrk_list) or die "Unable to open $mrk_list\n";;
my @mrk_array = <$mrk_fh>;
close($mrk_fh);

# skip first line as its a header
shift @mrk_array;

# then extract columns 0, 1, 6, and 8 into a hash
# 0: MGI Accession ID, e.g. MGI:1315197, which we will extract the ID # and leave 'MGI:'
# 1: Chr, e.g. 6
# 6: Marker Symbol, e.g. Hk2
# 8: Marker Name, e.g. hexokinase 2

# empty hash we will populate with MGI marker info
my %mrk = ();

foreach my $marker (@mrk_array) {
	# we won't chomp here since we don't care about the last column
	# split string by tab delimiter
	my @columns = split '\t', $marker;
	my ( $undef, $mgi_id ) = split ':', $columns[0];
	$mrk{$mgi_id} = {
			chr => $columns[1],
			symbol => $columns[6],
			name => $columns[8],};
}

# next, read the PANTHER SequenceAssociationPathway file,
# then match the MGI Accession and store in the DB

open(my $sap_fh, $sap_file) or die "Unable to open $sap_file\n";
my @sap_array = <$sap_fh>;
close($sap_fh);

# since this file does not have a header, we do not need to skip like before
# details on the file can be found here:
# ftp://ftp.pantherdb.org/pathway/current_release/README
# we will extract columns 0, 1, 4, 7, 8, 9, 10
# 0: Pathway Accession
# 1: Pathway Name
# 4: UniProt ID, we will extract the species and MGI from MOUSE|MGI=MGI=ID#|UniProtKB=ID#
# 7: Evidence ID
# 8: Evidence Type (PubMed, etc...)
# 9: PANTHER subfamily ID
# 10: PANTHER subfamily name

# purge database of any existing mouse entries
$sth = $dbh->prepare('DELETE FROM reference_table WHERE species = ?');
$r = $sth->execute($species_id);
if ($r < 0) {
	die $DBI::errstr;
} else {
	print "* table ready to be populated\n";
}

foreach my $sap (@sap_array) {
	# here, we will chomp because we care about the last column
	chomp $sap;
	# split string by tab delimiter
	my @columns = split '\t', $sap;
	my ( $species, $dbentryid, $uniprotid ) = split /\|/, $columns[4];

	if ($species eq 'MOUSE') {
		# extract the MGI Accession ID from $dbentryid
		my ( $mgi1, $mgi2, $mgi_id ) = split '=', $dbentryid;

		# set chr, symbol, and name to ? in case the corresponding MGI
		# accession # is not found in the hash
		my ( $chr, $symbol, $name ) = ( '?', '?', '?' );
		# check if MGI accession # exists
		if (exists $mrk{$mgi_id}) {
			# update chr, symbol, name
			$chr = $mrk{$mgi_id}{chr};
			$symbol = $mrk{$mgi_id}{symbol};
			$name = $mrk{$mgi_id}{name};
		}

		# insert into table
		$sth = $dbh->prepare('INSERT INTO reference_table(accession_id, gene_symbol, gene_name, chromosome, species, pathway_accession, pathway_name, evidence_id, evidence_type, panther_subfamily_id, panther_subfamily_name) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
		$r = $sth->execute($mgi_id, $symbol, $name, $chr, $species_id, $columns[0], $columns[1], $columns[7], $columns[8], $columns[9], $columns[10]);
		if ($r < 0) {
			print $DBI::errstr;
		} else {
			print "+ $mgi_id successfully added\n";
		}
	}
}

$dbh->disconnect();

