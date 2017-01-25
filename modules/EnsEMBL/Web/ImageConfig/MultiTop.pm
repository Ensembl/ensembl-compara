=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ImageConfig::MultiTop;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig::MultiSpecies);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    sortable_tracks  => 1,     # allow the user to reorder tracks
    opt_empty_tracks => 0,     # include empty tracks
    opt_lines        => 1,     # draw registry lines
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
    marker
    transcript
    synteny
    decorations
    information
  ));

  $self->add_track('sequence',    'contig', 'Contigs',     'contig', { display => 'normal', strand => 'f' });
  $self->add_track('information', 'info',   'Information', 'text',            { display => 'normal' });

  $self->load_tracks;

  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'f', menu => 'no' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );

  $self->modify_configs(
    [ 'transcript' ],
    { strand => 'r' }
  );
}

sub join_genes {
  my ($self, $chr, @slices) = @_;
  my ($ps, $pt, $ns, $nt) = map { $_->{'species'}, $_->{'target'} } @slices;
  my $sp         = $self->{'species'};
  my $sd         = $self->species_defs;
  my $multi_hash = $sd->multi_hash;

  for (map { @{$_->{'INTRA_SPECIES_ALIGNMENTS'}{'REGION_SUMMARY'}{$ps}{$pt} || []}, @{$_->{'INTRA_SPECIES_ALIGNMENTS'}{'REGION_SUMMARY'}{$ns}{$nt} || []} } map $multi_hash->{$_} || (), @{$sd->compara_like_databases}) {
    $self->set_parameter('homologue', $_->{'homologue'}) if $_->{'species'}{"$sp--$chr"};
  }

  foreach ($self->get_node('transcript')->nodes) {
    $_->set('previous_species', $ps) if $ps;
    $_->set('next_species',     $ns) if $ns;
    $_->set('previous_target',  $pt) if $pt;
    $_->set('next_target',      $nt) if $nt;
    $_->set('join', 1);
  }
}

sub highlight {
  my ($self, $gene) = @_;
  $_->set_data('g', $gene) for $self->get_node('transcript')->nodes;
}

1;
