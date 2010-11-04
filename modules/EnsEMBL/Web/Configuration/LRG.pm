# $Id$

package EnsEMBL::Web::Configuration::LRG;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Genome';
}

sub short_caption {
  my $self = shift;
  return 'LRG-based displays';
}

sub caption {
  my $self = shift;
  my $caption;
  
  if ($self->hub->param('lrg')) {
    $caption = 'LRG: ' . $self->hub->param('lrg'); 
  } else {
    $caption = 'LRGs';
  }
  
  return $caption;
}

sub counts {
  my $self = shift;
  my $hub = $self->hub;
  my $obj = $self->builder->api_object('Gene');

  return {} unless $obj;

  my $key = sprintf '::COUNTS::GENE::%s::%s::%s::', $hub->species, $hub->param('db'), $hub->param('lrg');
  my $counts = $hub->cache ? $hub->cache->get($key) : undef;

  if (!$counts) {
    $counts = {
      transcripts => scalar @{$self->builder->api_object('Transcript')},
      genes       => 1,
    };

    $hub->cache->set($key, $counts, undef, 'COUNTS') if $hub->cache;
  }
 
  return $counts;
}

sub populate_tree {
  my $self = shift;
  
  $self->create_node('Genome', 'All LRGs',
    [qw(
      karyotype EnsEMBL::Web::Component::LRG::Genome 
    )],
    { 'availability' => 1 }
  );

  $self->create_node('Summary', 'LRG summary',
    [qw(
      summary     EnsEMBL::Web::Component::LRG::LRGSummary
      transcripts EnsEMBL::Web::Component::LRG::TranscriptsImage  
    )],
    { 'availability' => 'lrg' }
  );

  $self->create_node('Sequence', 'Sequence',
    [qw( exons EnsEMBL::Web::Component::LRG::LRGSeq )],
    { 'availability' => 'lrg' }
  );

  $self->create_node('Differences', 'Reference comparison',
    [qw( exons EnsEMBL::Web::Component::LRG::LRGDiff )],
    { 'availability' => 'lrg' }
  );
 
  my $var_menu = $self->create_submenu('Variation', 'Genetic Variation');

  $var_menu->append($self->create_node('Variation_LRG/Table', 'Variation Table',
    [qw( snptable EnsEMBL::Web::Component::LRG::LRGSNPTable )],
    { 'availability' => 'lrg' }
  ));

#  $var_menu->append($self->create_node('Variation_LRG/Image',  'Variation Image',
#    [qw( image EnsEMBL::Web::Component::LRG::LRGSNPImage )],
#    { 'availability' => 'lrg' }
#  ));

  # External Data tree, including non-positional DAS sources
  #my $external = $self->create_node('ExternalData', 'External Data',
  #  [qw( external EnsEMBL::Web::Component::Gene::ExternalData )],
  #  { 'availability' => 'gene' }
  #);
  
  #$external->append($self->create_node('UserAnnotation', 'Personal annotation',
  #  [qw( manual_annotation EnsEMBL::Web::Component::Gene::UserAnnotation )],
  #  { 'availability' => 'gene' }
  #));
  
  $self->create_subnode('Export', 'Export Gene Data',
    [qw( export EnsEMBL::Web::Component::Export::Gene )],
    { 'availability' => 'gene', 'no_menu_entry' => 1 }
  );
}

1;
