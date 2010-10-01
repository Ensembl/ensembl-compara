# $Id$

package EnsEMBL::Web::ZMenu::SupportingEvidenceAlignment;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $hit_name   = $hub->param('id');
  my $hit_db     = $self->object->get_sf_hit_db_name($hit_name);
  my $link_name  = $hit_db eq 'RFAM' ? [ split '-', $hit_name ]->[0] : $hit_name;
  my $hit_length = $hub->param('hit_length');
  my $hit_url    = $hub->get_ExtURL_link($link_name, $hit_db, $link_name);
  my $tsid       = $hub->param('t');
  my $esid       = $hub->param('exon');

  $self->caption("$hit_name ($hit_db)");

  if ($esid) {
    my $exon_length = $hub->param('exon_length');

    if ($hub->param('er')) {
      $self->add_entry({
	label_html => "Entry removed from $hit_db",
      });
    }

    $self->add_entry({
      type  => 'View alignments',
      label => "$esid ($tsid)",
      link  => $hub->url({
	type     => 'Transcript',
	action   => 'SupportingEvidence',
	function => 'Alignment',
	sequence => $hit_name,
	exon     => $esid
      })
    });

    $self->add_entry({
      type  => 'View record',
      label => $hit_name,
      link  => $hit_url,
      extra => { abs_url => 1 }
    });

    $self->add_entry({
      type  => 'Exon length',
      label => "$exon_length bp"
    });

    if ($hub->param('five_end_mismatch')) {
      $self->add_entry({
        type  => "5' mismatch",
        label => $hub->param('five_end_mismatch') . ' bp'
      });
    }

    if ($hub->param('three_end_mismatch')) {
      $self->add_entry({
        type  => "3' mismatch",
        label => $hub->param('three_end_mismatch') . ' bp'
      });
    }
  } else {
    $self->add_entry({
      type  => 'View record',
      labe  => $hit_name,
      link  => $hit_url,
      extra => { abs_url => 1 }
    });
  }
}

1;
