#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::LoadUniProt

=cut

=head1 DESCRIPTION

This object uses the getz and pfetch command line programs to access
the SRS database of Uniprot sequences.
Its purpose is to load protein sequences from Uniprot into the compara 
database.
Right now it has hard coded filters of a minimum sequence length of 80
and taxon in metazoa and distinguishes SWISSPROT from SPTREMBL.

The format of the input_id follows the format of a perl hash reference
example:
  "{srs=>'uniprot', taxon_id=>4932}" 
  #loads all uniprot for S. cerevisiae

keys:
  srs => valid values 'swissprot', 'sptrembl', 'uniprot'
  taxon_id => <taxon_id>
       optional if one want to load from a specific species
       if not specified it will load all 'metazoa' from the srs source
  genome_db_id => <genome_db_id>
       optional: will associate this loaded set into the specified 
       GenomeDB does not create genome_db entry, assumes it was already 
       created.  Use prudently since it does no checks
  accession_number => 0/1 (default is 1=on)
       optional if one want to load Accession Number (AC) (DEFAULT) as 
       stable_id rather than Entry Name (ID) 
more examples:
  "{srs=>'swissprot'}" #loads all swissprot metazoa
  "{srs=>'swissprot', taxon_id=>4932}"
  "{srs=>'sptrembl', taxon_id=>4932}"

=cut

=head1 CONTACT

  Contact Jessica Severin on LoadUniprot implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL::Compara in general: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadUniProt;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;

use Bio::EnsEMBL::Hive;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

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

  $self->{'source'} = 'SWISSPROT';
  $self->{'taxon_id'} = undef;  #no ncbi_taxid filter, get all metzoa
  $self->{'genome_db_id'} = undef;
  $self->{'accession_number'} = 1;
  $self->debug(0);
  if(defined($self->input_id)) {
    #print("input_id = ".$self->input_id."\n");
    my $input_hash = eval($self->input_id);
    if(defined($input_hash)) {
      $self->{'accession_number'} = $input_hash->{'accession_number'} if(defined($input_hash->{'accession_number'}));
      $self->{'source'} = $input_hash->{'srs'} if(defined($input_hash->{'srs'}));
      $self->{'taxon_id'} = $input_hash->{'taxon_id'} if(defined($input_hash->{'taxon_id'}));
      $self->{'genome_db_id'} = $input_hash->{'genome_db_id'} if(defined($input_hash->{'genome_db_id'}));
    }
  }
    
  return 1;
}


sub run
{
  my $self = shift;

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  $self->{internal_taxon_ids};
  foreach my $genome_db (@{$self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all}) {
    $self->{internal_taxon_ids}{$genome_db->taxon_id} = 1;
  }

  return unless($self->{'source'});

  my $subset_name = $self->{'source'};
  
  my $uniprot_ids = [];
  my %allowed_taxon_ids = {};
  if($self->{'taxon_id'}) {
    $subset_name .= " ncbi_taxid:" . $self->{'taxon_id'};
    $uniprot_ids = $self->fetch_all_uniprot_ids_for_taxid($self->{'source'}, $self->{'taxon_id'});
    $allowed_taxon_ids{$self->{'taxon_id'}} = 1;
  } else {
    $subset_name .= " metazoa";
    $uniprot_ids = $self->get_metazoa_uniprot_ids($self->{'source'});

    # Fungi/Metazoa group
    my $taxon_id = 33154;
    my $node = $self->{'comparaDBA'}->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($taxon_id);

    #    foreach my $leaf ( @{$node->get_all_leaves} ) {
    # the indexed method should be much faster when data has left and right indexes built
    foreach my $leaf ( @{$node->get_all_leaves_indexed} ) {
      $allowed_taxon_ids{$leaf->node_id} = 1;
      if ($leaf->rank ne "species") {
        $allowed_taxon_ids{$leaf->parent->node_id} = 1;
      }
    }
    $node->release_tree;
  }

  $self->{'subset'}  = Bio::EnsEMBL::Compara::Subset->new(-name=>$subset_name);
  $self->{'comparaDBA'}->get_SubsetAdaptor->store($self->{'subset'});
  $self->{'allowed_taxon_ids'} = \%allowed_taxon_ids;

  $self->loadMembersFromUniprotIdList($self->{'source'}, $uniprot_ids);
  
  return 1;
}


sub write_output 
{  
  my $self = shift;

  my $outputHash = {};
  $outputHash = eval($self->input_id) if(defined($self->input_id));
  $outputHash->{'ss'} = $self->{'subset'}->dbID;
  $outputHash->{'gdb'} = $self->{'genome_db_id'} if($self->{'genome_db_id'});
  my $output_id = $self->encode_hash($outputHash);
  
  $self->input_job->input_id($output_id);

  if($self->{'genome_db_id'}) {
    $self->dataflow_output_id($output_id, 2);
  }
  return 1;
}


######################################
#
# subroutines
#
#####################################


sub loadMembersFromUniprotIdList
{
  my $self = shift;
  my $source = shift;
  my $uniprot_ids = shift;  #array ref
  
  my @id_chunk; 

  my $count = scalar(@$uniprot_ids);
  
# while(@uniprot_ids) {
#   @id_chunk = splice(@uniprot_ids, 0, 30);
#   $self->pfetch_and_store_by_ids($source, @id_chunk);
# }

  my $index=1;
  foreach my $id (@$uniprot_ids) {
    $index++;
    print("check/load $index ids\n") if($index % 100 == 0 and $self->debug);
    my $stable_id = $id;
    $stable_id = $1 if($id =~ /^(\S+)\.\d+$/);
    my $member = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_source_stable_id('Uniprot/'.$source, $stable_id);
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

  printf("fetched %d ids from %s\n", $count, $source) if($self->debug);
}


sub get_metazoa_uniprot_ids
{
  my $self   = shift;
  my $source = shift;  #'swissprot' or 'sptrembl'

  my @taxonomy_division = qw(FUN HUM MAM ROD VRT INV);
  my $division = "STD";
  $division = "PRE" if ($source eq "SPTREMBL");
  my @all_ids;
  foreach my $txd (@taxonomy_division) {
    my $cmd = "mfetch -d uniprot -v av -i 'txd:$txd&div:$division'";
    print("$cmd\n") if($self->debug);
    my @ids = split(/\s/, qx/$cmd/);
    push @all_ids, @ids;
  }
  printf("fetched %d ids from %s\n", scalar(@all_ids), $source) if($self->debug);
  return \@all_ids;
}


sub fetch_all_uniprot_ids_for_taxid
{
  my $self   = shift;
  my $source = shift;  #'uniprot', 'swissprot' or 'sptrembl'
  my $taxon_id = shift;
  my $division = "STD";
  $division = "PRE" if ($source eq "SPTREMBL");

  my $cmd = "mfetch -d uniprot -v av -i 'txi:$taxon_id&div:$division'";

  print("$cmd\n") if($self->debug);
  my @ids = split(/\s/, qx/$cmd/);
  printf("fetched %d ids from %s\n", scalar(@ids), $source) if($self->debug);
  return \@ids;
}


sub pfetch_and_store_by_ids {
  my $self = shift;
  my $source = shift;

#  my @orig_ids = @_;
#  my @ids;
  my @ids = @_;

#  foreach my $id (@orig_ids) {
#    if($id =~ /(.*)\:(.*)/) {
#      #$source = $1;
#      $id = $2;
#    }
#    push @ids, $id;
#  }
  return unless(@ids);
  my $id_string = join(' ', @ids);

  open(IN, "pfetch -F $id_string |")
    or $self->throw("Error running pfetch for ids [$id_string]");

  print STDERR "$id_string\n";
  my $fh = Bio::SeqIO->new(-fh=>\*IN, -format=>"swiss");
  my $nb_seq = 0;
  while (my $seq = $fh->next_seq){
    next if ($seq->length < 80);

    ####################################################################
    # This bit is to avoid duplicated entries btw Ensembl and Uniprot
    # It only affects the Ensembl species dbs, and right now I am using
    # a home-brewed version of Bio::SeqIO::swiss to parse the PE entries
    # in a similar manner as comments (CC) but of type 'evidence'
    $DB::single=1;1;
    my $taxon_id; eval { $taxon_id = $seq->species->ncbi_taxid;};
    if (defined($self->{internal_taxon_ids}{$taxon_id})) {
      my $evidence_annotations = $seq->get_Annotations('evidence');
      if (defined $evidence_annotations) {
        if ($evidence_annotations->text =~ /^4/) {
          print STDERR $seq->display_id, "PE discarded ", $evidence_annotations->text, "\n";
          next;
        }
        # We dont want duplicated entries
      }
    }
    ####################################################################

    $self->store_bioseq($seq, $source);
    $nb_seq++;
  }
  close IN;
  if ($self->debug && $nb_seq != scalar @ids) {
    print "Expected ", scalar @ids," seqs but only $nb_seq seen from $id_string\n";
  }
}


sub store_bioseq
{
  my $self = shift;
  my $bioseq = shift;
  my $source = shift;

  if ($source =~ /swissprot/i) {
    $source = "Uniprot/SWISSPROT";
  } elsif ($source =~ /sptrembl/i) {
    $source = "Uniprot/SPTREMBL";
  }

  return unless($bioseq);
  my $species = $bioseq->species;
  return unless($species);

  if($self->debug) {
    printf("store_bioseq %s %s : %d : %s", $source, $bioseq->display_id, $species->ncbi_taxid, $species->species);
  }
   
  my $taxon = $self->{'comparaDBA'}->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($species->ncbi_taxid);
  unless($taxon) {
    #taxon not in compara, do not store the member and warn
    warning("Taxon id " . $species->ncbi_taxid . " from $source " . $bioseq->accession_number ." not in the database.
Member not stored.");
    return 1;
  }
  unless ($self->{'allowed_taxon_ids'}{$taxon->dbID}) {
    return 1;
  }

  my $member = new Bio::EnsEMBL::Compara::Member;
  if (defined $self->{'accession_number'} && $self->{'accession_number'} == 1) {
    $member->stable_id($bioseq->accession_number);
  } else {
    $member->stable_id($bioseq->display_id);
  }
  $member->display_label($bioseq->display_id);
  $member->taxon_id($taxon->dbID);
  $member->description($bioseq->desc);
  $member->source_name($source);
  $member->sequence($bioseq->seq);
  $member->genome_db_id($self->{'genome_db_id'}) if($self->{'genome_db_id'});

  eval {
    $self->{'comparaDBA'}->get_MemberAdaptor->store($member);
    print(" --stored") if($self->debug);
  };

  $self->{'subset'}->add_member($member);
  print("\n") if($self->debug);
  return 1;
}


1;
