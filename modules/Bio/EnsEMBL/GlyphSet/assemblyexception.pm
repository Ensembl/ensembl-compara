package Bio::EnsEMBL::GlyphSet::assemblyexception;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish {1;}

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_AssemblyExceptionFeatures();
}

sub colour_key {
  my( $self, $f ) = @_;
  ( my $key = lc($f->type) ) =~ s/ /_/g;
  return $key;
}

sub feature_label {
  my ($self, $f) = @_;
  return undef if $self->my_config( 'label' ) eq 'off';
  if( $self->my_config( 'short_labels') ) {
    return( $f->{'alternate_slice'}->seq_region_name, 'under' ) ;
  }
  return(
    sprintf( "%s: %s:%d-%d (%s)",
      $f->type,
      $f->{'alternate_slice'}->seq_region_name,
      $f->{'alternate_slice'}->start,
      $f->{'alternate_slice'}->end,
      $self->readable_strand( $f->{'alternate_slice'}->strand )
    ), 'undef'
  );
}

sub title {
  my ($self, $f ) = @_;

  return sprintf "%s; %s:%d-%d (%s); %s:%d-%d (%s)",
    $self->my_colour($self->colour_key($f),'text'),
    $f->{'slice'}->seq_region_name,
    $f->{'slice'}->start+$f->{'start'}-1,
    $f->{'slice'}->start+$f->{'end'}-1,
    $self->readable_strand( $f->{'slice'}->strand ),
    $f->{'alternate_slice'}->seq_region_name,
    $f->{'alternate_slice'}->start,
    $f->{'alternate_slice'}->end,
    $self->readable_strand( $f->{'alternate_slice'}->strand );
}


sub href {
  my ($self, $f ) = @_;
  my $c2 = $f->{'alternate_slice'}->seq_region_name;
  my $s2 = $f->{'alternate_slice'}->start;
  my $e2 = $f->{'alternate_slice'}->end;
  my $o2 = $f->{'alternate_slice'}->strand;
  my $script = $ENV{'ENSEMBL_SCRIPT'} eq 'multicontigview' ? 'contigview' : $ENV{'ENSEMBL_SCRIPT'};
  return $self->_url({
    'action' => 'View',
    'r'      => "$c2:$s2-$e2"
  });
}

sub tag {
  my ($self, $f) = @_;
  
  return {
    'style' => 'join',
    'tag' => $f->{'start'}.'-'.$f->{'end'},
    'colour' => $self->my_colour( $self->colour_key($f),'join' ),
    'zindex' => -20
  };
}

1;
