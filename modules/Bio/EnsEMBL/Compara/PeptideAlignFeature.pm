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

use Bio::Root::RootI;

@ISA = qw(Bio::Root::RootI);

sub new {
  my($pkg, @args) = @_;

  my $self = bless {}, $pkg;

  my ($queryid,
      $hitid,
      $qstart,
      $hstart,
      $qend,
      $hend,
      $qlength,
      $hlength,
      $alength
      $score,
      $evalue,
      $pid,
    ) = $self->_rearrange([qw(
      QUERYID
      HITID
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
    )],@args);

  $self->queryid($queryid);
  $self->hitid($hitid);
  $self->qstart($qstart);
  $self->hstart($hstart);
  $self->qend($qend);
  $self->hend($hend);
  $self->qlength($qlength);
  $self->hlength($hlength);
  $self->align_length($alength);
  $self->score($score);
  $self->evalue($evalue);
  $self->perc_ident($pid);

  return $self;

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
  }
  return $self->{_identical_matches};
}

sub positive_matches {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_positive_matches} = $arg;
  }
  return $self->{_positive_matches};
}

sub align_length {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_align_length} = $arg;
  }
  return $self->{_align_length};
}

sub cigar_line {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    $self->{_cigar_line} = $arg;
  }
  return $self->{_cigar_line};
}

1;
