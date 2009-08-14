package Bio::EnsEMBL::GlyphSet::_qtl;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub _das_type {  return 'qtl'; }

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_QtlFeatures();
}

sub colour_key {
  sub _das_type {  return 'simple'; }
  return 'default';
}

sub feature_label {
  my ($self, $f) = @_;
  return $f->qtl->trait,'overlaid';
}

sub title {
  my ($self, $f) = @_;
  my $title = $f->qtl->trait;
  my $f_proj = $self->_se($f);
  $title.= sprintf(
    '; Location: %s:%d-%d',
    $f_proj->{name}, $f_proj->{start}, $f_proj->{end}
  );
  return $title;
}


sub href {
  my($self,$f, $src) = @_;

  my $syns = $f->qtl->get_synonyms;

  #if no source specified use first src
  ($src) = keys %$syns if(!$src);

  my $id = $syns->{$src};

  ( my $SRC = uc( $src ) ) =~s/ /_/g;
  my $qtl_link = $self->species_defs->ENSEMBL_EXTERNAL_URLS->{$SRC};
  $qtl_link =~ s/###ID###/$id/;
  return $qtl_link;
}

sub _se {
  my( $self, $f ) = @_;
  my $f_proj = $f->project( 'toplevel' );
  $_ = shift @$f_proj;
  my $name = $_->[2]->seq_region_name;
  my ($start,$end) = ($_->[2]->start, $_->[2]->end);
  foreach( @$f_proj )  {
    unless( $_->[2]->seq_region_name eq $name ) {
      warn "CANNOT PROJECT AS NAMES DIFFERENT.... $name != ".$_->[2]->seq_region_name;
      next;
    }
    $start = $_->[2]->start if $_->[2]->start < $start;
    $end   = $_->[2]->end   if $_->[2]->end   > $end;
  }
  return { 'name' => $name, 'start' => $start, 'end' => $end };
}

sub tag {
  my ($self, $f) = @_;
  my $qtl = $f->qtl;
  my $markers = {
    'flank_marker_1' => $qtl->flank_marker_1,
    'peak_marker'    => $qtl->peak_marker,
    'flank_marker_2' => $qtl->flank_marker_2
  };
  my $f_proj = $self->_se($f);
  my @tags = ();
  foreach my $type ( sort keys %$markers ) {
    my $m = $markers->{$type};
    next unless $m;
    my $mfs = $m->get_all_MarkerFeatures();
    next unless $mfs && @$mfs;
    ## We have a marker feature... lets see if it on the slice!!
    foreach my $mf ( @$mfs ) {
      my $mf_proj = $self->_se($mf);
      next if $mf_proj->{'name'} ne $f_proj->{'name'};
      next if $mf_proj->{'end'}   < $self->{'container'}->start;
      next if $mf_proj->{'start'} > $self->{'container'}->end;
      push @tags, {
        'style'        => 'rect',
        'colour'       => $self->my_colour( $type ),
        'start'        => $mf->start - $self->{'container'}->start - 1,
        'end'          => $mf->end   - $self->{'container'}->start - 1
      };
    }
  }
  return @tags;
}

1;
