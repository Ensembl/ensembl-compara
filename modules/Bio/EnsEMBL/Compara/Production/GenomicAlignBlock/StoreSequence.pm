#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::StoreSequence

=cut

=head1 SYNOPSIS

my $db       = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::StoreSequence>new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object gets the DnaFrag objects from a DnaFragChunkSet and stores the sequence (if short enough) in the Compara sequence table

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::StoreSequence;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::Production::DnaCollection;

use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;

use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Hive::Process;

our @ISA = qw(Bio::EnsEMBL::Hive::Process Bio::EnsEMBL::Analysis::RunnableDB);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
    my( $self) = @_;
    
    #create a Compara::DBAdaptor which shares the same DBI handle
    #with the DBAdaptor that is based into this runnable
    $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);
    
    $self->get_params($self->parameters);
    $self->get_params($self->input_id);
    
    return 1;
}


sub run
{
  my $self = shift;

  return 1;
}


sub write_output 
{  
  my $self = shift;

  #
  #Get all the chunks in this dnaFragChunkSet
  #
  if (defined $self->{'dnaFragChunkSet'}) {
      my $chunkSet = $self->{'dnaFragChunkSet'};
      my $chunk_array = $chunkSet->get_all_DnaFragChunks;
      
      #Store sequence in Sequence table
      foreach my $chunk (@$chunk_array) {
	  my $bioseq = $chunk->bioseq;
	  if($chunk->sequence_id==0) {
	      $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->update_sequence($chunk);
	  }
      }
  }

  if (defined $self->{'dnaFragChunk'}) {
      my $chunk = $self->{'dnaFragChunk'};

      #Store sequence in Sequence table
      my $bioseq = $chunk->bioseq;
      if($chunk->sequence_id==0) {
	  $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->update_sequence($chunk);
      }
  }
  return 1;
}



######################################
#
# subroutines
#
#####################################

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

  #Convert chunkSetID into DnaFragChunkSet object
  if(defined($params->{'chunkSetID'})) {
     my $chunkset = $self->{'comparaDBA'}->get_DnaFragChunkSetAdaptor->fetch_by_dbID($params->{'chunkSetID'});
     $self->{'dnaFragChunkSet'} = $chunkset;
  }

  #Convert chunkID into DnaFragChunk object
  if(defined($params->{'chunkID'})) {
     my $chunk = $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->fetch_by_dbID($params->{'chunkID'});
     $self->{'dnaFragChunk'} = $chunk;
  }

}

