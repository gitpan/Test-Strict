#!/usr/bin/perl -w
use strict;
use Test::Strict;

##
## This should check all perl files in the distribution
## including this current file, the Makefile.PL etc.
## and check for "use strict;" and syntax ok
##

all_perl_files_ok();

strict_ok( $0, "got strict" );
syntax_ok( $0, "syntax" );
syntax_ok( 'Test::Strict' );
strict_ok( 'Test::Strict' );
