#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadMembers

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::GenomeLoadMembers->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Pipeline::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. A Bio::EnsEMBL::Pipeline::DBSQL::Obj is
required for databse access.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadMembers;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Runnable::Blast;
use Bio::EnsEMBL::Pipeline::Runnable::BlastDB;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;

use Bio::EnsEMBL::Pipeline::RunnableDB;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

sub init {
  my $self = shift;
  #$self->SUPER::init();
  $self->batch_size(1);
  $self->carrying_capacity(20);
}

=head2 batch_size
  Arg [1] : (optional) string $value
  Title   :   batch_size
  Usage   :   $value = $self->batch_size;
              $self->batch_size($new_value);
  Description: Defines the number of jobs the RunnableDB subclasses should run in batch
               before querying the database for the next job batch.  Used by the
               Hive system to manage the number of workers needed to complete a
               particular job type.
  DefaultValue : 1
  Returntype : integer scalar
=cut

sub batch_size {
  my $self = shift;
  my $value = shift;

  $self->{'_batch_size'} = 1 unless($self->{'_batch_size'});
  $self->{'_batch_size'} = $value if($value);

  return $self->{'_batch_size'};
}

=head2 carrying_capacity
  Arg [1] : (optional) string $value
  Title   :   batch_size
  Usage   :   $value = $self->carrying_capacity;
              $self->carrying_capacity($new_value);
  Description: Defines the total number of Workers of this RunnableDB for a particular
               analysis_id that can be created in the hive.  Used by Queen to manage
               creation of Workers.
  DefaultValue : 1
  Returntype : integer scalar
=cut

sub carrying_capacity {
  my $self = shift;
  my $value = shift;

  $self->{'_carrying_capacity'} = 1 unless($self->{'_carrying_capacity'});
  $self->{'_carrying_capacity'} = $value if($value);

  return $self->{'_carrying_capacity'};
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  $self->throw("No input_id") unless defined($self->input_id);
  print("input_id = ".$self->input_id."\n");
  $self->throw("Improper formated input_id") unless ($self->input_id =~ /{/);

  my $input_hash = eval($self->input_id);
  my $genome_db_id = $input_hash->{'gdb'};
  print("gdb = $genome_db_id\n");
  $self->throw("No genome_db_id in input_id") unless defined($genome_db_id);
  
  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db);

  #get the Compara::GenomeDB object for the genome_db_id
  $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
  
  
  #using genome_db_id, connect to external core database
  $self->{'coreDBA'} = $self->connectGenomeCore($genome_db_id);

  #global boolean control value (whether the genes are also stored as members)
  $self->{'store_genes'} = 1;

  #variables for tracking success of process  
  $self->{'sliceCount'}       = 0;
  $self->{'geneCount'}        = 0;
  $self->{'realGeneCount'}    = 0;
  $self->{'transcriptCount'}  = 0;
  $self->{'longestCount'}     = 0;

  return 1;
}


sub run
{
  my $self = shift;

  # main routine which takes a genome_db_id (from input_id) and
  # access the ensembl_core database, useing the SliceAdaptor
  # it will load all slices, all genes, and all transscripts
  # and convert them into members to be stored into compara
  $self->loadMembersFromCoreSlices();
  

  # working from the longest peptide subset, create an analysis of
  # with logic_name 'SubmitPep_<taxon_id>_<assembly>'
  # with type MemberPep and fill the input_id_analysis table where
  # input_id is the member_id of a peptide and the analysis_id
  # is the above mentioned analysis
  #
  # This creates the starting point for the blasts (members against database)
  $self->submitSubsetForAnalysis();
                      
  return 1;
}

sub write_output 
{  
  my $self = shift;
  #need to subclass otherwise it defaults to a version that fails
  #just return 1 so success

  my $output_id = "{gdb=>" . $self->{'genome_db'}->dbID .
                  ",ss=>" . $self->{'pepSubset'}->dbID . "}";
  $self->input_id($output_id);                    
  return 1;
}


######################################
#
# subroutines
#
#####################################

sub connectGenomeCore
{
  #using genome_db_id, connect to external core database
  my $self = shift;
  my $genome_db_id = shift;
  my $genomeDBA;

  my $sql = "SELECT locator FROM genome_db_extn " .
            "WHERE genome_db_extn.genome_db_id=$genome_db_id;";
  my $sth = $self->{'comparaDBA'}->prepare( $sql );
  $sth->execute();

  my ($locator);
  $sth->bind_columns( undef, \$locator );

  if( $sth->fetch() ) {
    print("genome_db_id=$genome_db_id => $locator\n");
    $genomeDBA = Bio::EnsEMBL::DBLoader->new($locator);
  }
  $sth->finish();

  $self->throw("Can't connect to genome database for id=$genome_db_id")  unless($genomeDBA);

  return $genomeDBA;
}


sub loadMembersFromCoreSlices
{
  my $self = shift;

  #create subsets for the gene members, and the longest peptide members
  $self->{'pepSubset'}  = Bio::EnsEMBL::Compara::Subset->new(-name=>$self->{'genome_db'}->name . ' longest translations');
  $self->{'geneSubset'} = Bio::EnsEMBL::Compara::Subset->new(-name=>$self->{'genome_db'}->name . ' genes');

  $self->{'comparaDBA'}->get_SubsetAdaptor->store($self->{'pepSubset'});
  $self->{'comparaDBA'}->get_SubsetAdaptor->store($self->{'geneSubset'});


  #from core database, get all slices, and then all genes in slice
  #and then all transcripts in gene to store as members in compara
  my @slices = @{$self->{'coreDBA'}->get_SliceAdaptor->fetch_all('toplevel')};
  SLICE: foreach my $slice (@slices) {
    $self->{'sliceCount'}++;
    #print("slice " . $slice->name . "\n");
    foreach my $gene (@{$slice->get_all_Genes}) {
      $self->{'geneCount'}++;
      if((lc($gene->type) ne 'pseudogene') and (lc($gene->type) ne 'bacterial_contaminant')) {
        $self->{'realGeneCount'}++;
        $self->store_gene_and_all_transcripts($gene);
      }
      if($self->{'transcriptCount'} >= 100) { last SLICE; }
      # if($self->{'geneCount'} >= 1000) { last SLICE; }
    }
    # last SLICE;
  }

  print("loaded ".$self->{'sliceCount'}." slices\n");
  print("       ".$self->{'geneCount'}." genes\n");
  print("       ".$self->{'realGeneCount'}." real genes\n");
  print("       ".$self->{'transcriptCount'}." transscripts\n");
  print("       ".$self->{'longestCount'}." longest transscripts\n");
  print("       ".$self->{'pepSubset'}->count()." in Subset\n");
}


sub store_gene_and_all_transcripts
{
  my $self = shift;
  my $gene = shift;
  
  my @longestPeptideMember;
  my $maxLength=0;
  my $gene_member;

  my $MemberAdaptor = $self->{'comparaDBA'}->get_MemberAdaptor();

  if($self->{'store_genes'}) {
    print("     gene       " . $gene->stable_id );
    $gene_member = Bio::EnsEMBL::Compara::Member->new_from_gene(
                   -gene=>$gene,
                   -genome_db=>$self->{'genome_db'});
    print(" => member " . $gene_member->stable_id);

    eval {
      $MemberAdaptor->store($gene_member);
      print(" : stored");
    };

    $self->{'geneSubset'}->add_member($gene_member);
    print("\n");
  }

  foreach my $transcript (@{$gene->get_all_Transcripts}) {
    $self->{'transcriptCount'}++;
    #print("gene " . $gene->stable_id . "\n");
    print("     transcript " . $transcript->stable_id );

    unless (defined $transcript->translation) {
      warn("\nCOREDB error: No translation for transcript transcript_id" . $transcript->dbID."\n");
      next; #only use for Chimp
    }

    unless (defined $transcript->translation->stable_id) {
      warn("\nCOREDB error: does not contain translation stable id for translation_id ".$transcript->translation->dbID."\n");
      next; #only use for Chimp
    }

    my $description = $self->fasta_description($gene, $transcript);
    my $pep_member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
         -transcript=>$transcript,
         -genome_db=>$self->{'genome_db'},
         -translate=>'yes',
         -description=>$description);

    print(" => member " . $pep_member->stable_id);

    eval {
      $MemberAdaptor->store($pep_member);
      $MemberAdaptor->store_gene_peptide_link($gene_member->dbID, $pep_member->dbID);
      print(" : stored");
    };


    if($pep_member->seq_length > $maxLength) {
      $maxLength = $pep_member->seq_length;
      @longestPeptideMember = ($transcript, $pep_member);
    }

    print("\n");
  }

  if(@longestPeptideMember) {
    my ($transcript, $member) = @longestPeptideMember;
    $self->{'pepSubset'}->add_member($member);
    $self->{'longestCount'}++;
    # print("     LONGEST " . $transcript->stable_id . "\n");
  }
}


sub fasta_description {
  my ($self, $gene, $transcript) = @_;

  my $description = "Transcript:" . $transcript->stable_id .
                    " Gene:" .      $gene->stable_id .
                    " Chr:" .       $gene->seq_region_name .
                    " Start:" .     $gene->seq_region_start .
                    " End:" .       $gene->seq_region_end;
  return $description;
}


# working from the longest peptide subset, create an analysis of
# with logic_name 'SubmitPep_<taxon_id>_<assembly>'
# with type MemberPep and fill the input_id_analysis table where
# input_id is the member_id of a peptide and the analysis_id
# is the above mentioned analysis
#
# This creates the starting point for the blasts (members against database)
sub submitSubsetForAnalysis {
  my $self    = shift;
  my $subset  = $self->{'pepSubset'};
  
  print("\nSubmitSubsetForAnalysis\n");

  #my $sicDBA = $self->db->get_StateInfoContainer;  # $self->db is a pipeline DBA
  my $jobDBA = $self->db->get_AnalysisJobAdaptor;

  my $logic_name = "SubmitPep_" .
                   $self->{'genome_db'}->dbID() .
                   "_".$self->{'genome_db'}->assembly();

  print("  see if analysis '$logic_name' is in database\n");                   
  my $analysis =  $self->db->get_AnalysisAdaptor->fetch_by_logic_name($logic_name);
  if($analysis) { print("  YES in database with analysis_id=".$analysis->dbID()); }
  
  unless($analysis) {                   
    $analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
        #-db              => $blastdb->dbname(),
        -db_file         => $subset->dump_loc(),
        -db_version      => '1',
        -parameters      => "subset_id=>" . $subset->dbID().",genome_db_id=>".$self->{'genome_db'}->dbID(),
        -logic_name      => $logic_name,
        -input_id_type   => 'MemberPep',
        -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Dummy',
      );
    $self->db->get_AnalysisAdaptor()->store($analysis);
  }

  #my $host = hostname();
  print("store member_id into input_id_analysis table\n");
  my $errorCount=0;
  my $tryCount=0;
  my @member_id_list = @{$subset->member_id_list()};
  print($#member_id_list+1 . " members in subset\n");

  foreach my $member_id (@member_id_list) {
    $jobDBA->create_new_job (
        -input_id       => $member_id,
        -analysis_id    => $analysis->dbID,
        -input_job_id   => 0,
        -block          => 1
        );
  }

  print("CREATED all analysis_jobs\n");
      

=head3
      eval {
        $tryCount++;
        $sicDBA->store_input_id_analysis($member_id, #input_id
                                         $analysis,
                                         'gaia', #execution_host
                                         0 #save runtime NO (ie do insert)
                                        );
      };
      if($@) {
        $errorCount++;
        if($errorCount>42 && ($errorCount/$tryCount > 0.95)) {
          die("too many repeated failed insert attempts, assume will continue for durration. ACK!!\n");
        }
      } # should handle the error, but ignore for now
    }
  };
=cut


  return $logic_name;
}

1;
