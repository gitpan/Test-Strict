#!/usr/bin/perl -w

##
## Tests errors
## by creating files with incorrect syntax or no "use strict;"
## and run Test::Strict under an external perl interpreter.
## The output is parsed to check result.
##

use strict;
use Test::More tests => 6;
use File::Temp qw( tempdir tempfile );


my $perl  = $^X || 'perl';
my $inc = join(' -I ', @INC) || '';
$inc = "-I $inc" if $inc;

test1();
test2();

exit;


sub test1 {
  my $dir = make_bad_file();
  my ($fh, $outfile) = tempfile( UNLINK => 1 );
  ok( my $result = `$perl $inc -MTest::Strict -e "all_perl_files_ok( '$dir' )" 2>&1 > $outfile` );
  local $/ = undef;
  my $content = <$fh>;
  like( $content, qr/^ok 1 - Syntax check /m, "Syntax ok" );
  like( $content, qr/not ok 2 - use strict /, "Does not have use strict" );
}

sub test2 {
  my $dir = make_another_bad_file();
  my ($fh, $outfile) = tempfile( UNLINK => 1 );
  ok( my $result = `$perl $inc -MTest::Strict -e "all_perl_files_ok( '$dir' )" 2>&1 > $outfile` );
  local $/ = undef;
  my $content = <$fh>;
  like( $content, qr/not ok 1 - Syntax check /, "Syntax error" );
  like( $content, qr/^ok 2 - use strict /m, "Does have use strict" );
}


sub make_bad_file {
  my $tmpdir = tempdir();
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
  my $tmpdir = tempdir();
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
