#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreatePairAlignerJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::CreatePairAlignerJobs->new (
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

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreatePairAlignerJobs;

use strict;

use Bio::EnsEMBL::Hive;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::Production::DnaCollection;

use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Hive::Process;

our @ISA = qw(Bio::EnsEMBL::Hive::Process Bio::EnsEMBL::Analysis::RunnableDB );

sub fetch_input {
  my $self = shift;

  #
  # parameters which can be set either via
  # $self->parameters OR
  # $self->input_id
  #
  $self->{'pair_aligner_logic_name'}    = undef;
  $self->{'query_dna'}                  = undef;
  $self->{'target_dna'}                 = undef;
  $self->{'method_link_species_set_id'} = undef;

  $self->get_params($self->parameters);  
  $self->get_params($self->input_id); 

  # create a Compara::DBAdaptor which shares my DBConnection
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  # get the PairAligner analysis
  throw("must specify pair_aligner to identify logic_name of PairAligner analysis") 
    unless(defined($self->{'pair_aligner_logic_name'}));
  $self->{'pair_aligner'} = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($self->{'pair_aligner_logic_name'});
  throw("unable to find analysis with logic_name ". $self->{'pair_aligner_logic_name'})
    unless(defined($self->{'pair_aligner'}));

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


  $self->print_params;

 if ( $self->dump_chunks == 1 ) { 
    if ( defined $self->dump_chunks_loc && ! -e $self->dump_chunks_loc ) {  
         throw("your dump_chunks_loc " . $self->dump_chunks_loc . " does not exist!\n");
    }
 }   
  print "FETCH_INPUT *done*\n"; 
  return 1;
}


sub run
{
  my $self = shift;
  $self->createPairAlignerJobs(); 
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

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");
  
  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }
                      
  $self->{'pair_aligner_logic_name'} = $params->{'pair_aligner'} if(defined($params->{'pair_aligner'}));
  $self->{'query_collection_name'} = $params->{'query_collection_name'} if(defined($params->{'query_collection_name'}));
  $self->{'target_collection_name'} = $params->{'target_collection_name'} if(defined($params->{'target_collection_name'}));

  $self->{'method_link_species_set_id'} = $params->{'method_link_species_set_id'} 
      if(defined($params->{'method_link_species_set_id'}));
  $self->dump_chunks($params->{'dump_chunks'}) if(defined($params->{'dump_chunks'}));
  $self->dump_chunks_loc($params->{'dump_chunks_loc'}) if(defined($params->{'dump_chunks_loc'}));
  
  return;
}


sub print_params {
  my $self = shift;

  printf(" params:\n");
  printf("   method_link_species_set_id : %d\n", $self->{'method_link_species_set_id'});
  printf("   pair_aligner               : (%d) %s\n", 
         $self->{'pair_aligner'}->dbID,  $self->{'pair_aligner'}->logic_name);
  printf("   query_collection           : (%d) %s\n", 
         $self->{'query_collection'}->dbID, $self->{'query_collection'}->description);
  printf("   target_collection          : (%d) %s\n",
         $self->{'target_collection'}->dbID, $self->{'target_collection'}->description);

}


sub dump_chunks {
  my $self = shift;
  $self->{'_dump_chunks'} = shift if(@_); 
  return $self->{'_dump_chunks'};
}

sub dump_chunks_loc {
  my $self = shift;
  $self->{'_dump_chunks_loc'} = shift if(@_); 
  return $self->{'_dump_chunks_loc'};
}


sub createPairAlignerJobs
{
  my $self = shift;

  my $query_dna_list  = $self->{'query_collection'}->get_all_dna_objects;
  my $target_dna_list = $self->{'target_collection'}->get_all_dna_objects;

  my %target_dnafrag_chunk; 
  my %target_dnafrag_chunk_set; 
  my %query_dnafrag_chunk; 
  my %query_dnafrag_chunk_set; 

  my $count=0;
  foreach my $target_dna (@{$target_dna_list}) {
    my $input_hash = {};

    $input_hash->{'dbChunk'}      = undef;
    $input_hash->{'dbChunkSetID'} = undef;

    if($target_dna->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk')) {
      $input_hash->{'dbChunk'} = $target_dna->dbID;
      $target_dnafrag_chunk{$target_dna->dbID}= $target_dna; 
    }
    if($target_dna->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet')) {
      $input_hash->{'dbChunkSetID'} = $target_dna->dbID;
      $target_dnafrag_chunk_set{$target_dna->dbID}=$target_dna; 
    }
 
    foreach my $query_dna (@{$query_dna_list}) {
      $input_hash->{'qyChunk'}      = undef
      $input_hash->{'qyChunkSetID'} = undef;

      if($query_dna->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk')) {
        $input_hash->{'qyChunk'} = $query_dna->dbID; 
        $query_dnafrag_chunk{$query_dna->dbID}=$query_dna;
      }
      if($query_dna->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet')) {
        $input_hash->{'qyChunkSetID'} = $query_dna->dbID;
        $query_dnafrag_chunk_set{$query_dna->dbID}=$query_dna
      }
    
      my $input_id = main::encode_hash($input_hash);
      
      Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'pair_aligner'},
        -input_job_id   => 0,
        );
      $count++;
    }
    #printf("create_job : " . $target_dna->dbID . "\n" ) ; 
  } 
  
  printf("jhv created %d jobs for pair aligner\n", $count);    

  if ( $self->dump_chunks == 1 ) {  
    unless ( -e $self->dump_chunks_loc ) {  
      throw("The dump chunks-location " . $self->dump_chunks_loc . " in the analysis.parameters-table does not exist\n") ; 
    } 
    if ( defined $self->dump_chunks_loc) {  
      # First write the 'single' chunks 
      for my $t ( keys %target_dnafrag_chunk ) {   
        $self->write_dnafrag_chunk($target_dnafrag_chunk{$t});
      }  
      for my $q ( keys %query_dnafrag_chunk ) { 
        $self->write_dnafrag_chunk($query_dnafrag_chunk{$q});
      }
      # now write the sets. 
      for my $q ( keys %query_dnafrag_chunk_set ) { 
        $self->write_dnafrag_chunk_set($query_dnafrag_chunk_set{$q});
      }   
      for my $t ( keys %target_dnafrag_chunk_set ) { 
        $self->write_dnafrag_chunk_set($target_dnafrag_chunk_set{$t});
      }  
    } 
  } else {  
    warning("You specified to dump the chunks but you have to give a dump_chunks_loc location where to dump the chunks to, too.\n".
            " you can specify this in the analysis.parameters column   'dump_chunks_loc=>\"/path/to/dump/loc\"}\n") ; 
  } 
} 


sub write_dnafrag_chunk_set{ 
  my ($self,$chunk_set) = @_ ;    

  my $dump_location = $self->dump_chunks_loc ; 
  $dump_location = $dump_location ."/" unless $dump_location =~m/\/$/; 
  my $fastafile = $dump_location .  "chunk_set_" . $chunk_set->dbID . ".fasta";  # same name is used in blastz  
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /

  open(OUTSEQ, ">$fastafile") or $self->throw("Error opening $fastafile for write");
  my $output_seq = Bio::SeqIO->new( -fh =>\*OUTSEQ, -format => 'Fasta'); 

  my $chunk_array = $chunk_set->get_all_DnaFragChunks ;

  my $dna_frag_chunk_adaptor = $self->{'comparaDBA'}->get_DnaFragChunkAdaptor; 
  my $dis_con = $self->{'comparaDBA'}->disconnect_when_inactive() ;
  $self->{'comparaDBA'}->disconnect_when_inactive(0) ;

  # my @sequences_to_store_and_update ; 
  foreach my $chunk (@$chunk_array) {
    printf("  writing $fastafile -> chunk %s\n", $chunk->display_id);
    my $bioseq = $chunk->bioseq; 
    # it might be that the sequence is not stored , so we have to store it here ........ select count(*) from sequence 
    if($chunk->sequence_id==0) {  
       # push  @sequences_to_store_and_update, $chunk;
       print "storing sequence .\n" ; 
       $dna_frag_chunk_adaptor->update_sequence($chunk);
    }
    $output_seq->write_seq($bioseq);
    # $dna_frag_chunk_adaptor->update_multiple_sequences(\@sequences_to_store_and_update) ; 
  }
  close OUTSEQ;
  $self->{'comparaDBA'}->disconnect_when_inactive($dis_con) ;
}

sub write_dnafrag_chunk{ 
  my ($self,$chunk) = @_ ;    

  my $dump_location = $self->dump_chunks_loc ;
  $dump_location = $dump_location ."/" unless $dump_location =~m/\/$/; 
  my $fastafile = $dump_location .  "chunk_" . $chunk->dbID . ".fasta";  # same name is used in blastz  
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  print "dumping dnafrag_chunk : $fastafile\n" ; 
  $chunk->dump_to_fasta_file($fastafile);
} 

1;
