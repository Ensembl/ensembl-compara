=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtIndex

=head1 DESCRIPTION

This RunnableDB uses 'mfetch' to get the list of Uniprot accession numbers and dataflows to actual loading jobs.

The format of the input_id follows the format of a Perl hash reference.
Examples:
  "{'uniprot_source' => 'SWISSPROT', taxon_id=>4932}"      # loads all SwissProt for S.cerevisiae
  "{'uniprot_source' => 'SPTREMBL'}"                       # loads all SPTrEMBL Fungi/Metazoa
  "{'uniprot_source' => 'SPTREMBL', taxon_id=>4932}"       # loads all SPTrEMBL for S.cerevisiae
  "{'uniprot_source' => 'SWISSPROT', 'tax_div' => 'FUN'}"  # loads all SwissProt fungi proteins
  "{'uniprot_source' => 'SPTREMBL',  'tax_div' => 'ROD'}"  # loads all SwissProt rodent proteins

supported keys:
  uniprot_source    =>  'SWISSPROT' or 'SPTREMBL'
  taxon_id          => <taxon_id>
                            optional if one wants to load from a specific species
                            if not specified it will load all Fungi/Metazoa from the uniprot_source 
  tax_div           => <tax_div>
                            optional taxonomic division

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtIndex;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'uniprot_version'   => 'uniprot',   # but you can ask for a specific version of uniprot that mfetch would recognize
        'taxon_id'          => undef,       # no ncbi_taxid filter means get all Fungi/Metazoa
        'buffer_size'       => 16,          # how many uniprot_ids are fetched per one execution of mfetch
        'tax_div'           => undef,       # metazoa can be split into 6 parts and loaded in parallel
    };
}

sub fetch_input {
    my $self = shift @_;


    my $uniprot_version = $self->param('uniprot_version');
    my $uniprot_source  = $self->param('uniprot_source') or die "'uniprot_source' has to be either 'SWISSPROT' or 'SPTREMBL'";

    $self->compara_dba()->dbc->disconnect_when_inactive(1);

    if(my $taxon_id = $self->param('taxon_id')) {
        $self->param('uniprot_ids', $self->mfetch_uniprot_ids($uniprot_version, $uniprot_source, $taxon_id) );
    } else {
        my $tax_div = $self->param('tax_div');
        $self->param('uniprot_ids', $self->mfetch_uniprot_ids($uniprot_version, $uniprot_source, '' , $tax_div && [ $tax_div ]) );
    }

    $self->compara_dba()->dbc->disconnect_when_inactive(0);
}


sub write_output {
    my $self = shift @_;

    my $buffer_size     = $self->param('buffer_size');
    my $uniprot_source  = $self->param('uniprot_source');
    my $uniprot_ids     = $self->param('uniprot_ids');

    while (@$uniprot_ids) {
        my @id_buffer = splice(@$uniprot_ids, 0, $buffer_size);
        $self->dataflow_output_id( { 'uniprot_source' => $uniprot_source, 'ids' => [@id_buffer] }, 2);
    }
}


######################################
#
# subroutines
#
#####################################

sub mfetch_uniprot_ids {
    my $self            = shift;
    my $uniprot_version = shift;  # 'uniprot' or a specific version of it
    my $uniprot_source  = shift;  # 'SWISSPROT' or 'SPTREMBL'
    my $taxon_id        = shift;  # assume Fungi/Metazoa if not set
    my $tax_divs        = shift || [ $taxon_id ? 0 : qw(FUN HUM MAM ROD VRT INV) ];

    my @filters = ( 'div:'.((uc($uniprot_source) eq 'SPTREMBL') ? 'PRE' : 'STD') );
    if($taxon_id) {
        push @filters, "txi:$taxon_id";
    } else {
        push @filters, "txt:33154"; # anything that belongs to Fungi/Metazoa subtree (clade)
    }

    my @all_ids = ();
    foreach my $txd (@$tax_divs) {
        my $cmd = "mfetch -d $uniprot_version -v av -i '".join('&', @filters).($txd ? "&txd:$txd" : '')."'";
        print("$cmd\n") if($self->debug);
        if( my $output_text = `$cmd` ) {
            my @ids = split(/\s/, $output_text);
            push @all_ids, @ids;
        } else {
            die "[$cmd] returned nothing, mole server probably down";
        }
    }
    printf("fetched %d ids from %s\n", scalar(@all_ids), $uniprot_source) if($self->debug);
    return \@all_ids;
}

1;

