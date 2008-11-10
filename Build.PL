#!/usr/bin/perl
use Module::Build;
Module::Build->new(
    module_name => 'Fiddle',
    license     => 'perl',
    dist_author => 'Peter Stuifzand <peter@stuifzand.eu>',
    build_requires => {
        'Test::Deep' => 0,
    },
    recursive_test_files => 1,
)->create_build_script();
