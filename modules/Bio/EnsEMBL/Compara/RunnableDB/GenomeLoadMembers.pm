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
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Pipeline::Runnable::Blast;
use Bio::EnsEMBL::Pipeline::Runnable::BlastDB;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;


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

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db);

  #using genome_db_id, connect to external core database
  $self->{'coreDBA'} = $self->connectGenomeCore($self->input_id);

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

  my $genome_db_id = $self->input_id();

  #get the Compara::GenomeDB object for the genome_db_id
  $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);

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
    #print(STDERR "slice " . $slice->name . "\n");
    foreach my $gene (@{$slice->get_all_Genes}) {
      $self->{'geneCount'}++;
      if((lc($gene->type) ne 'pseudogene') and (lc($gene->type) ne 'bacterial_contaminant')) {
        $self->{'realGeneCount'}++;
        $self->store_gene_and_all_transcripts($gene);
      }
      #if($transcriptCount >= 1000) { last SLICE; }
      #if($geneCount >= 1000) { last SLICE; }
    }
    #last SLICE;
  }

  print("loaded ".$self->{'sliceCount'}." slices\n");
  print("       ".$self->{'geneCount'}." genes\n");
  print("       ".$self->{'realGeneCount'}." real genes\n");
  print("       ".$self->{'transcriptCount'}." transscripts\n");
  print("       ".$self->{'longestCount'}." longest transscripts\n");
  print("       ".$self->{'pepSubset'}->count()." in Subset\n");
        
}


sub write_output {
  my $self = shift;

  # using the genome_db and longest peptides subset, create a fasta
  # file which can be used as a blast database
  #$self->dumpPeptidesToFasta();

  # working from the longest peptide subset, create an analysis of
  # with logic_name 'SubmitPep_<taxon_id>_<assembly>'
  # with type MemberPep and fill the input_id_analysis table where
  # input_id is the member_id of a peptide and the analysis_id
  # is the above mentioned analysis
  #
  # This creates the starting point for the blasts (members against database)
  $self->submitSubsetForAnalysis();

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


sub store_gene_and_all_transcripts
{
  my $self = shift;
  my $gene = shift;
  
  my @longestPeptideMember;
  my $maxLength=0;
  my $gene_member;

  my $MemberAdaptor = $self->{'comparaDBA'}->get_MemberAdaptor();

  if($self->{'store_genes'}) {
    print(STDERR "     gene       " . $gene->stable_id );
    $gene_member = Bio::EnsEMBL::Compara::Member->new_from_gene(
                   -gene=>$gene,
                   -genome_db=>$self->{'genome_db'});
    print(STDERR " => member " . $gene_member->stable_id);

    $MemberAdaptor->store($gene_member);
    print(STDERR " : stored");

    $self->{'geneSubset'}->add_member($gene_member);
    print(STDERR "\n");
  }

  foreach my $transcript (@{$gene->get_all_Transcripts}) {
    $self->{'transcriptCount'}++;
    #print(STDERR "gene " . $gene->stable_id . "\n");
    print(STDERR "     transcript " . $transcript->stable_id );

    unless (defined $transcript->translation) {
      $self->throw("COREDB error: No translation for transcript transcript_id" . $transcript->dbID);
    }

    unless (defined $transcript->translation->stable_id) {
      $self->throw("COREDB error: does not contain translation stable id for translation_id ".$transcript->translation->dbID);
    }

    my $description = $self->fasta_description($gene, $transcript);
    my $pep_member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
         -transcript=>$transcript,
         -genome_db=>$self->{'genome_db'},
         -translate=>'yes',
         -description=>$description);

    print(STDERR " => member " . $pep_member->stable_id);

    $MemberAdaptor->store($pep_member);
    $MemberAdaptor->store_gene_peptide_link($gene_member->dbID, $pep_member->dbID);
    print(STDERR " : stored");


    if($pep_member->seq_length > $maxLength) {
      $maxLength = $pep_member->seq_length;
      @longestPeptideMember = ($transcript, $pep_member);
    }

    print(STDERR "\n");
  }

  if(@longestPeptideMember) {
    my ($transcript, $member) = @longestPeptideMember;
    #fasta_output($gene, @longestPeptideMember);
    $self->{'pepSubset'}->add_member($member);
    #print(STDERR "     LONGEST " . $transcript->stable_id . "\n");
    $self->{'longestCount'}++;
  }
  #if($longestCount >= 1000) { last SLICE; }
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


sub submitSubsetForAnalysis {
  my $self    = shift;
  my $subset  = $self->{'pepSubset'};
  
  print("\nSubmitSubsetForAnalysis\n");

  my $sicDBA = $self->db->get_StateInfoContainer;  # $self->db is a pipeline DBA

  my $logic_name = "SubmitPep_" .
                   $self->{'genome_db'}->dbID() .
                   "_".$self->{'genome_db'}->assembly();

  my $analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      #-db              => $blastdb->dbname(),
      -db_file         => $subset->dump_loc(),
      -db_version      => '1',
      -parameters      => "subset_id=" . $subset->dbID().";genome_db_id=".$self->{'genome_db'}->dbID(),
      -logic_name      => $logic_name,
      -input_id_type   => 'MemberPep'
    );
  $self->db->get_AnalysisAdaptor()->store($analysis);

  #my $host = hostname();
  print("store using sic\n");
  my $errorCount=0;
  my $tryCount=0;
  eval {
    foreach my $member_id (@{$subset->member_id_list()}) {
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
      if($tryCount>=5) { last; }
    }
  };
  print("CREATED all input_id_analysis\n");

  return $logic_name;
}

=head1
sub dumpPeptidesToFasta
{
  my $self = shift;

  # create logical path name for fastafile
  my $species = $self->{'genome_db'}->name();
  $species =~ s/\s+/_/g;  # replace whitespace with '_' characters

  my $fastafile = $fastadir . "/" .
                  $species . "_" .
                  $self->{'genome_db'}->assembly() . ".fasta";
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  print("fastafile = '$fastafile'\n");

  # write fasta file
  $comparaDBA->get_SubsetAdaptor->dumpFastaForSubset($self->{'pepSubset'}, $fastafile);

  # configure the fasta file for use as a blast database file
  my $blastdb     = new Bio::EnsEMBL::Pipeline::Runnable::BlastDB (
      -dbfile     => $fastafile,
      -type       => 'PROTEIN');
  $blastdb->run;
  print("registered ". $blastdb->dbname . " for ".$blastdb->dbfile . "\n");

  # create blast analysis
}
=cut

=head3
  #
  # now add the 'blast' analysis
  #
  $logic_name = "blast_" . $genome->assembly();
  my $analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db              => "subset_id=" . $subset->dbID().";genome_db_id=".$genome->dbID,
      -db_file         => $subset->dump_loc(),
      -db_version      => '1',
      -logic_name      => $logic_name,
      -input_id_type   => 'MemberPep'
    );

  $pipelineDBA->get_AnalysisAdaptor()->store($analysis);



  my $logic_name = "blast_" . $species1Ptr->{abrev};
  print("build analysis $logic_name\n");
  my %analParams = %analysis_template;
  $analParams{'-logic_name'}    = $logic_name;
  $analParams{'-input_id_type'} = $species1Ptr->{condition}->input_id_type();
  $analParams{'-db'}            = $species2Ptr->{abrev};
  $analParams{'-db_file'}       = $species2Ptr->{condition}->db_file();
  my $analysis = new Bio::EnsEMBL::Pipeline::Analysis(%analParams);
  $db->get_AnalysisAdaptor->store($analysis);
=cut

1;
