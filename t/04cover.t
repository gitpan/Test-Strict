#!/usr/bin/perl -w
use strict;
use Test::More;
use Test::Strict;

unless (Test::Strict::cover_path) {
  plan skip_all => "cover binary required to run test coverage - Set \$Test::Strict::COVER to the path to 'cover'";
  exit;
}

my $covered = all_cover_ok();  # 50% coverage
ok( $covered > 50 );
is( $Test::Strict::COVERAGE_THRESHOLD, 50 );
