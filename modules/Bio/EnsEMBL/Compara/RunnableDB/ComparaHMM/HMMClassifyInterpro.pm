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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyInterpro

=head1 DESCRIPTION

This module lookup the interpro classification of peptides
, creating HMMer_classify job for each peptide unclassify
by interpro

=cut
package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyInterpro;

use strict;
use warnings;
use Data::Dumper;
use DBI;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::PantherAnnotAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub param_defaults {
    return {
            'sort_clusters'       => 1,
            'immediate_dataflow'  => 0,
            'member_type'         => 'protein',
            'input_id_prefix'     => 'protein',
           };
}

sub fetch_input {
    my ($self) = @_;

    my $registry_dbs = $self->param('registry_dbs');
    $self->throw('registry_dbs is an obligatory parameter') unless (defined $self->param('registry_dbs'));

return;
}

sub run {
    my ($self) = @_;

    $self->get_clusters;

return;
}

sub write_output {
    my ($self) = @_;
    
    $self->store_clusterset('default', $self->param('allclusters'));
return;
}

######################
# internal methods
######################
sub get_clusters {
    my ($self) = @_;

    my %allclusters 	 = ();
    $self->param('allclusters',\%allclusters);

    my $unknownByPanther   = 0;
    my $knownByPantherPTHR = 0;
    my $knownByPantherSF   = 0;
    my $allMembers         = 0;

    my $mlss_id          = $self->param('mlss_id');
    $self->throw('mlss_id is an obligatory parameter') unless (defined $self->param('mlss_id'));
    my $SeqMemberAdaptor = $self->compara_dba->get_SeqMemberAdaptor;
    my $mlssAdaptor      = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss             = $mlssAdaptor->fetch_by_dbID($mlss_id);
    my $genomeDBs        = $mlss->species_set_obj->genome_dbs();

    my $genomeDB_id;
    my $job_count        = 0;
    
    for my $genomeDB (@$genomeDBs) {
        $genomeDB_id      = $genomeDB->dbID;
	my $members       = $SeqMemberAdaptor->fetch_all_canonical_by_source_genome_db_id('ENSEMBLPEP',$genomeDB_id);

        for my $mem (@$members) {
            my $member_id = $mem->member_id;  
 	    my $member    = $SeqMemberAdaptor->fetch_by_dbID($member_id);
            my $stable_id = $member->stable_id; 
	    my $res       = $self->compara_dba->get_PantherAnnotAdaptor->fetch_by_ensembl_id_SF($stable_id);
	    my $res2      = $self->compara_dba->get_PantherAnnotAdaptor->fetch_by_ensembl_id_PTHR($stable_id);
            $allMembers++;           	

	    if (defined $res->[0]) {
               my $fam = $res->[0];  
               $knownByPantherSF++;
	       push @{$allclusters{$fam}{members}}, $member->member_id;
	    } 
            elsif(defined $res2->[0]){
               my $fam = $res2->[0];
               $knownByPantherPTHR++;
               push @{$allclusters{$fam}{members}}, $member->member_id;
            }
            else {
               my $cluster_dir_count;
               $job_count++;

    	       if ($job_count < 1000){
       	         $cluster_dir_count = '/cluster_0';
    	       }
    	       else {
       	         my $remainder       = $job_count % 1000;
       	         my $quotient        = ($job_count - $remainder)/1000;
       	         $cluster_dir_count  = '/cluster_'.$quotient;
     	       }
               $self->dataflow_output_id( { 'non_annot_member' => $member_id,'genomeDB_id'=> $genomeDB_id,'cluster_dir_count'=>$cluster_dir_count }, 2);
               $unknownByPanther++;
           }
	}
   }
   my $singleton_clusters=0;

   for my $model_name (keys %allclusters) {
      $allclusters{$model_name}{model_name} = $model_name;
      ## singleton clusters is filtered out in StoreClusters.pm
      if (scalar @{$allclusters{$model_name}{members}} == 1) {
      $singleton_clusters++;
      }
   }
   print STDERR $self->param('allclusters')."\n" if ($self->debug());
   print STDERR "$allMembers members to be annotated\n" if ($self->debug());
   print STDERR "$knownByPantherSF members annotated in Panther SF\n" if ($self->debug());
   print STDERR "$knownByPantherPTHR members annotated in Panther PTHR\n" if ($self->debug());
   print STDERR "$unknownByPanther members missing in Panther\n" if ($self->debug());
   print STDERR "$singleton_clusters members in singleton cluster\n" if ($self->debug());
}


1;
