#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ChunkDna

=cut

=head1 SYNOPSIS

my $db       = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Pipeline::RunnableDB::ChunkDna->new (
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

package Bio::EnsEMBL::Compara::RunnableDB::ChunkDna;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;
use Bio::EnsEMBL::Compara::DnaFragChunk;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );

use Bio::EnsEMBL::Pipeline::RunnableDB;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

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
  $self->{'genome_db_id'}      = 0;  # 'gdb'
  $self->{'store_seq'}         = 1;
  $self->{'overlap'}           = 1000;
  $self->{'chunk_size'}        = 1000000;
  $self->{'masking'}            = 'soft';
  $self->{'mask_params'}       = undef;

  $self->{'prog'}              = undef;
  $self->{'create'}            = undef; # 'analysis', 'job'
  #$self->{'coordinate_system'} = "chromosome";

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  throw("No genome_db specified") unless defined($self->{'genome_db_id'});
  $self->print_params;
  
  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  #get the Compara::GenomeDB object for the genome_db_id
  $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->
                           fetch_by_dbID($self->{'genome_db_id'});
  throw("Can't fetch genome_db for id=".$self->{'genome_db_id'}) unless($self->{'genome_db'});

    
  #using genome_db_id, connect to external core database
  my $coreDBA = $self->{'genome_db'}->db_adaptor();  
  throw("Can't connect to genome database for id=".$self->{'genome_db_id'}) unless($coreDBA);
  
  return 1;
}


sub run
{
  my $self = shift;

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  
  # main routine which takes a genome_db_id (from input_id) and
  # access the ensembl_core database, useing the SliceAdaptor
  # it will load all slices, all genes, and all transscripts
  # and convert them into members to be stored into compara
  $self->create_chunks_from_genomeDB($self->{'genome_db'});
  
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
                                          
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
      
  $self->{'store_seq'} = $params->{'store_seq'} if(defined($params->{'store_seq'}));
  $self->{'chunk_size'} = $params->{'chunk_size'} if(defined($params->{'chunk_size'}));
  $self->{'overlap'} = $params->{'overlap'} if(defined($params->{'overlap'}));

  $self->{'genome_db_id'} = $params->{'gdb'} if(defined($params->{'gdb'}));
  $self->{'prog'} = $params->{'prog'} if(defined($params->{'prog'}));
  $self->{'create'} = $params->{'create'} if(defined($params->{'create'}));
  $self->{'masking'} = $params->{'masking'} if(defined($params->{'masking'}));
  #$self->{'coordinate_system'} = $params->{'coordinate_system'} if(defined($params->{'coordinate_system'});

  return;

}


sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   genome_db_id : ", $self->{'genome_db_id'},"\n"); 
  print("   store_seq    : ", $self->{'store_seq'},"\n");
  print("   chunk_size   : ", $self->{'chunk_size'},"\n");
  print("   overlap      : ", $self->{'overlap'} ,"\n");
  print("   masking      : ", $self->{'masking'} ,"\n");
 #print("   prog         : ", $self->{'prog'} ,"\n");
 #print("   create       : ", $self->{'create'} ,"\n");
}


sub create_chunks_from_genomeDB
{
  my $self      = shift;
  my $genome_db = shift;

  #$self->{'subset'} = new Bio::EnsEMBL::Compara::Subset;
  #$self->{'subset'}->description($genome_db->name . ' chunks');
  #$self->{'comparaDBA'}->get_SubsetAdaptor->store($self->{'subset'});

  $genome_db->db_adaptor->dbc->disconnect_when_inactive(0);
  my $SliceAdaptor = $genome_db->db_adaptor->get_SliceAdaptor;
  my $dnafragDBA = $self->{'comparaDBA'}->get_DnaFragAdaptor;
  
  my $chromosomes = $SliceAdaptor->fetch_all('toplevel');

  my $starttime = time();
  foreach my $chr (@{$chromosomes}) {
    #print "fetching dnafrag\n";

    my ($dnafrag) = @{$dnafragDBA->fetch_all_by_GenomeDB_region(
                       $genome_db,
                       $chr->coord_system->name(), #$self->{'coordinate_system'},
                       $chr->seq_region_name)};

    #if($dnafrag) { print("  already stores as dbID ", $dnafrag->dbID, "\n"); }
    unless($dnafrag) {
      #
      # create dnafrag for this chromosome
      #
      #print "loading dnafrag for ".$chr->name."...\n";
      $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
      $dnafrag->name($chr->seq_region_name); #ie just 22
      $dnafrag->genome_db($genome_db);
      $dnafrag->coord_system_name($chr->coord_system->name());
      $dnafrag->length($chr->length);
      $dnafragDBA->store_if_needed($dnafrag);
    }

    $self->create_dnafrag_chunks($dnafrag);

  }
  print "genome_db ",$genome_db->dbID, " : total time ", (time()-$starttime), " secs\n";
}


sub create_dnafrag_chunks {
  my $self = shift;
  my $dnafrag = shift;

 #return if($dnafrag->display_id =~ /random/);

  my $dnafragDBA = $self->{'comparaDBA'}->get_DnaFragAdaptor;
        
  my $length = $dnafrag->length;
  #print "dnafrag : ", $dnafrag->display_id, "n";
  #print "  sequence length : ",$length,"\n";

  my $lasttime = time();
  #all seq in inclusive coordinates so need to +1
  for (my $i=1; $i<=$length; $i=$i+$self->{'chunk_size'}-$self->{'overlap'}) {

    my $chunk = new Bio::EnsEMBL::Compara::DnaFragChunk();
    $chunk->dnafrag($dnafrag);
    $chunk->seq_start($i);
    $chunk->seq_end($i + $self->{'chunk_size'} - 1);

    if($self->{'chunk_size'} <=15000000 and $self->{'store_seq'}) {
      my $bioseq = $chunk->fetch_masked_sequence($self->{'masking'}, $self->{'mask_params'});
      $chunk->sequence($bioseq->seq);
    }
    print "storing chunk ",$chunk->display_id,"\n";
    $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->store($chunk);
  }
  
  #print "Done\n";
  #print scalar(time()-$lasttime), " secs to chunk, and store\n";
}


sub test {
  my $self = shift;

  my $dnafragDBA = $self->{'comparaDBA'}->get_DnaFragAdaptor;
  
  my $qyChunk = $dnafragDBA->fetch_by_dbID(1);
  my $dbChunk = $dnafragDBA->fetch_by_dbID(2);

  my $starttime = time();
  my $qySeq = $qyChunk->fetch_masked_sequence;
  print scalar(time()-$starttime), " secs\n";
  my $dbSeq = $dbChunk->fetch_masked_sequence;
  print scalar(time()-$starttime), " secs\n";

  exit(0);
}

1;
