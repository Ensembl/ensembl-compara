=head1 NAME - Bio::EnsEMBL::Compara::PeptideAlignFeature

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::PeptideAlignFeature;

use vars qw(@ISA);
use strict;
use Bio::EnsEMBL::Root;

#se overload '<=>' => "sort_by_score_evalue_and_pid";   # named method

@ISA = qw(Bio::EnsEMBL::Root);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);

  if (scalar @args) {
    my ($queryid,$hitid,$analysis,
        $qstart,$hstart,$qend,$hend,
        $qlength,$hlength,$alength,
        $score,$evalue,$pid,$pos,
        $cigar_line,$feature
       ) = $self->_rearrange([qw(
        QUERYID
        HITID
        ANALYSIS
        QSTART
        QEND
        HSTART
        HEND
        QLENGTH
        HLENGTH
        ALENGTH
        SCORE
        EVALUE
        PID
        POS
        CIGAR
        FEATURE
      )],@args);

    $feature && $self->init_from_feature($feature);
    
    $queryid && $self->queryid($queryid);
    $hitid && $self->hitid($hitid);
    $analysis && $self->analysis($analysis);
    $qstart && $self->qstart($qstart);
    $hstart && $self->hstart($hstart);
    $qend && $self->qend($qend);
    $hend && $self->hend($hend);
    $qlength && $self->qlength($qlength);
    $hlength && $self->hlength($hlength);
    $alength && $self->alignment_length($alength);
    $score && $self->score($score);
    $evalue && $self->evalue($evalue);
    $pid && $self->perc_ident($pid);
    $pos && $self->perc_pos($pos);
    $cigar_line && $self->cigar_line($cigar_line);
  }

  return $self;
}

sub init_from_feature {
  my($self, $feature) = @_;

  unless(defined($feature) and $feature->isa('Bio::EnsEMBL::BaseAlignFeature')) {
    $self->throw(
    "arg must be a [Bio::EnsEMBL::BaseAlignFeature] ".
    "not a [$feature]");
  }

  $self->queryid($feature->seqname);
  $self->hitid($feature->hseqname);
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
}

sub queryid {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_queryid} = $arg;
  }
  return $self->{_queryid};
}

sub  hitid {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_hitid} = $arg;
  }
  return $self->{_hitid};
}

sub query_member_id {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_query_member_id} = $arg;
  }
  return $self->{_query_member_id};
}

sub  hit_member_id {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_hit_member_id} = $arg;
  }
  return $self->{_hit_member_id};
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
    $self->{_analysis} = $analysis;
  }
  return $self->{_analysis};
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

1;
