package EnsEMBL::Web::Configuration::Variation;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Document::Panel::Image;
use Data::Dumper;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  unless( ref $self->object ){
    $self->{_data}{default} = 'Summary';
    return;
  }
  my $x = $self->object->availability || {};
  if( $x->{'variation'} ) {
    $self->{_data}{default} = 'Summary';
  }

}

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub ajax_zmenu {
  my $self = shift;
  
  my $action = $self->object->action;
   
  if ($action eq 'Variation') {
    return $self->ajax_zmenu_variation;
  }  elsif ($action eq 'Variation_protein') {
    return $self->ajax_zmenu_variation_protein;
  }
}

sub populate_tree {
  my $self = shift;

  $self->create_node( 'Summary', "Summary",
    [qw(summary EnsEMBL::Web::Component::Variation::VariationSummary
        flanking EnsEMBL::Web::Component::Variation::FlankingSequence )],
    { 'availability' => 'variation' , 'concise' => 'Variation summary' }
  );
  $self->create_node( 'Mappings', "Gene/Transcript  ([[counts::transcripts]])",
    [qw(summary EnsEMBL::Web::Component::Variation::Mappings)],
    { 'availability' => 'variation', 'concise' => 'Gene/Transcript' }
  );
  $self->create_node( 'Population', "Population genetics ([[counts::populations]])",
    [qw(summary EnsEMBL::Web::Component::Variation::PopulationGenotypes)],
    { 'availability' => 'variation', 'concise' => 'Population genotypes and allele frequencies' }
  );
  $self->create_node( 'Individual', "Individual genotypes ([[counts::individuals]])",
    [qw(summary EnsEMBL::Web::Component::Variation::IndividualGenotypes)],
    { 'availability' => 'variation', 'concise' => 'Individual genotypes' }
  );
  $self->create_node( 'Context', "Context",
    [qw(summary EnsEMBL::Web::Component::Variation::Context)],
    { 'availability' => 'variation', 'concise' => 'Context' }
  );
  $self->create_node( 'Phenotype', "Phenotype Data ([[counts::ega]])",
    [qw(summary EnsEMBL::Web::Component::Variation::ExternalData)],
    { 'availability' => 'variation', 'concise' => 'Phenotype Data' }
  );
  $self->create_node( 'Compara_Alignments', "Phylogenetic Context ([[counts::alignments]])",
    [qw(selector EnsEMBL::Web::Component::Compara_AlignSliceSelector
        summary EnsEMBL::Web::Component::Variation::Compara_Alignments)],
    { 'availability' => 'variation database:compara', 'concise' => 'Evolutionary or Phylogenetic Context' }
  );
}

1;
