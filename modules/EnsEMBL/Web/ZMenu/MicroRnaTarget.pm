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

package EnsEMBL::Web::ZMenu::MicroRnaTarget;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self              = shift;
  my $hub               = $self->hub;
  my $feature           = $hub->database('funcgen')->get_MirnaTargetFeatureAdaptor->fetch_by_dbID($hub->param('dbid'));
  my $adaptor           = $hub->database('funcgen')->get_DBEntryAdaptor;
  my $gene_stable_id    = $feature->gene_stable_id;

  my $logic_name = $feature->analysis->logic_name;
  my $source_page = $hub->get_ExtURL($logic_name, 
                      {
                        'ID' => $feature->accession,
                        'GENE' => $gene_stable_id,
                      }
                    );
  
  $self->caption('MicroRNA ID: '.$feature->display_label);

  $self->add_entry ({
    type   => 'Source',
    label  => "TarBase ".$feature->display_label." target",
    link   => $source_page,
  });

  my $mirbase_url = $hub->get_ExtURL('MIRBASE_MATURE', $feature->accession);
  $self->add_entry ({
    type   => 'miRBase mature ID',
    label  => $feature->accession,
    link   => $mirbase_url,
  });

  my $r = sprintf("%s:%d-%d",
                   $feature->seq_region_name,
                   $feature->seq_region_start,
                   $feature->seq_region_end);
  $self->add_entry ({
    type        => 'bp',
    label       => $r,
    link        => $hub->url({ r => $r, type => 'Location',  action => 'View' }),
    link_class  => '_location_change _location_mark'
  });

  $self->add_entry ({
    type      => 'Target(s)',
    label_html => sprintf('<a href="%s">%s</a>', $hub->url({'type' => 'Gene', 'action' => 'Summary', 'g' => $gene_stable_id, 'db' => 'core'}), $gene_stable_id), 
  });

  $self->add_entry ({
    type   => 'Evidence',
    label  => $feature->evidence,
  });

  $self->add_entry ({
    type   => 'Supporting information',
    label  => $feature->supporting_information,
  });

  my $feature_view_link = $self->hub->url({
                              type   => 'Location',
                              action => 'Genome',
                              ftype  => 'RegulatoryFactor',
                              fset   => $feature->get_FeatureType->name,
                              id     => $feature->display_label,
                            });

  if ($feature_view_link) {
    $self->add_entry({
      label_html => 'View all locations',
      link       => $feature_view_link,
    });
  }
}

1;
