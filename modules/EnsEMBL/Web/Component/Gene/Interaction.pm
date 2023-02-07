=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::Interaction;
use strict;

use URI::Escape qw(uri_escape);
use HTML::Entities qw(encode_entities);
use JSON qw(from_json to_json encode_json decode_json);

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->{panel_type} = 'Interaction';
}

sub content {
  my $self    = shift;
  my $object  = $self->object;
  my $hub     = $self->hub;
  my $geneId = $hub->param('g');

  if (!$hub->mol_int_status) {
    return $self->_warning("Molecular interactions unavailable", "Cannot retrieve data as the molecular interactions server is not accessible at the moment. Please try again later.");
  }

  my $interactions = $object->get_molecular_interactions($geneId);

  if(! keys %$interactions) {
    # Should not come here because we do the availability check
    return $self->_info('No data available', 'No molecular interactions available for this gene');
  }

  my $interactor_1 = $interactions->{'interactor_1'};

  my $col_headers_int1 = [
              { 'key' => 'species',   'title' => 'Species', 'width' => '150px', 'sort' => 'none' },
              { 'key' => 'gene',   'title' => 'Gene ID', 'width' => '150px', 'sort' => 'none' },
              { 'key' => 'interactor',  'title' => 'Interactor', 'width' => '150px', 'sort' => 'none' },
              { 'key' => 'identifier',   'title' => 'Identifier', 'sort' => 'none' }
            ];

  my $col_headers_int2 = {
    'species' => [
              { 'key' => 'name',   'title' => 'Species', 'width' => '150px', 'sort' => 'none' },
              { 'key' => 'gene',   'title' => 'Gene ID', 'width' => '150px', 'sort' => 'none' },
              { 'key' => 'interactor',  'title' => 'Interactor', 'width' => '150px', 'sort' => 'none' },
              { 'key' => 'identifier',   'title' => 'Identifier', 'width' => '150px', 'sort' => 'none' },
              { 'key' => 'source',   'title' => 'Source DB', 'sort' => 'none' }
            ],
    'other' => [
              { 'key' => 'name',   'title' => 'Other', 'width' => '200px', 'sort' => 'none' },
              { 'key' => 'interactor',  'title' => 'Interactor', 'width' => '150px', 'sort' => 'none' },
              { 'key' => 'identifier',   'title' => 'Identifier', 'width' => '150px', 'sort' => 'none' },
              { 'key' => 'source',   'title' => 'Source DB', 'sort' => 'none' }
            ]
  };
          

  my $col_headers_int2_species = [];

  my $table_interactor1 =  $self->new_table($col_headers_int1);

  $table_interactor1->add_row({
    'species' =>  $interactor_1->{'name'},
    'gene' =>  &createLink($interactor_1->{'gene'}),
    'interactor' =>  $interactor_1->{'interactor'},
    'identifier' =>  &createLink($interactor_1->{'identifier'})
  });

  my $table_interactor_species =  $self->new_table($col_headers_int2->{species});
  my $table_interactor_other =  $self->new_table($col_headers_int2->{other});

  my $metadata = {};
  my $data_availability_map = {};

  for my $int (@{$interactions->{'interactor_2'}}) {
    if ($int->{'type'} eq 'species') {
      my $gene_id = &createLink($int->{'gene'});
      my $identifier = &createLink($int->{'identifier'});

      $table_interactor_species->add_row({
        'name' =>  $int->{'name'},
        'gene' =>  $gene_id || '-',
        'interactor' =>  $int->{'interactor'} || '-',
        'identifier' =>  $identifier,
        'source' =>  &createLink($int->{'source_DB'}) || '-'
      });
      $data_availability_map->{'species'} = 1;
      push(@{$metadata->{'species'}}, $int->{'metadata'});
    }
    else {
      $table_interactor_other->add_row({
        'name' =>  $int->{'name'},
        'interactor' =>  $int->{'interactor'},
        'identifier' =>  &createLink($int->{'identifier'}),
        'source' =>  &createLink($int->{'source_DB'})
      });
      $data_availability_map->{'other'} = 1;
      push(@{$metadata->{'other'}}, $int->{'metadata'});
    }
  }

  my $tab1 = $table_interactor1->render;
  my $tab2 = $data_availability_map->{'species'} && $table_interactor_species->render;
  my $tab3 = $data_availability_map->{'other'} && $table_interactor_other->render;

      
  return sprintf('
    <div id="interaction" class="js_panel interactions-wrapper">
      <input class="panel_type" type="hidden" value="Interaction">
      <div class="interactions-left">
        <div class="bold-label">This species</div>
        <div> %s </div>
      </div>
      <div class="interactions-right">
        <div class="label"><span class="bold-label">Interacts with </span><a>Show metadata</a></div>
        <div class="interactions-species"> %s </div>
        <div class="interactions-other"> %s </div>
      </div>
      <input type="hidden" name="intr_metadata" value="%s">
    </div>',
    $tab1, $tab2, $tab3, encode_entities(to_json($metadata))
  );
}

sub createLink {
  my $data = shift;

  if ($data->{'url'}) {
    return sprintf(qq{<a href="%s" target="_blank">%s</a>}, $data->{'url'} || '', $data->{'name'})
  }
  else {
    return $data->{'name'}
  }
}

1;
