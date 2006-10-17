#! /usr/bin/perl
#---------------------------------------------------------------------
# $Id$
# Copyright 2006 Christopher J. Madsen
#
# Build.PL for Texinfo-Menus
#---------------------------------------------------------------------

use strict;

use FindBin;
use lib $FindBin::Bin; # Make sure we're using My_Build from our distribution

use My_Build;          # Our customized version of Module::Build

my $builder = My_Build->new(
  module_name        => 'Texinfo::Menus',
  license            => 'perl',
  dist_author        => 'Christopher J. Madsen <cjm@pobox.com>',
  dist_version_from  => 'lib/Texinfo/Menus.pm',
  requires => {
       perl         => '5.6.0',
       'Test::More' => 0,
  },
  script_files       => [ 'bin/up_menus' ],
  create_makefile_pl => 'passthrough',
);

$builder->create_build_script();
