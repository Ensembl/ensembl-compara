# $Id$

package EnsEMBL::Web::ZMenu::Repeat;

use strict;

use Bio::EnsEMBL::GlyphSet::_repeat;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $id         = $hub->param('id');
  my $click_data = $self->click_data;
  my @features;
  
  if ($click_data) {
    @features = @{Bio::EnsEMBL::GlyphSet::_repeat->new($click_data)->features};
    @features = () unless grep $_->dbID eq $id, @features;
  }
  
  @features = $hub->get_adaptor('get_RepeatFeatureAdaptor')->fetch_by_dbID($id) unless scalar @features;
  
  $self->feature_content($_) for @features;
}

sub feature_content {
  my ($self, $f) = @_;
  my $consensus = $f->repeat_consensus;
  my $analysis  = $f->analysis;
  
  $self->new_feature;
  $self->caption($consensus->name);
  $self->add_entry({ type  => 'Location',    label      => sprintf('%s:%s-%s', $f->seq_region_name, $f->seq_region_start, $f->seq_region_end) });
  $self->add_entry({ type  => 'Length',      label      => $f->length });
  $self->add_entry({ type  => 'Strand',      label      => $f->strand }) if $f->strand;
  $self->add_entry({ type  => 'Type',        label      => $consensus->repeat_type });
  $self->add_entry({ type  => 'Class',       label      => $consensus->repeat_class });
  $self->add_entry({ type  => 'Consensus',   label_html => sprintf '<div style="word-break:break-all">%s</div>', $consensus->repeat_consensus });
  $self->add_entry({ type  => 'Analysis',    label_html => $analysis->display_label });
  $self->add_entry({ type  => 'Description', label_html => $analysis->description });
}

1;
  