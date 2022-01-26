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

package EnsEMBL::Draw::GlyphSet::alternative_assembly;

### Draws alternative assembly tracks (e.g. Vega) on Region in Detail
### and Region Overview images

use strict;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::SimpleFeature;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub label_overlay { return 1; }

sub features {
  my $self = shift;
  my $assembly = $self->my_config( 'assembly_name' );

  my $reg = "Bio::EnsEMBL::Registry";
  my $species = $self->{'config'}->{'species'};
  my $orig_group;
  my $this_slice = $self->{'container'};

  my $res = [];
  my $projection = $this_slice->project('chromosome', $assembly);
  foreach my $seg ( @$projection ) {
    my $slice = $seg->to_Slice;
    my $location = $slice->seq_region_name.":".$slice->start."-".$slice->end;
    my $f = Bio::EnsEMBL::SimpleFeature->new(
      -display_label  => $location,
      -start          => $seg->from_start,
      -end            => $seg->from_end,
      -strand         => $slice->strand,
    );
    push @$res, $f;
  }

  return $res;
}

sub href {
  my ($self, $f) = @_;
  my ($location) = split /\./ ,  $f->display_id;
  my $species = $self->species;
  my $assembly = $self->my_config( 'assembly_name' );
  my $url = $self->_url({
    'new_r'    => $location,
    'assembly' => $self->my_config( 'assembly_name' ),
  });
  return $url;
}

sub feature_label {
  my ($self, $f) = @_; 
  return $f->display_id;
}

sub title {
  my ($self, $f ) = @_;
  my $assembly = $self->my_config( 'assembly_name' );
  my $title = $assembly.':'.$f->display_id;
  return $title;
}

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type) = @_;
  my $assembly = $self->my_config( 'assembly_name' );

  my $container = $self->{'container'};

  return $self->_render_text($feature, $feature_type, { 
    'headers' => [ "$assembly" ],
    'values' => [ [$self->feature_label($feature)]->[0] ]
  }, {
    'seqname' => $container->seq_region_name,
    'start'   => $feature->start + ($container->strand > 0 ? $container->start : $container->end) - 1,
    'end'     => $feature->end + ($container->strand > 0 ? $container->start : $container->end) - 1,
    'source'  => $assembly,
  });
}

1;
