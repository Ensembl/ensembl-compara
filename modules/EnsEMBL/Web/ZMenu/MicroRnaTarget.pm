=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

  my @gene_stable_ids   = ();
  my $gene_string = join(',', @gene_stable_ids);

  my $logic_name = $feature->analysis->logic_name;
  my $source_site = $hub->get_ExtURL($logic_name);
  my $source_page = $hub->get_ExtURL($logic_name.'_FEATURE', 
                      {
                        'ID' => $feature->accession,
                        'GENE' => $gene_string,
                      }
                    );
  
  $self->caption('MicroRNA target: '.$feature->$display_label);

  $self->add_entry ({
    type   => 'Source',
    label  => $feature->feature_set->description,
    link   => $source_site,
  });

  $self->add_entry ({
    type   => 'Accession',
    label  => $feature->accession,
    link   => $source_page,
  });

  $self->add_entry ({
    type   => 'bp',
    label  => $feature->seq_region_start.' - '.$feature->seq_region_end,
  });

  my @gene_links;
  foreach (@gene_stable_ids) {
    push @gene_links, sprintf('<a href="%s">%s</a>', $hub->url({'type' => 'Gene', 'action' => 'Summary', 'g' => $_}), $_);
  }
  $self->add_entry ({
    type      => 'Target(s)',
    label_html => join(', ', @gene_links), 
  });

  $self->add_entry ({
    type   => 'Evidence',
    label  => $feature->evidence,
  });

}

1;
