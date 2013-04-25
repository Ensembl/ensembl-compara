# $Id$

package EnsEMBL::Web::ZMenu::Marker;

use strict;

use Bio::EnsEMBL::GlyphSet::_marker;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $m          = $hub->param('m');
  my $click_data = $self->click_data;
  my @features;
  
  if ($click_data) {
    my $glyphset = Bio::EnsEMBL::GlyphSet::_marker->new($click_data);
    $glyphset->{'text_export'} = 1;
    @features = @{$glyphset->features};
    @features = () unless grep $_->{'drawing_id'} eq $m, @features;
  }
  
  @features = { drawing_id => $m } unless scalar @features;
  
  $self->feature_content($_) for @features;
}

sub feature_content {
  my ($self, $f) = @_;
  my $hub = $self->hub;
  
  $self->new_feature;
  $self->caption($f->{'drawing_id'});
  
  $self->add_entry({
    label => 'Marker info.',
    link  => $hub->url({
      type   => 'Marker',
      action => 'Details',
      m      => $f->{'drawing_id'}
    })
  });
}

1;
