package Test::Strict;

=head1 NAME

Test::Strict - Check syntax, presence of use strict; and test coverage

=head1 SYNOPSIS

C<Test::Strict> lets you check the syntax and presence of C<use strict;>
in your perl code.
It report its results in standard C<Test::Simple> fashion:

  use Test::Strict tests => 2;
  syntax_ok( 'bin/myscript.pl' );
  strict_ok( 'My::Module', "use strict; in My::Module" );
  warnings_ok( 'lib/My/Module.pm' );

Module authors can include the following in a t/strict.t
and have C<Test::Strict> automatically find and check
all perl files in a module distribution:

  use Test::Strict;
  all_perl_files_ok(); # Syntax ok and use strict;

or

  use Test::Strict;
  all_perl_files_ok( @mydirs );

C<Test::Strict> can also enforce a minimum test coverage
the test suite should reach.
Module authors can include the following in a t/cover.t
and have C<Test::Strict> automatically check the test coverage:

  use Test::Strict;
  all_cover_ok( 80 );  # at least 80% coverage

or

  use Test::Strict;
  all_cover_ok( 80, 't/' );

=head1 DESCRIPTION

The most basic test one can write is "does it compile ?".
This module tests if the code compiles and play nice with C<Test::Simple> modules.

Another good practice this module can test is to "use strict;" in all perl files.

By setting a minimum test coverage through C<all_cover_ok()>, a code author
can ensure his code is tested above a preset level of I<kwality> throughout the development cycle.

Along with L<Test::Pod>, this module can provide the first tests to setup for a module author.

This module should be able to run under the -T flag for perl >= 5.6.
All paths are untainted with the following pattern: C<qr|^([-+@\w./:\\]+)$|>
controlled by C<$Test::Strict::UNTAINT_PATTERN>.

=cut

use strict;
use 5.004;
use Test::Builder;
use File::Spec;
use FindBin qw($Bin);
use File::Find;

use vars qw( $VERSION $PERL $COVERAGE_THRESHOLD $COVER $UNTAINT_PATTERN $PERL_PATTERN $CAN_USE_WARNINGS);
$VERSION = '0.04';
$PERL    = $^X || 'perl';
$COVERAGE_THRESHOLD = 50; # 50%
$UNTAINT_PATTERN    = qr|^([-+@\w./:\\]+)$|;
$PERL_PATTERN       = qr/^#!.*perl/;
$CAN_USE_WARNINGS   = ($] >= 5.006);

my $Test  = Test::Builder->new;
my $updir = File::Spec->updir();
my %file_find_arg = ($] <= 5.006) ? ()
                                  : (
                                      untaint         => 1,
                                      untaint_pattern => $UNTAINT_PATTERN,
                                      untaint_skip    => 1,
                                    );


sub import {
  my $self   = shift;
  my $caller = caller;
  {
    no strict 'refs';
    *{$caller.'::strict_ok'}         = \&strict_ok;
    *{$caller.'::warnings_ok'}       = \&warnings_ok;
    *{$caller.'::syntax_ok'}         = \&syntax_ok;
    *{$caller.'::all_perl_files_ok'} = \&all_perl_files_ok;
    *{$caller.'::all_cover_ok'}      = \&all_cover_ok;
  }
  $Test->exported_to($caller);
  $Test->plan(@_);
}


##
## all_perl_files( @dirs )
## Returns a list of perl files in @dir
## if @dir is not provided, it searches from one dir level above
##
sub all_perl_files {
  my @all_files = all_files(@_);
  return grep { _is_perl_module($_) || _is_perl_script($_) } @all_files;
}

sub all_files {
  my @base_dirs = @_ ? @_
                     : File::Spec->catdir($Bin, $updir);
  my @found;
  my $want_sub = sub {
    return if ($File::Find::dir =~ m![\\/]?CVS[\\/]|[\\/]?.svn[\\/]!); # Filter out cvs or subversion dirs/
    return unless (-f $File::Find::name && -r _);
    push @found, File::Spec->no_upwards( $File::Find::name );
  };
  my $find_arg = {
                    %file_find_arg,
                    wanted   => $want_sub,
                    no_chdir => 1,
                 };
  find( $find_arg, @base_dirs);
  @found;
}


=head1 FUNCTIONS

=head2 syntax_ok( $file [, $text] )

Run a syntax check on C<$file> by running C<perl -c $file> with an external perl interpreter.
The external perl interpreter path is stored in C<$Test::Strict::PERL> which can be modified.
You may prefer C<use_ok()> from L<Test::More> to syntax test a module.
For a module, the path (lib/My/Module.pm) or the name (My::Module) can be both used.

=cut

sub syntax_ok {
  my $file     = shift;
  my $test_txt = shift || "Syntax check $file";
  $file = module_to_path($file);
  unless (-f $file && -r _) {
    $Test->ok( 0, $test_txt );
    $Test->diag( "File $file not found or not readable" );
    return;
  }
  if (! _is_perl_module($file) and ! _is_perl_script($file)) {
    $Test->ok( 0, $test_txt );
    $Test->diag( "$file is not a perl module or a perl script" );
    return;
  }

  my $inc = join(' -I ', @INC) || '';
  $inc = "-I $inc" if $inc;
  $file            = _untaint($file);
  my $perl_bin     = _untaint($PERL);
  local $ENV{PATH} = _untaint($ENV{PATH}) if $ENV{PATH};

  my $eval = `$perl_bin $inc -c $file 2>&1`;
  my $ok = $eval =~ qr!$file syntax OK!ms;
  $Test->ok($ok, $test_txt);
  unless ($ok) {
    $Test->diag( $eval );
  }
  return $ok;
}


=head2 strict_ok( $file [, $text] )

Check if C<$file> contains a C<use strict;> statement.

This is a pretty naive test which may be fooled in some edge cases.
For a module, the path (lib/My/Module.pm) or the name (My::Module) can be both used.

=cut

sub strict_ok {
  my $file     = shift;
  my $test_txt = shift || "use strict   $file";
  $file = module_to_path($file);
  open my($fh), $file or do { $Test->ok(0, $test_txt); $Test->diag("Could not open $file: $!"); return; };
  while (<$fh>) {
    next if (/^\s*#/); # Skip comments
    next if (/^\s*=.+/ .. /^\s*=(cut|back|end)/); # Skip pod
    last if (/^\s*(__END__|__DATA__)/); # End of code
    if ( /\buse\s+strict\s*;/ ) {
      $Test->ok(1, $test_txt);
      return 1;
    }
  }
  $Test->ok(0, $test_txt);
  return;
}


=head2 warnings_ok( $file [, $text] )

Check if warnings have been turned on.

If C<$file> is a module, check if it contains a C<use warnings;> or C<use warnings::...> statement.
However, if the perl version is <= 5.6, this test is skipped (C<use warnings> appeared in perl 5.6).

If C<$file> is a script, check if it starts with C<#!...perl -w>.
If the -w is not found and perl is >= 5.6, check for a C<use warnings;> or C<use warnings::...> statement.

This is a pretty naive test which may be fooled in some edge cases.
For a module, the path (lib/My/Module.pm) or the name (My::Module) can be both used.

=cut

sub warnings_ok {
  my $file = shift;
  my $test_txt = shift || "use warnings $file";
  $file = module_to_path($file);
  my $is_module = _is_perl_module( $file );
  my $is_script = _is_perl_script( $file );
  if (!$is_script and $is_module and ! $CAN_USE_WARNINGS) {
    $Test->skip();
    $Test->diag("This version of perl ($]) does not have use warnings - perl 5.6 or higher is required");
    return;
  }

  open my($fh), $file or do { $Test->ok(0, $test_txt); $Test->diag("Could not open $file: $!"); return; };
  while (<$fh>) {
    if ($. == 1 and $is_script and $_ =~ $PERL_PATTERN) {
      if (/perl\s+\-\w*[wW]/) {
        $Test->ok(1, $test_txt);
        return 1;
      }
    }
    last unless $CAN_USE_WARNINGS;
    next if (/^\s*#/); # Skip comments
    next if (/^\s*=.+/ .. /^\s*=(cut|back|end)/); # Skip pod
    last if (/^\s*(__END__|__DATA__)/); # End of code
    if ( /\buse\s+warnings(\s|::|;)/ ) {
      $Test->ok(1, $test_txt);
      return 1;
    }
  }
  $Test->ok(0, $test_txt);
  return;
}


=head2 all_perl_files_ok( [ @directories ] )

Applies C<strict_ok()> and C<syntax_ok()> to all perl files found in C<@directories> (and sub directories).
If no <@directories> is given, the starting point is one level above the current running script,
that should cover all the files of a typical CPAN distribution.
A perl file is *.pl or *.pm or *.t or a file starting with C<#!...perl>

If the test plan is defined:

  use Test::Strict tests => 18;
  all_perl_files_ok();

the total number of files tested must be specified.

=cut

sub all_perl_files_ok {
  my @files = all_perl_files( @_ );

  _make_plan();
  foreach my $file ( @files ) {
    syntax_ok( $file );
    strict_ok( $file );
  }
}


=head2 all_cover_ok( [coverage_threshold [, @t_dirs]] )

This will run all the tests in @t_dirs
(or current script's directory if @t_dirs is undef)
under L<Devel::Cover>
and calculate the global test coverage of the code loaded by the tests.
If the test coverage is greater or equal than C<coverage_threshold>, it is a pass,
otherwise it's a fail. The default coverage threshold is 50
(meaning 50% of the code loaded has been covered by test).

The threshold can be modified through C<$Test::Strict::COVERAGE_THRESHOLD>.
The path to C<cover> utility can be modified through C<$Test::Strict::COVER>.

The 50% threshold is a completely arbitrary value, which should not be considered
as a good enough coverage.

The total coverage is the return value of C<all_cover_ok()>.

=cut

sub all_cover_ok {
  my $threshold = shift || $COVERAGE_THRESHOLD;
  my @dirs = @_ ? @_
                : (File::Spec->splitpath( $0 ))[1] || '.';
  my @all_files = grep { ! /$0$/o && $0 !~ /$_$/ }
                  grep { _is_perl_script($_)     }
                       all_files(@dirs);
  _make_plan();

  my $cover_bin    = cover_path() or do{ $Test->skip(); $Test->diag("Cover binary not found"); return};
  my $perl_bin     = _untaint($PERL);
  local $ENV{PATH} = _untaint($ENV{PATH}) if $ENV{PATH};
  `$cover_bin -delete`;
  if ($?) {
    $Test->skip();
    $Test->diag("Cover binary $cover_bin not found");
    return;
  }
  foreach my $file ( @all_files ) {
    $file = _untaint($file);
    `$perl_bin -MDevel::Cover $file 2>&1 > /dev/null`;
    $Test->ok(! $?, "Coverage captured from $file" );
  }
  $Test->ok(my $cover = `$cover_bin 2>/dev/null`, "Got cover");

  my ($total) = ($cover =~ /^\s*Total.+?([\d\.]+)\s*$/m);
  $Test->ok( $total >= $threshold, "coverage = ${total}% > ${threshold}%");
  return $total;
}


sub _is_perl_module {
  $_[0] =~ /\.pm$/i
  ||
  $_[0] =~ /::/;
}


sub _is_perl_script {
  my $file = shift;
  return 1 if $file =~ /\.pl$/i;
  return 1 if $file =~ /\.t$/;
  open my($fh), $file or return;
  my $first = <$fh>;
  return 1 if defined $first && ($first =~ $PERL_PATTERN);
  return;
}


##
## Return the path of a module
##
sub module_to_path {
  my $file = shift;
  return $file unless ($file =~ /::/);
  my @parts = split /::/, $file;
  my $module = File::Spec->catfile(@parts) . '.pm';
  foreach my $dir (@INC) {
    my $candidate = File::Spec->catfile($dir, $module);
    next unless (-e $candidate && -f _ && -r _);
    return $candidate;
  }
  return $file; # non existing file - error is catched elsewhere
}


sub cover_path {
  return $COVER if $COVER;
  foreach my $path (split /:/, $ENV{PATH}) {
    my $path_cover = File::Spec->catfile($path, 'cover');
    next unless -x $path_cover;
    return $COVER = _untaint($path_cover);
  }
  return;
}


sub _make_plan {
  unless ($Test->has_plan) {
    $Test->plan( no_plan => 1 );
  }
  $Test->expected_tests;
}


sub _untaint {
  my @untainted = map { ($_ =~ $UNTAINT_PATTERN) } @_;
  wantarray ? @untainted
            : $untainted[0];
}


=head1 CAVEATS

For C<all_cover_ok()> to work properly, it is strongly advised to install the most recent version of L<Devel::Cover>
and use perl 5.8.1 or above.
In the case of a C<make test> scenario, C<all_perl_files_ok()> re-run all the tests in a separate perl interpreter,
this may lead to some side effects.

=head1 SEE ALSO

L<Test::More>, L<Test::Pod>. L<Test::Distribution>, L<Test:NoWarnings>

=head1 AUTHOR

Pierre Denis, C<< <pierre@itrelease.net> >>.

=head1 COPYRIGHT

Copyright 2005, Pierre Denis, All Rights Reserved.

You may use, modify, and distribute this package under the
same terms as Perl itself.

=cut

1;
