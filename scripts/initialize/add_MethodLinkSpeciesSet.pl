#!/usr/local/bin/perl

use strict;
use Getopt::Long;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my (
    $dbname,
    $dbhost,
    $dbuser,
    $dbport,
    $dbpass,
    $method_link_name,
    @species,
);

&GetOptions(
            'dbname=s' => \$dbname,
            'dbuser=s' => \$dbuser,
            'dbhost=s' => \$dbhost,
            'dbport=s' => \$dbport,
            'dbpass=s' => \$dbpass,
            'method_link=s' => \$method_link_name,
            'species=s@'    => \@species,
);

die "You must supply a method_link type\n"
    if not defined $method_link_name;
die "You must supply at least one species name\n"
    if not @species;

my $db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
	'-dbname' => $dbname,
	'-host' => $dbhost,
	'-user' => $dbuser,
	'-port' => $dbport,
	'-pass' => $dbpass
);

my $gdb_adap = $db->get_GenomeDBAdaptor;
my $mlss_adap = $db->get_MethodLinkSpeciesSetAdaptor; 

my @gdbs;
foreach my $s (@species) {
  my $gdb = $gdb_adap->fetch_by_name_assembly($s);
  if (defined $gdb) {
    push @gdbs, $gdb;
  } else {
    die "Could not find GenomeDB entry for species $s\n";
  }
}

my $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new;
$mlss->method_link_type($method_link_name);
$mlss->species_set(\@gdbs);

$mlss_adap->store($mlss);

