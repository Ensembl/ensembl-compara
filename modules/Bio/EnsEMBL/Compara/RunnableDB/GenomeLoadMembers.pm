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
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;

use Bio::EnsEMBL::Pipeline::RunnableDB;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

=head2 batch_size
  Title   :   batch_size
  Usage   :   $value = $self->batch_size;
  Description: Defines the number of jobs the RunnableDB subclasses should run in batch
               before querying the database for the next job batch.  Used by the
               Hive system to manage the number of workers needed to complete a
               particular job type.
  Returntype : integer scalar
=cut
sub batch_size { return 1; }

=head2 carrying_capacity
  Title   :   carrying_capacity
  Usage   :   $value = $self->carrying_capacity;
  Description: Defines the total number of Workers of this RunnableDB for a particular
               analysis_id that can be created in the hive.  Used by Queen to manage
               creation of Workers.
  Returntype : integer scalar
=cut
sub carrying_capacity { return 20; }


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
  $self->{'coreDBA'} = $self->{'genome_db'}->connect_to_genome_locator();
  $self->throw("Can't connect to genome database for id=$genome_db_id") unless($self->{'coreDBA'});
  
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

  $self->{'comparaDBA'}->disconnect_when_inactive(0);
  $self->{'coreDBA'}->disconnect_when_inactive(0);  
  
  # main routine which takes a genome_db_id (from input_id) and
  # access the ensembl_core database, useing the SliceAdaptor
  # it will load all slices, all genes, and all transscripts
  # and convert them into members to be stored into compara
  $self->loadMembersFromCoreSlices();
  
  $self->{'comparaDBA'}->disconnect_when_inactive(1);
  $self->{'coreDBA'}->disconnect_when_inactive(1);
                                          
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
#      if((lc($gene->type) ne 'pseudogene') and (lc($gene->type) ne 'bacterial_contaminant')) {
      if((lc($gene->type) ne 'pseudogene') and 
         (lc($gene->type) ne 'bacterial_contaminant') and
         ($gene->type !~ /RNA/i)) {
        $self->{'realGeneCount'}++;
        $self->store_gene_and_all_transcripts($gene);
      }
      # if($self->{'transcriptCount'} >= 100) { last SLICE; }
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


1;
