use ExtUtils::MakeMaker;

# $Id: Makefile.PL,v 1.4 2002/04/28 23:28:48 piers Exp $

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
);

