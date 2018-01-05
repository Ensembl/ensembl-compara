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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->output();
$runnable->write_output(); #writes to DB

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

use Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Analysis::Runnable::AlignmentNets;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception qw(throw );

our @ISA = qw(Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing);


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
  my $fake_analysis     = Bio::EnsEMBL::Analysis->new;

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
              || throw("No MethodLinkSpeciesSet for method_link_species_set_id".$self->param('input_mlss_id'));

  #Check if doing self_alignment where the species_set will contain only one
  #entry
  my $self_alignment = 0;
  if (@{$mlss->species_set->genome_dbs} == 1) {
      $self_alignment = 1;
  }
  
  my $out_mlss = $mlssa->fetch_by_dbID($self->param_required('output_mlss_id'))
                  || throw("No MethodLinkSpeciesSet for method_link_species_set_id".$self->param('output_mlss_id'));

  ######## needed for output####################
  $self->param('output_MethodLinkSpeciesSet', $out_mlss);
  
  if ($self->input_job->retry_count > 0) {
    $self->warning("Deleting alignments as it is a rerun");
    $self->delete_alignments($out_mlss,
                             $query_dnafrag,
                             $self->param('start'),
                             $self->param('end'));
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
  my %parameters = (-analysis             => $fake_analysis, 
                    -query_lengths        => \%query_lengths,
                    -target_lengths       => \%target_lengths,
                    -chains               => [ map {$features_by_group{$_}} sort {$group_score{$b} <=> $group_score{$a}} keys %group_score ],
                    -chains_sorted => 1,
                    -chainNet             =>  $self->param('chainNet'),
                    -workdir              => $self->worker_temp_directory,
		    -min_chain_score      => $self->param('min_chain_score'));
  
  my $runnable = Bio::EnsEMBL::Analysis::Runnable::AlignmentNets->new(%parameters);
  #Store runnable in param
  $self->param('runnable', $runnable);
}

sub delete_alignments {
  my ($self, $mlss, $qy_dnafrag, $start, $end) = @_;

  my $dbc = $self->db->dbc;
  my $sql = "select ga1.genomic_align_block_id, ga1.genomic_align_id, ga2.genomic_align_id from genomic_align ga1, genomic_align ga2 where ga1.genomic_align_block_id=ga2.genomic_align_block_id and ga1.dnafrag_id = ? and ga1.dnafrag_id!=ga2.dnafrag_id and ga1.method_link_species_set_id = ?";

  my $sth;
  if (defined $start and defined $end) {
    $sql .= " and ga1.dnafrag_start <= ? and ga1.dnafrag_end >= ?";
    $sth = $dbc->prepare($sql);
    $sth->execute($qy_dnafrag->dbID, $mlss->dbID, $end, $start);
  } elsif (defined $start) {
    $sql .= " and ga1.dnafrag_end >= ?";
    $sth->execute($qy_dnafrag->dbID, $mlss->dbID, $start);
  } elsif (defined $end) {
    $sql .= " and ga1.dnafrag_start <= ? ";
    $sth->execute($qy_dnafrag->dbID, $mlss->dbID, $end);
  } else {
    $sth = $dbc->prepare($sql);
    $sth->execute($qy_dnafrag->dbID, $mlss->dbID);
  }

  my $nb_gabs = 0;
  my @gabs;
  while (my $aref = $sth->fetchrow_arrayref) {
    my ($gab_id, $ga_id1, $ga_id2) = @$aref;
    push @gabs, [$gab_id, $ga_id1, $ga_id2];
    $nb_gabs++;
  }

  my $sql_gab = "delete from genomic_align_block where genomic_align_block_id in ";
  my $sql_ga = "delete from genomic_align where genomic_align_id in ";

  for (my $i=0; $i < scalar @gabs; $i=$i+20000) {
    my (@gab_ids, @ga1_ids, @ga2_ids);
    for (my $j = $i; ($j < scalar @gabs && $j < $i+20000); $j++) {
      push @gab_ids, $gabs[$j][0];
      push @ga1_ids, $gabs[$j][1];
      push @ga2_ids, $gabs[$j][2];
#      print $j," ",$gabs[$j][0]," ",$gabs[$j][1]," ",$gabs[$j][2],"\n";
    }
    my $sql_gab_to_exec = $sql_gab . "(" . join(",", @gab_ids) . ")";
    my $sql_ga_to_exec1 = $sql_ga . "(" . join(",", @ga1_ids) . ")";
    my $sql_ga_to_exec2 = $sql_ga . "(" . join(",", @ga2_ids) . ")";

    foreach my $sql ($sql_ga_to_exec1,$sql_ga_to_exec2,$sql_gab_to_exec) {
      my $sth = $dbc->prepare($sql);
      $sth->execute;
      $sth->finish;
    }
  }
}

sub run {
  my ($self) = @_;

  $self->compara_dba->dbc->disconnect_if_idle();    # this one should disconnect only if there are no active kids
  my $runnable = $self->param('runnable');
  $runnable->run;
  $self->cleanse_output($runnable->output);
  $self->param('chains', $runnable->output);

}


1;
