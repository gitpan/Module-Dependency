package Module::Dependency::Info;

use Storable qw/retrieve/;
use vars qw/$VERSION $UNIFIED $unified_file $LOADED/;

($VERSION) = ('$Revision: 1.5 $' =~ /([\d\.]+)/ );
$unified_file = '/var/tmp/dependence/unified.dat';

sub setIndex {
	my $file = shift;
	TRACE("Trying to set index to <$file>");
	return unless $file;
	$unified_file = $file;
	$LOADED = 0;
	return 1;
}

sub retrieveIndex {
	TRACE("retrieving index");
	$UNIFIED = retrieve( $unified_file ) || return(undef);
	$LOADED = 1;
	return $UNIFIED;
}

sub allItems {
	my $force = shift;
	if (! $LOADED || $force) { retrieveIndex(); }
	return [ keys %{$UNIFIED->{'allobjects'}} ];
}

sub allScripts {
	my $force = shift;
	if (! $LOADED || $force) { retrieveIndex(); }
	return $UNIFIED->{'scripts'};
}

sub getItem {
	my ($packname, $force) = @_;
	if (! $LOADED || $force) { retrieveIndex(); }
	TRACE("Getting record for <$packname>");
	if (exists $UNIFIED->{'allobjects'}->{$packname}) {
		return $UNIFIED->{'allobjects'}->{$packname};
	} else {
		return undef;
	}
}

sub getFilename {
	my $obj = getItem( @_ ) || return(undef);
	return $obj->{'filename'};
}

sub getChildren {
	my $obj = getItem( @_ ) || return(undef);
	return $obj->{'depends_on'};
}

sub getParents {
	my $obj = getItem( @_ ) || return(undef);
	return $obj->{'depended_upon_by'};
}

sub dropIndex {
	$LOADED = 0;
	undef $UNIFIED;
	return 1;
}

sub TRACE {}

=head1 NAME

Module::Dependency::Info - retrieve dependency information for scripts and modules

=head1 SYNOPSIS

	use Module::Dependecy::Info;
	Module::Dependecy::Info::setIndex( '/var/tmp/dependence/unified.dat' );
	
	# load the index (actually it's loaded automatically if needed so this is optional)
	Module::Dependecy::Info::retrieveIndex();
	# or
	$refToEntireDatabase = Module::Dependecy::Info::retrieveIndex();
	
	$listref = Module::Dependency::Info::allItems();
	$listref = Module::Dependency::Info::allScripts();
	
	# note the syntax here - the name of perl scripts, but the package name of modules.
	$dependencyInfo = Module::Dependecy::Info::getItem( 'Foo::Bar' [, $forceReload ] );
	# and
	$dependencyInfo = Module::Dependecy::Info::getItem( 'blahblah.pl' [, $forceReload ] );
	
	$filename = Module::Dependecy::Info::getFilename( 'Foo::Bar' [, $forceReload ] );
	$listref = Module::Dependecy::Info::getChildren( $node [, $forceReload ] );
	$listref = Module::Dependecy::Info::getParents( $node [, $forceReload ] );
	
	Module::Dependecy::Info::dropIndex();

=head1 DESCRIPTION

This module is used to access the data structures created by Module::Dependecy::Indexer. 
Although you can get at the database structure itself you should use the accessor methods.

=head1 METHODS

=over 4

=item setIndex( $filename );

This tells the module where the database is. It doesn't affect the ...::Indexer 
module - that has its own setIndex routine. The default is /var/tmp/dependence/unified.dat

=item retrieveIndex();

Loads the database into memory. You only have to do this once - after that it's there in 
RAM ready for use. This routine is called automatically if needed anyway.
Incidentally it returns a reference to the entire data structure, but don't use it directly, use this...

=item $listref = Module::Dependency::Info::allItems();

Returns a reference to an array of all the items in the currently loaded datafile. The order is whatever
keys() gives us. The entries in the array are things like 'foo.pl' and 'Bar::Baz'.

=item $listref = Module::Dependency::Info::allScripts();

Returns a reference ot an array of all the scripts in the currently loaded datafile. The order is whatever
it is in the datafile.

=item $record = Module::Dependecy::Info::getItem( $name [, $forceReload ] );

Returns entire record for the thing you name, or undef if no such entry can be found 
(remember modules are referred to like 'Foo::Bar' whereas scripts like 'foo.pl'). 
Implicity loads the datafile from disk, using the current setting
of the data location, if it isn't loaded. Pass in a 1 as the second argument 
if you want to force a reload - this may be relevant in long-lived perl processes 
like mod_perl, but only do it when you need to, like every 10 minutes 
or whatever makes sense for your application.

=item $filename = Module::Dependecy::Info::getFilename( $node [, $forceReload ] );

Gets the full filename for the package/script named, or undef if no record could be found.

=item $listref = Module::Dependecy::Info::getChildren( $node [, $forceReload ] );

Gets a list of all dependencies, i.e. packages that this item depends on, for the 
package/script named, or undef if no record could be found.

=item $listref = Module::Dependecy::Info::getParents( $node [, $forceReload ] );

Gets a list of all reverse dependencies, i.e. packages that depend upon this item, for 
the package/script named, or undef if no record could be found.

=item dropIndex

drops the current database - you generally have no need to do this unless you're trying to save
memory. Usually all you need to do is setIndex followed by a retrieveIndex, get* or all* function.

=back

=head1 DATA RECORDS

The database contains a list of all scripts (.pl and .plx files) encountered. We treat 
these as special because they form the 'top' of the dependency tree - they 'use' things, 
but they are not 'use'd themselves. It's just an array of all their nodenames (the filename, 
excluding the path to the file, e.g. 'foo.pl').

The main bit is a hash. The keys of the hash are one of two things: a) keys to module records 
are the name of the package, e.g. 'Foo::Bar'; b) keys to script records are the nodename of 
the file, e.g. 'foo.pl'.

A data records looks like the right-hand half of these:

	# lots of Data::Dumper output snipped
	'IFL::Beasts::Evol::RendererUtils' => {
		'filename' => '/home/system/cgi-bin/lib/IFL/Beasts/Evol/RendererUtils.pm',
		'package' => 'IFL::Beasts::Evol::RendererUtils',
		'depended_upon_by' => [
			'IFL::Beasts::Evol::TextSkin',
			'IFL::Beasts::Evol::HTMLSkin'
		],
		'depends_on' => [
			'lib',
			'Exporter',
			'Carp',
			'IFL::Beasts::Evol::LanguageUtils',
			'IFL::Beasts::Evol::MathUtils',
			'EDUtemplate'
		]
	},
	# lots of Data::Dumper output snipped

Or like this, for a script file:

	# lots of Data::Dumper output snipped
	'csv_validator.pl' => {
		'filename' => '/home/system/cgi-bin/education/user_reg/csv_validator.pl',
		'package' => 'csv_validator.pl',
		'depends_on' => [
			'CGI',
			'EDUprofile',
			'LWP::Simple',
			'File::Find'
		]
	},
	# lots of Data::Dumper output snipped

But of course you should use the accessor methods to get at the information.

=head1 DEBUGGING

There is a TRACE stub function, and the module uses TRACE() to log activity. Override our 
TRACE with your own routine, e.g. one that prints to STDERR, to see these messages.

=cut


