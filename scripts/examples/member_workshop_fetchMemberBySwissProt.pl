use strict;
use warnings;

use Bio::EnsEMBL::Registry;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the compara member adaptor
my $member_adaptor =
    $reg->get_adaptor("Multi", "compara", "Member");

## Get the member for SwissProt entry O93279
my $member = $member_adaptor->fetch_by_source_stable_id(
    "Uniprot/SWISSPROT", "O93279");
print ">", $member->stable_id, "\n";
print $member->sequence, "\n";
