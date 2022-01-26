=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::patch_ref_alignment;

### Draws alternate sequence alignment track on Region in Detail

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my $self = shift;

  return $self->render_text if $self->{'text_export'};

  my $container     = $self->{'container'};
  my $length        = $self->{'container'}->length;
  my $features      = $self->features;
  my $join_colour   = $self->my_colour(lc $self->{'container'}->assembly_exception_type, 'join'); 

  if (scalar @$features) {
    my $patch_start   = $self->{'container'}->get_all_AssemblyExceptionFeatures->[0]->start; 
    my $patch_end     = $self->{'container'}->get_all_AssemblyExceptionFeatures->[0]->end; 
    $patch_start      = 1 if $patch_start < 1;
    my $patch_length  = $patch_end - $patch_start +1;
    $patch_length     = $length if $patch_length > $length;

    foreach (0, 8) {
      $self->push($self->Rect({
        x         => $patch_start -1,
        y         => $_,
        width     => $patch_length,
        height    => 0,
        colour    => $join_colour,
        absolutey => 1,
      }));
    }
    $self->init_alignment($features);
  } else {
    $self->errorTrack('No alignments to display') if $self->{'config'}->get_option('opt_empty_tracks') == 1;
  }
}

sub init_alignment {
  my ($self, $features) = @_;
  my $length            = $self->{'container'}->length;
  my $base_colour       = $self->my_colour(lc $self->{'container'}->assembly_exception_type);
  my $alt_colour        = $self->{'config'}->colourmap->mix($base_colour, 'white', 0.45);
  my @colours           = ($base_colour, $alt_colour);
  my $i                 = 0;

  foreach (sort { $a->{'start'} <=> $b->{'start'} } @$features) {
    my $strand = $_->strand;
    my $rend   = $_->{'end'}; 
    my $rstart = $_->{'start'}; 
    my $region = $_->{'name'};

    ($rstart, $rend) = ($rend, $rstart) if $rstart > $rend;
    $rstart = 1 if $rstart < 1;
    $rend   = $length if $rend > $length;

    $self->push($self->Rect({
      x         => $rstart - 1,
      y         => 0,
      width     => $rend - $rstart + 1,
      height    => 8,
      colour    => $colours[$i],
      absolutey => 1,
      href      => $self->href($_)
    }));

    $i = $i == 0 ? 1 : 0;
  }
}


sub features {
  my $self = shift;
  my $method       = 'get_all_' . ($self->my_config('object_type') || 'DnaAlignFeature') . 's';
  my $db           = $self->my_config('db');
  my @logic_names  = @{$self->my_config('logic_names') || []};
  my @results = @{$self->{'container'}->$method($logic_names[0], undef, $db) || ()};

  return \@results;
}

sub href {
  ### Links to /Location/Genome

  my ($self, $f) = @_;
  my $ln     = $f->can('analysis') ? $f->analysis->logic_name : '';
  my $id     = $f->display_id;
     $id     = $f->dbID if $ln eq 'alt_seq_mapping';

  return $self->_url({
    species => $self->species,
    action  => $self->my_config('zmenu') ? $self->my_config('zmenu') : 'Genome',
    ftype   => $self->my_config('object_type') || 'DnaAlignFeature',
    db      => $self->my_config('db'),
    r       => $f->seq_region_name . ':' . $f->seq_region_start . '-' . $f->seq_region_end,
    id      => $id,
    ln      => $ln,
  });
}
 
1;

