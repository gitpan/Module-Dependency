#!/usr/bin/perl -w
# $Id: pmd_indexer.plx 6570 2006-06-27 15:01:04Z timbo $

use strict;
use Getopt::Std;
use Module::Dependency::Indexer;

use vars qw/$VERSION $opt_h $opt_t $opt_b $opt_o/;
$VERSION = (q$Revision: 6570 $ =~ /(\d+)/g)[0];

getopts('htbo:');
if ( $opt_h || !scalar(@ARGV) ) { usage(); }

*Module::Dependency::Indexer::TRACE = \*TRACE;

unless ($opt_b) { die("Use the -b option to make the index, -h for help"); }

LOG("Running... -o switch <$opt_o>, indexing @ARGV");
Module::Dependency::Indexer::setIndex($opt_o) if $opt_o;
Module::Dependency::Indexer::makeIndex(@ARGV);
LOG("Done!");

### END OF MAIN

sub usage {
    while (<DATA>) { last if / NAME/; }
    while (<DATA>) {
        last if / DESCRIPTION/;
        s/^\t//;
        s/^=head1 //;
        print;
    }
    exit;
}

sub TRACE {
    return unless $opt_t;
    LOG(@_);
}

sub LOG {
    my $msg = shift;
    print STDERR "> $msg\n";
}

__DATA__

=head1 NAME

pmd_indexer - make Module::Dependency index

=head1 SYNOPSIS

	pmd_indexer.plx [-h] [-t] [-o <datafile>] -b <directory> [<directory>...]

	-h Displays this help
	-t Displays trace messages
	-b Actually build the indexes
	-o the location of the datafile (default is 
	   /var/tmp/dependence/unified.dat)

	Followed by a list of directories that you want to index.

=head1 EXAMPLE

	pmd_indexer.plx -o ./unified.dat -t -b ~/src/dependency/

=head1 DESCRIPTION

Module::Dependency modules rely on a database of dependencies because creating the
index at every runtime is both expensive and unnecessary. This program
uses File::Find for every named directory and looks for .pl and .pm files, which it
then extracts dependency information from.

The default location for the index file is /var/tmp/dependence/unified.dat but
you can look in another directory using the -o option.

=head1 VERSION

$Id: pmd_indexer.plx 6570 2006-06-27 15:01:04Z timbo $

=cut


