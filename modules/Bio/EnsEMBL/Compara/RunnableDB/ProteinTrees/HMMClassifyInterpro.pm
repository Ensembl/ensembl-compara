=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassifyInterpro

=head1 DESCRIPTION

This module lookup the interpro classification of peptides
, creating HMMer_classify job for each peptide unclassify
by interpro

=cut
package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassifyInterpro;

use strict;
use warnings;
use Data::Dumper;
use DBI;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassify');



sub run {
    my ($self) = @_;

    $self->get_clusters;

}


######################
# internal methods
######################
sub get_clusters {
    my ($self) = @_;

    my $unknownByPanther   = 0;
    my $knownByPantherPTHR = 0;
    my $knownByPantherSF   = 0;
    my $allMembers         = 0;

    foreach my $member (@{$self->param('unannotated_members')}) {

            my $stable_id = $member->stable_id; 
            my $res       = $self->compara_dba->get_HMMAnnotAdaptor->fetch_by_ensembl_id_SF($stable_id);
            my $res2      = $self->compara_dba->get_HMMAnnotAdaptor->fetch_by_ensembl_id_PTHR($stable_id);
            $allMembers++;

            if (defined $res->[0]) {
               my $fam = $res->[0];  
               $knownByPantherSF++;
               $self->add_hmm_annot($member->member_id, $fam, undef);
            }
            elsif(defined $res2->[0]){
               my $fam = $res2->[0];
               $knownByPantherPTHR++;
               $self->add_hmm_annot($member->member_id, $fam, undef);
            }
            else {
               $unknownByPanther++;
           }
       }

   print STDERR "$allMembers members to be annotated\n" if ($self->debug());
   print STDERR "$knownByPantherSF members annotated in Panther SF\n" if ($self->debug());
   print STDERR "$knownByPantherPTHR members annotated in Panther PTHR\n" if ($self->debug());
   print STDERR "$unknownByPanther members missing in Panther\n" if ($self->debug());
}


1;
