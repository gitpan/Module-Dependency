package Module::Dependency::Indexer;
use strict;
use File::Find;
use File::Spec;
use Storable qw/nstore/;
use vars qw/$VERSION $UNIFIED @NOINDEX $unified_file $check_shebang/;

($VERSION) = ('$Revision: 1.13 $' =~ /([\d\.]+)/ );
@NOINDEX = qw(.AppleDouble /test /CVS/);
$check_shebang = 1;

$unified_file = '/var/tmp/dependence/unified.dat';

sub setIndex {
	my $file = _makeAbsolute( shift );
	TRACE("Trying to set index to <$file>");
	return unless $file;
	$unified_file = $file;
}

sub makeIndex {
	my @dirs = map { _makeAbsolute( $_ ) } @_;
	
	TRACE( "Running search to build indexes" );
	$UNIFIED = {};
	File::Find::find( \&_wanted, @dirs );
	_reverseDepend();
	_storeIndex();
	return 1;
}

sub setShebangCheck {
	$check_shebang = shift;
}

######### PRIVATE

# if we get given relative pathnames then things stop working when File::Find changes working directory
# the fix is now to ensure we use absolute paths internally.
sub _makeAbsolute {
	my $dir = $_[0];
	if ( File::Spec->file_name_is_absolute( $dir ) ) {
		TRACE("$dir is an absolute path");
		return $dir;
	} else {
		my $abs = File::Spec->rel2abs( $dir );
		TRACE("$dir is relative - changed to $abs");
		return $abs
	}
}

sub _storeIndex {
	TRACE( "storing to disk" );
	
	my $CACHEDIR = $unified_file;
	if ( index( $CACHEDIR, '/' ) > -1 ) {
		$CACHEDIR =~ s|^(.*)/.*$|$1|;
		unless (-d $CACHEDIR) {
			LOG( "making data directory $CACHEDIR" );
			umask(0000);
			mkdir($CACHEDIR, 0777) or die("Can't make data directory <$CACHEDIR> because: $!");
		}
	}

	nstore( $UNIFIED, $unified_file ) or die("Problem with nstore! $!");
}

# work out and install reverse dependencies
sub _reverseDepend {
	foreach my $Obj ( values( %{$UNIFIED->{'allobjects'}} ) ) {
		my $item = $Obj->{'package'};
		TRACE( "Resolving dependencies for $item" );
		
		# iterate over dependencies...
		foreach my $dep ( @{$Obj->{'depends_on'}} ) {
			if (exists $UNIFIED->{'allobjects'}->{ $dep }) {
				# put reverse dependencies into packages
				TRACE( "Installing reverse dependency in $dep" );
				push( @{$UNIFIED->{'allobjects'}->{ $dep }->{'depended_upon_by'}}, $item );
			}
		}
	}
}

sub _wanted {
	local $_ = $_;
	my $fname = $File::Find::name;
	
	foreach (@NOINDEX) {
		if (index($fname, $_) > -1) {
			TRACE("Rejecting $fname");
			return;
		}
	}
	
	TRACE("Indexing $fname");
	my $is_perl_script = 0;
	if (m/\.pm$/) {
		my $moduleObj = _parseModule( $fname ) || return;
		$UNIFIED->{'allobjects'}->{ $moduleObj->{'package'} } = $moduleObj;
	} elsif (m/\.plx?$/) {
		$is_perl_script++;
	} elsif ($check_shebang && -f $fname && open(F, "<$fname")) {
		my $first_line = <F> || '';
		close F;
		if ($first_line =~ /^#!.*perl/) {
			$is_perl_script++;
		}
	} else {
		return;
	}

	if ($is_perl_script) {
 		my $scriptObj = _parseScript( $fname ) || return;
 		push( @{$UNIFIED->{'scripts'}} , $scriptObj->{'package'} );
 		$UNIFIED->{'allobjects'}->{ $scriptObj->{'package'} } = $scriptObj;
 	}
}

# Get data from a module file, returns a dependency unit object
sub _parseModule {
	my $file = shift;
	my $self = {
		'filename' => $file,
		'package' => '',
		'depends_on' => [],
		'depended_upon_by' => [],
	};
	my $foundPackage = 0;
	
	my %seen;
	
	# go through the file and try to find out some things
	local *FILE;
	open(FILE, $file) or do { warn("Can't open file $file for read: $!"); return undef; };
	
	my $in_pod;
	while(<FILE>) {
		if ($in_pod) {
			$in_pod = 0 if (/^=cut\s*$/);
			next;
		}

		# get the package name
		if (m/^\s*package\s+([\w\:]+)\s*;/ && $foundPackage == 0) {
			$foundPackage = 1;
			$self->{'package'} = $1;
			TRACE("*** package is <$1> ***");
		}
		# get the dependencies
		if (m/^\s*use\s+([\w\:]+).*;/) {
			push (@{$self->{'depends_on'}}, $1) unless ($seen{$1}++);
		}
		# get the dependencies
		if (m/^\s*require\s+([\w\:]+).*;/) {
			push (@{$self->{'depends_on'}}, $1) unless ($seen{$1}++);
		}
		
		# the 'base' pragma - SREZIC
		if (m/^\s*use\s+base\s+(.*)/) {
			require Safe;
			my $safe = new Safe;
			(my $list = $1) =~ s/\s+\#.*//;
			$list =~ s/[\r\n]//;
			while ($list !~ /;\s*$/ && ($_ = <FILE>)) {
				s/\s+#.*//;
				s/[\r\n]//;
				$list .= $_;
			}
			$list =~ s/;\s*$//;
			my(@mods) = $safe->reval($list);
			foreach my $mod (@mods) {
				push (@{$self->{'depends_on'}}, $mod) unless ($seen{$mod}++);
			}
		}

		$in_pod = 1 if m/^=\w+/;
		last if m/^__/;
		last if m/^1;/;
	}
	close FILE;
	
	if ($foundPackage) {
		return $self;
	} else {
		return undef;
	}
}

# Get data from a program file, returns a dependency unit object
sub _parseScript {
	my $file = shift;
	
	my $node;
	(undef, undef, $node) = File::Spec->splitpath( $file );
	TRACE("Filename $node found from $file");
	
	my $self = {
		'filename' => $file,
		'package' => $node,
		'depends_on' => [],
	};
	my $foundPackage = 0;
	
	my %seen;
	
	# go through the file and try to find out some things
	local *FILE;
	open(FILE, $file) or do { warn("Can't open file $file for read: $!"); return undef; };

	my $in_pod;
	while(<FILE>) {
		if ($in_pod) {
			$in_pod = 0 if (/^=cut\s*$/);
			next;
		}

		# get the dependencies
		if (m/\s*use\s+([\w\:]+).*;/) {
			push (@{$self->{'depends_on'}}, $1) unless ($seen{$1}++);
		}
		# get the dependencies
		if (m/\s*require\s+([\w\:]+).*;/) {
			push (@{$self->{'depends_on'}}, $1) unless ($seen{$1}++);
		}

		$in_pod = 1 if m/^=\w+/;
		last if m/^__/;
	}
	close FILE;
	
	return $self;
}

sub TRACE {}
sub LOG {}

1;

=head1 NAME

Module::Dependency::Indexer - creates the databases used by the dependency mapping module

=head1 SYNOPSIS

	use Module::Dependency::Indexer;
	Module::Dependency::Indexer::setIndex( '/var/tmp/dependency/unified.dat' );
	Module::Dependency::Indexer::makeIndex( $directory, [ $another, $andanother... ] );
	Module::Dependency::Indexer::setShebangCheck( 0 );

=head1 DESCRIPTION

This module looks at all .pm, .pl and .plx files within and below a given directory/directories 
(found with File::Find), reads through them and extracts some information about them.
If the shebang check is turned on then it also looks at the first line of all
other files, to see if they're perl programs too. We extract this information:

=over 4

=item *

The name of the package (e.g. 'Foo::Bar') or the name of the script (e.g. 'chat.pl')

=item *

The full filesystem location of the file.

=item *

The dependencies of the file - i.e. the packages that it 'use's or 'require's

=item *

The reverse dependencies - i.e. what other scripts and modules B<THAT IT HAS INDEXED> use or require
the file. It can't, of course, know about 'use' statements in files it hasn't examined.

=back

When it has extracted all this information it uses Storable to write the data to disk in the indexfile location.

This search is quite an expensive operation, taking around 10 seconds for the site_perl directory here.
However once the information has been gathered it's extremely fast to use.

=head1 FUNCTIONS

=over 4

=item setIndex( $filename )

This function tells the module where to write out the datafile. You can set this, make an index 
of some directory of perl stuff, set it to something else, index a different folder, etc., in order 
to build up many indices. This only affects this module - you need to tell ...::Info where to look 
for datafiles independently of this module.

Default is /var/tmp/dependence/unified.dat

=item makeIndex( $directory, [ $another, $andanother... ] )

Builds, and stores to the current data file, a SINGLE database for all the files found under 
all of the supplied directories. To create multiple indexes, run this method many times with a setIndex 
inbetween each so that you don't clobber the previous run's datafile.

=item setShebangCheck( BOOLEAN )

Turns on or off the checking of #! lines for all files that are not .pl, .plx or .pm filenames.
By default we do check the #! lines.

=back

=head1 NOTE ABOUT WHAT IS INDEXED

A database entry is made for B<each file scanned>. This makes the generally good assumption that a .pl file is
a script that is not use/required by anything else, and a .pm file is a package file which may be use/required
by many other files. Database entries ARE NOT made just because a file is use/required - hence the database
will not contain an entry for 'strict' or 'File::Find' (for example) unless you explicitly index your perl's lib/ folder.

E.g., if 'Local::Foo.pm' uses strict and File::Find and we index it, its entry in the database will show that it 
depends on strict and File::Find, as you'd expect. It's just that we won't create an entry for 'strict' on that basis alone.

In practice this behaviour is what you want - you want to see how the mass of perl in your cgi-bin and site_perl folders
fits together (for example), or maybe just a single project in CVS.
You may of course include your perl lib directory in the database should you want to see the dependencies involving
the standard modules, but generally that's not relevant.

=head1 USE OF THE DATA

Now you've got a datafile which links all the scripts and modules in a set of directories. Use ...::Info to get at the data.
Note that the data is stored using Storable's nstore method which _should_ make these indexes portable across platforms.
Not tested though.

=head1 ADVICE, GETTING AT DATA

As Storable is so fast, you may want to make one big index of all folders where perl things are. Then you can load this 
datafile back up, extract the entry for, say, Local::Foo and examine its dependencies (and reverse dependencies). 
Based on what you find, you can get the entries for Local::Foo::Bar and Local::Foo::Baz (things used by Local::Foo) or
perhaps Local::Stuff (which uses Local::Foo). Then you can examine those records, etc. This is how ...::Grapher builds
the tree of dependencies, basically.

You use Module::Dependency::Info to get at these records using a nice simple API. If you're feeling keen you can just
grab the entire object - but that's in the ...::Info module.

Here we have a single index for all our local perl code, and that lives in /var/tmp/dependence/unified.dat - the default
location. Other applications just use that file.

=head1 DEBUGGING

There is a TRACE stub function, and the module uses TRACE() to log activity. Override our TRACE with your own routine, e.g.
one that prints to STDERR, to see these messages.

=head1 SEE ALSO

Module::Dependency and the README files.

=head1 VERSION

$Id: Indexer.pm,v 1.13 2002/09/25 23:06:35 piers Exp $

=cut


