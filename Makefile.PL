use ExtUtils::MakeMaker;

# $Id: Makefile.PL,v 1.1 2002/01/07 04:03:05 piers Exp $

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
				GD => 0,
				Storable => 0,
				File::Find => 0
			},
);

