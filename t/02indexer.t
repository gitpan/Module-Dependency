#!/usr/bin/perl -w
# $Id: 02indexer.t,v 1.1 2002/01/21 15:40:39 piers Exp $
use strict;
use lib qw(./lib ../lib);
use Test;
use Cwd;
use File::Spec::Functions;
use Module::Dependency::Indexer;
BEGIN { plan tests => 10; }

my $dir = cwd();
if (-d 't') {
	$dir = catfile( $dir, 't');
}

my $index = catfile( $dir, 'dbindext.dat' );
my $index2 = catfile( $dir, 'dbindex2.dat' );
my $tree = catfile( $dir, 'u' );

#print "$dir\n$index\n$tree\n";

ok( $dir );
ok( $index );
ok( $tree );

if ( -f $index ) { unlink($index); }
ok( ! -f $index );

ok( Module::Dependency::Indexer::setIndex( $index ) );
ok( Module::Dependency::Indexer::makeIndex( $tree ) );

ok( -f $index );

ok( Module::Dependency::Indexer::setIndex( $index2 ) );
ok( Module::Dependency::Indexer::makeIndex( $tree ) );

ok( -f $index2 );

