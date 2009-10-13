# $Id$

package EnsEMBL::Web::ZMenu::MiscFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object     = $self->object;
  my $name       = $object->param('misc_feature_n');
  my $db_adaptor = $object->database(lc $object->param('db') || 'core');
  my $mf         = $db_adaptor->get_MiscFeatureAdaptor->fetch_by_dbID($object->param('mfid'));
  my $type       = $mf->get_all_MiscSets->[0]->code;
  my $caption    = $type eq 'encode' ? 'Encode region' : $type eq 'ntctgs' ? 'NT Contig' : 'Clone';
  
  $self->caption("$caption: $name");
  
  $self->add_entry({
    type  => 'bp',
    label => $mf->seq_region_start . '-' . $mf->seq_region_end
  });
  
  $self->add_entry({
    type  => 'length',
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
      $value = "http://www.sanger.ac.uk/cgi-bin/humace/clone_status?clone_name=$value";
    }
    
    if ($value) {
      $entry = {
        type  => $_->[1],
        label => $value
      };
      
      $entry->{'link'} = $object->get_ExtURL($_->[2], $value) if $_->[2];
      
      $self->add_entry($entry);
    }
  }
  
  $self->add_entry({
    label => "Center on $caption",
    link  => $object->_url({
      type         => 'Location', 
      action       => 'View', 
      misc_feature => $name
    })
  });
}

1;
