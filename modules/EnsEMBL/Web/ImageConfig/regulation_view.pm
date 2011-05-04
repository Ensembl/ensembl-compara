# $Id$

package EnsEMBL::Web::ImageConfig::regulation_view;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title          => 'Feature context',
    show_labels    => 'yes',
    label_width    => 113,
    opt_lines      => 1,
    opt_highllight => 'yes',
  });  

  $self->create_menus(
    sequence       => 'Sequence',
    transcript     => 'Genes',
    prediction     => 'Prediction transcripts',
    dna_align_rna  => 'RNA alignments',
    oligo          => 'Probe features',
    simple         => 'Simple features',
    misc_feature   => 'Misc. regions',
    repeat         => 'Repeats',
    functional     => 'Functional Genomics', 
    multiple_align => 'Multiple alignments',
    variation      => 'Germline variation',
    other          => 'Decorations',
    information    => 'Information'
  );

  $self->add_tracks('other',
    [ 'scalebar',                 '', 'scalebar',                 { display => 'normal', strand => 'f', menu => 'no', name => 'Scale bar' }],
    [ 'ruler',                    '', 'ruler',                    { display => 'normal', strand => 'f', menu => 'no', name => 'Ruler'     }],
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', strand => 'r', menu => 'no', tag => 0            }],
);
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r' }]
  );

  $self->load_tracks;
  $self->load_configured_das;

  $self->modify_configs(
    [ 'functional' ],
    { display => 'off', menu => 'no' }
  );
  
  my @feature_sets = ('cisRED', 'VISTA', 'miRanda', 'NestedMICA', 'REDfly CRM', 'REDfly TFBS', 'search');
  
  $self->modify_configs(
    [ map "regulatory_regions_funcgen_$_", @feature_sets ],
    { menu => 'yes' }
  );
  
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'collapsed_nolabel' }
  );
  
  $self->modify_configs(
    [ 'information' ],
    { menu => 'no', display => 'off' }
  );
  
  $self->modify_configs(
    [ 'opt_empty_tracks' ],
    { menu => 'yes', display => 'off' }
  );
}
1;
