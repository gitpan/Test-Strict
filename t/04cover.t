#!/usr/bin/perl -w
use strict;
use Test::More;
use Test::Strict;

my $covered = all_cover_ok();  # 50% coverage
ok( $covered > 50 );
is( $Test::Strict::COVERAGE_THRESHOLD, 50 );
