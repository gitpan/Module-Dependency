#!/usr/bin/perl5.00503
# $Id: cgidepend.plx,v 1.4 2002/01/21 23:29:44 piers Exp $

### YOU MAY NEED TO EDIT THE SHEBANG LINE!

use strict;

### EDIT THIS LINE - You may need to point this at some special lib directory
use lib qw(/home/piers/src/dependency/lib);

### EDIT THIS LINE - New versions of GD do not support GIF
### Set this to 'GIF' or 'PNG' depending on what your GD can handle
### This program will try to override this if the CGI parameter 'format' is given: this
### value is used when no guess can be made
use constant DEFAULT_FORMAT => 'PNG';

### EDIT THIS - set it to the URL of the stylesheet you want to use
use constant STYLESHEET_LOC => '/depend.css';

use CGI;
use Module::Dependency::Info;
use Module::Dependency::Grapher;

use vars qw/$VERSION $cgi/;

($VERSION) = ('$Revision: 1.4 $' =~ /([\d\.]+)/ );
$cgi = new CGI;

eval {
	# no parameters... print the usage
	unless ( $cgi->param('go') ) {
		print "Content-type: text/plain\n\n";
		require Pod::Text;
		Pod::Text::pod2text($0);
		die("NORMALEXIT");
	}
	
	my $datafile = $cgi->param('datafile');
	my $allscripts = $cgi->param('allscripts');
	my $seed;
	unless ( $allscripts) {
		$seed = $cgi->param('seed') || die("There must be a 'seed' specified");
	}
	my $kind = $cgi->param('kind') || 'both';
	my $embed = $cgi->param('embed');
	my $format = $cgi->param('format') || DEFAULT_FORMAT;
	$format =~ s/[^\w]//g;
	
	Module::Dependency::Grapher::setIndex( $datafile ) if $datafile;

	# what modules/scripts will be included
	my @objlist;
	my $objliststr;
	my $plural = '';
	
	if ( $allscripts ) {
		@objlist = @{ Module::Dependency::Info::allScripts() };
		$plural = 's';
		$objliststr = 'All Scripts';
	} else {
		if (index($seed, ',') > -1) {
			@objlist = split(/,\s*/, $seed);
			$plural = 's';
			$objliststr = join(', ', @objlist);
		} else {
			@objlist = $objliststr = $seed;
		}
	}
	
	my $title;
	if ($kind == 'both') {
		$title = "Parent & child dependencies for package$plural $objliststr";
	} elsif ($kind == 'parent') {
		$title = "Parent dependencies for package$plural $objliststr";
	} else {
		$title = "Dependencies for package$plural $objliststr";
	}

	if ( $embed ) {
		print "Content-type: image/" . lc($format) . "\n\n";
		Module::Dependency::Grapher::makeImage( $kind, \@objlist, '-', {Title => $title, Format => $format} );
	} else {
		print "Content-type: text/html\n\n";
		
		html_head($seed, $format, $kind, $datafile, $allscripts);
		Module::Dependency::Grapher::makeHtml( $kind, \@objlist, '-', {Title => $title, NoVersion => 1, NoLegend => 1});
		
		unless ( $allscripts ) {
			foreach ( @objlist ) {
				print "\n<hr />\n";
				my $obj = Module::Dependency::Info::getItem( $_ ) || do {print("<h2>No such item *$_* in database</h2>\n"); next;};
				
				print "<h2>Textual information for $_</h2>\n<dl>\n<dt>Direct Dependencies</dt>\n";
				if (exists($obj->{'depends_on'})) {
					print "<dd>", join(', ', sort(@{$obj->{'depends_on'}})), "</dd>\n";
				} else {
					print "<dd>none</dd>\n";
				}

				print "<dt>Direct Parent Dependencies</dt>\n";
				if (exists($obj->{'depended_upon_by'})) {
					print "<dd>", join(', ', sort(@{$obj->{'depended_upon_by'}})), "</dd>";
				} else {
					print "<dd>none</dd>\n";
				}		
				print "<dt>Full Filesystem Path</dt>\n";
				print "<dd>$obj->{'filename'}</dd>\n</dl>\n";
			}
		}
		html_foot();
	}
};
if ($@ && $@ !~ /NORMALEXIT/) {
	print "Content-type: text/plain\n\nError encountered! The error was: $@";
}

### END OF MAIN

sub esc {
	my $x = shift;
	$x =~ s/&/&amp;/g;
	$x =~ s/</&lt;/g;
	$x =~ s/>/&gt;/g;
	return $x;
}

sub html_head {
	my ($seed, $format, $kind, $datafile, $allscripts) = @_;
	my $prog = $0;
	$prog =~ s|^.*/||;
	my $title = $seed || 'all scripts';
print qq(<html>
<head><title>Dependencies for $title</title>
<link rel="stylesheet" href=") . STYLESHEET_LOC . qq(" type="text/css">
</head>
<body>
<h1>Dependency Information for $seed</h1><hr />
<h2>Plot of relationships</h2>
<img src="$prog?go=1&embed=1&seed=$seed&kind=$kind&format=$format&datafile=$datafile&allscripts=$allscripts" alt="Dependency tree">
);
}

sub html_foot {
	my $prog = $0;
	$prog =~ s|^.*/||;print qq(
<hr />
<p>$prog version $VERSION</p>
</body>
</html>
);
}

__END__

=head1 NAME

cgidepend - display Module::Dependency info to your web browser

=head1 SYNOPSIS

Called without any/sufficient parameters you get this documentation returned.
	
These CGI parameters are recognized:

=over 4

=item go

Must be true - used to ensure we have been called correctly

=item embed

If true, returns an image, else returns the HTML.

=item format

Optionally, specifically ask for one kind of image format (default is 'PNG', but may be 
'GIF' if your GD allows that)

=item datafile

Optionally sets the data file location.

=item seed

Which item to start with, or...

=item allscripts

if true, use all the scripts in the database as seeds

=item kind

Which dependencies to plot - may be 'both' (the default) 'parent' or 'child'.

=back

=head1 DESCRIPTION

The original thought that created the Module::Dependency software came when browsing our
CVS repository. CVSWeb is installed to allow web browsing, and a tree of documentation is
made automatically. I thought it would be useful to see what a module depended upon, and
what depended upon it.

This CGI is an attempt at doing that. It can be called in 2 modes: one returns the HTML of
the page, and the other returns a PNG (or GIF) that the page embeds.

The HTML mode basically gives you all the dependency info for the item, and the image shows
it to you in an easy to understand way.

=head1 VERSION

$Id: cgidepend.plx,v 1.4 2002/01/21 23:29:44 piers Exp $

=cut


