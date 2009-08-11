#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::OtherParalogs

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $otherparalogs = Bio::EnsEMBL::Compara::RunnableDB::OtherParalogs->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$otherparalogs->fetch_input(); #reads from DB
$otherparalogs->run();
$otherparalogs->output();
$otherparalogs->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This analysis will load a super protein tree alignment and insert the
extra paralogs into the homology tables.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::OtherParalogs;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Graph::Link;
use Bio::EnsEMBL::Compara::Graph::Node;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'tree_scale'} = 1;
  $self->{'store_homologies'} = 1;

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
    (
     -DBCONN=>$self->db->dbc
    );

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  if($self->{analysis_data_id}) {
    my $analysis_data_id = $self->{analysis_data_id};
    my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
    $self->get_params($analysis_data_params);
  }

  $self->print_params if($self->debug);

  my $starttime = time();

  $self->{'streeDBA'} = $self->{'comparaDBA'}->get_SuperProteinTreeAdaptor;
  $self->{homologyDBA} = $self->{'comparaDBA'}->get_HomologyAdaptor;
  $self->{'protein_tree'} =  $self->{'streeDBA'}->fetch_node_by_node_id($self->{'protein_tree_id'});

  if($self->debug) {
    $self->{'protein_tree'}->print_tree($self->{'tree_scale'});
    printf("time to fetch tree : %1.3f secs\n" , time()-$starttime);
  }
  unless($self->{'protein_tree'}) {
    throw("undefined ProteinTree as input\n");
  }

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  foreach my $key (qw[protein_tree_id analysis_data_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  return;
}

sub print_params {
  my $self = shift;

  print("params:\n");
  printf("  tree_id   : %d\n", $self->{'protein_tree_id'});
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  $self->run_otherparalogs;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

  $self->store_other_paralogs;
}


##########################################
#
# internal methods
#
##########################################

1;

sub run_otherparalogs {
  my $self = shift;
  my $tree = $self->{'protein_tree'};

  my $tmp_time = time();

  my @all_protein_leaves = @{$tree->get_all_leaves};
  printf("%1.3f secs to fetch all leaves\n", time()-$tmp_time) if ($self->debug);

  if($self->debug) {
    printf("%d proteins in tree\n", scalar(@all_protein_leaves));
  }
  printf("build paralogs graph\n") if($self->debug);
  my @genepairlinks;
  my $graphcount = 0;
  my $tree_node_id = $tree->node_id;
  while (my $protein1 = shift @all_protein_leaves) {
    foreach my $protein2 (@all_protein_leaves) {
      next unless ($protein1->genome_db_id == $protein2->genome_db_id);
      my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link
        (
         $protein1, $protein2, 0
        );
      $genepairlink->add_tag("tree_node_id", $tree_node_id);
      push @genepairlinks, $genepairlink;
      print STDERR "build graph $graphcount\n" if ($graphcount++ % 10 == 0);
    }
  }
  printf("%1.3f secs build links and features\n", time()-$tmp_time) if($self->debug>1);

  foreach my $genepairlink (@genepairlinks) {
    $self->other_paralog($genepairlink);
  }

  if($self->debug) {
    printf("%d pairings\n", scalar(@genepairlinks));
  }

  $self->{'other_paralog_links'} = \@genepairlinks;

  return 1;
}

sub other_paralog {
  my $self = shift;
  my $genepairlink = shift;

  my ($pep1, $pep2) = $genepairlink->get_nodes;
  return undef unless($pep1->genome_db_id == $pep2->genome_db_id);

  $genepairlink->add_tag("orthotree_type", 'other_paralog');
  $genepairlink->add_tag("orthotree_subtype", "Undetermined");

  return 1;
}

sub store_other_paralogs {
  my $self = shift;

  my $linkscount = 0;
  foreach my $genepairlink (@{$self->{'other_paralog_links'}}) {
    my $homology = $self->store_gene_link_as_homology($genepairlink);
    print STDERR "homology links $linkscount\n" if ($linkscount++ % 500 == 0);
  }
}

sub store_gene_link_as_homology
{
  my $self = shift;
  my $genepairlink  = shift;

  my $type = $genepairlink->get_tagvalue('orthotree_type');
  return unless($type);
  my $subtype = $genepairlink->get_tagvalue('orthotree_subtype');
  my $tree_node_id = $genepairlink->get_tagvalue('tree_node_id');
  warn("Tag tree_node_id undefined\n") unless(defined($tree_node_id) && $tree_node_id ne '');

  my ($protein1, $protein2) = $genepairlink->get_nodes;
  # Check is stored as within_species_paralog
  my $member_id1 = $protein1->gene_member->member_id;
  my $member_id2 = $protein2->gene_member->member_id;
  my $stored_as_within_species_paralog = @{$self->{homologyDBA}->fetch_by_Member_id_Member_id($member_id1,$member_id2)}[0];
  next if (defined($stored_as_within_species_paralog)); # Already stored as within_species_paralog

  # create method_link_species_set
  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $mlss->method_link_type("ENSEMBL_PARALOGUES");
  $mlss->species_set([$protein1->genome_db]);
  $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);

  # create an Homology object
  my $homology = new Bio::EnsEMBL::Compara::Homology;
  $homology->description($type);
  $homology->subtype($subtype);
  # $homology->node_id($ancestor->node_id);
  $homology->ancestor_node_id($tree_node_id);
  $homology->tree_node_id($tree_node_id);
  $homology->method_link_type($mlss->method_link_type);
  $homology->method_link_species_set($mlss);

  my $key = $mlss->dbID . "_" . $protein1->dbID;
  $self->{_homology_consistency}{$key}{$type} = 1;
  #$homology->dbID(-1);

  # NEED TO BUILD THE Attributes (ie homology_members)
  my ($cigar_line1, $perc_id1, $perc_pos1,
      $cigar_line2, $perc_id2, $perc_pos2) = 
        $self->generate_attribute_arguments($protein1, $protein2,$type);

  # QUERY member
  #
  my $attribute;
  $attribute = new Bio::EnsEMBL::Compara::Attribute;
  $attribute->peptide_member_id($protein1->dbID);
  $attribute->cigar_line($cigar_line1);
  $attribute->perc_cov(100);
  $attribute->perc_id(int($perc_id1));
  $attribute->perc_pos(int($perc_pos1));

  my $gene_member1 = $protein1->gene_member;
  $homology->add_Member_Attribute([$gene_member1, $attribute]);

  #
  # HIT member
  #
  $attribute = new Bio::EnsEMBL::Compara::Attribute;
  $attribute->peptide_member_id($protein2->dbID);
  $attribute->cigar_line($cigar_line2);
  $attribute->perc_cov(100);
  $attribute->perc_id(int($perc_id2));
  $attribute->perc_pos(int($perc_pos2));

  my $gene_member2 = $protein2->gene_member;
  $homology->add_Member_Attribute([$gene_member2, $attribute]);

  ## Check if it has already been stored, in which case we dont need to store again
  my $matching_homology = 0;
  if ($self->input_job->retry_count > 0 && !defined($self->{old_homologies_deleted})) {
    my $member_id1 = $protein1->gene_member->member_id;
    my $member_id2 = $protein2->gene_member->member_id;
    if ($member_id1 == $member_id2) {
      my $tree_id = $self->{protein_tree}->node_id;
      my $pmember_id1 = $protein1->member_id; my $pstable_id1 = $protein1->stable_id;
      my $pmember_id2 = $protein2->member_id; my $pstable_id2 = $protein2->stable_id;
      $self->throw("$member_id1 ($pmember_id1 - $pstable_id1) and $member_id2 ($pmember_id2 - $pstable_id2) shouldn't be the same");
    }
    my $stored_homology = @{$self->{homologyDBA}->fetch_by_Member_id_Member_id($member_id1,$member_id2)}[0];
    if (defined($stored_homology)) {
      $matching_homology = 1;
      $matching_homology = 0 if ($stored_homology->description ne $homology->description);
      $matching_homology = 0 if ($stored_homology->subtype ne $homology->subtype);
      $matching_homology = 0 if ($stored_homology->ancestor_node_id ne $homology->ancestor_node_id);
      $matching_homology = 0 if ($stored_homology->tree_node_id ne $homology->tree_node_id);
      $matching_homology = 0 if ($stored_homology->method_link_type ne $homology->method_link_type);
      $matching_homology = 0 if ($stored_homology->method_link_species_set->dbID ne $homology->method_link_species_set->dbID);
    }

    # Delete old one, then proceed to store new one
    if (defined($stored_homology) && (0 == $matching_homology)) {
      my $homology_id = $stored_homology->dbID;
      my $sql1 = "delete from homology where homology_id=$homology_id";
      my $sql2 = "delete from homology_member where homology_id=$homology_id";
      my $sth1 = $self->dbc->prepare($sql1);
      my $sth2 = $self->dbc->prepare($sql2);
      $sth1->execute;
      $sth2->execute;
      $sth1->finish;
      $sth2->finish;
    }
  }

  if($self->{'store_homologies'} && 0 == $matching_homology) {
    $self->{'homologyDBA'}->store($homology);
  }

  return $homology;
}

sub generate_attribute_arguments {
  my ($self, $protein1, $protein2, $type) = @_;

  my $new_aln1_cigarline = "";
  my $new_aln2_cigarline = "";

  my $perc_id1 = 0;
  my $perc_pos1 = 0;
  my $perc_id2 = 0;
  my $perc_pos2 = 0;

  my $identical_matches = 0;
  my $positive_matches = 0;
  my $m_hash = $self->get_matrix_hash;

  my ($aln1state, $aln2state);
  my ($aln1count, $aln2count);

  # my @aln1 = split(//, $protein1->alignment_string); # Speed up
  # my @aln2 = split(//, $protein2->alignment_string);
  my $alignment_string = $protein1->alignment_string;
  my @aln1 = unpack("A1" x length($alignment_string), $alignment_string);
  $alignment_string = $protein2->alignment_string;
  my @aln2 = unpack("A1" x length($alignment_string), $alignment_string);

  for (my $i=0; $i <= $#aln1; $i++) {
    next if ($aln1[$i] eq "-" && $aln2[$i] eq "-");
    my ($cur_aln1state, $cur_aln2state) = qw(M M);
    if ($aln1[$i] eq "-") {
      $cur_aln1state = "D";
    }
    if ($aln2[$i] eq "-") {
      $cur_aln2state = "D";
    }
    if ($cur_aln1state eq "M" && $cur_aln2state eq "M" && $aln1[$i] eq $aln2[$i]) {
      $identical_matches++;
      $positive_matches++;
    } elsif ($cur_aln1state eq "M" && $cur_aln2state eq "M" && $m_hash->{uc $aln1[$i]}{uc $aln2[$i]} > 0) {
        $positive_matches++;
    }
    unless (defined $aln1state) {
      $aln1count = 1;
      $aln2count = 1;
      $aln1state = $cur_aln1state;
      $aln2state = $cur_aln2state;
      next;
    }
    if ($cur_aln1state eq $aln1state) {
      $aln1count++;
    } else {
      if ($aln1count == 1) {
        $new_aln1_cigarline .= $aln1state;
      } else {
        $new_aln1_cigarline .= $aln1count.$aln1state;
      }
      $aln1count = 1;
      $aln1state = $cur_aln1state;
    }
    if ($cur_aln2state eq $aln2state) {
      $aln2count++;
    } else {
      if ($aln2count == 1) {
        $new_aln2_cigarline .= $aln2state;
      } else {
        $new_aln2_cigarline .= $aln2count.$aln2state;
      }
      $aln2count = 1;
      $aln2state = $cur_aln2state;
    }
  }
  if ($aln1count == 1) {
    $new_aln1_cigarline .= $aln1state;
  } else {
    $new_aln1_cigarline .= $aln1count.$aln1state;
  }
  if ($aln2count == 1) {
    $new_aln2_cigarline .= $aln2state;
  } else {
    $new_aln2_cigarline .= $aln2count.$aln2state;
  }
  my $seq_length1 = $protein1->seq_length;
  unless (0 == $seq_length1) {
    $perc_id1 = $identical_matches*100.0/$seq_length1;
    $perc_pos1 = $positive_matches*100.0/$seq_length1;
  }
  my $seq_length2 = $protein2->seq_length;
  unless (0 == $seq_length2) {
    $perc_id2 = $identical_matches*100.0/$seq_length2;
    $perc_pos2 = $positive_matches*100.0/$seq_length2;
  }

#   my $perc_id1 = $identical_matches*100.0/$protein1->seq_length;
#   my $perc_pos1 = $positive_matches*100.0/$protein1->seq_length;
#   my $perc_id2 = $identical_matches*100.0/$protein2->seq_length;
#   my $perc_pos2 = $positive_matches*100.0/$protein2->seq_length;

  return ($new_aln1_cigarline, $perc_id1, $perc_pos1, $new_aln2_cigarline, $perc_id2, $perc_pos2);
}

sub get_matrix_hash {
  my $self = shift;

  return $self->{'matrix_hash'} if (defined $self->{'matrix_hash'});

  my $BLOSUM62 = "#  Matrix made by matblas from blosum62.iij
#  * column uses minimum score
#  BLOSUM Clustered Scoring Matrix in 1/2 Bit Units
#  Blocks Database = /data/blocks_5.0/blocks.dat
#  Cluster Percentage: >= 62
#  Entropy =   0.6979, Expected =  -0.5209
   A  R  N  D  C  Q  E  G  H  I  L  K  M  F  P  S  T  W  Y  V  B  Z  X  *
A  4 -1 -2 -2  0 -1 -1  0 -2 -1 -1 -1 -1 -2 -1  1  0 -3 -2  0 -2 -1  0 -4
R -1  5  0 -2 -3  1  0 -2  0 -3 -2  2 -1 -3 -2 -1 -1 -3 -2 -3 -1  0 -1 -4
N -2  0  6  1 -3  0  0  0  1 -3 -3  0 -2 -3 -2  1  0 -4 -2 -3  3  0 -1 -4
D -2 -2  1  6 -3  0  2 -1 -1 -3 -4 -1 -3 -3 -1  0 -1 -4 -3 -3  4  1 -1 -4
C  0 -3 -3 -3  9 -3 -4 -3 -3 -1 -1 -3 -1 -2 -3 -1 -1 -2 -2 -1 -3 -3 -2 -4
Q -1  1  0  0 -3  5  2 -2  0 -3 -2  1  0 -3 -1  0 -1 -2 -1 -2  0  3 -1 -4
E -1  0  0  2 -4  2  5 -2  0 -3 -3  1 -2 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4
G  0 -2  0 -1 -3 -2 -2  6 -2 -4 -4 -2 -3 -3 -2  0 -2 -2 -3 -3 -1 -2 -1 -4
H -2  0  1 -1 -3  0  0 -2  8 -3 -3 -1 -2 -1 -2 -1 -2 -2  2 -3  0  0 -1 -4
I -1 -3 -3 -3 -1 -3 -3 -4 -3  4  2 -3  1  0 -3 -2 -1 -3 -1  3 -3 -3 -1 -4
L -1 -2 -3 -4 -1 -2 -3 -4 -3  2  4 -2  2  0 -3 -2 -1 -2 -1  1 -4 -3 -1 -4
K -1  2  0 -1 -3  1  1 -2 -1 -3 -2  5 -1 -3 -1  0 -1 -3 -2 -2  0  1 -1 -4
M -1 -1 -2 -3 -1  0 -2 -3 -2  1  2 -1  5  0 -2 -1 -1 -1 -1  1 -3 -1 -1 -4
F -2 -3 -3 -3 -2 -3 -3 -3 -1  0  0 -3  0  6 -4 -2 -2  1  3 -1 -3 -3 -1 -4
P -1 -2 -2 -1 -3 -1 -1 -2 -2 -3 -3 -1 -2 -4  7 -1 -1 -4 -3 -2 -2 -1 -2 -4
S  1 -1  1  0 -1  0  0  0 -1 -2 -2  0 -1 -2 -1  4  1 -3 -2 -2  0  0  0 -4
T  0 -1  0 -1 -1 -1 -1 -2 -2 -1 -1 -1 -1 -2 -1  1  5 -2 -2  0 -1 -1  0 -4
W -3 -3 -4 -4 -2 -2 -3 -2 -2 -3 -2 -3 -1  1 -4 -3 -2 11  2 -3 -4 -3 -2 -4
Y -2 -2 -2 -3 -2 -1 -2 -3  2 -1 -1 -2 -1  3 -3 -2 -2  2  7 -1 -3 -2 -1 -4
V  0 -3 -3 -3 -1 -2 -2 -3 -3  3  1 -2  1 -1 -2 -2  0 -3 -1  4 -3 -2 -1 -4
B -2 -1  3  4 -3  0  1 -1  0 -3 -4  0 -3 -3 -2  0 -1 -4 -3 -3  4  1 -1 -4
Z -1  0  0  1 -3  3  4 -2  0 -3 -3  1 -1 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4
X  0 -1 -1 -1 -2 -1 -1 -1 -1 -1 -1 -1 -1 -1 -2  0  0 -2 -1 -1 -1 -1 -1 -4
* -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4  1
";
  my $matrix_string;
  my @lines = split(/\n/,$BLOSUM62);
  foreach my $line (@lines) {
    next if ($line =~ /^\#/);
    if ($line =~ /^[A-Z\*\s]+$/) {
      $matrix_string .= sprintf "$line\n";
    } else {
      my @t = split(/\s+/,$line);
      shift @t;
      #       print scalar @t,"\n";
      $matrix_string .= sprintf(join(" ",@t)."\n");
    }
  }

  my %matrix_hash;
  @lines = ();
  @lines = split /\n/, $matrix_string;
  my $lts = shift @lines;
  $lts =~ s/^\s+//;
  $lts =~ s/\s+$//;
  my @letters = split /\s+/, $lts;

  foreach my $letter (@letters) {
    my $line = shift @lines;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    my @penalties = split /\s+/, $line;
    die "Size of letters array and penalties array are different\n"
      unless (scalar @letters == scalar @penalties);
    for (my $i=0; $i < scalar @letters; $i++) {
      $matrix_hash{uc $letter}{uc $letters[$i]} = $penalties[$i];
    }
  }

  $self->{'matrix_hash'} = \%matrix_hash;

  return $self->{'matrix_hash'};
}

1;
