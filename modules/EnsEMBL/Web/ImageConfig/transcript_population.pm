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

package EnsEMBL::Web::ImageConfig::transcript_population;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    storable          => 0,
    label_width       => 100, # width of labels on left-hand side
    opt_halfheight    => 0,   # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks  => 0,   # include empty tracks..
  });

  $self->create_menus(qw(
    transcript
    variation
    somatic
    prediction
    tsv_transcript
    other
  ));

  $self->load_tracks;

  if ($self->cache_code ne $self->type) {
    my $func = "init_".$self->cache_code;
    $self->$func if $self->can($func);
  }
}

sub init_transcript {
  my $self = shift;

  $self->set_parameters({
    _options    => [qw(pos col known unknown)],
    _add_labels => 1,
  });

  $self->modify_configs(
    [ 'transcript' ],
    { display => 'off' }
  );

  $self->add_tracks('transcript',
    [ 'snp_join', '', 'snp_join', { display => 'on', strand => 'b', tag => 0, colours => $self->species_defs->colour('variation'), menu => 'no' }]
  );

  $self->add_tracks('other',
    [ 'transcriptexon_bgtrack', '', 'transcriptexon_bgtrack', { display => 'normal', strand => 'b', menu => 'no' , src => 'all', colours => 'bisque', tag => 0                                        }],
    [ 'scalebar',               '', 'scalebar',               { display => 'normal', strand => 'f', name => 'Scale bar', description => 'Shows the scalebar'                                          }],
    [ 'ruler',                  '', 'ruler',                  { display => 'normal', strand => 'f', name => 'Ruler',     description => 'Shows the length of the region being displayed', notext => 1 }],
    [ 'spacer',                 '', 'spacer',                 { display => 'normal', strand => 'r', menu => 'no', height => 22                                                                        }],
  );

  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'compact', strand => 'f' }
  );
}

sub init_transcripts_top {
  my $self = shift;

  $self->add_tracks('other',
    [ 'transcriptexon_bgtrack', '', 'geneexon_bgtrack', { display => 'normal', strand => 'f', menu => 'no', tag => 1, colours => 'bisque', src => 'all'                                  }],
    [ 'snp_join',               '', 'snp_join',         { display => 'on',     strand => 'f', menu => 'no', tag => 1, colours => $self->species_defs->colour('variation'), context => 50 }],
  );
}

sub init_transcripts_bottom {
  my $self = shift;

  $self->add_tracks('other',
    [ 'transcriptexon_bgtrack', '', 'geneexon_bgtrack', { display => 'normal', strand => 'r', menu => 'no', tag => 1, colours => 'bisque', src => 'all'                                  }],
    [ 'snp_join',               '', 'snp_join',         { display => 'on',     strand => 'r', menu => 'no', tag => 1, colours => $self->species_defs->colour('variation'), context => 50 }],
    [ 'ruler',                  '', 'ruler',            { display => 'normal', strand => 'r', name => 'Ruler', notext => 1                                                               }],
    [ 'spacer',                 '', 'spacer',           { display => 'normal', strand => 'r', menu => 'no', height => 50                                                                 }],
  );
}

sub init_sample_transcript {
  my $self = shift;

  $self->add_tracks('other',
    [ 'coverage_top',   '', 'coverage',       { display => 'on',     strand => 'r', menu => 'no', type => 'top', caption => 'Resequence coverage'     }],
    [ 'tsv_variations', '', 'tsv_variations', { display => 'normal', strand => 'r', menu => 'no', colours => $self->species_defs->colour('variation') }],
  );
}

1;
