#!/usr/bin/perl -w
# $Id: dumper.plx,v 1.7 2002/01/21 15:41:17 piers Exp $

use strict;
use lib './lib';
use Getopt::Std;
use Module::Dependency::Info;
use Data::Dumper;

use vars qw/$VERSION $opt_h $opt_t $opt_o $opt_a $opt_s $opt_l $opt_f $opt_p $opt_c $opt_i/;
($VERSION) = ('$Revision: 1.7 $' =~ /([\d\.]+)/ );

getopts('hto:aslf:p:c:i:');
if ($opt_h) { usage(); }

*Module::Dependency::Info::TRACE = \*TRACE;

Module::Dependency::Info::setIndex( $opt_o ) if $opt_o;

if ($opt_a) {
	header("Entire Database");
	print Dumper( Module::Dependency::Info::retrieveIndex() );
} elsif ($opt_s) {
	header("List of all scripts");
	prettyList( Module::Dependency::Info::allScripts() );
} elsif ($opt_l) {
	header("List of all items");
	prettyList( Module::Dependency::Info::allItems() );
} elsif ($opt_f) {
	header("Filename for $opt_f");
	my $data = Module::Dependency::Info::getFilename( $opt_f );
	print( (defined $data) ? $data . "\n" : "No such item in database\n" );
} elsif ($opt_p) {
	header("Items that directly depend upon $opt_p");
	prettyList( Module::Dependency::Info::getParents( $opt_p ) );
} elsif ($opt_c) {
	header("Items that $opt_c directly depends on");
	prettyList( Module::Dependency::Info::getChildren( $opt_c ) );
} elsif ($opt_i) {
	header("Complete entry for $opt_i");
	print Dumper( Module::Dependency::Info::getItem( $opt_i ) );
} else {
	usage();
}

### END OF MAIN
sub header {
	my $string = shift;
	my $len = (80 - length($string)) / 2;
	my $under = $string;
	$under =~ s/\S/-/g;
	print "\n", (' ' x $len), $string, "\n", (' ' x $len), $under, "\n\n";
}

sub prettyList {
	my $data = shift;

	unless ( defined $data ) {
		print "No Data\n";
		return;
	}
	my $longest = 1;
	foreach( @$data ) { (length($_) > $longest) && ($longest = length($_)); }
	my $cols = (int( 80 / $longest ) || 1) + 1;
	my $current;
	foreach( sort @$data ) { printf("%-$longest.${longest}s " . (++$current % $cols ? '' : "\n"), $_); }
	print "\n";
}

sub usage {
	while(<DATA>) { last if / NAME/; }
	while(<DATA>) {
		last if / DESCRIPTION/;
		s/^\t//;
		s/^=head1 //;
		print;
	}
	exit;
}

sub TRACE {
	return unless $opt_t;
	LOG( @_ );
}

sub LOG {
	my $msg = shift;
	print STDERR "> $msg\n";
}

__DATA__

=head1 NAME

dumper - print basic Module::Dependency info

=head1 SYNOPSIS

	dumper.plx [-h] [-t] [-o <datafile>] [-a] [-s] [-l] [ {-f|-p|-c|-i} <script/module>]

	-h Displays this help
	-t Displays tracing messages
	-o the location of the datafile (default is 
	   /var/tmp/dependence/unified.dat)
	-a Get the entire database
	-s List the names of all scripts indexed
	-l List all items indexed
	-f Full filename of given script/module
	-p Get list of items that immediately depend on script/module (i.e. parents)
	-c Get list of items that script/module immediately depends on (i.e. children)
	-i Dump the record for the script/module

=head1 EXAMPLE

	dumper.plx -o ./unified.dat -i Module::Dependency::Info

=head1 DESCRIPTION

Module::Dependency modules rely on a database of dependencies. This tool allows
you to query the index, verify that it contains what it should contain, look up
module dependencies, etc, all using the Module::Dependency::Info API.

The default location for the index file is /var/tmp/dependence/unified.dat but
you can select another file using the -o option.

When you run this tool it prints a dump of the data requested using Data::Dumper.

=head1 VERSION

$Id: dumper.plx,v 1.7 2002/01/21 15:41:17 piers Exp $

=cut


