=head1 NAME Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor

=head1 SYNOPSIS

=head1 CONTACT

  Michele Clamp : michele@sanger.ac.uk

=head1 APPENDIX

=cut


package Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
#use Bio::EnsEMBL::Compara::SyntenyPair;
use Bio::EnsEMBL::Compara::PeptideAlignFeature;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
use Bio::EnsEMBL::GenePair::PeptidePair;

use vars '@ISA';

@ISA = ('Bio::EnsEMBL::DBSQL::BaseAdaptor');

sub get_hits_by_qyid {
  my ($self,$id) = @_;

  my $idlength = $self->get_peptide_length($id);

  my $command = "select peptide.length,feature.* from peptide,feature where feature.id1 = \'$id\' and feature.id2 = peptide.id";

  my $sth = $self->db->prepare($command);
  my $res = $sth->execute;

  my @hits;

  while (my $row = $sth->fetchrow_hashref) {

    my $p = new Bio::EnsEMBL::GenePair::PeptidePair;

    $p->queryid($row->{id1});
    $p->hitid  ($row->{id2});
    $p->qstart ($row->{qstart});
    $p->qend   ($row->{qend});
    $p->hstart ($row->{hstart});
    $p->hend   ($row->{hend});
    $p->score  ($row->{score});
    $p->evalue ($row->{evalue});
    $p->pid    ($row->{pid});
    $p->qlength($idlength);
    $p->hlength($row->{length});

    $p->pos    ($row->{pos});
    $p->identical_matches    ($row->{identical_matches});
    $p->positive_matches    ($row->{positive_matches});
    $p->cigar_line    ($row->{cigar_line});

    push(@hits,$p);

  }
  return @hits;
}

sub get_hits_by_qyid_and_hitid {
  my ($self,$id,$hitid) = @_;

  my $idlength = $self->get_peptide_length($id);

  my $command = "select peptide.length,feature.* from peptide,feature where feature.id1 = \'$id\' and feature.id2 = peptide.id and feature.id2 = \'$hitid\'";

  my $sth = $self->db->prepare($command);
  my $res = $sth->execute;

  my @hits;

  while (my $row = $sth->fetchrow_hashref) {

    my $p = new Bio::EnsEMBL::GenePair::PeptidePair;

    $p->queryid($row->{id1});
    $p->hitid  ($row->{id2});
    $p->qstart ($row->{qstart});
    $p->qend   ($row->{qend});
    $p->hstart ($row->{hstart});
    $p->hend   ($row->{hend});
    $p->score  ($row->{score});
    $p->evalue ($row->{evalue});
    $p->pid    ($row->{pid});
    $p->qlength($idlength);
    $p->hlength($row->{length});

    $p->pos    ($row->{pos});
    $p->identical_matches    ($row->{identical_matches});
    $p->positive_matches    ($row->{positive_matches});
    $p->cigar_line    ($row->{cigar_line});

    push(@hits,$p);

  }
  return @hits;
}

#############################
#
# store methods
#
#############################

sub store {
  my ($self, @features)  = @_;

  my @pafList = ();

  foreach my $feature (@features) {
    if($feature->isa('Bio::EnsEMBL::BaseAlignFeature')) {
      #displayHSP_short($feature);
      my $pepFeature = new Bio::EnsEMBL::Compara::PeptideAlignFeature(-feature => $feature);
      #displayPAF_short($pepFeature);
      push @pafList, $pepFeature;
    }
    elsif($feature->isa('Bio::EnsEMBL::Compara::PeptideAlignFeature')) {
      push @pafList, $pepFeature;
    }
  }

  @pafList = sort sort_by_score_evalue_and_pid @pafList;
  my $rank=1;
  foreach my $feature (@pafList) {
    $feature->hit_rank($rank++);
  }

  $self->_store_PAFS(@pafList);
}

sub _store_PAFS {
  my ($self, @out)  = @_;

  my $memberAdaptor = $self->db->get_MemberAdaptor();

  my $query = "INSERT INTO peptide_align_feature(".
                "qmember_id,hmember_id,analysis_id," .
                "qstart,qend,hstart,hend,".
                "score,evalue,align_length," .
                "identical_matches,perc_ident,".
                "positive_matches,perc_pos,hit_rank,cigar_line) ".
              " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
  my $sth = $self->db->prepare($query);

  foreach my $feature (@out) {
    if($feature->isa('Bio::EnsEMBL::Compara::PeptideAlignFeature')) {

      unless($feature->query_member_id) {
        my $qy_member  = $memberAdaptor->fetch_by_source_stable_id('ENSEMBLPEP', $feature->queryid);
        $feature->query_member_id($qy_member->dbID);
      }
      unless($feature->hit_member_id) {
        my $hit_member = $memberAdaptor->fetch_by_source_stable_id('ENSEMBLPEP', $feature->hitid);
        $feature->hit_member_id($hit_member->dbID);
      }

      displayPAF_short($feature);

      my $analysis_id = 0;
      if($feature->analysis()) {
        #print("feature has analysis '".$feature->analysis->logic_name()."' dbID=".$feature->analysis->dbID."\n");
        $analysis_id=$feature->analysis()->dbID();
      }

      $sth->execute($feature->query_member_id,
                    $feature->hit_member_id,
                    $analysis_id,
                    $feature->qstart,
                    $feature->qend,
                    $feature->hstart,
                    $feature->hend,
                    $feature->score,
                    $feature->evalue,
                    $feature->alignment_length,
                    $feature->identical_matches,
                    $feature->perc_ident,
                    $feature->positive_matches,
                    $feature->perc_pos,
                    $feature->hit_rank,
                    $feature->cigar_line
                   );
    }
  }
}


sub sort_by_score_evalue_and_pid {
  $b->score <=> $a->score ||
    $a->evalue <=> $b->evalue ||
      $b->perc_ident <=> $a->perc_ident ||
        $b->perc_pos <=> $a->perc_pos;
}


sub displayHSP {
  my($feature) = @_;

  my $percent_ident = int($feature->identical_matches*100/$feature->alignment_length);
  my $pos = int($feature->positive_matches*100/$feature->alignment_length);

  print("=> $feature\n");
  print("pep_align_feature :\n" .
    " seqname           : " . $feature->seqname . "\n" .
    " start             : " . $feature->start . "\n" .
    " end               : " . $feature->end . "\n" .
    " hseqname          : " . $feature->hseqname . "\n" .
    " hstart            : " . $feature->hstart . "\n" .
    " hend              : " . $feature->hend . "\n" .
    " score             : " . $feature->score . "\n" .
    " p_value           : " . $feature->p_value . "\n" .
    " alignment_length  : " . $feature->alignment_length . "\n" .
    " identical_matches : " . $feature->identical_matches . "\n" .
    " perc_ident        : " . $percent_ident . "\n" .
    " positive_matches  : " . $feature->positive_matches . "\n" .
    " perc_pos          : " . $pos . "\n" .
    " cigar_line        : " . $feature->cigar_string . "\n");
}

sub displayHSP_short {
  my($feature) = @_;

  unless(defined($feature)) {
    print("qy_stable_id\t\t\thit_stable_id\t\t\tscore\talen\t\%ident\t\%positive\n");
    return;
  }
  
  my $perc_ident = int($feature->identical_matches*100/$feature->alignment_length);
  my $perc_pos = int($feature->positive_matches*100/$feature->alignment_length);

  print("HSP ".$feature->seqname."(".$feature->start.",".$feature->end.")".
        "\t" . $feature->hseqname. "(".$feature->hstart.",".$feature->hend.")".
        "\t" . $feature->score .
        "\t" . $feature->alignment_length .
        "\t" . $perc_ident . 
        "\t" . $perc_pos . "\n");
}

sub displayPAF_short {
  my($feature) = @_;

  unless(defined($feature)) {
    print("qy_stable_id\t\t\thit_stable_id\t\t\tscore\talen\t\%ident\t\%positive\thit_rank\n");
    return;
  }

  print("PAF ".$feature->queryid."(".$feature->qstart.",".$feature->qend.")".
        "\t" . $feature->hitid. "(".$feature->hstart.",".$feature->hend.")".
        "\t" . $feature->score .
        "\t" . $feature->alignment_length .
        "\t" . $feature->perc_ident .
        "\t" . $feature->perc_pos .
        "\t" . $feature->hit_rank .
        "\n");
}

1;
