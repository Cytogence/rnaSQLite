#!/usr/bin/perl

# Interactive console for accessing SQLite database

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
my $dbh = DBI->connect($dsn, {RaiseError => 1}) or die $DBI::errstr;

print "+ successfully connected to db\n";

print "\nWelcome to rnaSQLite Terminal\n";

while (1) {
	my $q = promptUser('rnaSQLite>');
	
	next if not defined $q;

	# TODO: handle DBI failures so that program doesn't quit due to wrong syntax

	if ($q =~ /SELECT/i) {
		my $sth = $dbh->prepare($q);
		my $r = $sth->execute();
		if ($r < 0) {
			print $DBI::errstr;
		} else {
			my @fields = @{ $sth->{NAME} };
			print "@fields\n";
			while (my @row = $sth->fetchrow_array) {
				print "@row\n";
			}
			$sth->finish();
			undef $sth;
		}
	}

	if ($q eq 'exit') {
		$dbh->disconnect();
		print "- disconnected from db\n";
		print "Goodbye!\n";
		exit();
	}
}

# https://alvinalexander.com/perl/edu/articles/pl010005

#-------------------------------------------------------------------------#
# promptUser, a Perl subroutine to prompt a user for input.
# Copyright 2010 Alvin Alexander, http://www.devdaily.com
# This code is shared here under the 
# Creative Commons Attribution-ShareAlike Unported 3.0 license.
# See http://creativecommons.org/licenses/by-sa/3.0/ for more information.
#-------------------------------------------------------------------------#

#----------------------------(  promptUser  )-----------------------------#
#                                                                         #
#  FUNCTION:	promptUser                                                #
#                                                                         #
#  PURPOSE:	Prompt the user for some type of input, and return the    #
#		input back to the calling program.                        #
#                                                                         #
#  ARGS:	$promptString - what you want to prompt the user with     #
#		$defaultValue - (optional) a default value for the prompt #
#                                                                         #
#-------------------------------------------------------------------------#

sub promptUser {
	my ($prompt, $default) = @_;
	my $defaultValue = $default ? "[$default]" : "";
	print "$prompt$defaultValue ";
	chomp(my $input = <STDIN>);
	return $input ? $input : $default;
}

