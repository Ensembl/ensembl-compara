package EnsEMBL::Web::Component::Gene::HistoryLinked;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  return "Associated archeived ID's for this stable ID version";
}

sub content {
  my $self = shift;
  my $OBJ = $self->object;
  my $object = $OBJ->get_archive_object();

  my @associated = @{ $object->get_all_associated_archived };
  return 0 unless (@associated);

  my @sorted = sort { $a->[0]->release <=> $b->[0]->release ||
                      $a->[0]->stable_id cmp $b->[0]->stable_id } @associated;

  my $last_release;
  my $last_gsi;

  while (my $r = shift(@sorted)) {

  my ($release, $gsi, $tsi, $tlsi, $pep_seq);

    # release
    if ($r->[0]->release == $last_release) {
      $release = undef;
    } else {
      $release = $r->[0]->release;
    }

    # gene
    if ($r->[0]->stable_id eq $last_gsi) {
      $gsi = undef;
    } else {
      $gsi = _idhistoryview_link('gene', $r->[0]->stable_id);
    }

    # transcript
    $tsi = _idhistoryview_link('transcript', $r->[1]->stable_id);

    # translation
    if ($r->[2]) {
      $tlsi = _idhistoryview_link('peptide', $r->[2]->stable_id);
      $tlsi .= '<br />'._get_formatted_pep_seq($r->[3], $r->[2]->stable_id);
    } else {
      $tlsi = 'none';
    }

    $last_release = $r->[0]->release;
    $last_gsi = $r->[0]->stable_id;
  }

  return 1;
}

1;
