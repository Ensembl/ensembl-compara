# Cared for by Ensembl
#
# Copyright GRL & EBI
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentChains

=head1 SYNOPSIS

  my $db      = Bio::EnsEMBL::DBAdaptor->new($locator);
  my $genscan = Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentChains->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
  $genscan->fetch_input();
  $genscan->run();
  $genscan->write_output(); #writes to DB


=head1 DESCRIPTION

Given an compara MethodLinkSpeciesSet identifer, and a reference genomic
slice identifer, fetches the GenomicAlignBlocks from the given compara
database, forms them into sets of alignment chains, and writes the result
back to the database. 

This module (at least for now) relies heavily on Jim Kent\'s Axt tools.


=cut
package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentChains;

use strict;
use Bio::EnsEMBL::Analysis::RunnableDB::AlignmentFilter;
use Bio::EnsEMBL::Analysis::Runnable::AlignmentChains;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Utils::Exception;
#use Bio::EnsEMBL::Utils::Argument qw( rearrange );

our @ISA = qw(Bio::EnsEMBL::Analysis::RunnableDB::AlignmentFilter);

my $DEFAULT_DUMP_MIN_SIZE = 11500000;
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
  if(defined($params->{'qyDnaFragID'})) {
    my $dnafrag = $self->{'comparaDBA'}->get_DnaFragAdaptor->fetch_by_dbID($params->{'qyDnaFragID'});
    $self->query_dnafrag($dnafrag);
  }
  if(defined($params->{'tgDnaFragID'})) {
    my $dnafrag = $self->{'comparaDBA'}->get_DnaFragAdaptor->fetch_by_dbID($params->{'tgDnaFragID'});
    $self->target_dnafrag($dnafrag);
  }
  if(defined($params->{'query_nib_dir'})) {
    $self->QUERY_NIB_DIR($params->{'query_nib_dir'});
  }
  if(defined($params->{'target_nib_dir'})) {
    $self->TARGET_NIB_DIR($params->{'target_nib_dir'});
  }

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
  if (defined($params->{'group_type'})) {
    $self->GROUP_TYPE($params->{'group_type'});
  }

  return 1;
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
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

  my $qy_gdb = $self->query_dnafrag->genome_db;
  my $tg_gdb = $self->target_dnafrag->genome_db;


  ################################################################
  # get the compara data: MethodLinkSpeciesSet, reference DnaFrag, 
  # and all GenomicAlignBlocks
  ################################################################
  print "mlss: ",$self->INPUT_METHOD_LINK_TYPE," ",$qy_gdb->dbID," ",$tg_gdb->dbID,"\n";
  my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($self->INPUT_METHOD_LINK_TYPE,
                                                         [$qy_gdb,
                                                          $tg_gdb]);
  throw("No MethodLinkSpeciesSet for :\n" .
        $self->INPUT_METHOD_LINK_TYPE . "\n" .
        $qy_gdb->dbID . "\n" .
        $tg_gdb->dbID)
    if not $mlss;

  my $out_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $out_mlss->method_link_type($self->OUTPUT_METHOD_LINK_TYPE);
  $out_mlss->species_set([$qy_gdb, $tg_gdb]);
  $mlssa->store($out_mlss);

  ######## needed for output####################
  $self->output_MethodLinkSpeciesSet($out_mlss);

  my $query_slice = $self->query_dnafrag->slice;
  my $target_slice = $self->target_dnafrag->slice;

  print STDERR "Fetching all DnaDnaAlignFeatures by query and target...\n";
  print STDERR "start fetching at time: ",time,"\n";
  
  my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag($mlss,$self->query_dnafrag,undef,undef,$self->target_dnafrag);
  my $features;
  while (my $gab = shift @{$gabs}) {
    my ($qy_ga) = $gab->reference_genomic_align;
    my ($tg_ga) = @{$gab->get_all_non_reference_genomic_aligns};

    unless (defined $self->query_DnaFrag_hash->{$qy_ga->dnafrag->name}) {
      ######### needed for output ######################################
      $self->query_DnaFrag_hash->{$qy_ga->dnafrag->name} = $qy_ga->dnafrag;
    }
      
    unless (defined $self->target_DnaFrag_hash->{$tg_ga->dnafrag->name}) {
      ######### needed for output #######################################
      $self->target_DnaFrag_hash->{$tg_ga->dnafrag->name} = $tg_ga->dnafrag;
    }
    
    my $daf_cigar = $self->daf_cigar_from_compara_cigars($qy_ga->cigar_line,
                                                         $tg_ga->cigar_line);

    if (defined $daf_cigar) {
      my $daf = Bio::EnsEMBL::DnaDnaAlignFeature->new
        (-seqname => $qy_ga->dnafrag->name,
         -start   => $qy_ga->dnafrag_start,
         -end     => $qy_ga->dnafrag_end,
         -strand  => $qy_ga->dnafrag_strand,
         -hseqname => $tg_ga->dnafrag->name,
         -hstart  => $tg_ga->dnafrag_start,
         -hend    => $tg_ga->dnafrag_end,
         -hstrand => $tg_ga->dnafrag_strand,
         -cigar_string => $daf_cigar);
      push @{$features}, $daf;
    }
  }
  
  print STDERR scalar @{$features}," features at time: ",time,"\n";

  $WORKDIR = "/tmp/worker.$$";
  unless(defined($WORKDIR) and (-e $WORKDIR)) {
    #create temp directory to hold fasta databases
    mkdir($WORKDIR, 0777);
  }

  my %parameters = (-analysis             => $self->analysis,
                    -query_slice          => $query_slice,
                    -target_slices        => {$self->target_dnafrag->name => $target_slice},
                    -query_nib_dir        => $query_slice->length > $DEFAULT_DUMP_MIN_SIZE ? $self->QUERY_NIB_DIR : undef,
                    -target_nib_dir       => $target_slice->length > $DEFAULT_DUMP_MIN_SIZE ? $self->TARGET_NIB_DIR : undef,
                    -features             => $features,
                    -workdir              => $WORKDIR);
  
  foreach my $program (qw(faToNib lavToAxt axtChain)) {
    $parameters{'-' . $program} = $BIN_DIR . "/" . $program;
  }
  
  my $runnable = Bio::EnsEMBL::Analysis::Runnable::AlignmentChains->new(%parameters);
  $self->runnable($runnable);
}

sub query_dnafrag {
  my ($self, $dir) = @_;

  if (defined $dir) {
    $self->{_query_dnafrag} = $dir;
  }

  return $self->{_query_dnafrag};
}

sub target_dnafrag {
  my ($self, $dir) = @_;

  if (defined $dir) {
    $self->{_target_dnafrag} = $dir;
  }

  return $self->{_target_dnafrag};
}

sub QUERY_NIB_DIR {
  my ($self, $dir) = @_;

  if (defined $dir) {
    $self->{_query_nib_dir} = $dir;
  }

  return $self->{_query_nib_dir};
}


sub TARGET_NIB_DIR {
  my ($self, $dir) = @_;

  if (defined $dir) {
    $self->{_target_nib_dir} = $dir;
  }

  return $self->{_target_nib_dir};
}

1;
