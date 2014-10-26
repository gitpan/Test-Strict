#!/usr/bin/perl -w

##
## Tests errors
## by creating files with incorrect syntax or no "use strict;"
## and run Test::Strict under an external perl interpreter.
## The output is parsed to check result.
##

use strict;
BEGIN {
  if ($^O =~ /win32/i) {
    require Test::More;
    Test::More->import(
      skip_all => "Windows does not allow two processes to access the same file."
    );
  }
}

use Test::More tests => 8;
use File::Temp qw( tempdir tempfile );

my $perl  = $^X || 'perl';
my $inc = join(' -I ', @INC) || '';
$inc = "-I $inc" if $inc;

test1();
test2();
test3();

exit;


sub test1 {
  my $dir = make_bad_file();
  my ($fh, $outfile) = tempfile( UNLINK => 1 );
  ok( `$perl $inc -MTest::Strict -e "all_perl_files_ok( '$dir' )" 2>&1 > $outfile` );
  local $/ = undef;
  my $content = <$fh>;
  like( $content, qr/^ok 1 - Syntax check /m, "Syntax ok" );
  like( $content, qr/not ok 2 - use strict /, "Does not have use strict" );
}

sub test2 {
  my $dir = make_another_bad_file();
  my ($fh, $outfile) = tempfile( UNLINK => 1 );
  ok( `$perl $inc -MTest::Strict -e "all_perl_files_ok( '$dir' )" 2>&1 > $outfile` );
  local $/ = undef;
  my $content = <$fh>;
  like( $content, qr/not ok 1 - Syntax check /, "Syntax error" );
  like( $content, qr/^ok 2 - use strict /m, "Does have use strict" );
}

sub test3 {
  my $file = make_bad_warning();
  my ($fh, $outfile) = tempfile( UNLINK => 1 );
  ok( `$perl $inc -e "use Test::Strict no_plan =>1; warnings_ok( '$file' )" 2>&1 > $outfile` );
  local $/ = undef;
  my $content = <$fh>;
  like( $content, qr/not ok 1 - use warnings /, "Does not have use warnings" );
}



sub make_bad_file {
  my $tmpdir = tempdir( CLEANUP => 1 );
  my ($fh, $filename) = tempfile( DIR => $tmpdir, SUFFIX => '.pL' );
  print $fh <<'DUMMY';
print "Hello world without use strict";
# use strict;
=over
use strict;
=back

=for
use strict;
=end

=pod
use strict;
=cut

DUMMY
  return $tmpdir;
}

sub make_another_bad_file {
  my $tmpdir = tempdir( CLEANUP => 1 );
  my ($fh, $filename) = tempfile( DIR => $tmpdir, SUFFIX => '.pm' );
  print $fh <<'DUMMY';
=pod
blah
=cut
# a comment
undef;use    strict ; foobarbaz + 1; # another comment
DUMMY
  return $tmpdir;
}


sub make_bad_warning {
  my $tmpdir = tempdir( CLEANUP => 1 );
  my ($fh, $filename) = tempfile( DIR => $tmpdir, SUFFIX => '.pL' );
  print $fh <<'DUMMY';
print "Hello world without use warnings";
# use warnings;
=over
use warnings;
=back

=for
use warnings;
=end

=pod
use warnings;
=cut

DUMMY
  return $filename;
}

