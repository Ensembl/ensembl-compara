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
use Bio::EnsEMBL::Analysis::RunnableDB::AlignmentFilter;
use Bio::EnsEMBL::Analysis::Runnable::AlignmentNets;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Utils::Exception;

our @ISA = qw(Bio::EnsEMBL::Hive::Process Bio::EnsEMBL::Analysis::RunnableDB::AlignmentFilter);

my $WORKDIR; # global variable holding the path to the working directory where output will be written
my $BIN_DIR = "/usr/local/ensembl/bin";

############################################################
sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);

  $self->query_DnaFrag_hash({});
  $self->target_DnaFrag_hash({});

  return $self;
}

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  #print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  # from input_id
  if(defined($params->{'DnaFragID'})) {
    my $dnafrag = $self->{'comparaDBA'}->get_DnaFragAdaptor->fetch_by_dbID($params->{'DnaFragID'});
    $self->query_dnafrag($dnafrag);
  }
  $self->{'start'} = $params->{'start'} if(defined($params->{'start'}));
  $self->{'end'} = $params->{'end'} if(defined($params->{'end'}));
  $self->{'method_link_species_set_id'} = $params->{'method_link_species_set_id'} if(defined($params->{'method_link_species_set_id'}));

  # from parameters
  if(defined($params->{'input_method_link'})) {
    $self->INPUT_METHOD_LINK_TYPE($params->{'input_method_link'});
  }
  if(defined($params->{'output_method_link'})) {
    $self->OUTPUT_METHOD_LINK_TYPE($params->{'output_method_link'});
  }
  if (defined($params->{'max_gap'})) {
    $self->MAX_GAP($params->{'max_gap'});
  }
  if (defined($params->{'output_group_type'})) {
    $self->OUTPUT_GROUP_TYPE($params->{'output_group_type'});
  }
  if (defined($params->{'input_group_type'})) {
    $self->INPUT_GROUP_TYPE($params->{'input_group_type'});
  }
  $self->{'input_group_type'} = $params->{'input_group_type'} if(defined($params->{'input_group_type'}));

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

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  my $mlssa = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $dafa = $self->{'comparaDBA'}->get_DnaAlignFeatureAdaptor;
  my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;

  $self->get_params($self->analysis->parameters);
  $self->get_params($self->input_id);

  ################################################################
  # get the compara data: MethodLinkSpeciesSet, reference DnaFrag, 
  # and GenomicAlignBlocks
  ################################################################

  my $mlss = $mlssa->fetch_by_dbID($self->{'method_link_species_set_id'});

  throw("No MethodLinkSpeciesSet for method_link_species_set_id".$self->{'method_link_species_set_id'}."\n")
    if not $mlss;

  my $out_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $out_mlss->method_link_type($self->OUTPUT_METHOD_LINK_TYPE);
  $out_mlss->species_set($mlss->species_set);
  $mlssa->store($out_mlss);

  ######## needed for output####################
  $self->output_MethodLinkSpeciesSet($out_mlss);

  if ($self->input_job->retry_count > 0) {
    print STDERR "Deleting alignments as it is a rerun\n";
    $self->delete_alignments($out_mlss,$self->query_dnafrag,$self->{'start'},$self->{'end'});
  }

  my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_GroupType($mlss,$self->query_dnafrag,$self->{'start'},$self->{'end'}, $self->{'input_group_type'});

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

    my $group_id = $qy_ga->genomic_align_group_id_by_type($self->{'input_group_type'});
    if ($group_id != $tg_ga->genomic_align_group_id_by_type($self->{'input_group_type'})) {
      throw("GenomicAligns in a GenomicAlignBlock belong to different group");
    }

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
                    -chainNet             =>  $BIN_DIR . "/" . "chainNet",
                    -workdir              => $WORKDIR);
  
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

sub convert_output {
  my ($self, $chains) = @_;
  
  foreach my $chain (@{$chains}) {
    foreach my $gab (@{$chain}) {
      $gab->{'adaptor'} = undef;
      $gab->{'dbID'} = undef;
      $gab->{'method_link_species_set_id'} = undef;
      $gab->method_link_species_set($self->output_MethodLinkSpeciesSet);
      foreach my $ga (@{$gab->get_all_GenomicAligns}) {
        $ga->genomic_align_group_by_type("chain");
        $ga->{'adaptor'} = undef;
        $ga->{'dbID'} = undef;
        $ga->{'method_link_species_set_id'} = undef;
        $ga->method_link_species_set($self->output_MethodLinkSpeciesSet);
      }
    }
  }

  return $chains;
}

sub delete_alignments {
  my ($self, $mlss, $qy_dnafrag, $start, $end) = @_;

  my $dbc = $self->db->dbc;
  my $sql = "select ga1.genomic_align_block_id, ga1.genomic_align_id, ga2.genomic_align_id from genomic_align ga1, genomic_align ga2 where ga1.genomic_align_block_id=ga2.genomic_align_block_id and ga1.dnafrag_id = ? and ga1.dnafrag_start <= ? and ga1.dnafrag_end >= ? and ga1.method_link_species_set_id = ?";
  my $sth = $dbc->prepare($sql);
  $sth->execute($qy_dnafrag->dbID, $end, $start, $mlss->dbID);

  my $nb_gabs = 0;
  my @gabs;
  while (my $aref = $sth->fetchrow_arrayref) {
    my ($gab_id, $ga_id1, $ga_id2) = @$aref;
    push @gabs, [$gab_id, $ga_id1, $ga_id2];
    $nb_gabs++;
  }

  my $sql_gab = "delete from genomic_align_block where genomic_align_block_id in ";
  my $sql_ga = "delete from genomic_align where genomic_align_id in ";
  my $sql_gag = "delete from genomic_align_group where genomic_align_id in ";

  for (my $i=0; $i < scalar @gabs; $i=$i+20000) {
    my (@gab_ids, @ga1_ids, @ga2_ids);
    for (my $j = $i; ($j < scalar @gabs && $j < $i+20000); $j++) {
      push @gab_ids, $gabs[$j][0];
      push @ga1_ids, $gabs[$j][1];
      push @ga2_ids, $gabs[$j][2];
      print $j," ",$gabs[$j][0]," ",$gabs[$j][1]," ",$gabs[$j][2],"\n";
    }
    my $sql_gab_to_exec = $sql_gab . "(" . join(",", @gab_ids) . ")";
    my $sql_ga_to_exec1 = $sql_ga . "(" . join(",", @ga1_ids) . ")";
    my $sql_ga_to_exec2 = $sql_ga . "(" . join(",", @ga2_ids) . ")";
    my $sql_gag_to_exec1 = $sql_gag . "(" . join(",", @ga1_ids) . ")";
    my $sql_gag_to_exec2 = $sql_gag . "(" . join(",", @ga2_ids) . ")";

    foreach my $sql ($sql_gab_to_exec,$sql_ga_to_exec1,$sql_ga_to_exec2,$sql_gag_to_exec1,$sql_gag_to_exec2) {
      my $sth = $dbc->prepare($sql);
      $sth->execute;
      $sth->finish;
    }
  }
}

sub run {
#  my $self = shift;
#  bless $self, "Bio::EnsEMBL::Analysis::RunnableDB::AlignmentFilter";
#  $self->run;
  my ($self) = @_;
  foreach my $runnable(@{$self->runnable}){
    $runnable->run;
    my $converted_output = $self->convert_output($runnable->output);
    $self->output($converted_output);
#    rmdir($runnable->workdir) if (defined $runnable->workdir);
  }
}

sub write_output {
  my $self = shift;

  my $disconnect_when_inactive_default = $self->{'comparaDBA'}->disconnect_when_inactive;
  $self->{'comparaDBA'}->disconnect_when_inactive(0);

  bless $self, "Bio::EnsEMBL::Analysis::RunnableDB::AlignmentFilter";
  $self->write_output;
  bless $self, "Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentChains";

  $self->{'comparaDBA'}->disconnect_when_inactive($disconnect_when_inactive_default);
}

1;
