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

# This ZMenu was modelled after EnsEMBL::Web::ZMenu::FeatureEvidence
package EnsEMBL::Web::ZMenu::BigbedPeak;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

use Bio::EnsEMBL::IO::Parser;

sub content {
  my $self                = shift;
  my $hub                 = $self->hub;
  my ($chr, $start, $end) = split /\:|\-/, $hub->param('pos'); 
  my $length              = $end - $start + 1;

  my $content_from_file = $self->content_from_file($hub);
  return unless $content_from_file;

  my $chromosome = $content_from_file->{'chromosome'};
  my $start = $content_from_file->{'chromStart'};
  my $end = $content_from_file->{'chromEnd'};
  my $name = $content_from_file->{'name'};
  my $epigenome_track_source = $content_from_file->{'epigenome_track_source'};
  my $caption = $content_from_file->{'caption'};

  $self->caption($caption);
  
  $self->add_entry({
    type  => 'Feature',
    label => $name
  });

  my $source_label = $epigenome_track_source;

  if(defined $source_label){
    $self->add_entry({
      type        => 'Source',
      label_html  =>  sprintf '<a href="%s">%s</a> ',
                      $hub->url({'type' => 'Experiment', 'action' => 'Sources', 'ex' => $epigenome_track_source }),
                      $source_label
                     });
  }

  my $loc_link = sprintf '<a href="%s">%s</a>', 
                          $hub->url({'type'=>'Location','action'=>'View','r'=> "${chromosome}:${start}-${end}"}),
                          "${chromosome}:${start}-${end}";
  $self->add_entry({
    type        => 'bp',
    label_html  => $loc_link,
  });

  my $matrix_url = $self->hub->url('Config', {
    action => 'ViewBottom',
    matrix => 'RegMatrix',
    menu => 'regulatory_features'
  });

  $self->add_entry({
    label => "Configure tracks",
    link => $matrix_url,
    link_class => 'modal_link',
    link_rel => 'modal_config_viewbottom'
  });

}

# Notice that this subroutine has a potential of returning an undef, if things go wrong (which they shouldn't).
sub content_from_file {
  my ($self, $hub) = @_;


  my $pc_adaptor    = $hub->get_adaptor('get_PeakCallingAdaptor', 'funcgen');
  my $peak_calling_lookup = $hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'peak_calling'};

  my $peak_calling_id = $peak_calling_lookup->{$hub->param('cell_line')}{$hub->param('feat_name')};
  my $peak_calling  = $pc_adaptor->fetch_by_dbID($peak_calling_id);

  my $click_data = $self->click_data;

  return unless $click_data;
  $click_data->{'display'}  = 'text';
  $click_data->{'strand'}   = $hub->param('fake_click_strand');

  my $strand = $hub->param('fake_click_strand') || 1;
  my $slice    = $click_data->{'container'};

  my $bigbed_lookup = $hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'epigenome_track'};
  my $peaks_lookup = $bigbed_lookup->{$hub->param('cell_line')}{$hub->param('feat_name')}{'peaks'};
  my $bigbed_file_id = $peaks_lookup->{'data_file_id'};
  my $epigenome_track_id = $peaks_lookup->{'track_id'};

  if ($bigbed_file_id) {
    my $data_file_adaptor   = $hub->get_adaptor('get_DataFileAdaptor', 'funcgen');
    my $bigbed_file         = $data_file_adaptor->fetch_by_dbID($bigbed_file_id);
    my $bigbed_file_subpath = $bigbed_file->path if $bigbed_file;

    my $epigenome_track_adaptor   = $hub->get_adaptor('get_EpigenomeTrackAdaptor', 'funcgen');
    # my $epigenome_track = $epigenome_track_adaptor->fetch_by_data_file_id($bigbed_file_id)); # This is undefined
    my $epigenome_track = $epigenome_track_adaptor->fetch_by_dbID($epigenome_track_id);
    my $epigenome_track_source_label = $epigenome_track->get_source_label();

    my $full_bigbed_file_path = join '/',
            $hub->species_defs->DATAFILE_BASE_PATH,
            $hub->species_defs->SPECIES_PRODUCTION_NAME,
            $hub->species_defs->ASSEMBLY_VERSION,
            $bigbed_file_subpath;

    my $parser = Bio::EnsEMBL::IO::Parser::open_as('BigBed', $full_bigbed_file_path);
    my ($chr, $start, $end) = split /\:|\-/, $hub->param('pos'); 
    $parser->seek($slice->seq_region_name, $slice->start, $slice->end);
    my $columns = $parser->{'column_map'};
    my $feature_name_column_index = $columns->{'name'};
    my $start;
    my $end;
    my $region;
    my $feature_name;

    if ($parser->next) {
      # At this point, bigbed parser reads the first match that it finds, and the parsed data can be accessed off it.
      # Although, in theory, there may be more than one match, we only know how to handle one.
      $feature_name = $parser->{'record'}[$feature_name_column_index];
      $start = $parser->get_start;
      $end = $parser->get_end;
    }

    return {
      'chromosome' => $slice->seq_region_name,
      'chromStart' => $start,
      'chromEnd' => $end,
      'name' => $peak_calling->display_label,
      'epigenome_track_source' => $epigenome_track_source_label,
      'caption' => $peak_calling->get_FeatureType->evidence_type_label
    };

  }
}

1;
