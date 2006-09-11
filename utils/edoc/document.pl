#! /usr/bin/perl 

use strict;
use warnings;

use EnsEMBL::Web::Tools::Document;

my $export = shift @ARGV;
my $base = shift @ARGV;
my $support = shift @ARGV;
my @locations = @ARGV;

if (-e $export) {
print "Exporting to $export\n";
print "Searching for documentation\n";
my $document = EnsEMBL::Web::Tools::Document->new( (
                 directory => \@locations,
                 identifier => "###"
               ) );

$document->find_modules;
$document->generate_html($export, $base, $support);
print "Done\n";
}
