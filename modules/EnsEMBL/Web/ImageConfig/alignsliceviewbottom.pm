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

package EnsEMBL::Web::ImageConfig::alignsliceviewbottom;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::MultiSpecies);

sub init {
  my $self    = shift;
  my $species = $self->species;
  
  $self->set_parameters({
    sortable_tracks => 1, # allow the user to reorder tracks
  });

  my $sp_img_48 = $self->species_defs->ENSEMBL_WEBROOT . '/../public-plugins/ensembl/htdocs/i/species/48'; # XXX make configurable
  if(-e $sp_img_48) {
    $self->set_parameters({ spritelib => {
      %{$self->get_parameter('spritelib')||{}},
      species => $sp_img_48,
    }});
  }
  $self->create_menus(qw(
    sequence
    transcript
    repeat
    variation
    somatic
    conservation
    information
  ));
  
  $self->add_track('sequence', 'contig', 'Contigs', 'contig', { display => 'normal', strand => 'r', description => 'Track showing underlying assembly contigs' });
 
  $self->add_tracks('information', 
    [ 'alignscalebar',     '',                  'alignscalebar',     { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'ruler',             '',                  'ruler',             { display => 'normal', strand => 'f', menu => 'no' }],
    [ 'draggable',         '',                  'draggable',         { display => 'normal', strand => 'b', menu => 'no' }], # TODO: get this working
    [ 'variation_legend', 'Variation Legend','variation_legend', {  display => 'normal', strand => 'r', accumulate => 'yes' }],
    [ 'alignslice_legend', 'AlignSlice Legend', 'alignslice_legend', { display => 'normal', strand => 'r', accumulate => 'yes' }],
    [ 'gene_legend', 'Gene Legend','gene_legend', {  display => 'normal', strand => 'r', accumulate => 'yes' }],
  );
  
  if ($species eq 'Multi') {
    $self->set_parameter('sortable_tracks', 0);
  } else {
    $self->load_tracks;
  }
  
  my $gencode_version = $self->hub->species_defs->GENCODE ? $self->hub->species_defs->GENCODE->{'version'} : '';
  $self->add_track('transcript', 'gencode', "Basic Gene Annotations from GENCODE $gencode_version", '_gencode', {
      labelcaption => "Genes (Basic set from GENCODE $gencode_version)",
      display     => 'off',       
      description => 'The GENCODE set is the gene set for human and mouse. GENCODE Basic is a subset of representative transcripts (splice variants).',
      sortable    => 1,
      colours     => $self->species_defs->colour('gene'), 
      label_key  => '[biotype]',
      logic_names => ['proj_ensembl',  'proj_ncrna', 'proj_havana_ig_gene', 'havana_ig_gene', 'ensembl_havana_ig_gene', 'proj_ensembl_havana_lincrna', 'proj_havana', 'ensembl', 'mt_genbank_import', 'ensembl_havana_lincrna', 'proj_ensembl_havana_ig_gene', 'ncrna', 'assembly_patch_ensembl', 'ensembl_havana_gene', 'ensembl_lincrna', 'proj_ensembl_havana_gene', 'havana'], 
      renderers   =>  [
        'off',                     'Off',
        'gene_nolabel',            'No exon structure without labels',
        'gene_label',              'No exon structure with labels',
        'transcript_nolabel',      'Expanded without labels',
        'transcript_label',        'Expanded with labels',
        'collapsed_nolabel',       'Collapsed without labels',
        'collapsed_label',         'Collapsed with labels',
        'transcript_label_coding', 'Coding transcripts only (in coding genes)',
      ],
    }) if($gencode_version);
  
  $self->modify_configs(
    [ 'transcript' ],
    { renderers => [ 
      off                   => 'Off', 
      as_transcript_label   => 'Expanded with labels',
      as_transcript_nolabel => 'Expanded without labels',
      as_collapsed_label    => 'Collapsed with labels',
      as_collapsed_nolabel  => 'Collapsed without labels' 
    ]}
  );
  
  $self->modify_configs(
    [ 'conservation' ],
    { menu => 'no' }
  );

  # Move last gene_legend to after alignslice_legend

  my $dest;
  foreach my $track ($self->get_tracks) {
    if($track->id eq 'alignslice_legend') {
      $self->modify_configs(['gene_legend'],{track_after => $track });
    }
 }
  $self->modify_configs(
    [ 'gene_legend' ],
    { accumulate => 'yes' }
  );
  $self->modify_configs(
    [ 'variation_legend' ],
    { accumulate => 'yes' }
  );
}

sub species_list {
  my $self = shift;
  
  if (!$self->{'species_list'}) {
    my $species_defs = $self->species_defs;
    my $referer      = $self->hub->referer;
    my ($align)      = split '--', $referer->{'params'}{'align'}[0];
    my $alignment    = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'species'} || {};
    my $primary      = $referer->{'ENSEMBL_SPECIES'};
    my @species      = scalar keys %$alignment ? () : ([ $primary, $species_defs->SPECIES_COMMON_NAME($primary) ]);
    
    foreach (sort { $a->[1] cmp $b->[1] } map [ $_, $species_defs->SPECIES_COMMON_NAME($_) ], keys %$alignment) {
      if ($_->[0] eq $primary) {
        unshift @species, $_;
      } elsif ($_->[0] eq 'ancestral_sequences') {
        push @species, [ 'Multi', 'Ancestral sequences' ]; # Cheating: set species to Multi to stop errors due to invalid species.
      } else {
        push @species, $_;
      }
    }
    
    $self->{'species_list'} = \@species;
  }
  
  return $self->{'species_list'};
}

1;
