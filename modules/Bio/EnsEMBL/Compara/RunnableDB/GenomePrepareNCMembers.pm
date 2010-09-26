#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomePrepareNCMembers

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $g_load_members = Bio::EnsEMBL::Compara::RunnableDB::GenomePrepareNCMembers->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$g_load_members->fetch_input(); #reads from DB
$g_load_members->run();
$g_load_members->output();
$g_load_members->write_output(); #writes to DB

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

package Bio::EnsEMBL::Compara::RunnableDB::GenomePrepareNCMembers;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

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
  if($input_hash->{'pseudo_stableID_prefix'}) {
    $self->{'pseudo_stableID_prefix'} = $input_hash->{'pseudo_stableID_prefix'};
  }

  my $p = eval($self->analysis->parameters);
  $self->{p} = $p;

  $self->{memberDBA} = $self->compara_dba->get_MemberAdaptor();

  #get the Compara::GenomeDB object for the genome_db_id
  $self->{'genome_db'} = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
  
  
  #using genome_db_id, connect to external core database
  $self->{'coreDBA'} = $self->{'genome_db'}->db_adaptor();  
  $self->throw("Can't connect to genome database for id=$genome_db_id") unless($self->{'coreDBA'});
  
  #global boolean control value (whether the genes are also stored as members)
  $self->{'store_genes'} = 1;

  $self->{'verbose'} = 0;

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

  $self->compara_dba->dbc->disconnect_when_inactive(0);
  $self->{'coreDBA'}->dbc->disconnect_when_inactive(0);

  # main routine which takes a genome_db_id (from input_id) and
  # access the ensembl_core database, useing the SliceAdaptor
  # it will load all slices, all genes, and all transcripts
  # and convert them into members to be stored into compara
  $self->prepareMembersFromCoreSlices();

  $self->compara_dba->dbc->disconnect_when_inactive(1);
  $self->{'coreDBA'}->dbc->disconnect_when_inactive(1);

  return 1;
}

sub write_output 
{
  my $self = shift;

  return 1;
}


######################################
#
# subroutines
#
#####################################


sub prepareMembersFromCoreSlices
{
  my $self = shift;

  #create subsets for the gene members, and the longest peptide members
  $self->{'pepSubset'}  = Bio::EnsEMBL::Compara::Subset->new(
      -name=>"gdb:".$self->{'genome_db'}->dbID ." ". $self->{'genome_db'}->name . ' longest translations');
  $self->{'geneSubset'} = Bio::EnsEMBL::Compara::Subset->new(
      -name=>"gdb:".$self->{'genome_db'}->dbID ." ". $self->{'genome_db'}->name . ' genes');

  $self->compara_dba->get_SubsetAdaptor->store($self->{'pepSubset'});
  $self->compara_dba->get_SubsetAdaptor->store($self->{'geneSubset'});

  #from core database, get all slices, and then all genes in slice
  #and then all transcripts in gene to store as members in compara
  my @slices = @{$self->{'coreDBA'}->get_SliceAdaptor->fetch_all('toplevel')};
  print("fetched ",scalar(@slices), " slices to load from\n");
  throw("problem: no toplevel slices") unless(scalar(@slices));

  # Make sure we only flow the jobs for each gene that is found, and
  # not a useless autoflow when non genes are found.
  $self->input_job->autoflow(0);

  SLICE: foreach my $slice (@slices) {
    $self->{'sliceCount'}++;
    #print("slice " . $slice->name . "\n");
    foreach my $gene (sort {$a->start <=> $b->start} @{$slice->get_all_Genes}) {
      $self->{'geneCount'}++;

      # LV and C are for the Ig/TcR family, which rearranges
      # somatically so is considered as a different biotype in EnsEMBL
      # D and J are very short or have no translation at all
      if ($self->{p}{type} =~ /ncrna/i) {
        if ($gene->biotype =~ /rna/i) {
        # if ($gene->analysis->logic_name eq 'ncRNA') {
          $self->{'realGeneCount'}++;
          my $output_id = $self->input_id;
          my $gene_stable_id = $gene->stable_id;
          $output_id =~ s/\}/'stable_id'=>'$gene_stable_id'\}/;
          $self->dataflow_output_id($output_id, 1);
          print STDERR $self->{'realGeneCount'} , " ncRNA genes sent to store analysis\n" if ($self->debug && (0 == ($self->{'realGeneCount'} % 10)));
        }
      }
      # if($self->{'transcriptCount'} >= 100) { last SLICE; }
      # if($self->{'geneCount'} >= 1000) { last SLICE; }
    }
    # last SLICE;
  }

  print("loaded ".$self->{'sliceCount'}." slices\n");
  print("       ".$self->{'geneCount'}." genes\n");
  print("       ".$self->{'realGeneCount'}." real genes\n");
  print("       ".$self->{'transcriptCount'}." transcripts\n");
  print("       ".$self->{'longestCount'}." longest transcripts\n");
  print("       ".$self->{'pepSubset'}->count()." in Subset\n");
}

1;
