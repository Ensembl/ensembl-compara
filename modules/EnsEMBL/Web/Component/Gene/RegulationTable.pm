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

package EnsEMBL::Web::Component::Gene::RegulationTable;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub caption {
  my $self = shift;
  return 'Regulatory elements located in the region of ' . $self->object->stable_id;
}

sub content {
  my $self    = shift;
  my $object  = $self->object;
  my $hub     = $self->hub;

  ## Only show TarBase features, as there are too many of the other kinds
  my $fg_db         = $hub->database('funcgen');
  my $mirna_adaptor = $fg_db->get_MirnaTargetFeatureAdaptor;
  my @reg_features  = $self->hub->species =~/Drosophila_melanogaster/ ? () : @{$mirna_adaptor->fetch_all_by_gene_stable_id($object->stable_id)};

  ## return if no regulatory elements ##
  if (scalar @reg_features < 1) {
    my $html = "<p><strong>There are no TarBase features linked to this gene</strong></p>";
    return $html;
  }

  my $table = $self->new_table([], [], { data_table => 1 });
  $table->add_columns(
    { key => 'type',      title => 'Feature type',  width => '20%', align => 'left', sort => 'html'         },
    { key => 'accession', title => 'Accession',     width => '25%', align => 'left', sort => 'position_html'  },
    { key => 'location',  title => 'Location',      width => '25%', align => 'left', sort => 'position_html'  },
    { key => 'source',    title => 'Source',        width => '30%', align => 'left', sort => 'html'           },
  );
  
  foreach my $feature (@reg_features) {
    my $accession = $feature->accession;
    my $r         = sprintf("%s:%d-%d",
                          $feature->seq_region_name,
                          $feature->seq_region_start,
                          $feature->seq_region_end);
    my $location  =  $hub->url({ r => $r, type => 'Location',  action => 'View' });
    my $location_link = sprintf('<a href="%s">%s</a>', $location, $location);

    my $logic_name = $feature->analysis->logic_name;
    my $source_page = $hub->get_ExtURL($logic_name,
      {
        'ID' => $feature->accession,
                        'GENE' => $object->stable_id,
                      }
                    );
    my $source_link = sprintf('<a href="%s">Tarbase %s target</a>', $source_page, $feature->display_label);

    my $row = {
      type      => 'TarBase',
      accession => $accession,
      location  => $location_link, 
      source    => $source_link,
  };
    $table->add_row($row);
  }

  return $table->render;
}

1;
