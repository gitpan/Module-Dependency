#!/usr/bin/perl -w
# $Id: 00base.t,v 1.1 2002/01/21 15:40:39 piers Exp $
use strict;
use Test;
BEGIN { plan tests => 8; }

use lib qw(./lib ../lib);
use Module::Dependency::Info;
BEGIN { ok( $Module::Dependency::Info::VERSION ) };
use Module::Dependency::Indexer;
BEGIN { ok( $Module::Dependency::Indexer::VERSION ) };
use Module::Dependency::Grapher;
BEGIN { ok( $Module::Dependency::Grapher::VERSION ) };
use Storable;
BEGIN { ok( $Storable::VERSION ) };

BEGIN {
	if ( -d 't') {
		chdir( 't' );
		ok(1);
	} else {
		ok(1);
	}
	require 'dbdump.dd';
	ok( ! $@ );
}

if ( $DB->{'scripts'}->[0] eq 'y.pl' ) {
	ok(1);
} else {
	ok(0);
	die("Could not load the demo database! Most tests will not work");
}

ok( Storable::nstore( $DB, 'dbdump.dat' ) );

# ok, looks like we have an OK environment to do tests in, so let's go...