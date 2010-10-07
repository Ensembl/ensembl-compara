# $Id$

package EnsEMBL::Web::Configuration::Variation;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = 'Summary';
}

sub tree_cache_key {
  my $self = shift;
  my $key  = $self->SUPER::tree_cache_key(@_);
  $key .= '::SOMATIC' if $self->object->Obj->is_somatic;
  return $key;
}

sub populate_tree {
  my $self = shift;
  my $somatic = $self->object->Obj->is_somatic;

  $self->create_node('Summary', 'Summary',
    [qw(
      summary  EnsEMBL::Web::Component::Variation::VariationSummary
      flanking EnsEMBL::Web::Component::Variation::FlankingSequence
    )],
    { 'availability' => 'variation', 'concise' => 'Variation summary' }
  );
  
  $self->create_node('Mappings', 'Gene/Transcript  ([[counts::transcripts]])',
    [qw( summary EnsEMBL::Web::Component::Variation::Mappings )],
    { 'availability' => 'variation has_transcripts', 'concise' => 'Gene/Transcript' }
  );
    
  $self->create_node('Population', 'Population genetics ([[counts::populations]])',
    [qw( summary EnsEMBL::Web::Component::Variation::PopulationGenotypes )],
    { 'availability' => 'variation has_populations not_somatic', 'concise' => 'Population genetics', 'no_menu_entry' => $somatic }
  );
  
  $self->create_node('Populations', 'Sample information ([[counts::populations]])',
    [qw( summary EnsEMBL::Web::Component::Variation::PopulationGenotypes )],
    { 'availability' => 'variation has_populations is_somatic', 'concise' => 'Sample information', 'no_menu_entry' => !$somatic }
  );
  
  $self->create_node('Individual', 'Individual genotypes ([[counts::individuals]])',
    [qw( summary EnsEMBL::Web::Component::Variation::IndividualGenotypes )],
    { 'availability' => 'variation has_individuals not_somatic', 'concise' => 'Individual genotypes', 'no_menu_entry' => $somatic }
  ); 

  $self->create_node('Context', 'Context',
    [qw( summary EnsEMBL::Web::Component::Variation::Context )],
    { 'availability' => 'variation', 'concise' => 'Context' }
  );
  
  $self->create_node('HighLD', 'Linked variations',
    [qw( summary EnsEMBL::Web::Component::Variation::HighLD )],
    { 'availability' => 'variation has_ldpops variation has_individuals not_somatic', 'concise' => 'Linked variations', 'no_menu_entry' => $somatic }
  );
    
  $self->create_node('Phenotype', 'Phenotype Data ([[counts::ega]])',
    [qw( summary EnsEMBL::Web::Component::Variation::Phenotype )],
    { 'availability' => 'variation has_ega', 'concise' => 'Phenotype Data' }
  );
  
  $self->create_node('Compara_Alignments', 'Phylogenetic Context ([[counts::alignments]])',
    [qw(
      selector EnsEMBL::Web::Component::Compara_AlignSliceSelector
      summary  EnsEMBL::Web::Component::Variation::Compara_Alignments
    )],
    { 'availability' => 'variation database:compara has_alignments', 'concise' => 'Phylogenetic Context' }
  );

  # External Data tree, including non-positional DAS sources
  my $external = $self->create_node('ExternalData', 'External Data',
    [qw( external EnsEMBL::Web::Component::Variation::ExternalData )],
    { 'availability' => 'variation' }
  );
}

sub user_populate_tree {
  my $self        = shift;
  my $hub         = $self->hub;
  my $all_das     = $hub->get_all_das;
  my $view_config = $hub->get_viewconfig(undef, 'ExternalData');
  my @active_das  = grep { $view_config->get($_) eq 'yes' && $all_das->{$_} } $view_config->options;
  my $ext_node    = $self->tree->get_node('ExternalData');
  
  for my $logic_name (sort { lc($all_das->{$a}->caption) cmp lc($all_das->{$b}->caption) } @active_das) {
    my $source = $all_das->{$logic_name};
    
    $ext_node->append($self->create_subnode("ExternalData/$logic_name", $source->caption,
      [qw( textdas EnsEMBL::Web::Component::Variation::TextDAS )], {
        availability => 'variation', 
        concise      => $source->caption, 
        caption      => $source->caption, 
        full_caption => $source->label
      }
    ));	 
  }
}


1;
