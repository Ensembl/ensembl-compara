# $Id$

package EnsEMBL::Web::ZMenu::SupportingEvidenceAlignment;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object     = $self->object;
  my $hit_name   = $object->param('id');
  my $link_name = $hit_name;
  my $hit_db     = $object->get_sf_hit_db_name($hit_name);
  if ($hit_db eq 'RFAM') {
    ($link_name) = split '-', $hit_name;
  }
  my $hit_length = $object->param('hit_length');
  my $hit_url    = $object->get_ExtURL_link( $link_name, $hit_db, $link_name );
  my $tsid       = $object->param('t');
  my $esid       = $object->param('exon');
  
  $self->caption("$hit_name ($hit_db)");
  
  if ($esid) {
    my $exon_length = $object->param('exon_length');
    
    $self->add_entry({
      type  => 'View alignments',
      label => "$esid ($tsid)",
      link  => $object->_url({
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
    
    if ($object->param('five_end_mismatch')) {
      $self->add_entry({
        type  => "5' mismatch",
        label => $object->param('five_end_mismatch') . ' bp'
      });
    }
    
    if ($object->param('three_end_mismatch')) {
      $self->add_entry({
        type  => "3' mismatch",
        label => $object->param('three_end_mismatch') . ' bp'
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
