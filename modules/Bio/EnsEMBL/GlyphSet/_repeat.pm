package Bio::EnsEMBL::GlyphSet::_repeat;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub features {
  my $self        = shift;
  my $types       = $self->my_config('types');
  my $logic_names = $self->my_config('logic_names');
  my @repeats     = sort { $a->seq_region_start <=> $b->seq_region_end } map { my $t = $_; map @{$self->{'container'}->get_all_RepeatFeatures($t, $_)}, @$types } @$logic_names;

  $self->errorTrack(sprintf 'No %s features in this region', $self->my_config('name')) unless scalar @repeats >= 1 || $self->{'config'}->get_option('opt_empty_tracks') == 0;
  
  return \@repeats;
}

sub colour_key { return 'repeat'; }
sub class      { return 'group'; }
sub title      { return sprintf '%s; bp: %s-%s; length: %s', $_[1]->repeat_consensus->name, $_[1]->seq_region_start, $_[1]->seq_region_end, $_[1]->length; }

sub href {
  my ($self, $f)  = @_;
  
  return $self->_url({
    species => $self->species,
    type    => 'Repeat',
    id      => $f->dbID
  });
}

sub export_feature {
  my ($self, $feature) = @_;
  my $id = "repeat:$feature->{'dbID'}";
  
  return if $self->{'export_cache'}{$id};
  
  $self->{'export_cache'}{$id} = 1;
  
  return $self->_render_text($feature, 'Repeat', undef, { source => $feature->display_id });
}

1;
