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

Bio::EnsEMBL::Compara::RunnableDB::Families::LoadLRGs

=head1 SYNOPSIS

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::Families::LoadLRGs -compara_db "mysql://ensadmin:${ENSADMIN_PSW}@compara2/lg4_test_loadmembers" -genome_db_id 150

=head1 DESCRIPTION

This RunnableDB loads all the LRG genes of a given genome (identified by a genome_db_id).

The module relies on the super-class to provide fetch_input() (to load dnafrags) and other
methods to store the GeneMember and SeqMembers.

=head1 CONTACT

Contact anybody in Compara.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::LoadLRGs;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::LoadMembers');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults()},

        'production_db_url'             => 'DUMMY',     # Dummy value to make fetch_input not crash on its absence. It is never used anyway because _load_biotype_groups is overriden

        'store_exon_coordinates'        => 0,
    };
}


sub run {
    my $self = shift @_;

    my $compara_dba = $self->compara_dba();
    my $core_dba    = $self->param('core_dba');
    
    my $n_genes_loaded = 0;
    $self->param('transcriptCount', 0); # To please the super-class

    # It may take some time to load the genes, so let's free the connection
    $compara_dba->dbc->disconnect_if_idle();

    $core_dba->dbc->prevent_disconnect( sub {

        my $all_lrgs = $core_dba->get_GeneAdaptor->fetch_all_by_biotype('LRG_gene');
        # preload all the transcripts etc
        $_->load() for @$all_lrgs;

        foreach my $lrg_gene (@$all_lrgs) {
            $lrg_gene->load();

            my $dnafrag = $self->param('all_dnafrags_by_name')->{$lrg_gene->seq_region_name}
                            or die "Could not find a DnaFrag named '".$lrg_gene->seq_region_name."'";

            my $gene_member = $self->store_protein_coding_gene_and_all_transcripts($lrg_gene, $dnafrag);

            if ($gene_member) {
                $n_genes_loaded ++;
            } else {
                $self->warning($lrg_gene->stable_id." could not be stored");
            }
        }
    } );

    print("loaded $n_genes_loaded genes\n");
}

sub _load_biotype_groups {
    my $self = shift;
    $self->param('biotype_groups', {'lrg_gene' => 'LRG'});
}


1;
