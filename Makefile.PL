use ExtUtils::MakeMaker;
use strict;
WriteMakefile(
    NAME	 => "Test::Strict",
    VERSION_FROM => 'lib/Test/Strict.pm',
    PREREQ_PM    => {
      'Test::Simple'     => 0.47,
      'Test::Builder'    => 0.01,
      'File::Spec'       => 0.01,
      'FindBin'          => 0.01,
      'File::Find::Rule' => 0.01,
      'Test::Tester'     => 0.01,
      'Devel::Cover'     => 0.43,
        },
);
