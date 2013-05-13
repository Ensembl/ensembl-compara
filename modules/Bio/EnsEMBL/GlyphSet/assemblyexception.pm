package Bio::EnsEMBL::GlyphSet::assemblyexception;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub readable_strand { return $_[1] < 0 ? 'rev' : 'fwd'; }
sub my_label        { return undef; }

sub features        { return $_[0]->{'container'}->get_all_AssemblyExceptionFeatures; }

sub colour_key {
  my ($self, $f) = @_;
  (my $key = lc $f->type) =~ s/ /_/g;
  return $key;
}

sub feature_label {
  my ($self, $f) = @_;
  
  return undef if $self->my_config('label') eq 'off';

=pod
  my %type_lookup = (
    'HAP' => 'Haplotype(s)',
    'PAR' => 'PAR',
    'PATCH_NOVEL' => 'Novel patch',
    'PATCH_FIX'   => 'Fix patch',
  );

  if ($self->my_config('short_labels')) {
    (my $key = $f->type) =~ s/ REF//;
    my $label = $type_lookup{$key};
    return $label;
  }
=cut
  return $f->{'alternate_slice'}->seq_region_name if $self->my_config('short_labels');

  return sprintf(
    '%s: %s:%d-%d (%s)',
    $f->type,
    $f->{'alternate_slice'}->seq_region_name,
    $f->{'alternate_slice'}->start,
    $f->{'alternate_slice'}->end,
    $self->readable_strand($f->{'alternate_slice'}->strand)
  );
}

sub title {
  my ($self, $f) = @_;

  return sprintf('%s; %s:%d-%d (%s); %s:%d-%d (%s)',
    $self->my_colour($self->colour_key($f), 'text'),
    $f->{'slice'}->seq_region_name,
    $f->{'slice'}->start + $f->{'start'} - 1,
    $f->{'slice'}->start + $f->{'end'}   - 1,
    $self->readable_strand($f->{'slice'}->strand),
    $f->{'alternate_slice'}->seq_region_name,
    $f->{'alternate_slice'}->start,
    $f->{'alternate_slice'}->end,
    $self->readable_strand($f->{'alternate_slice'}->strand)
  );
}


sub href {
  my ($self, $f) = @_;
  my $slice = $f->alternate_slice;
  my $c2    = $slice->seq_region_name;
  my $s2    = $slice->start;
  my $e2    = $slice->end;
  my $o2    = $slice->strand;
  my $class = $self->colour_key($f);
  
  return $self->_url({
    species     => $f->species,
    action      => 'View',
    r           => "$c2:$s2-$e2",
    target      => $f->slice->seq_region_name,
    target_type => [ split ' ', $f->type ]->[0],
    class       => $class,
  });
}

sub tag {
  my ($self, $f) = @_;
  
  return {
    style  => 'join',
    tag    => $f->{'alternate_slice'}->seq_region_name . ":$f->{'start'}-$f->{'end'}",
    colour => $self->my_colour($self->colour_key($f), 'join'),
    zindex => -20
  };
}

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type) = @_;
  
  return $self->_render_text($feature, $feature_type, { 
    headers => [ 'alternate_slice' ],
    values  => [ $feature->{'alternate_slice'}->seq_region_name ]
  });
}

1;
