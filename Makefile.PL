use ExtUtils::MakeMaker;

# $Id: Makefile.PL,v 1.5 2002/09/12 00:42:41 piers Exp $

WriteMakefile(
	AUTHOR		=> 'P Kent (pause@selsyn.co.uk)',
	ABSTRACT	=> 'Investigate dependencies between files',
	NAME		=> 'Module::Dependency',
	DISTNAME	=> 'Module-Dependency',
	dist		=> {
		COMPRESS	=> 'gzip',
		SUFFIX		=> '.gz',
	},
	VERSION_FROM	=> 'lib/Module/Dependency/Indexer.pm',
	PREREQ_PM	=> {
				Storable => 0,
				File::Find => 0,
				File::Spec => 0,
				Safe => 0,
			},
	EXE_FILES	=> [ qw(cgidepend.plx  dumper.plx  grapher.plx  indexer.plx) ],
	PREFIX		=> '/usr/local/dependency',
);

