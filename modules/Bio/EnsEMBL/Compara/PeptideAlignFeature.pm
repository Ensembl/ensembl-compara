=head1 NAME - Bio::EnsEMBL::Compara::PeptideAlignFeature

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

my $_paf_build_homology_idx = time(); #global index counter

package Bio::EnsEMBL::Compara::PeptideAlignFeature;

use strict;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Utils::Exception;

#se overload '<=>' => "sort_by_score_evalue_and_pid";   # named method

sub new {
  my ($class) = @_;
  my $self = {};

  bless $self,$class;

  $self->query_member(new Bio::EnsEMBL::Compara::Member);
  $self->hit_member(new Bio::EnsEMBL::Compara::Member);
  return $self;
}

sub init_from_feature {
  my($self, $feature) = @_;

  unless(defined($feature) and $feature->isa('Bio::EnsEMBL::BaseAlignFeature')) {
    throw("arg must be a [Bio::EnsEMBL::BaseAlignFeature] not a [$feature]");
  }

  $self->query_member->stable_id($feature->seqname);
  $self->hit_member->stable_id($feature->hseqname);
  $self->analysis($feature->analysis);

  $self->qstart($feature->start);
  $self->hstart($feature->hstart);
  $self->qend($feature->end);
  $self->hend($feature->hend);
  #$self->qlength($qlength);
  #$self->hlength($hlength);
  $self->score($feature->score);
  $self->evalue($feature->p_value);
  $self->cigar_line($feature->cigar_string);

  $self->alignment_length($feature->alignment_length);
  $self->identical_matches($feature->identical_matches);
  $self->positive_matches($feature->positive_matches);

  $self->perc_ident(int($feature->identical_matches*100/$feature->alignment_length));
  $self->perc_pos(int($feature->positive_matches*100/$feature->alignment_length));
  return $self;
}


sub create_homology
{
  my $self = shift;

  # create an Homology object
  my $homology = new Bio::EnsEMBL::Compara::Homology;
  my $stable_id = $self->query_member->taxon_id() . "_" . $self->hit_member->taxon_id . "_";
  $stable_id .= sprintf ("%011.0d",$_paf_build_homology_idx++);
  $homology->stable_id($stable_id);
  $homology->source_name("ENSEMBL_ORTHOLOGUES");
  # The previous line should be replaced by
  # $homology->method_link_type("ENSEMBL_ORTHOLOGUES");
  # unless the calling script/modules using $homology->method_link_species_set method
  # my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  # $mlss->method_link_type("ENSEMBL_ORTHOLOGUES");
  # $mlss->species_set([$self->query_member->genome_db_id, $self->hit_member->qgenome_db_id]);
  # $homology->method_link_species_set($mlss);

  # NEED TO BUILD THE Attributes (ie homology_members)
  #
  # QUERY member
  #
  my $attribute;
  $attribute = new Bio::EnsEMBL::Compara::Attribute;
  $attribute->peptide_member_id($self->query_member->dbID);
  $attribute->cigar_start($self->qstart);
  $attribute->cigar_end($self->qend);
  my $qlen = ($self->qend - $self->qstart + 1);
  $attribute->perc_cov(int($qlen*100/$self->query_member->seq_length));
  $attribute->perc_id(int($self->identical_matches*100.0/$qlen));
  $attribute->perc_pos(int($self->positive_matches*100/$qlen));
  $attribute->peptide_align_feature_id($self->dbID);

  my $cigar_line = $self->cigar_line;
  #print("original cigar_line '$cigar_line'\n");
  $cigar_line =~ s/I/M/g;
  $cigar_line = compact_cigar_line($cigar_line);
  $attribute->cigar_line($cigar_line);
  #print("   '$cigar_line'\n");

  $homology->add_Member_Attribute([$self->query_member->gene_member, $attribute]);

  # HIT member
  #
  $attribute = new Bio::EnsEMBL::Compara::Attribute;
  $attribute->peptide_member_id($self->hit_member->dbID);
  $attribute->cigar_start($self->hstart);
  $attribute->cigar_end($self->hend);
  my $hlen = ($self->hend - $self->hstart + 1);
  $attribute->perc_cov(int($hlen*100/$self->hit_member->seq_length));
  $attribute->perc_id(int($self->identical_matches*100.0/$hlen));
  $attribute->perc_pos(int($self->positive_matches*100/$hlen));
  $attribute->peptide_align_feature_id($self->rhit_dbID);

  $cigar_line = $self->cigar_line;
  #print("original cigar_line\n    '$cigar_line'\n");
  $cigar_line =~ s/D/M/g;
  $cigar_line =~ s/I/D/g;
  $cigar_line = compact_cigar_line($cigar_line);
  $attribute->cigar_line($cigar_line);
  #print("   '$cigar_line'\n");

  $homology->add_Member_Attribute([$self->hit_member->gene_member, $attribute]);

  return $homology;
}


sub compact_cigar_line
{
  my $cigar_line = shift;

  #print("cigar_line '$cigar_line' => ");
  my @pieces = ( $cigar_line =~ /(\d*[MDI])/g );
  my @new_pieces = ();
  foreach my $piece (@pieces) {
    $piece =~ s/I/M/;
    if (! scalar @new_pieces || $piece =~ /D/) {
      push @new_pieces, $piece;
      next;
    }
    if ($piece =~ /\d*M/ && $new_pieces[-1] =~ /\d*M/) {
      my ($matches1) = ($piece =~ /(\d*)M/);
      my ($matches2) = ($new_pieces[-1] =~ /(\d*)M/);
      if (! defined $matches1 || $matches1 eq "") {
        $matches1 = 1;
      }
      if (! defined $matches2 || $matches2 eq "") {
        $matches2 = 1;
      }
      $new_pieces[-1] = $matches1 + $matches2 . "M";
    } else {
      push @new_pieces, $piece;
    }
  }
  my $new_cigar_line = join("", @new_pieces);
  #print(" '$new_cigar_line'\n");
  return $new_cigar_line;
}


##########################
#
# getter/setter methods
#
##########################

sub query_member {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    throw("arg must be a [Bio::EnsEMBL::Compara::Member] not a [$arg]")
        unless($arg->isa('Bio::EnsEMBL::Compara::Member'));
    $self->{'_query_member'} = $arg;
  }
  return $self->{'_query_member'};
}

sub  hit_member {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    throw("arg must be a [Bio::EnsEMBL::Compara::Member] not a [$arg]")
        unless($arg->isa('Bio::EnsEMBL::Compara::Member'));
    $self->{'_hit_member'} = $arg;
  }
  return $self->{'_hit_member'};
}

sub  qstart {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_qstart} = $arg;
  }
  return $self->{_qstart};
}

sub  hstart {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_hstart} = $arg;
  }
  return $self->{_hstart};
}

sub  qend {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_qend} = $arg;
  }
  return $self->{_qend};
}

sub  qlength {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_qlength} = $arg;
  }
  return $self->{_qlength};
}

sub  hend {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_hend} = $arg;
  }
  return $self->{_hend};
}

sub  hlength{
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_hlength} = $arg;
  }
  return $self->{_hlength};
}

sub score{
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_score} = $arg;
  }
  return $self->{_score};
}

sub evalue {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_evalue} = $arg;
  }
  return $self->{_evalue};
}

sub perc_ident {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_perc_ident} = $arg;
  }
  return $self->{_perc_ident};
}

sub perc_pos {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_perc_pos} = $arg;
  }
  return $self->{_perc_pos};
}

sub identical_matches {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_identical_matches} = $arg;
    if(defined($self->alignment_length)) {
      $self->perc_ident(int($arg*100/$self->alignment_length));
    }
  }
  return $self->{_identical_matches};
}

sub positive_matches {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_positive_matches} = $arg;
    if(defined($self->alignment_length)) {
      $self->perc_pos(int($arg*100/$self->alignment_length));
    }
  }
  return $self->{_positive_matches};
}

sub alignment_length {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_alignment_length} = $arg;
  }
  return $self->{_alignment_length};
}

sub cigar_line {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_cigar_line} = $arg;
  }
  return $self->{_cigar_line};
}

sub hit_rank {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_hit_rank} = $arg;
  }
  return $self->{_hit_rank};
}

sub analysis
{
  my ($self,$analysis) = @_;

  if (defined($analysis)) {
    unless($analysis->isa('Bio::EnsEMBL::Analysis')) {
      throw("arg must be a [Bio::EnsEMBL::Analysis] not a [$analysis]");
    }
    $self->{_analysis} = $analysis;
  }
  return $self->{_analysis};
}

sub dbID {
  my ( $self, $dbID ) = @_;
  $self->{'_dbID'} = $dbID if defined $dbID;
  return $self->{'_dbID'};
}

sub rhit_dbID {
  my ( $self, $dbID ) = @_;
  $self->{'_rhit_dbID'} = $dbID if defined $dbID;
  return $self->{'_rhit_dbID'};
}

=head3
sub sort_by_score_evalue_and_pid {
  #print("operator redirect YEAH!\n");
  $b->score <=> $a->score ||
    $a->evalue <=> $b->evalue ||
      $b->perc_ident <=> $a->perc_ident ||
        $b->perc_pos <=> $a->perc_pos;
}
=cut

sub display_short {
  my($self) = @_;

  unless(defined($self)) {
    print("qy_stable_id\t\t\thit_stable_id\t\t\tscore\talen\t\%ident\t\%positive\thit_rank\n");
    return;
  }

  my $qm = $self->query_member;
  my $hm = $self->hit_member;
  my $dbID = $self->dbID;  $dbID = '' unless($dbID);

  my $header = "PAF(".$dbID.")";
  $header .= "(".$self->rhit_dbID.")" if($self->rhit_dbID);
  while(length($header)<20) { $header .= ' '; }
  printf($header);
  print($qm->stable_id,"(".$self->qstart,",",$self->qend,")",
        "(",$qm->chr_name,":",$qm->chr_start,")\t",
        "\t" , $hm->stable_id, "(".$self->hstart,",",$self->hend,")",
        "(",$hm->chr_name,":",$hm->chr_start,")\t",
        "\t" , $self->score ,
        "\t" , $self->alignment_length ,
        "\t" , $self->perc_ident ,
        "\t" , $self->perc_pos ,
        "\t" , $self->hit_rank ,
        "\n");
}


=head2 hash_key
  Args       : none
  Example    : $somehash->{$paf->hash_key} = $someValue;
  Description: used for keeping track of known/stored gene/gene relationships
  Returntype : string $key
  Exceptions : none
  Caller     : general
=cut

sub hash_key
{
  my $self = shift;
  my $key = '1';

  return $key unless($self->query_member);
  return $key unless($self->hit_member);
  my $gene1 = $self->query_member->gene_member;
  my $gene2 = $self->hit_member->gene_member;
  return $key unless($gene1 and $gene2);
  if($gene1->genome_db_id > $gene2->genome_db_id) {
    my $temp = $gene1;
    $gene1 = $gene2;
    $gene2 = $temp;
  }
  $key = $gene1->stable_id . '_' . $gene2->stable_id;
  return $key;
}

1;
