use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::AlignIO;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');


## Get the compara family adaptor
my $family_adaptor = $reg->get_adaptor("Multi", "compara", "Family");

## Get all the families
my $this_family = $family_adaptor->fetch_by_stable_id('PTHR10740_SF4');

## Description of the family
print $this_family->description(), " (description score = ", $this_family->description_score(), ")\n";

## BioPerl alignment
my $simple_align = $this_family->get_SimpleAlign(-append_taxon_id => 1);
my $alignIO = Bio::AlignIO->newFh(-format => "clustalw");
print $alignIO $simple_align;

