#!/usr/bin/perl -w
# $Id: 03indexing.t,v 1.1 2002/01/21 15:40:39 piers Exp $
use strict;
use lib qw(./lib ../lib);
use Test;
use Cwd;
use File::Spec::Functions;
use Module::Dependency::Info;
BEGIN { plan tests => 23; }

my $dir = cwd();
if (-d 't') { $dir = catfile( $dir, 't'); }
my $index = catfile( $dir, 'dbindext.dat' );
my $index2 = catfile( $dir, 'dbindex2.dat' );

ok( $dir );
ok( $index );

if ( -f $index ) {
	ok(1);
} else {
	for (3..23) { ok(1); }
	warn( "You need to run all the tests in order! $index not found, so skipping tests!" );
	exit;
}

Module::Dependency::Info::setIndex( $index );
ok( Module::Dependency::Info::retrieveIndex );

ok( @{ Module::Dependency::Info::allItems() } == 10 );
ok( Module::Dependency::Info::allScripts()->[1] eq 'x.pl' );

my $i = Module::Dependency::Info::getItem('d');
ok( $i->{'filename'} =~ m|d\.pm| );
ok( $i->{'package'} eq 'd' );
ok( $i->{'depended_upon_by'}->[2] eq 'c' );
ok( $i->{'depends_on'}->[3] eq 'h' );

ok( Module::Dependency::Info::getFilename('f') =~ m|f\.pm$|);
ok( Module::Dependency::Info::getChildren('f')->[0] eq 'strict');
ok( Module::Dependency::Info::getParents('f')->[0] eq 'd');

ok( Module::Dependency::Info::dropIndex() );
ok( ! defined( $Module::Dependency::Info::UNIFIED ) );

# implicit load - only need one test
ok( Module::Dependency::Info::getParents('f')->[0] eq 'd');

# bad data
ok( ! defined( Module::Dependency::Info::getItem('floop') ) );
ok( ! defined( Module::Dependency::Info::getFilename('floop') ) );
ok( ! defined( Module::Dependency::Info::getChildren('floop') ) );
ok( ! defined( Module::Dependency::Info::getParents('floop') ) );

Module::Dependency::Info::setIndex( $index2 );
ok( Module::Dependency::Info::getFilename('f') =~ m|f\.pm$|);
ok( Module::Dependency::Info::getChildren('f')->[0] eq 'strict');
ok( Module::Dependency::Info::getParents('f')->[0] eq 'd');

# right, that's tested the Indexing system
