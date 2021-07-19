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

package EnsEMBL::Web::ZMenu::MiscFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $name       = $hub->param('misc_feature');
  my $db_adaptor = $hub->database(lc $hub->param('db') || 'core');
  my $mf         = $db_adaptor->get_MiscFeatureAdaptor->fetch_by_dbID($hub->param('mfid'));
  my $type       = $mf->get_all_MiscSets->[0]->code;
  my $caption    = $type eq 'encode' ? 'Encode region' : $type eq 'ntctgs' ? 'NT Contig' : 'Clone';
  
  $self->caption("$caption: $name");
  
  $self->add_entry({
    type  => 'Range',
    label => $mf->seq_region_start . '-' . $mf->seq_region_end
  });
  
  $self->add_entry({
    type  => 'Length',
    label => $mf->length . ' bps'
  });
  
  # add entries for each of the following attributes
  my @names = ( 
    [ 'name',            'Name'                   ],
    [ 'well_name',       'Well name'              ],
    [ 'sanger_project',  'Sanger project'         ],
    [ 'clone_name',      'Library name'           ],
    [ 'synonym',         'Synonym'                ],
    [ 'embl_acc',        'EMBL accession', 'EMBL' ],
    [ 'bacend',          'BAC end acc',    'EMBL' ],
    [ 'bac',             'AGP clones'             ],
    [ 'alt_well_name',   'Well name'              ],
    [ 'bacend_well_nam', 'BAC end well'           ],
    [ 'state',           'State'                  ],
    [ 'htg',             'HTGS_phase'             ],
    [ 'remark',          'Remark'                 ],
    [ 'organisation',    'Organisation'           ],
    [ 'seq_len',         'Seq length'             ],
    [ 'fp_size',         'FP length'              ],
    [ 'supercontig',     'Super contig'           ],
    [ 'fish',            'FISH'                   ],
    [ 'description',     'Description'            ]
  );
  
  foreach (@names) {
    my $value = $mf->get_scalar_attribute($_->[0]);
    my $entry;
    
    # hacks for these type of entries
    if ($_->[0] eq 'BACend_flag') {
      $value = ('Interpolated', 'Start located', 'End located', 'Both ends located')[$value]; 
    } elsif ($_->[0] eq 'synonym' && $mf->get_scalar_attribute('organisation') eq 'SC') {
      $value = "//www.sanger.ac.uk/cgi-bin/humace/clone_status?clone_name=$value";
    }
    
    if ($value) {
      $entry = {
        type  => $_->[1],
        label => $value
      };
      
      $entry->{'link'} = $hub->get_ExtURL($_->[2], $value) if $_->[2];
      
      $self->add_entry($entry);
    }
  }
  
  $self->add_entry({
    label => "Centre on $caption",
    link  => $hub->url({
      type   => 'Location', 
      action => 'View'
    })
  });
}

1;
