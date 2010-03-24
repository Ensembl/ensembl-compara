#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateAlignmentChainsJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnableDB = Bio::EnsEMBL::Compara::RunnableDB::CreateAlignmentChainsJobs->new (
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnableDB->fetch_input(); #reads from DB
$runnableDB->run();
$runnableDB->output();
$runnableDB->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

=cut

=head1 CONTACT

Abel Ureta-Vidal <abel@ebi.ac.uk>

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateAlignmentChainsJobs;

use strict;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Utils::Exception;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

#my $DEFAULT_DUMP_MIN_SIZE = 11500000;
my $DEFAULT_OUTPUT_METHOD_LINK = "BLASTZ_CHAIN";

sub fetch_input {
  my $self = shift;

  #
  # parameters which can be set either via
  # $self->parameters OR
  # $self->input_id
  #
  $self->{'query_collection'} = undef;
  $self->{'target_collection'} = undef;
  $self->{'query_genome_db'} = undef;
  $self->{'target_genome_db'} = undef;
  $self->{'method_link_species_set'} = undef;
  $self->{'output_method_link'} = undef;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  # create a Compara::DBAdaptor which shares my DBConnection
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);
  
  # get DnaCollection of query
  throw("must specify 'query_collection_name' to identify DnaCollection of query") 
    unless(defined($self->{'query_collection_name'}));
  $self->{'query_collection'} = $self->{'comparaDBA'}->get_DnaCollectionAdaptor->
                                fetch_by_set_description($self->{'query_collection_name'});
  throw("unable to find DnaCollection with name : ". $self->{'query_collection_name'})
    unless(defined($self->{'query_collection'}));

  # get DnaCollection of target
  throw("must specify 'target_collection_name' to identify DnaCollection of query") 
    unless(defined($self->{'target_collection_name'}));
  $self->{'target_collection'} = $self->{'comparaDBA'}->get_DnaCollectionAdaptor->
                                fetch_by_set_description($self->{'target_collection_name'});
  throw("unable to find DnaCollection with name : ". $self->{'target_collection_name'})
    unless(defined($self->{'target_collection'}));

  # get genome_db of query
  throw("must specify 'query_genome_db_id' to identify DnaCollection of query") 
    unless(defined($self->{'query_genome_db_id'}));
  $self->{'query_genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->
                                fetch_by_dbID($self->{'query_genome_db_id'});
  throw("unable to find genome_db with dbID : ". $self->{'query_genome_db_id'})
    unless(defined($self->{'query_genome_db'}));
  
  # get genome_db of target
  throw("must specify 'target_genome_db_id' to identify DnaCollection of target") 
    unless(defined($self->{'target_genome_db_id'}));
  $self->{'target_genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->
                                fetch_by_dbID($self->{'target_genome_db_id'});
  throw("unable to find genome_db with dbID : ". $self->{'target_genome_db_id'})
    unless(defined($self->{'target_genome_db'}));

  # get the MethodLinkSpeciesSet
  throw("must specify a method_link to identify a MethodLinkSpeciesSet") 
    unless(defined($self->{'method_link'}));
  if ($self->{'query_genome_db'}->dbID == $self->{'target_genome_db'}->dbID) {
    $self->{'method_link_species_set'} = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_genome_db_ids($self->{'method_link'}, [$self->{'query_genome_db'}->dbID] );
  } else {
    $self->{'method_link_species_set'} = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_genome_db_ids($self->{'method_link'}, [$self->{'query_genome_db'}->dbID, $self->{'target_genome_db'}->dbID] );
  }
  throw("unable to find method_link_species_set for method_link=",$self->{'method_link'}," and the following genome_db_ids ",$self->{'query_genome_db_id'},", ",$self->{'target_genome_db_id'},"\n")
    unless(defined($self->{'method_link_species_set'}));

  $self->print_params;
    
  
  return 1;
}


sub run
{
  my $self = shift;
  $self->createAlignmentChainsJobs();
  return 1;
}


sub write_output
{
  my $self = shift;
  my $output_id = "{\'query_genome_db_id\' => \'" . $self->{'query_genome_db_id'} . "\',\'target_genome_db_id\' => \'" . $self->{'target_genome_db_id'} . "\'}";
  $self->dataflow_output_id($output_id, 2);
  return 1;
}

##################################
#
# subroutines
#
##################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");
  
  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  # from input_id
  $self->{'query_genome_db_id'} = $params->{'query_genome_db_id'} if(defined($params->{'query_genome_db_id'}));
  $self->{'target_genome_db_id'} = $params->{'target_genome_db_id'} if(defined($params->{'target_genome_db_id'}));
  $self->{'query_collection_name'} = $params->{'query_collection_name'} if(defined($params->{'query_collection_name'}));
  $self->{'target_collection_name'} = $params->{'target_collection_name'} if(defined($params->{'target_collection_name'}));
  $self->{'logic_name'} = $params->{'logic_name'} if(defined($params->{'logic_name'}));

  # from parameters
  ## method_link alias for input_method_link, for backwards compatibility
  $self->{'method_link'} = $params->{'method_link'} if(defined($params->{'method_link'}));
  $self->{'method_link'} = $params->{'input_method_link'} if(defined($params->{'input_method_link'}));
  $self->{'output_method_link'} = $params->{'output_method_link'} if(defined($params->{'output_method_link'}));


  return;
}


sub print_params {
  my $self = shift;

  printf(" params:\n");
  printf("   method_link_species_set_id : %d\n", $self->{'method_link_species_set'}->dbID);
  printf("   query_collection           : (%d) %s\n", 
         $self->{'query_collection'}->dbID, $self->{'query_collection'}->description);
  printf("   target_collection          : (%d) %s\n",
         $self->{'target_collection'}->dbID, $self->{'target_collection'}->description);
  printf("   query_genome_db           : (%d) %s\n", 
         $self->{'query_genome_db'}->dbID, $self->{'query_genome_db'}->name);
  printf("   target_genome_db          : (%d) %s\n",
         $self->{'target_genome_db'}->dbID, $self->{'target_genome_db'}->name);
}


sub createAlignmentChainsJobs
{
  my $self = shift;

  #my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name('AlignmentChains');
  my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($self->{'logic_name'});

  my (%qy_dna_hash, %tg_dna_hash);

  foreach my $obj (@{$self->{'query_collection'}->get_all_dna_objects}) {
    my @dna_chunks;
    if ($obj->isa("Bio::EnsEMBL::Compara::Production::DnaFragChunkSet")) {
      push @dna_chunks, @{$obj->get_all_DnaFragChunks};
    } else {
      push @dna_chunks, $obj;
    }
    foreach my $chunk (@dna_chunks) {
      my $dnafrag = $chunk->dnafrag;
      if (not exists $qy_dna_hash{$dnafrag->dbID}) {
        $qy_dna_hash{$dnafrag->dbID} = $dnafrag;
      }
    }
  }
  my %target_dna_hash;
  foreach my $dna_object (@{$self->{'target_collection'}->get_all_dna_objects}) {
    my @dna_chunks;
    if ($dna_object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet')) {
      push @dna_chunks, @{$dna_object->get_all_DnaFragChunks};
    } else {
      push @dna_chunks, $dna_object;
    }
    foreach my $chunk (@dna_chunks) {
      my $dnafrag = $chunk->dnafrag;
      if (not exists $tg_dna_hash{$dnafrag->dbID}) {
        $tg_dna_hash{$chunk->dnafrag->dbID} = $dnafrag;
      }
    }
  }

  my $count=0;

  my $sql = "select g2.dnafrag_id from genomic_align g1, genomic_align g2 where g1.method_link_species_set_id = ? and g1.genomic_align_block_id=g2.genomic_align_block_id and g1.dnafrag_id = ? and g1.genomic_align_id != g2.genomic_align_id group by g2.dnafrag_id";
  my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);

  my $reverse_pairs; # used to avoid getting twice the same results for self-comparisons
  foreach my $qy_dnafrag_id (keys %qy_dna_hash) {
    $sth->execute($self->{'method_link_species_set'}->dbID, $qy_dnafrag_id);

    my $tg_dnafrag_id;
    $sth->bind_columns(\$tg_dnafrag_id);
    while ($sth->fetch()) {

      next unless exists $tg_dna_hash{$tg_dnafrag_id};
      next if (defined($reverse_pairs->{$qy_dnafrag_id}->{$tg_dnafrag_id}));
      
      my $input_hash = {};
      $input_hash->{'qyDnaFragID'} = $qy_dnafrag_id;
      $input_hash->{'tgDnaFragID'} = $tg_dnafrag_id;


      if ($self->{'query_collection'}->dump_loc) {
        my $nib_file = $self->{'query_collection'}->dump_loc 
            . "/" 
            . $qy_dna_hash{$qy_dnafrag_id}->name 
            . ".nib";
        if (-e $nib_file) {
          $input_hash->{'query_nib_dir'} = $self->{'query_collection'}->dump_loc;
        }
      }
      if ($self->{'target_collection'}->dump_loc) {
        my $nib_file = $self->{'target_collection'}->dump_loc 
            . "/" 
            . $tg_dna_hash{$tg_dnafrag_id}->name
            . ".nib";
        if (-e $nib_file) {
          $input_hash->{'target_nib_dir'} = $self->{'target_collection'}->dump_loc;
        }
      }
      $reverse_pairs->{$tg_dnafrag_id}->{$qy_dnafrag_id} = 1;

      my $input_id = main::encode_hash($input_hash);
      #printf("create_job : %s : %s\n", $self->{'pair_aligner'}->logic_name, $input_id);
      Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
                                                                   -input_id       => $input_id,
                                                                   -analysis       => $analysis,
                                                                   -input_job_id   => 0,
                                                                  );
      $count++;
    }
  }
  $sth->finish;

  if ($count == 0) {
    # No alignments have been found. Remove the control rule to unblock following analyses
    my $analysis_ctrl_rule_adaptor = $self->db->get_AnalysisCtrlRuleAdaptor;
    $analysis_ctrl_rule_adaptor->remove_by_condition_analysis_url($analysis->logic_name);
    print "No jobs created. Deleting analysis ctrl rule for " . $analysis->logic_name . "\n";
  } else {
    printf("created %d jobs for AlignmentChains\n", $count);
  }


  ## Create new MethodLinkSpeciesSet
  # Use the value set in the parameters or the input_id
  my $output_method_link = $self->{'output_method_link'};
  # Use the output_method_link from the target analysis if the previous is not set
  if (!$output_method_link and $self->{'logic_name'}) {
    my $params = eval($analysis->parameters);
    if ($params->{'output_method_link'}) {
      $output_method_link = $params->{'output_method_link'}
    }
  }
  # Use the default value otherwise
  if (!$output_method_link) {
    $output_method_link = $DEFAULT_OUTPUT_METHOD_LINK;
  }
  my $new_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
      -species_set => $self->{'method_link_species_set'}->species_set,
      -method_link_type => $output_method_link
    );
  $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($new_mlss);

}

1;
