#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::LoadUniProt

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::LoadUniProt->new (
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

package Bio::EnsEMBL::Compara::RunnableDB::LoadUniProt;

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
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  #create subsets for the gene members, and the longest peptide members
  $self->{'subset'}  = Bio::EnsEMBL::Compara::Subset->new(-name=>'uniprot');
  $self->{'comparaDBA'}->get_SubsetAdaptor->store($self->{'subset'});

  $self->{'source'} = undef;

  if(defined($self->input_id)) {
    print("input_id = ".$self->input_id."\n");
    my $input_hash = eval($self->input_id);
    $self->{'source'} = $input_hash->{'srs'} if(defined($input_hash));
  }

  my $taxon = $self->{'comparaDBA'}->get_TaxonAdaptor->fetch_by_dbID(8790);
  
  return 1;
}


sub run
{
  my $self = shift;

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  if($self->{'source'}) {
    $self->loadMembersFromUniprot($self->{'source'});
  } else {
    $self->loadMembersFromUniprot('SWISSPROT');
    #$self->loadMembersFromUniprot('SPTREMBL');
  }
                                            
  return 1;
}


sub write_output 
{  
  my $self = shift;
  #need to subclass otherwise it defaults to a version that fails
  #just return 1 so success

  my $output_id =  "{ss=>" . $self->{'subset'}->dbID . "}";
  print("output_id = $output_id\n");
  $self->input_id($output_id);                    
  return 1;
}


######################################
#
# subroutines
#
#####################################


sub loadMembersFromUniprot
{
  my $self = shift;
  my $source = shift;

  my @uniprot_ids = $self->get_uniprot_ids($source);
  my @id_chunk; 

  my $count = scalar(@uniprot_ids);
  
# while(@uniprot_ids) {
#   @id_chunk = splice(@uniprot_ids, 0, 30);
#   $self->pfetch_and_store_by_ids($source, @id_chunk);
# }

  my $index=1;
  foreach my $id (@uniprot_ids) {
    $index++;
    print("check/load $index ids\n") if($index % 100 == 0);
    my $stable_id = $id;
    $stable_id = $1 if($id =~ /$source:(.*)/);
    my $member = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_source_stable_id($source, $stable_id);
    if($member and $member->sequence_id) {
      #print("$source $stable_id : already loadled in compara\n");
    } else {
      #print("need to load $index : $source $stable_id\n");
      push @id_chunk, $id;
    }
    if(scalar(@id_chunk)>=30) {
      $self->pfetch_and_store_by_ids($source, @id_chunk);
      @id_chunk = ();
    }
  }
  $self->pfetch_and_store_by_ids($source, @id_chunk);

  printf("fetched %d ids from %s\n", $count, $source);
}


sub get_uniprot_ids
{
  my $self   = shift;
  my $source = shift;  #'uniprot', 'swissprot' or 'sptrembl'

  my $cmd = "getz ".
            "\"((([$source-tax: metazoa] ".
              " ! [$source-org: */*]) ".
              " ! [$source-org: *'\''*]) ".
              " & [$source-SeqLength# 80:])\"";

  print("$cmd\n");
  my @ids = split(/\s/, qx/$cmd/);
  printf("fetched %d ids from %s\n", scalar(@ids), $source);
  return @ids;
}


sub pfetch_and_store_by_ids {
  my $self = shift;
  my $source = shift;

  my @orig_ids = @_;
  my @ids;

  foreach my $id (@orig_ids) {
    if($id =~ /(.*)\:(.*)/) {
      #$source = $1;
      $id = $2;
    }
    push @ids, $id;
  }
  return unless(@ids);

  my $id_string = join(' ', @ids);

  open(IN, "pfetch -F $id_string |")
    or $self->throw("Error running pfetch for ids [$id_string]");

  my $fh = Bio::SeqIO->new(-fh=>\*IN, -format=>"swiss");

  while (my $seq = $fh->next_seq){
    $self->store_bioseq($seq, $source);
  }
  close IN;
}


sub store_bioseq
{
  my $self = shift;
  my $bioseq = shift;
  my $source = shift;

  return unless($bioseq);
  my $species = $bioseq->species;
  return unless($species);

  printf("store_bioseq %s %s : %d : %s", $source, $bioseq->display_id, $species->ncbi_taxid, $species->species);
   
  my $taxon = $self->{'comparaDBA'}->get_TaxonAdaptor->fetch_by_dbID($species->ncbi_taxid);
  unless($taxon) {
    #taxon not in compara, so create and store
    $taxon = $species;
    bless $taxon, "Bio::EnsEMBL::Compara::Taxon";
    $self->{'comparaDBA'}->get_TaxonAdaptor->store($taxon);
  }

  my $member = new Bio::EnsEMBL::Compara::Member;

  $member->stable_id($bioseq->display_id);
  $member->taxon_id($taxon->dbID);
  $member->description($bioseq->desc);
  $member->source_name($source);
  $member->sequence($bioseq->seq);

  eval {
    $self->{'comparaDBA'}->get_MemberAdaptor->store($member);
    print(" --stored");
  };

  $self->{'subset'}->add_member($member);
  print("\n");
}


1;
