=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets

=head1 DESCRIPTION

Given an compara MethodLinkSpeciesSet identifer, and a reference genomic
slice identifer, fetches the GenomicAlignBlocks from the given compara
database, infers chains from the group identifiers, and then forms
an alignment net from the chains and writes the result
back to the database. 

This module (at least for now) relies heavily on Jim Kent\'s Axt tools.


=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::Production::Analysis::AlignmentNets');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   
    Returns :   nothing
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_; 

  $self->SUPER::fetch_input;

  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $dafa = $self->compara_dba->get_DnaAlignFeatureAdaptor;
  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  
  my $query_dnafrag;
  if(defined($self->param('DnaFragID'))) {
      $query_dnafrag = $self->compara_dba->get_DnaFragAdaptor->fetch_by_dbID($self->param('DnaFragID'));
  }

  ################################################################
  # get the compara data: MethodLinkSpeciesSet, reference DnaFrag, 
  # and GenomicAlignBlocks
  ################################################################
  my $mlss = $mlssa->fetch_by_dbID($self->param_required('input_mlss_id'))
              || $self->throw("No MethodLinkSpeciesSet for method_link_species_set_id".$self->param('input_mlss_id'));

  #Check if doing self_alignment where the species_set will contain only one
  #entry
  my $self_alignment = 0;
  if (@{$mlss->species_set->genome_dbs} == 1) {
      $self_alignment = 1;
  }
  
  my $out_mlss = $mlssa->fetch_by_dbID($self->param_required('output_mlss_id'))
                  || $self->throw("No MethodLinkSpeciesSet for method_link_species_set_id".$self->param('output_mlss_id'));

  ######## needed for output####################
  $self->param('output_MethodLinkSpeciesSet', $out_mlss);
  
  if ($self->input_job->retry_count > 0) {
    $self->warning("Deleting alignments as it is a rerun");
    $self->delete_alignments($out_mlss);
  }

  my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss,
							      $query_dnafrag,
							      $self->param('start'),
							      $self->param('end'));
  
  ###################################################################
  # get the target slices and bin the GenomicAlignBlocks by group id
  ###################################################################
  my (%features_by_group, %query_lengths, %target_lengths);
  my %group_score;

  while (my $gab = shift @{$gabs}) {
    
    my ($qy_ga) = $gab->reference_genomic_align;
    my ($tg_ga) = @{$gab->get_all_non_reference_genomic_aligns};
    
    if (not exists($self->param('query_DnaFrag_hash')->{$qy_ga->dnafrag->name})) {
      ######### needed for output ######################################
      $self->param('query_DnaFrag_hash')->{$qy_ga->dnafrag->name} = $qy_ga->dnafrag;
    }
    if (not exists($self->param('target_DnaFrag_hash')->{$tg_ga->dnafrag->name})) {
      ######### needed for output #######################################
      $self->param('target_DnaFrag_hash')->{$tg_ga->dnafrag->name} = $tg_ga->dnafrag;
    }

    #for self alignments, need to group on the query genomic_align_id not the
    #group_id 
    my $group_id;
    if ($self_alignment) {
	$group_id = $qy_ga->dbID();
    } else {
	$group_id = $gab->group_id();
    }
    #print "gab " . $gab->dbID . " group_id $group_id\n";

    push @{$features_by_group{$group_id}}, $gab;

    if (! defined $group_score{$group_id} || $gab->score > $group_score{$group_id}) {
      $group_score{$group_id} = $gab->score;
    }
  }

  foreach my $group_id (keys %features_by_group) {
    $features_by_group{$group_id} = [ sort {$a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start} @{$features_by_group{$group_id}} ];
  }

  foreach my $nm (keys %{$self->param('query_DnaFrag_hash')}) {
    $query_lengths{$nm} = $self->param('query_DnaFrag_hash')->{$nm}->length;
  }
  foreach my $nm (keys %{$self->param('target_DnaFrag_hash')}) {
    $target_lengths{$nm} = $self->param('target_DnaFrag_hash')->{$nm}->length;
  }
  
  $self->param('query_length_hash',     \%query_lengths);
  $self->param('target_length_hash',    \%target_lengths);
  $self->param('chains',                [ map {$features_by_group{$_}} sort {$group_score{$b} <=> $group_score{$a}} keys %group_score ]);
  $self->param('chains_sorted',         1);
}

sub run {
  my ($self) = @_;

  $self->compara_dba->dbc->disconnect_if_idle();    # this one should disconnect only if there are no active kids
  my $chains = $self->run_nets;
  $self->cleanse_output($chains);
  $self->param('chains', $chains);

}


1;
