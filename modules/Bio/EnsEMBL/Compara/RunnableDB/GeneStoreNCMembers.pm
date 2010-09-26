#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneStoreNCMembers

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $g_load_members = Bio::EnsEMBL::Compara::RunnableDB::GeneStoreNCMembers->new (
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

package Bio::EnsEMBL::Compara::RunnableDB::GeneStoreNCMembers;

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
  $self->{'input_stable_id'} = $input_hash->{'stable_id'};

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
  $self->loadMembersFromCoreSlices();

  $self->compara_dba->dbc->disconnect_when_inactive(1);
  $self->{'coreDBA'}->dbc->disconnect_when_inactive(1);

  return 1;
}

sub write_output 
{
  my $self = shift;

  my $output_id = "{'gdb'=>" . $self->{'genome_db'}->dbID .
                  ",'ss'=>" . $self->{'pepSubset'}->dbID . "}";
  $self->input_job->input_id($output_id);
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
  $self->{'pepSubset'}  = Bio::EnsEMBL::Compara::Subset->new(
      -name=>"gdb:".$self->{'genome_db'}->dbID ." ". $self->{'genome_db'}->name . ' longest translations');
  $self->{'geneSubset'} = Bio::EnsEMBL::Compara::Subset->new(
      -name=>"gdb:".$self->{'genome_db'}->dbID ." ". $self->{'genome_db'}->name . ' genes');

  $self->compara_dba->get_SubsetAdaptor->store($self->{'pepSubset'});
  $self->compara_dba->get_SubsetAdaptor->store($self->{'geneSubset'});

  #from core database, get all slices, and then all genes in slice
  #and then all transcripts in gene to store as members in compara

  $self->{geneDBA} = $self->{'coreDBA'}->get_GeneAdaptor;
  my $input_stable_id = $self->{input_stable_id};
  my $gene = $self->{geneDBA}->fetch_by_stable_id($input_stable_id);
  throw("problem: no gene object for $input_stable_id") unless(defined($gene));

  # Store gene
  $self->store_ncrna_gene($gene);
}


sub store_gene_and_all_transcripts
{
  my $self = shift;
  my $gene = shift;
  
  my @longestPeptideMember;
  my $maxLength=0;
  my $gene_member;
  my $gene_member_not_stored = 1;

  my $self->{memberDBA} = $self->compara_dba->get_MemberAdaptor();

  if(defined($self->{'pseudo_stableID_prefix'})) {
    $gene->stable_id($self->{'pseudo_stableID_prefix'} ."G_". $gene->dbID);
  }

  foreach my $transcript (@{$gene->get_all_Transcripts}) {
    unless (defined $transcript->translation) {
      warn("COREDB error: No translation for transcript ", $transcript->stable_id, "(dbID=",$transcript->dbID.")\n");
      next;
    }
#    This test might be useful to put here, thus avoiding to go further in trying to get a peptide
#    my $next = 0;
#    try {
#      $transcript->translate;
#    } catch {
#      warn("COREDB error: transcript does not translate", $transcript->stable_id, "(dbID=",$transcript->dbID.")\n");
#      $next = 1;
#    };
#    next if ($next);
    my $translation = $transcript->translation;

    if(defined($self->{'pseudo_stableID_prefix'})) {
      $transcript->stable_id($self->{'pseudo_stableID_prefix'} ."T_". $transcript->dbID);
      $translation->stable_id($self->{'pseudo_stableID_prefix'} ."P_". $translation->dbID);
    }

    $self->{'transcriptCount'}++;
    #print("gene " . $gene->stable_id . "\n");
    print("     transcript " . $transcript->stable_id ) if($self->{'verbose'});

    unless (defined $translation->stable_id) {
      throw("COREDB error: does not contain translation stable id for translation_id ". $translation->dbID."\n");
      next;
    }

    my $description = $self->fasta_description($gene, $transcript);

    my $pep_member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
         -transcript=>$transcript,
         -genome_db=>$self->{'genome_db'},
         -translate=>'yes',
         -description=>$description);

    print(" => member " . $pep_member->stable_id) if($self->{'verbose'});

    unless($pep_member->sequence) {
      print("  => NO SEQUENCE!\n") if($self->{'verbose'});
      next;
    }
    print(" len=",$pep_member->seq_length ) if($self->{'verbose'});

    # store gene_member here only if at least one peptide is to be loaded for
    # the gene.
    if($self->{'store_genes'} && $gene_member_not_stored) {
      print("     gene       " . $gene->stable_id ) if($self->{'verbose'});
      $gene_member = Bio::EnsEMBL::Compara::Member->new_from_gene(
                                                                  -gene=>$gene,
                                                                  -genome_db=>$self->{'genome_db'});
      print(" => member " . $gene_member->stable_id) if($self->{'verbose'});

      eval {
        $self->{memberDBA}->store($gene_member);
        print(" : stored") if($self->{'verbose'});
      };

      $self->{'geneSubset'}->add_member($gene_member);
      print("\n") if($self->{'verbose'});
      $gene_member_not_stored = 0;
    }

    $self->{memberDBA}->store($pep_member);
    $self->{memberDBA}->store_gene_peptide_link($gene_member->dbID, $pep_member->dbID);
    print(" : stored\n") if($self->{'verbose'});

    if($pep_member->seq_length > $maxLength) {
      $maxLength = $pep_member->seq_length;
      @longestPeptideMember = ($transcript, $pep_member);
    }

  }

  if(@longestPeptideMember) {
    my ($transcript, $member) = @longestPeptideMember;
    $self->{'pepSubset'}->add_member($member);
    $self->{'longestCount'}++;
    # print("     LONGEST " . $transcript->stable_id . "\n");
  }
}

sub store_ncrna_gene
{
  my $self = shift;
  my $gene = shift;

  my @longestncRNAMember;
  my $maxLength=0;
  my $gene_member;
  my $gene_member_not_stored = 1;


  if(defined($self->{'pseudo_stableID_prefix'})) {
    $gene->stable_id($self->{'pseudo_stableID_prefix'} ."G_". $gene->dbID);
  }

  foreach my $transcript (@{$gene->get_all_Transcripts}) {
    if (defined $transcript->translation) {
      warn("Translation exists for ncRNA transcript ", $transcript->stable_id, "(dbID=",$transcript->dbID.")\n");
      next;
    }
#    This test might be useful to put here, thus avoiding to go further in trying to get a peptide
#    my $next = 0;
#    try {
#      $transcript->translate;
#    } catch {
#      warn("COREDB error: transcript does not translate", $transcript->stable_id, "(dbID=",$transcript->dbID.")\n");
#      $next = 1;
#    };
#    next if ($next);
    # my $translation = $transcript->translation;

    if(defined($self->{'pseudo_stableID_prefix'})) {
      $transcript->stable_id($self->{'pseudo_stableID_prefix'} ."T_". $transcript->dbID);
      # $translation->stable_id($self->{'pseudo_stableID_prefix'} ."P_". $translation->dbID);
    }

    $self->{'transcriptCount'}++;
    #print("gene " . $gene->stable_id . "\n");
    print("     transcript " . $transcript->stable_id ) if($self->{'verbose'});

#     unless (defined $translation->stable_id) {
#       throw("COREDB error: does not contain translation stable id for translation_id ". $translation->dbID."\n");
#       next;
#     }

    my $description = $self->fasta_description($gene, $transcript);

    my $ncrna_member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
         -transcript=>$transcript,
         -genome_db=>$self->{'genome_db'},
         -translate=>'ncrna',
         -description=>$description);

    print(" => member " . $ncrna_member->stable_id) if($self->{'verbose'});

#     unless($ncrna_member->sequence) {
#       print("  => NO SEQUENCE!\n") if($self->{'verbose'});
#       next;
#     }
#     print(" len=",$ncrna_member->seq_length ) if($self->{'verbose'});
    my $transcript_spliced_seq = $transcript->spliced_seq;

    # store gene_member here only if at least one peptide is to be loaded for
    # the gene.
    if($self->{'store_genes'} && $gene_member_not_stored) {
      print("     gene       " . $gene->stable_id ) if($self->{'verbose'});
      $gene_member = Bio::EnsEMBL::Compara::Member->new_from_gene(
                                                                  -gene=>$gene,
                                                                  -genome_db=>$self->{'genome_db'});
      print(" => member " . $gene_member->stable_id) if($self->{'verbose'});

      eval {
        $self->{memberDBA}->store($gene_member);
        print(" : stored") if($self->{'verbose'});
      };

      $self->{'geneSubset'}->add_member($gene_member);
      print("\n") if($self->{'verbose'});
      $gene_member_not_stored = 0;
    }

    $self->{memberDBA}->store($ncrna_member);
    $self->{memberDBA}->store_gene_peptide_link($gene_member->dbID, $ncrna_member->dbID);
    print(" : stored\n") if($self->{'verbose'});

    if(length($transcript_spliced_seq) > $maxLength) {
      $maxLength = length($transcript_spliced_seq);
      @longestncRNAMember = ($transcript, $ncrna_member);
    }

  }

  if(@longestncRNAMember) {
    my ($transcript, $member) = @longestncRNAMember;
    $self->{'pepSubset'}->add_member($member);
    $self->{'longestCount'}++;
    # print("     LONGEST " . $transcript->stable_id . "\n");
  }
}

sub fasta_description {
  my ($self, $gene, $transcript) = @_;
  my $acc = 'NULL'; my $biotype = undef;
  $DB::single=1;1;
  eval { $acc = $transcript->display_xref->primary_id;};
  unless ($acc =~ /RF00/) {
    $biotype = $transcript->biotype;
    if ($biotype =~ /miRNA/) {
      my @exons = @{$transcript->get_all_Exons};
      throw("unexpected miRNA with more than one exon") if (1 < scalar @exons);
      my $exon = $exons[0];
      my @supporting_features = @{$exon->get_all_supporting_features};
      if (1 < scalar @supporting_features || 0 == scalar @supporting_features) {
        warn("unexpected miRNA supporting features");
        next;
      }
      my $supporting_feature = $supporting_features[0];
      eval { $acc = $supporting_feature->hseqname; };
    } elsif ($biotype =~ /snoRNA/) {
      eval { $acc = $transcript->external_name; };
      #     } elsif ($biotype =~ /Mt_tRNA/) { # wont deal with these at the moment
      #       $acc = 'RF00005';
    } elsif ($biotype =~ /Mt_rRNA/) {
      # $acc = $biotype;
    } else {
      # We just leave it as NULL and will skip it in RFAMClassify
    }
  }
  my $description = "Transcript:" . $transcript->stable_id .
                    " Gene:" .      $gene->stable_id .
                    " Chr:" .       $gene->seq_region_name .
                    " Start:" .     $gene->seq_region_start .
                    " End:" .       $gene->seq_region_end.
                    " Acc:" .       $acc;
  print STDERR "Description... $description\n" if ($self->debug);
  return $description;
}

1;
