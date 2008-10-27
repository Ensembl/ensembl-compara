#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateFilterDuplicatesJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateFilterDuplicatesJobs->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateFilterDuplicatesJobs;

use strict;

#use Bio::EnsEMBL::Hive;
#use Bio::EnsEMBL::Hive::Extensions;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::Production::DnaCollection;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my $self = shift;

  #
  # parameters which can be set either via
  # $self->parameters OR
  # $self->input_id
  #
  $self->{'collection'} = undef;
  $self->{'filter_duplicates_analysis'} = undef;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  #{'collection_name'=>'rat','filter_duplicates'=>'in_chunk_overlaps','region'=>'chromosome:11'}

  # create a Compara::DBAdaptor which shares my DBConnection
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  # get the FilterDuplicates analysis
  throw("must specify pair_aligner to identify logic_name of FilterDuplicates analysis") 
    unless(defined($self->{'logic_name'}));
  $self->{'filter_duplicates_analysis'} = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($self->{'logic_name'});
  throw("unable to find analysis with logic_name ". $self->{'logic_name'})
    unless(defined($self->{'filter_duplicates_analysis'}));

  # get DnaCollection
  throw("must specify 'collection_name' to identify DnaCollection") 
    unless(defined($self->{'collection_name'}));
  $self->{'collection'} = $self->{'comparaDBA'}->get_DnaCollectionAdaptor->
                                fetch_by_set_description($self->{'collection_name'});
  throw("unable to find DnaCollection with name : ". $self->{'collection_name'})
    unless(defined($self->{'collection'}));

  $self->print_params;

  return 1;
}


sub run
{
  my $self = shift;
  $self->createFilterDuplicatesJobs();
  return 1;
}


sub write_output
{
  my $self = shift;
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
  #{'collection_name'=>'rat','filter_duplicates'=>'in_chunk_overlaps','region'=>'chromosome:11'}
  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");
  
  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  $self->{'logic_name'} = $params->{'logic_name'} if(defined($params->{'logic_name'}));
  $self->{'collection_name'} = $params->{'collection_name'} if(defined($params->{'collection_name'}));
  $self->{'region'} = $params->{'region'} if(defined($params->{'region'}));

  return;
}


sub print_params {
  my $self = shift;

  printf(" params:\n");
  printf("   logic_name : %s\n", $self->{'logic_name'});
  printf("   collection           : (%d) %s\n", 
         $self->{'collection'}->dbID, $self->{'collection'}->description);
  if (defined $self->{'region'}) {
    printf("   region          : %s\n", $self->{'region'});
  }
}


sub createFilterDuplicatesJobs
{
  my $self = shift;

  my $dna_collection  = $self->{'collection'};
  my $analysis = $self->{'filter_duplicates_analysis'};
  my $region = $self->{'region'};

  my ($coord_system_name, $seq_region_name, $seq_region_start, $seq_region_end);
  if (defined $region && $region =~ //) {
    ($coord_system_name, $seq_region_name, $seq_region_start, $seq_region_end) = split(/:/, $region);
  }

  my $dnafrag_id_list = $dna_collection->get_all_dnafrag_ids;

  my $count = 0;
  my %already_seen_dnafrag_ids;
  foreach my $dnafrag_id (@{$dnafrag_id_list}) {
    next if (defined $already_seen_dnafrag_ids{$dnafrag_id});
    my $input_hash = {};
    $input_hash->{'dnafrag_id'} = $dnafrag_id;
    $input_hash->{'seq_region_start'} = $seq_region_start if (defined $seq_region_start);
    $input_hash->{'seq_region_end'} = $seq_region_end if (defined $seq_region_end);
    my $input_id = main::encode_hash($input_hash);
    #printf("create_job : %s : %s\n", $analysis->logic_name, $input_id);
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
        (-input_id       => $input_id,
         -analysis       => $analysis,
         -input_job_id   => 0);
    $already_seen_dnafrag_ids{$dnafrag_id} = 1;
    $count++;
  }
  printf("created %d jobs for analysis logic_name %s\n", $count, $analysis->logic_name);
}

1;
