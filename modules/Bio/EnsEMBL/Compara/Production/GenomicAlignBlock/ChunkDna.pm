#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ChunkDna

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

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ChunkDna;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;

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
  $self->{'genome_db_id'}             = 0;  # 'gdb'
  $self->{'store_seq'}                = 0;
  $self->{'overlap'}                  = 1000;
  $self->{'chunk_size'}               = 1000000;
  $self->{'chr_name'}                 = undef;
  $self->{'masking_analysis_data_id'} = 0;
  $self->{'masking_options'}          = undef;

  $self->{'analysis_job'}             = undef;
  $self->{'create_analysis_prefix'}   = undef; # 'analysis', 'job'
  #$self->{'coordinate_system'} = "chromosome";

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  throw("No genome_db specified") unless defined($self->{'genome_db_id'});
  $self->print_params;
  
  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

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

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }
      
  $self->{'store_seq'} = $params->{'store_seq'} if(defined($params->{'store_seq'}));
  $self->{'chunk_size'} = $params->{'chunk_size'} if(defined($params->{'chunk_size'}));
  $self->{'overlap'} = $params->{'overlap'} if(defined($params->{'overlap'}));

  $self->{'genome_db_id'} = $params->{'gdb'} if(defined($params->{'gdb'}));
  $self->{'genome_db_id'} = $params->{'genome_db_id'} if(defined($params->{'genome_db_id'}));

  $self->{'chr_name'} = $params->{'chr_name'} if(defined($params->{'chr_name'}));
  $self->{'masking_options'} = $params->{'masking_options'}
    if(defined($params->{'masking_options'}));
  $self->{'masking_analysis_data_id'} = $params->{'masking_analysis_data_id'}
    if(defined($params->{'masking_analysis_data_id'}));
    
  $self->{'analysis_job'} = $params->{'analysis_job'} if(defined($params->{'analysis_job'}));
  $self->{'create_analysis_prefix'} = $params->{'create_analysis_prefix'}
    if(defined($params->{'create_analysis_prefix'}));

  return;

}


sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   genome_db_id             : ", $self->{'genome_db_id'},"\n"); 
  print("   store_seq                : ", $self->{'store_seq'},"\n");
  print("   chunk_size               : ", $self->{'chunk_size'},"\n");
  print("   overlap                  : ", $self->{'overlap'} ,"\n");
  print("   masking_analysis_data_id : ", $self->{'masking_analysis_data_id'} ,"\n");
  print("   masking_options          : ", $self->{'masking_options'} ,"\n") if($self->{'masking_options'});
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

  my $chromosomes = [];
  if(defined $self->{'chr_name'}) {
    push @{$chromosomes}, $SliceAdaptor->fetch_by_region('chromosome', $self->{'chr_name'});
  } else {
    $chromosomes = $SliceAdaptor->fetch_all('toplevel');
  }

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

    my $chunk = new Bio::EnsEMBL::Compara::Production::DnaFragChunk();
    $chunk->dnafrag($dnafrag);
    $chunk->seq_start($i);
    $chunk->seq_end($i + $self->{'chunk_size'} - 1);
    $chunk->masking_analysis_data_id($self->{'masking_analysis_data_id'});
    if($self->{'masking_options'}) {
      $chunk->masking_options($self->{'masking_options'});
    }

    if($self->{'chunk_size'} <=15000000 and $self->{'store_seq'}) {
      my $bioseq = $chunk->fetch_masked_sequence;
      $chunk->sequence($bioseq->seq);
    }
    print "storing chunk ",$chunk->display_id,"\n";
    $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->store($chunk);

    $self->submit_job($chunk) if($self->{'analysis_job'});
    $self->create_chunk_analysis($chunk) if($self->{'create_analysis_prefix'});
  }
  
  #print "Done\n";
  #print scalar(time()-$lasttime), " secs to chunk, and store\n";
}


sub submit_job {
  my $self  = shift;
  my $chunk = shift;

  unless($self->{'submit_analysis'}) {
    #print("\ncreate Submit Analysis\n");
    my $gdb = $chunk->dnafrag->genome_db;
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
      $stats->batch_size(7000);
      $stats->hive_capacity(11);
      $stats->status('BLOCKED');
      $stats->update();
    }
    $self->{'submit_analysis'} = $analysis;
  }

  my $input_id = "{'qyChunk'=>" . $chunk->dbID . "}";
  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $self->{'submit_analysis'},
        -input_job_id   => 0,
        );

  return;        
}


sub create_chunk_analysis {
  #routine to create one analysis per chunk
  my $self  = shift;
  my $chunk = shift;

  my $gdb = $chunk->dnafrag->genome_db;
  my $logic_name = $self->{'create_analysis_prefix'}
                   ."_". $gdb->dbID
                   ."_". $gdb->assembly
                   ."_". $chunk->dbID;

  my $parameters = "{'dbChunk'=>" . $chunk->dbID . "}";

  my $analysis = Bio::EnsEMBL::Analysis->new(
      -db              => '',
      -db_file         => '',
      -db_version      => '1',
      -parameters      => $parameters,
      -logic_name      => $logic_name,
      -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::BlastZ',
    );
  $self->db->get_AnalysisAdaptor()->store($analysis);

  my $stats = $analysis->stats;
  $stats->batch_size(10);
  $stats->hive_capacity(500);
  $stats->update();
  
  return;
}

1;
