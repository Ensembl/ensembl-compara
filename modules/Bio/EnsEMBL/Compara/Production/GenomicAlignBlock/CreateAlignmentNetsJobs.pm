#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateAlignmentNetsJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnableDB = Bio::EnsEMBL::Pipeline::RunnableDB::CreateAlignmentNetsJobs->new (
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

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateAlignmentNetsJobs;

use strict;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Utils::Exception;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

my $DEFAULT_DUMP_MIN_SIZE = 11500000;

sub fetch_input {
  my $self = shift;

  #
  # parameters which can be set either via
  # $self->parameters OR
  # $self->input_id
  #
  $self->{'query_collection'} = undef;
#  $self->{'target_collection'} = undef;
  $self->{'query_genome_db'} = undef;
  $self->{'target_genome_db'} = undef;
  $self->{'method_link_species_set'} = undef;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  # create a Compara::DBAdaptor which shares my DBConnection
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);
  
  # get DnaCollection of query
  throw("must specify 'collection_name' to identify DnaCollection of query") 
    unless(defined($self->{'collection_name'}));
  $self->{'collection'} = $self->{'comparaDBA'}->get_DnaCollectionAdaptor->
                                fetch_by_set_description($self->{'collection_name'});
  throw("unable to find DnaCollection with name : ". $self->{'collection_name'})
    unless(defined($self->{'collection'}));

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
    $self->{'method_link_species_set'} = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_genome_db_ids($self->{'method_link'}, [$self->{'query_genome_db'}->dbID]);
  } else {
    $self->{'method_link_species_set'} = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_genome_db_ids($self->{'method_link'}, [$self->{'query_genome_db'}->dbID, $self->{'target_genome_db'}->dbID] );
  }
  throw("unable to find method_link_species_set for method_link=" . $self->{'method_link'} . " and the following genome_db_ids " . $self->{'query_genome_db_id'}. ", " .$self->{'target_genome_db_id'} . "\n")
    unless(defined($self->{'method_link_species_set'}));

  $self->print_params;

  return 1;
}


sub run
{
  my $self = shift;
  $self->createAlignmentNetsJobs();
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
  #{'method_link'=>'BLASTZ_CHAIN','query_genome_db_id'=>'1','target_genome_db_id'=>'3','collection_name'=>'human for chain','logic_name'=>'AlignmentNets-29436b68','group_type'=>'chain'}

  $self->{'query_genome_db_id'} = $params->{'query_genome_db_id'} if(defined($params->{'query_genome_db_id'}));
  $self->{'target_genome_db_id'} = $params->{'target_genome_db_id'} if(defined($params->{'target_genome_db_id'}));
  $self->{'collection_name'} = $params->{'collection_name'} if(defined($params->{'collection_name'}));
  $self->{'method_link'} = $params->{'method_link'} if(defined($params->{'method_link'}));
  $self->{'group_type'} = $params->{'group_type'} if(defined($params->{'group_type'}));;
  $self->{'logic_name'} = $params->{'logic_name'} if(defined($params->{'logic_name'}));

  # from parameters
  # nothing
  return;
}


sub print_params {
  my $self = shift;

  printf(" params:\n");
  printf("   method_link_species_set_id : %d\n", $self->{'method_link_species_set'}->dbID);
  printf("   collection           : (%d) %s\n", 
         $self->{'collection'}->dbID, $self->{'collection'}->description);
  printf("   query_genome_db           : (%d) %s\n", 
         $self->{'query_genome_db'}->dbID, $self->{'query_genome_db'}->name);
  printf("   target_genome_db          : (%d) %s\n",
         $self->{'target_genome_db'}->dbID, $self->{'target_genome_db'}->name);
}


sub createAlignmentNetsJobs
{
  my $self = shift;

  my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($self->{'logic_name'});

  my $query_dna_list  = $self->{'collection'}->get_all_dna_objects;

  my $count=0;
#  my $sql ="select group_id,min(dnafrag_start) as min,max(dnafrag_end) as max from genomic_align ga, genomic_align_group gag where ga.genomic_align_id=gag.genomic_align_id and ga.method_link_species_set_id = ? and ga.dnafrag_id= ? and gag.type = ? group by group_id order by min asc,max asc";

  my $sql = "select ga.dnafrag_start, ga.dnafrag_end from genomic_align ga, genomic_align_block gab where ga.genomic_align_block_id=gab.genomic_align_block_id and ga.method_link_species_set_id= ? and ga.dnafrag_id= ? order by dnafrag_start asc, dnafrag_end asc";

  my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);

  foreach my $qy_dna_object (@{$query_dna_list}) {
    my $qy_dnafrag_id = $qy_dna_object->dnafrag->dbID;
    $sth->execute($self->{'method_link_species_set'}->dbID, $qy_dnafrag_id);
    my ($dnafrag_start,$dnafrag_end);
    $sth->bind_columns(\$dnafrag_start, \$dnafrag_end);
    my ($slice_start,$slice_end);
    my @genomic_slices;
    while ($sth->fetch()) {
      unless (defined $slice_start) {
        ($slice_start,$slice_end) = ($dnafrag_start, $dnafrag_end);
        next;
      }
      if ($dnafrag_start > $slice_end) {
        push @genomic_slices, [$slice_start,$slice_end];
        ($slice_start,$slice_end) = ($dnafrag_start, $dnafrag_end);
      } else {
        if ($dnafrag_end > $slice_end) {
          $slice_end = $dnafrag_end;
        }
      }
    }
    $sth->finish;

    # Skip if no alignments are found on this slice
    next if (!defined $slice_start || !defined $slice_end);

    push @genomic_slices, [$slice_start,$slice_end];

    my @grouped_genomic_slices;
    undef $slice_start;
    undef $slice_end;
    my $max_slice_length = 500000;
    while (my $genomic_slices = shift @genomic_slices) {
      my ($start, $end) = @{$genomic_slices};
      unless (defined $slice_start) {
        ($slice_start,$slice_end) = ($start, $end);
        next;
      }
      my $slice_length = $slice_end - $slice_start + 1;
      my $length = $end - $start + 1;
      if ($slice_length > $max_slice_length || $slice_length + $length > $max_slice_length) {
        push @grouped_genomic_slices, [$slice_start,$slice_end];
        ($slice_start,$slice_end) = ($start, $end);
      } else {
        $slice_end = $end;
      }
    }
    push @grouped_genomic_slices, [$slice_start,$slice_end];

    while (my $genomic_slices = shift @grouped_genomic_slices) {
      my ($start, $end) = @{$genomic_slices};
      my $input_hash = {};
      $input_hash->{'start'} = $start;
      $input_hash->{'end'} = $end;
      $input_hash->{'DnaFragID'} = $qy_dnafrag_id;
      $input_hash->{'method_link_species_set_id'} = $self->{'method_link_species_set'}->dbID;
      my $input_id = main::encode_hash($input_hash);
      #printf("create_job : %s : %s\n", $analysis->logic_name, $input_id);
      Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
          (-input_id       => $input_id,
           -analysis       => $analysis,
           -input_job_id   => 0);
      $count++;
    }
  }
  if ($count == 0) {
    # No alignments have been found. Remove the control rule to unblock following analyses
    my $analysis_ctrl_rule_adaptor = $self->db->get_AnalysisCtrlRuleAdaptor;
    $analysis_ctrl_rule_adaptor->remove_by_condition_analysis_url($analysis->logic_name);
    print "No jobs created. Deleting analysis ctrl rule for " . $analysis->logic_name . "\n";
  } else {
    printf("created %d jobs for AlignmentNets\n", $count);
  }
}

1;
