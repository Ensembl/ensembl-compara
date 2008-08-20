#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadExonMembers

=cut

=head1 SYNOPSIS


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

package Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadExonMembers;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;
use Bio::EnsEMBL::Utils::Exception;

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
  
  throw("No input_id") unless defined($self->input_id);
  print("input_id = ".$self->input_id."\n");
  throw("Improper formated input_id") unless ($self->input_id =~ /^\s*\{/);
  
  my $input_hash = eval($self->input_id);
  my $genome_db_id = $input_hash->{'gdb'};
  print("gdb = $genome_db_id\n");
  throw("No genome_db_id in input_id") unless defined($genome_db_id);

  throw("Improper formated analysis parameters") unless ($self->analysis->parameters =~ /^\s*\{/);
  $input_hash = eval($self->analysis->parameters);
  my $min_length = $input_hash->{'min_length'};
  $min_length = 0 unless (defined $min_length);
  $self->min_length($min_length);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  #get the Compara::GenomeDB object for the genome_db_id
  $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
  
  
  #using genome_db_id, connect to external core database
  $self->{'coreDBA'} = $self->{'genome_db'}->db_adaptor();
  throw("Can't connect to genome database for id=$genome_db_id") unless($self->{'coreDBA'});
  
  #global boolean control value (whether the genes are also stored as members)
  $self->{'store_genes'} = 1;

  $self->{'verbose'} = 0;

  #variables for tracking success of process
  $self->{'sliceCount'}       = 0;
  $self->{'geneCount'}        = 0;
  $self->{'realGeneCount'}    = 0;
  $self->{'transcriptCount'}  = 0;
  $self->{'exonCount'}  = 0;

  return 1;
}


sub run
{
  my $self = shift;

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  $self->{'coreDBA'}->dbc->disconnect_when_inactive(0);  

  # main routine which takes a genome_db_id (from input_id) and
  # access the ensembl_core database, useing the SliceAdaptor
  # it will load all slices, all genes, and all transscripts
  # and convert them into members to be stored into compara
  $self->loadCodingExonMembersFromCoreSlices();

  return 1;
}

sub write_output 
{  
  my $self = shift;
  #need to subclass otherwise it defaults to a version that fails
  #just return 1 so success

  my $output_id = "{gdb=>" . $self->{'genome_db'}->dbID .
                   ",ss=>" . $self->{'exonSubset'}->dbID . "}";
  $self->dataflow_output_id($output_id);
  return 1;
}


######################################
#
# subroutines
#
#####################################


sub loadCodingExonMembersFromCoreSlices
{
  my $self = shift;

  #create subsets for the gene members, and the longest peptide members
  $self->{'exonSubset'}  = Bio::EnsEMBL::Compara::Subset->new(
-name=>"gdb:".$self->{'genome_db'}->dbID ." ". $self->{'genome_db'}->name . ' coding exons');

  $self->{'comparaDBA'}->get_SubsetAdaptor->store($self->{'exonSubset'});
  my $dfa = $self->{'comparaDBA'}->get_DnafragAdaptor;

  #from core database, get all slices, and then all genes in slice
  #and then all transcripts in gene to store as members in compara
  my @slices = @{$self->{'coreDBA'}->get_SliceAdaptor->fetch_all('toplevel')};
  print("fetched ",scalar(@slices), " slices to load from\n");
  foreach my $slice (@slices) {
    my $df = new Bio::EnsEMBL::Compara::DnaFrag
      (-name => $slice->seq_region_name,
       -length => $slice->length,
       -coord_system_name => $slice->coord_system->name,
       -genome_db => $self->{'genome_db'});
    $dfa->store_if_needed($df);

    $self->{'sliceCount'}++;
    #print("slice " . $slice->name . "\n");
    my @genes = ();
    my $current_end;
    foreach my $gene (sort {$a->start <=> $b->start ||
                              $a->end <=> $b->end} @{$slice->get_all_Genes}) {
      $current_end = $gene->end unless (defined $current_end);
      $self->{'geneCount'}++;
      if((lc($gene->biotype) eq 'protein_coding')) {
        $self->{'realGeneCount'}++;
        if ($gene->start <= $current_end) {
          push @genes, $gene;
          $current_end = $gene->end if ($gene->end > $current_end);
        } else {
          $self->store_all_coding_exons(\@genes);
          @genes = ();
          $current_end = $gene->end;
          push @genes, $gene;
        }
      }
    }
    $self->store_all_coding_exons(\@genes);
  }

  print("loaded ".$self->{'sliceCount'}." slices\n");
  print("       ".$self->{'geneCount'}." genes\n");
  print("       ".$self->{'realGeneCount'}." real genes\n");
  print("       ".$self->{'transcriptCount'}." transcripts\n");
  print("       ".$self->{'exonCount'}." exons\n");
  print("       ".$self->{'exonSubset'}->count()." in Subset\n");
}


sub store_all_coding_exons
{
  my $self = shift;
  my $genes = shift;

  return 1 if (scalar @{$genes} == 0);

  my $MemberAdaptor = $self->{'comparaDBA'}->get_MemberAdaptor();
  my $genome_db = $self->{'genome_db'};
  my @exon_members = ();

  foreach my $gene (@{$genes}) {
    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      $self->{'transcriptCount'}++;

      print("     transcript " . $transcript->stable_id ) if($self->{'verbose'});
      
      foreach my $exon (@{$transcript->get_all_translateable_Exons}) {
        unless (defined $exon->stable_id) {
          warn("COREDB error: does not contain exon stable id for translation_id ".$exon->dbID."\n");
          next;
        }
        my $description = $self->fasta_description($exon, $transcript);
        
        my $exon_member = new Bio::EnsEMBL::Compara::Member;
        $exon_member->taxon_id($genome_db->taxon_id);
        if(defined $description ) {
          $exon_member->description($description);
        } else {
          $exon_member->description("NULL");
        }
        $exon_member->genome_db_id($genome_db->dbID);
        $exon_member->chr_name($exon->seq_region_name);
        $exon_member->chr_start($exon->seq_region_start);
        $exon_member->chr_end($exon->seq_region_end);
        $exon_member->chr_strand($exon->seq_region_strand);
        $exon_member->version($exon->version);
        $exon_member->stable_id($exon->stable_id);
        $exon_member->source_name("ENSEMBLEXON");
        
        my $seq_string = $exon->peptide($transcript)->seq;
        ## a star or a U (selenocysteine) in the seq breaks the pipe to the cast filter for Blast
        $seq_string =~ tr/\*U/XX/;
        if ($seq_string =~ /^X+$/) {
          warn("X+ in sequence from exon " . $exon->stable_id."\n");
        }
        else {
          $exon_member->sequence($seq_string);
        }

        print(" => member " . $exon_member->stable_id) if($self->{'verbose'});

        unless($exon_member->sequence) {
          print("  => NO SEQUENCE!\n") if($self->{'verbose'});
          next;
        }
        print(" len=",$exon_member->seq_length ) if($self->{'verbose'});
        next if ($exon_member->seq_length < $self->min_length);
        push @exon_members, $exon_member;
      }
    }
  }
  @exon_members = sort {$b->seq_length <=> $a->seq_length} @exon_members;
  my @exon_members_stored = ();
  while (my $exon_member = shift @exon_members) {
    my $not_to_store = 0;
    foreach my $stored_exons (@exon_members_stored) {
      if ($exon_member->chr_start <=$stored_exons->chr_end &&
          $exon_member->chr_end >= $stored_exons->chr_start) {
        $not_to_store = 1;
        last;
      }
    }
    next if ($not_to_store);
    push @exon_members_stored, $exon_member;
    $MemberAdaptor->store($exon_member);
    print(" : stored\n") if($self->{'verbose'});
    $self->{'exonSubset'}->add_member($exon_member);
    $self->{'exonCount'}++;
  }
}


sub fasta_description {
  my ($self, $exon, $transcript) = @_;

  my $description = "Exon:" .        $exon->stable_id .
                    " Chr:" .        $exon->seq_region_name .
                    " Start:" .      $exon->seq_region_start .
                    " End:" .        $exon->seq_region_end .
                    " Transcript:" . $transcript->stable_id;

  return $description;
}

sub min_length {
  my ($self, $value) = @_;

  if (defined $value) {
    $self->{_min_length} = $value;
  }

  return $self->{_min_length};
}

1;
