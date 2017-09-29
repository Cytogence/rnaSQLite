#!/usr/bin/perl

# Reads the PANTHER's SequenceAssociationPathway file and
# HGNC's protein coding annotation file to generate a reference 
# table for humans.
# At the time of writing, PANTHER's SequenceAssociationPathway
# file was at verion 3.5 (SequenceAssociationPathway3.5.txt).
#
# PANTHER's SequenceAssociationPathway at the time of writing:
# ftp://ftp.pantherdb.org/pathway/current_release/SequenceAssociationPathway3.5.txt
# ftp://ftp.pantherdb.org/pathway/current_release/README
# ftp://ftp.pantherdb.org/pathway/current_release/LICENSE
#
# protein-coding_gene.txt at the time of writing:
# ftp://ftp.ebi.ac.uk/pub/databases/genenames/new/tsv/locus_groups/protein-coding_gene.txt

# Kenneth P. Hough
# kenneth AT egtech DOT us
# License: GNU GPL 3.0

use DBI;
use strict;
use warnings;

my ($db_file, $sap_file, $hgnc_list) = @ARGV;

if (not defined $db_file) {
	print "SQLite database file must be specified.\n", Usage();
	exit();
}

if (not defined $sap_file) {
        print "PANTHER's SequenceAssociationPathway file must be specified.\n", Usage();
	exit();
}

if (not defined $hgnc_list) {
	print "HGNC protein coding list file must be specified.\n", Usage();
	exit();
}

my $driver = "SQLite";
my $database = $db_file;
my $dsn = "DBI:$driver:$database";
my $dbh = DBI->connect($dsn, {RaiseError => 1}) or die $DBI::errstr;

print "+ successfully connected to db\n";

# get HUMAN specied id #
my $sth = $dbh->prepare('SELECT id FROM species_table WHERE short_name = ?');
my $r = $sth->execute('HUMAN');
if ($r < 0) {
	die $DBI::errstr;
}

my $row = $sth->fetch();
if ($row == 0) {
	die "Unable to find specied ID for short name HUMAN\n";
}

my $species_id = $row->[0];

print "* Setting species to HUMAN ($species_id)\n";
$sth->finish();

# read HGNC protein coding list
# first slurp to an array for performance, neatly demonstrated by:
# https://stackoverflow.com/questions/14393295/best-way-to-skip-a-header-when-reading-in-from-a-text-file-in-perl

open(my $hgnc_fh, $hgnc_list) or die "Unable to open $hgnc_list\n";;
my @hgnc_array = <$hgnc_fh>;
close($hgnc_fh);

# skip first line as its a header
shift @hgnc_array;

# then extract columns 0, 1, 6, and 8 into a hash
# 0: HGNC Accession ID, e.g. HGNC:1315197, which we will extract the ID # and leave 'HGNC:'
# 1: Symbol, e.g. HK1
# 2: Name, e.g. Hexokinase 1
# 6: Location, 13q23.4, extract before q to get chromosome #

# empty hash we will populate with MGI marker info
my %hgnc = ();

foreach my $marker (@hgnc_array) {
	# we won't chomp here since we don't care about the last column
	# split string by tab delimiter
	my @columns = split '\t', $marker;
	my ( $undef, $hgnc_id ) = split ':', $columns[0];

	my ($hgnc_chr, $loci) = split 'q', $columns[6];

	$hgnc{$hgnc_id} = {
			chr => $hgnc_chr,
			symbol => $columns[1],
			name => $columns[2],};
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

	if ($species eq 'HUMAN') {
		# extract the HGNC Accession ID from $dbentryid
		my ( $hgnc1, $hgnc_id ) = split '=', $dbentryid;

		# set chr, symbol, and name to ? in case the corresponding HGNC
		# accession # is not found in the hash
		my ( $chr, $symbol, $name ) = ( '?', '?', '?' );
		# check if HGNC accession # exists
		if (exists $hgnc{$hgnc_id}) {
			# update chr, symbol, name
			$chr = $hgnc{$hgnc_id}{chr};
			$symbol = $hgnc{$hgnc_id}{symbol};
			$name = $hgnc{$hgnc_id}{name};
		}

		# insert into table
		$sth = $dbh->prepare('INSERT INTO reference_table(accession_id, gene_symbol, gene_name, chromosome, species, pathway_accession, pathway_name, evidence_id, evidence_type, panther_subfamily_id, panther_subfamily_name) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
		$r = $sth->execute($hgnc_id, $symbol, $name, $chr, $species_id, $columns[0], $columns[1], $columns[7], $columns[8], $columns[9], $columns[10]);
		if ($r < 0) {
			print $DBI::errstr;
		} else {
			print "+ $hgnc_id successfully added\n";
		}
	}
}

$dbh->disconnect();

sub Usage {
	return "Usage:\ninit_human_ref.pl sqlite_db SequenceAssociationPathway3.5.txt protein-coding-list.txt\n";
}
