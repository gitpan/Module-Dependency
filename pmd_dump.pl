#!/usr/bin/perl -w

our $VERSION = (q$Revision: 6570 $ =~ /(\d+)/g)[0];

use strict;

use Getopt::Std;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case);

use Module::Dependency::Info;

GetOptions(
    "o=f" => \my $opt_o,
    "t!"  => \my $opt_t,
    "P|Parents=i"   => \(my $opt_Parents=0),
    "C|Children=i"  => \(my $opt_Children=0),
    "M|Merge!"      => \(my $opt_Merge),
    "F|Filter=s"    => \(my $opt_Filter),
    "S|Select=s"    => \(my $opt_Select),
    "D|Deldeps!"    => \(my $opt_Deldeps),
    "p|parents=i"   => \(my $opt_parents=0),
    "c|children=i"  => \(my $opt_children=0),
    "f|fields=s"    => \(my $opt_fields=''),
    "i|indent=s"    => \(my $opt_indent = "\t"),
    "k|key!"        => \(my $opt_key),
    "h|header!"     => \(my $opt_header),
    "help"          => sub { usage() },
    "s|sort!"       => \(my $opt_sort),
    "u|uniq!"       => \(my $opt_unique),
    "r|rel=s"       => \(my $opt_rel),
) or exit 1;

*Module::Dependency::Info::TRACE = \*TRACE;

Module::Dependency::Info::setIndex($opt_o) if $opt_o;

my $allobj = Module::Dependency::Info::retrieveIndex()->{allobjects};
my @selected;

# select objects, in @ARGV and key order
for my $arg (@ARGV) {
    my $selector = mk_selector($arg);
    push @selected, map {
        $selector->($allobj->{$_}) ? ($allobj->{$_}) : ()
    } sort keys %$allobj;
}

die "Nothing selected by argument list @ARGV\n" unless @selected;

my @parents  = uniq( map { related_objs($_, 'depended_upon_by', $opt_Parents)  } @selected );
my @children = uniq( map { related_objs($_, 'depends_on',       $opt_Children) } @selected );
my @all      = uniq( @parents, @selected, @children );

if ($opt_Filter) {
    my $selector = mk_selector($opt_Filter);
    @all = grep { not $selector->($_) } @all;
}

if ($opt_Select) {
    my $selector = mk_selector($opt_Select);
    @all = grep { $selector->($_) } @all;
}

if ($opt_Merge) {
    my %all = map { ($_->{key} => $_) } @all;
    my $new = {};
    for my $obj (@all) {
        # XXX this should be a merge_with method on a real object
        # discard items we know nothing about
        next unless ref $obj;
        while ( my ($k, $v) = each %$obj ) {
            if (ref $v eq 'ARRAY') {
                push @{$new->{$k}}, @$v;
            }
            elsif (ref $v eq 'HASH') {
                $new->{$k} = { %{$new->{$k}}, %$v };
            }
            else {
                my @old = (exists $new->{$k}) ? (@{$new->{$k}}) : ();
                $new->{$k} = [ @old, $v ];
            }
        }
    }
    while ( my ($k, $v) = each %$new ) {
        if (ref $v eq 'ARRAY') {
            my @ary = uniq(@$v);
            @ary = sort @ary if $opt_sort;
            $new->{$k} = \@ary;
        }
    }
    $new->{key} = join ', ', @{$new->{key}};
    # remove dependencies that are resolved within the merged objects
    for my $f (qw(depends_on depended_upon_by)) {
        my $dep = $new->{$f};
        $new->{$f} = [ grep { !exists $all{$_}->{filename} } @$dep ];
    }
    @all = ($new);
}

if ($opt_Deldeps) {
    for (@all) {
        my $dep = $_->{depends_on} || [];
        $_->{depends_on} = [ grep { !locate_module($_) } @$dep ];
    }
}

my @rels;
if ($opt_rel) {
    my $selector = mk_selector($opt_rel);
    @rels = grep { $selector->($_) } @all;
    warn "No items match -r $opt_rel\n" unless @rels;
}

for my $obj (@all) {
    print format_obj($obj, 0, $opt_fields, $opt_parents, $opt_children, undef),"\n";

    for my $rel (@rels) { # XXX untested carryover from old pmd_dumper.plx
        my $rv = Module::Dependency::Info::relationship( $obj, $rel );
        if ( not defined $rv ) {
            print "Sorry, cannot find '$obj' in database\n";
        }
        elsif ( $rv eq 'NONE' ) {
            print "No relationship found between '$obj' and '$rel'\n";
        }
        elsif ( $rv eq 'PARENT' ) {
            print "'$rel' is a parent of '$obj'\n";
        }
        elsif ( $rv eq 'CHILD' ) {
            print "'$rel' is a child of '$obj'\n";
        }
        else {
            print "Circular dependency found between '$obj' and '$rel'\n";
        }
    }
}

exit 0;


sub mk_selector {
    my ($expr) = @_;
    my ($field, $pattern);

    if ($expr eq '') { # select everything
        ($field, $pattern) = ('key', qr/.*/);
    }
    elsif ($expr =~ m/^(\w+)=~?(.*)/) {
        ($field, $pattern) = ($1, qr/$2/);
    }
    elsif ($expr !~ /=/ && $expr =~ s/\$$//) {
        # as a convienience for selecting filenames without knowing how
        # much of the path to include, adding a trailing dollar means do a
        # suffix search on filename
        ($field, $pattern) = ("filename", qr/\Q$expr\E$/);
    }
    else {
        # else exact match on key (most useful for packages)
        ($field, $pattern) = ("key", qr/^\Q$expr\E$/);
    }
    TRACE("Selecting where $field =~ $pattern");
    return sub {
        my ($obj) = @_;
        $obj = { key => $obj } unless ref $obj;
        my $v = (defined $obj->{$field}) ? $obj->{$field} : "";
        $v = join " ", @$v if ref $v eq 'ARRAY';
        $v = join " ", %$v if ref $v eq 'HASH';
        return 1 if $v =~ /$pattern/;
    };
}


sub format_obj {
    my ($obj, $indent_level, $fields, $parent_levels, $child_levels, $seen) = @_;
    $seen ||= {};
    $fields = { map { ($_=>1) } split /,/, $fields } unless ref $fields;
    my $indent = $opt_indent x $indent_level;
    my @str;

    $obj = $allobj->{$obj} if not ref $obj and $allobj->{$obj};

    my $key = (ref $obj) ? $obj->{key} : $obj;
    return if $opt_unique and $seen->{$key};
    $seen->{$key} = $obj;

    if (!ref $obj) {
        return "$indent$obj";
    }

    my $parents = $obj->{depended_upon_by} || [];
    if ($parent_levels && @$parents) {
        push @str, map { format_obj($_, $indent_level+1, $fields, $parent_levels-1, 0, $seen) } @$parents;
    }

    for my $f (sort keys %$obj) {
        next if $f eq 'key';
        next if %$fields && !$fields->{$f};
        my $v = $obj->{$f};
        $v = join " ", @$v if ref $v eq 'ARRAY';
        $v = join " ", %$v if ref $v eq 'HASH';
        my $header;
        $header .= $indent;
        $header .= "$key " unless $opt_key;
        $header .= "$f: ";
        $header = "" if $opt_header;
        push @str, "$header$v" unless !defined $v;
    }

    my $children = $obj->{depends_on} || [];
    if ($child_levels && @$children) {
        push @str, map { format_obj($_, $indent_level+1, $fields, 0, $child_levels-1, $seen) } @$children;
    }
    return join "\n", @str;
}

sub related_objs {
    my ($obj, $field, $depth) = @_;
    die "$obj is not an item" unless ref $obj eq 'HASH';
    return if $depth <= 0;
    my $related = $obj->{$field};
    unless (defined $related) {
        warn "$obj->{key} doesn't have a '$field' value\n";
        return;
    }
    unless (ref $related eq 'ARRAY') {
        warn "$obj->{key} '$field' value isn't an array ref\n";
        return;
    }
    # map related names to objects, but fallback to name if there's no object
    my @related = map { $allobj->{$_} || $_ } @$related;
    # expand list via recursion
    push @related, map { related_objs($_, $field, $depth-1) } grep { ref $_ } @related;
    # collapse down to unique entries
    @related = uniq(@related);
    return @related;
}

sub locate_module {
    my ($module) = @_;
    (my $filename = $module) =~ s!::!/!g;
    $filename .= ".pm";
    foreach my $prefix (@INC) {
        my $realfilename = "$prefix/$filename";
        return $realfilename if -f $realfilename;
    }
    return undef;
}

sub usage {
    while (<DATA>) { last if /^=head1 NAME/; }
    while (<DATA>) {
        last if /^=cut/;
        s/^\t//;
        s/^=head1 //;
        print;
    }
    exit;
}

sub uniq {
    my %h;
    map { $h{$_}++ == 0 ? $_ : () } @_;
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

pmd_dump.pl - Query and print Module::Dependency info

=head1 SYNOPSIS

    pmd_dump.pl [options] object-patterns

object-patterns can be:

    f=S    - Select objects where field f equals string S
    f=~R   - Select objects where field f matches regex R
    S$     - Same as filename=~S$ to match by file suffix
    S      - Same as key=S

For example:

    package=Foo::Bar         - that specific package
    package=~^Foo::          - all packages that start with Foo::
    filename=~sub/dir/path   - everything with that path in the filename
    filename=~'\.pm$'        - all modules
    restart.pl$              - all files with names ending in restart.pl
    foo                      - same as key=foo

Fields available are:

    filename         - "dir/subdir/foo.pl"
    package          - "strict"
    key              - same as package for packages, or filename for other files
    filerootdir      - "/abs/path"
    depends_on       - "Carp strict Foo::Bar"
    depended_upon_by - "Other::Module dir/subdir/foo.pl dir2/bar.pl Another:Module"

Selected objects can be augmented using:

    -P=N   Also pre-select N levels of parent objects
    -C=N   Also pre-select N levels of child objects

Then filtered:

    -F=P   Filter OUT objects matching the object-pattern P
    -S=P   Only SELECT objects matching the object-pattern P

Then merged:

    -M     Merge data for selected objects into a single pseudo-object.
           Removes internally resolved dependencies.
           Handy to see all external dependencies of a group of files.
           The -P and -C flags are typically only useful with -M.

Then modified:

    -D     Delete dependencies on modules which weren't indexed but can
           be found in @INC

Then dumped:

    -f=f1,f2,... - only dump these fields (otherwise all)

And for each one dumped:

    -p=N   Recurse to show N levels of indented parent objects first
    -c=N   Recurse to show N levels of indented child objects after
    -i=S   Use S as the indent string (default is a tab)
    -u     Unique - only show a child or parent once
    -k     Don't show key in header, just the fieldname
    -h     Don't show header (like grep -h), used with -f=fieldname
    -s     sort by name
    -r=P   Show the relationship between the item and those matching P

Other options:

    -help Displays this help
    -t Displays tracing messages
    -o the location of the datafile (default is /var/tmp/dependence/unified.dat)
    -r State the relationship, if any, between item1 and item2 - both may be scripts or modules.

=head1 EXAMPLE

    pmd_dump.pl -o ./unified.dat Module::Dependency::Info

Select and merge everything in the database (which removes internally resolved
dependencies) and list the names of all unresolved packages:

    pmd_dump.pl -f=depends_on -h -M ''

Do the same but feed the results back into pmd_dump.pl to get details of what
depends on those unresolved items:

    pmd_dump.pl -f=depended_upon_by `pmd_dump.pl -f=depends_on -h -M ''` | less -S

=head1 DESCRIPTION

Module::Dependency modules rely on a database of dependencies. This tool allows
you to query the index, verify that it contains what it should contain, look up
module dependencies, etc.

The default location for the index file is /var/tmp/dependence/unified.dat but
you can select another file using the -o option.

=head1 VERSION

$Id: pmd_dump.pl 6570 2006-06-27 15:01:04Z timbo $

=cut


