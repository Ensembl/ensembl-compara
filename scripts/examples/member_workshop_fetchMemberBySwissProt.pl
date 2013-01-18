#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the compara member adaptor
my $seq_member_adaptor = $reg->get_adaptor("Multi", "compara", "SeqMember");

## Get the member for SwissProt entry O93279
my $seq_member = $seq_member_adaptor->fetch_by_source_stable_id( "Uniprot/SWISSPROT", "O93279");
print ">", $seq_member->stable_id, "\n";
print $seq_member->sequence, "\n";
