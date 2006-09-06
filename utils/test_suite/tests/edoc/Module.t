#! /usr/bin/perl -w

use Test::More qw( no_plan );
use warnings;
use strict;

use vars qw($name $base $location $module);

BEGIN {
  use_ok( 'EnsEMBL::Web::Tools::Document::Module' );
}

$name = "EnsEMBL::Web::Blast::Result";
my $location = `pwd`;
chomp $location;
$base = "$location/files/edoc/modules/EnsEMBL/Web/Blast/";
$location = $base . "Result.pm";
$module = EnsEMBL::Web::Tools::Document::Module->new( (
            name => $name,
            location => $location,
            find_methods => "yes"
          ) );

isa_ok( $module, "EnsEMBL::Web::Tools::Document::Module" );
ok( $module->name eq $name , "name ok");
ok( $module->location eq $location, "location ok");

my @methods_check = @{ $module->methods };
ok ( $#methods_check == 16, "adding methods ok" ); 

my $alignment = EnsEMBL::Web::Tools::Document::Module->new( (
                  name => "EnsEMBL::Web::Blast::Result::Alignment",
                  location => $base . "Result/Alignment.pm"
                ) );

my $hsp = EnsEMBL::Web::Tools::Document::Module->new( (
                  name => "EnsEMBL::Web::Blast::Result::HSP",
                  location => $base . "Result/HSP.pm"
                ) );

$module->add_subclass($alignment);
$module->add_subclass($hsp);

my @subclasses = @{ $module->subclasses };

foreach my $subclass (@subclasses) {
#  warn $subclass;
}

#warn "CHECK: " . $#methods_check;
foreach my $method (@methods_check) {
  #warn "METHOD: " . $method->name;
}
