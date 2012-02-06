# $Id$

package EnsEMBL::Web::ImageConfig::MultiTop;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::MultiSpecies);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    sortable_tracks   => 1,     # allow the user to reorder tracks
    opt_empty_tracks  => 0,     # include empty tracks
    opt_lines         => 1,     # draw registry lines
    opt_restrict_zoom => 1,     # when we get "zoom" working draw restriction enzyme info on it 
  });

  $self->create_menus(qw(
    sequence
    marker
    transcript
    synteny
    decorations
    information
  ));
    
  $self->add_track('sequence',    'contig', 'Contigs',     'stranded_contig', { display => 'normal', strand => 'f' });
  $self->add_track('information', 'info',   'Information', 'text',            { display => 'normal' });
  
  $self->load_tracks;

  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'f', menu => 'no' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );
  
  $self->modify_configs(
    [ 'transcript' ],
    { render => 'gene_label', strand => 'r' }
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
  $_->set('g', $gene) for $self->get_node('transcript')->nodes; 
}

1;
