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
  dist_author        => 'Christopher J. Madsen <perl@cjmweb.net>',
  dist_version_from  => 'lib/Texinfo/Menus.pm',
  requires => {
       perl            => '5.6.0',
  },
  build_requires => {
       FindBin         => 0,
       'Module::Build' => 0,
       'Test::More'    => 0,
  },
  dynamic_config     => 1,      # We have the --no-scripts option
  get_options        => { 'no-scripts' => undef },
  add_to_cleanup     => [ 't/testing' ],
  create_makefile_pl => 'passthrough',
  meta_merge         => { no_index => { file => ['My_Build.pm'] }},
);

my @scripts;

if ($builder->args('no-scripts')) {
  $builder->dispatch('clean');   # The scripts might already be in blib/
} else {
  @scripts = qw(bin/up_menus);
}

$builder->script_files(\@scripts);

$builder->create_build_script;

unless (@scripts) {
  print "The up_menus script will not be installed (installing module only).\n";
} else {
  print "The up_menus script will be installed along with the module.\n";
  print "Run 'perl Build.PL --no-scripts' if you don't want this script installed.\n";
}
