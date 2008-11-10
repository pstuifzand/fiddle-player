#!/usr/bin/perl
use Module::Build;
Module::Build->new(
    module_name => 'Fiddle',
    license     => 'perl',
)->create_build_script();
