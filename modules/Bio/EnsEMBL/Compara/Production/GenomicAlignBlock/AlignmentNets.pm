# Cared for by Ensembl
#
# Copyright GRL & EBI
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlign::AlignmentNets

=head1 SYNOPSIS

  my $db      = Bio::EnsEMBL::DBAdaptor->new($locator);
  my $genscan = Bio::EnsEMBL::Compara::Production::GenomicAlign::AlignmentNets->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
  $genscan->fetch_input();
  $genscan->run();
  $genscan->write_output(); #writes to DB


=head1 DESCRIPTION

Given an compara MethodLinkSpeciesSet identifer, and a reference genomic
slice identifer, fetches the GenomicAlignBlocks from the given compara
database, infers chains from the group identifiers, and then forms
an alignment net from the chains and writes the result
back to the database. 

This module (at least for now) relies heavily on Jim Kent\'s Axt tools.


=cut
package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentNets;

use strict;

use Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentProcessing;
use Bio::EnsEMBL::Analysis::Runnable::AlignmentNets;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

our @ISA = qw(Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentProcessing);

my $WORKDIR; # global variable holding the path to the working directory where output will be written
my $BIN_DIR = "/usr/local/ensembl/bin";


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  #print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  $self->SUPER::get_params($param_string);

  # from input_id
  if(defined($params->{'DnaFragID'})) {
    my $dnafrag = $self->compara_dba->get_DnaFragAdaptor->fetch_by_dbID($params->{'DnaFragID'});
    $self->query_dnafrag($dnafrag);
  }
  if (defined $params->{'start'}) {
    $self->REGION_START($params->{'start'});
  }
  if (defined $params->{'end'}) {
    $self->REGION_END($params->{'end'});
  }
  if (defined $params->{'method_link_species_set_id'}) {
    $self->METHOD_LINK_SPECIES_SET_ID($params->{'method_link_species_set_id'});
  }
	if (defined($params->{'bin_dir'})) {
		$self->BIN_DIR($params->{'bin_dir'});
	}

  return 1;
}


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

  $self->compara_dba->dbc->disconnect_when_inactive(0);
  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $dafa = $self->compara_dba->get_DnaAlignFeatureAdaptor;
  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  
  $self->get_params($self->analysis->parameters);
  $self->get_params($self->input_id);

  ################################################################
  # get the compara data: MethodLinkSpeciesSet, reference DnaFrag, 
  # and GenomicAlignBlocks
  ################################################################

  my $mlss = $mlssa->fetch_by_dbID($self->METHOD_LINK_SPECIES_SET_ID);
  
  throw("No MethodLinkSpeciesSet for method_link_species_set_id".$self->METHOD_LINK_SPECIES_SET_ID)
      if not $mlss;
  
  my $out_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $out_mlss->method_link_type($self->OUTPUT_METHOD_LINK_TYPE);
  $out_mlss->species_set($mlss->species_set);
  $mlssa->store($out_mlss);
  
  ######## needed for output####################
  $self->output_MethodLinkSpeciesSet($out_mlss);
  
  if ($self->input_job->retry_count > 0) {
    print STDERR "Deleting alignments as it is a rerun\n";
    $self->delete_alignments($out_mlss,
                             $self->query_dnafrag,
                             $self->REGION_START,
                             $self->REGION_END);
  }
  
  my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss,
							      $self->query_dnafrag,
							      $self->REGION_START,
							      $self->REGION_END);
  
  ###################################################################
  # get the target slices and bin the GenomicAlignBlocks by group id
  ###################################################################
  my (%features_by_group, %query_lengths, %target_lengths);
  my %group_score;

  while (my $gab = shift @{$gabs}) {
    
    my ($qy_ga) = $gab->reference_genomic_align;
    my ($tg_ga) = @{$gab->get_all_non_reference_genomic_aligns};
    
    if (not exists($self->query_DnaFrag_hash->{$qy_ga->dnafrag->name})) {
      ######### needed for output ######################################
      $self->query_DnaFrag_hash->{$qy_ga->dnafrag->name} = $qy_ga->dnafrag;
    }
    if (not exists($self->target_DnaFrag_hash->{$tg_ga->dnafrag->name})) {
      ######### needed for output #######################################
      $self->target_DnaFrag_hash->{$tg_ga->dnafrag->name} = $tg_ga->dnafrag;
    }

    my $group_id = $gab->group_id();

    push @{$features_by_group{$group_id}}, $gab;
    if (! defined $group_score{$group_id} || $gab->score > $group_score{$group_id}) {
      $group_score{$group_id} = $gab->score;
    }
  }

  foreach my $group_id (keys %features_by_group) {
    $features_by_group{$group_id} = [ sort {$a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start} @{$features_by_group{$group_id}} ];
  }

  $WORKDIR = "/tmp/worker.$$";
  unless(defined($WORKDIR) and (-e $WORKDIR)) {
    #create temp directory to hold fasta databases
    mkdir($WORKDIR, 0777);
  }

  foreach my $nm (keys %{$self->query_DnaFrag_hash}) {
    $query_lengths{$nm} = $self->query_DnaFrag_hash->{$nm}->length;
  }
  foreach my $nm (keys %{$self->target_DnaFrag_hash}) {
    $target_lengths{$nm} = $self->target_DnaFrag_hash->{$nm}->length;
  }

  my %parameters = (-analysis             => $self->analysis, 
                    -query_lengths        => \%query_lengths,
                    -target_lengths       => \%target_lengths,
                    -chains               => [ map {$features_by_group{$_}} sort {$group_score{$b} <=> $group_score{$a}} keys %group_score ],
                    -chains_sorted => 1,
                    -chainNet             =>  $self->BIN_DIR . "/" . "chainNet",
                    -workdir              => $WORKDIR,
		    -min_chain_score      => $self->MIN_CHAIN_SCORE);
  
  my $run = Bio::EnsEMBL::Analysis::Runnable::AlignmentNets->new(%parameters);
  $self->runnable($run);

}

sub query_dnafrag {
  my ($self, $dir) = @_;

  if (defined $dir) {
    $self->{_query_dnafrag} = $dir;
  }

  return $self->{_query_dnafrag};
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

    foreach my $sql ($sql_gab_to_exec,$sql_ga_to_exec1,$sql_ga_to_exec2) {
      my $sth = $dbc->prepare($sql);
      $sth->execute;
      $sth->finish;
    }
  }
}

sub run {
  my ($self) = @_;
  foreach my $runnable(@{$self->runnable}){
    $runnable->run;
    $self->cleanse_output($runnable->output);
    $self->output($runnable->output);
  }
}

sub write_output {
  my $self = shift;

  my $disconnect_when_inactive_default = $self->compara_dba->dbc->disconnect_when_inactive;
  $self->compara_dba->dbc->disconnect_when_inactive(0);
  $self->SUPER::write_output;
  $self->compara_dba->dbc->disconnect_when_inactive($disconnect_when_inactive_default);
}

###########################
## parameter place-holders

sub REGION_START {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_region_start} = $val;
  }

  if (exists $self->{_region_start}) {
    return $self->{_region_start};
  } else {
    return undef;
  }
}


sub REGION_END {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_region_end} = $val;
  }

  if (exists $self->{_region_end}) {
    return $self->{_region_end};
  } else {
    return undef;
  }
}

sub METHOD_LINK_SPECIES_SET_ID {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_method_link_species_set_id} = $val;
  }

  return $self->{_method_link_species_set_id}
}

sub BIN_DIR {
	my ($self, $val) = @_;
	$self->{_bin_dir} = $val if defined $val;
	return $self->{_bin_dir} || $BIN_DIR;
}

1;
