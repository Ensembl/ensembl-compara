#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateChunkSets

=cut

=head1 SYNOPSIS

my $db       = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Pipeline::RunnableDB::CreateChunkSets->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object chunks the Dna from a genome_db and creates and stores the
chunks as DnaFragChunk objects into the compara database

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateChunkSets;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;

use Bio::EnsEMBL::Pipeline::RunnableDB;
our @ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);


=head2 fetch_input
    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none
=cut
sub fetch_input {
  my( $self) = @_;

  #
  # parameters which can be set either via
  # $self->parameters OR
  # $self->input_id
  #
  $self->{'max_set_bps'}              = 10000000; #10Mbase
  $self->{'genome_db_id'}             = 0;  # 'gdb'
  $self->{'chunkset_id'}              = 0;
  $self->{'store_seq'}                = 0;
  $self->{'overlap'}                  = 1000;
  $self->{'chunk_size'}               = 1000000;
  $self->{'region'}                   = undef;
  $self->{'analysis_job'}             = undef;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  throw("No genome_db specified") unless defined($self->{'genome_db_id'});
  $self->print_params;
  
  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  return 1;
}


sub run
{
  my $self = shift;

  $self->create_chunk_sets;
  return 1;
}


sub write_output 
{  
  my $self = shift;

  my $output_id = $self->input_id;

  #$output_id =~ s/\}$//;
  #$output_id .= ",ss=>".$self->{'subset'}->dbID;
  #$output_id .= "}";

  print("output_id = $output_id\n");
  $self->input_id($output_id);                    
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

  $self->{'genome_db_id'} = $params->{'gdb'} if(defined($params->{'gdb'}));
  $self->{'genome_db_id'} = $params->{'genome_db_id'} if(defined($params->{'genome_db_id'}));

  $self->{'chunkset_id'} = $params->{'chunkset_id'} if(defined($params->{'chunkset_id'}));
  $self->{'max_set_bps'} = $params->{'group_set_size'} if(defined($params->{'group_set_size'}));

  $self->{'analysis_job'} = $params->{'analysis_job'} if(defined($params->{'analysis_job'}));

  return;

}


sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   genome_db_id             : ", $self->{'genome_db_id'},"\n");
  print("   chunkset_id              : ", $self->{'chunkset_id'},"\n");
}


sub create_chunk_sets
{
  my $self      = shift;

  my $starttime = time();
  my $all_chunks = [];
  
  if($self->{'chunkset_id'}) {
    $all_chunks = $self->{'comparaDBA'}->get_DnaFragChunkSetAdaptor->
                     fetch_by_dbID($$self->{'chunkset_id'});
  } elsif($self->{'genome_db_id'}) {
    $all_chunks = $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->
                     fetch_all_for_genome_db_id($self->{'genome_db_id'});
  }
  throw("unable to fetch chunks") unless(scalar(@$all_chunks));

  printf("fetched %d chunks in %d secs\n", scalar(@$all_chunks), (time()-$starttime));

  my $chunkSet = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
  my $set_size = 0;

  foreach my $chunk (@$all_chunks) {
    if(($set_size + $chunk->length) > $self->{'max_set_bps'}) {
      #set has hit max, so save it
      $self->{'comparaDBA'}->get_DnaFragChunkSetAdaptor->store($chunkSet);
      $self->submit_job($chunkSet);
      printf("created chunkSet(%d) %d chunks, %1.3f mbase\n",
             $chunkSet->dbID, $chunkSet->count, $set_size/1000000.0);
      $chunkSet = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
      $set_size = 0;
    }

    $chunkSet->add_dnafrag_chunk_id($chunk->dbID);
    #$chunkSet->add_DnaFragChunk($chunk);
    $set_size += $chunk->length;
  }

  printf("create_chunk_sets : total time %d secs\n", (time()-$starttime));
}



sub submit_job {
  my $self     = shift;
  my $chunkSet = shift;

  return unless($self->{'analysis_job'});
  
  unless($self->{'submit_analysis'}) {
    #print("\ncreate Submit Analysis\n");
    my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($self->{'genome_db_id'});
    my $logic_name = $self->{'analysis_job'} ."_". $gdb->dbID ."_". $gdb->assembly;

    #print("  see if analysis '$logic_name' is in database\n");
    my $analysis =  $self->{'comparaDBA'}->get_AnalysisAdaptor->fetch_by_logic_name($logic_name);
    #if($analysis) { print("  YES in database with analysis_id=".$analysis->dbID()); }

    unless($analysis) {
      #print("  NOPE: go ahead and insert\n");
      $analysis = Bio::EnsEMBL::Analysis->new(
          -db              => '',
          -db_file         => '',
          -db_version      => '1',
          -parameters      => "",
          -logic_name      => $logic_name,
          -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        );
      $self->db->get_AnalysisAdaptor()->store($analysis);

      my $stats = $analysis->stats;
      $stats->batch_size(3);
      $stats->hive_capacity(11);
      $stats->status('BLOCKED');
      $stats->update();
    }
    $self->{'submit_analysis'} = $analysis;
  }

  my $input_id = "{'qyChunkSetID'=>" . $chunkSet->dbID . "}";
  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'submit_analysis'},
        -input_job_id   => 0,
        );

  return;        
}



1;
