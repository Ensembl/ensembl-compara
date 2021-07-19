=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::_qtl;

### Draws QTL (Quantitative Trait Loci) tracks
### STATUS : Uncertain. Not sure we have any of these tracks right now

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub label_overlay { return 1; }

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_QtlFeatures();
}

sub colour_key {
  return 'default';
}

sub feature_label {
  my ($self, $f) = @_;
  return $f->qtl->trait;
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
  return $self->ID_URL( $SRC, $id);
}

sub _se {
  my ($self, $f) = @_;
  my $f_proj = $f->project('toplevel');
     $f      = shift @$f_proj;
  my $name   = $f->[2]->seq_region_name;
  my ($start, $end) = ($f->[2]->start, $f->[2]->end);
  
  foreach (@$f_proj)  {
    if ($_->[2]->seq_region_name ne $name) {
      warn "CANNOT PROJECT AS NAMES DIFFERENT.... $name != " . $_->[2]->seq_region_name;
      next;
    }
    
    $start = $_->[2]->start if $_->[2]->start < $start;
    $end   = $_->[2]->end   if $_->[2]->end   > $end;
  }
  
  return { name => $name, start => $start, end => $end };
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

sub ID_URL {
  my ($self, $db, $id) = @_;
  
  return undef unless $self->species_defs;
  return undef if $db eq 'NULL';
  
  if (exists $self->species_defs->ENSEMBL_EXTERNAL_URLS->{$db}) {
    my $url = $self->species_defs->ENSEMBL_EXTERNAL_URLS->{$db};
       $url =~ s/###ID###/$id/;
    
    return $url;
  } else {
    return '';
  }
}

1;
