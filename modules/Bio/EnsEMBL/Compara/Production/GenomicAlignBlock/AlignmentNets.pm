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
#use Bio::EnsEMBL::Utils::Argument qw( rearrange );


our @ISA = qw(Bio::EnsEMBL::Analysis::RunnableDB::AlignmentFilter);

my $WORKDIR; # global variable holding the path to the working directory where output will be written
my $BIN_DIR = "/usr/local/ensembl/bin";

############################################################
sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);

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
    $self->GROUP_TYPE($params->{'output_group_type'});
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
  $gaba->lazy_loading(1);
  $self->get_params($self->analysis->parameters);
  $self->get_params($self->input_id);

  ################################################################
  # get the compara data: MethodLinkSpeciesSet, reference DnaFrag, 
  # and GenomicAlignBlocks
  ################################################################
#  print "mlss_id: ",$self->{'method_link_species_set_id'},"\n";
  my $mlss = $mlssa->fetch_by_dbID($self->{'method_link_species_set_id'});

  throw("No MethodLinkSpeciesSet for method_link_species_set_id".$self->{'method_link_species_set_id'}."\n")
    if not $mlss;

  my $out_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $out_mlss->method_link_type($self->OUTPUT_METHOD_LINK_TYPE);
  $out_mlss->species_set($mlss->species_set);
  $mlssa->store($out_mlss);

  ######## needed for output####################
  $self->output_MethodLinkSpeciesSet($out_mlss);

  my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss,$self->query_dnafrag,$self->{'start'},$self->{'end'});

  ###################################################################
  # get the target slices and bin the GenomicAlignBlocks by group id
  ###################################################################
  my (%features_by_group, %query_lengths, %target_lengths);
  my $number_of_gabs = scalar @{$gabs};
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

#    my $daf_cigar = $self->daf_cigar_from_compara_cigars($qy_ga->cigar_line,
#                                                         $tg_ga->cigar_line);

#    my $daf = Bio::EnsEMBL::DnaDnaAlignFeature->new
#        (-seqname => $qy_ga->dnafrag->name,
#         -start    => $qy_ga->dnafrag_start,
#         -end      => $qy_ga->dnafrag_end,
#         -strand   => $qy_ga->dnafrag_strand,
#         -hseqname => $tg_ga->dnafrag->name,
#         -hstart   => $tg_ga->dnafrag_start,
#         -hend     => $tg_ga->dnafrag_end,
#         -hstrand  => $tg_ga->dnafrag_strand,
#         -score    => $gab->score,
#         -cigar_string => $daf_cigar);

    my $group_id = $qy_ga->genomic_align_group_id_by_type($self->{'input_group_type'});
    if ($group_id != $tg_ga->genomic_align_group_id_by_type($self->{'input_group_type'})) {
      throw("GenomicAligns in a GenomicAlignBlock belong to different group");
    }

#    push @{$features_by_group{$group_id}}, $daf;
#    if ($number_of_gabs > 100000) {
#      $gab->genomic_align_array(0);
#    }
    push @{$features_by_group{$group_id}}, $gab;
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
                    -chains               => [values %features_by_group],
                    -chainNet             =>  $BIN_DIR . "/" . "chainNet",
                    -workdir              => $WORKDIR);
  
  my $run = Bio::EnsEMBL::Analysis::Runnable::AlignmentNets->new(%parameters);
  $self->runnable($run);

}

=head2 run

  Arg [1]   : Bio::EnsEMBL::Analysis::RunnableDB
  Function  : cycles through all the runnables, calls run and pushes
  their output into the RunnableDBs output array
  Returntype: array ref
  Exceptions: none
  Example   : 

=cut

sub run{
  my ($self) = @_;
  foreach my $runnable(@{$self->runnable}){
    $runnable->run;
#    my $converted_output = $self->convert_output($runnable->output);
#    $self->output($converted_output);
    $self->output($runnable->output);
    rmdir($runnable->workdir) if (defined $runnable->workdir);
  }
}

sub query_dnafrag {
  my ($self, $dir) = @_;

  if (defined $dir) {
    $self->{_query_dnafrag} = $dir;
  }

  return $self->{_query_dnafrag};
}

1;
