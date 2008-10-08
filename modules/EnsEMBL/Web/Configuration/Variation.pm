package EnsEMBL::Web::Configuration::Variation;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Document::Panel::Image;
use Data::Dumper;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Summary';
}

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub populate_tree {
  my $self = shift;

  $self->create_node( 'Summary', "Summary",
    [qw(summary EnsEMBL::Web::Component::Variation::VariationSummary
        flanking EnsEMBL::Web::Component::Variation::FlankingSequence )],
    { 'availability' => 1, 'concise' => 'Variation summary' }
  );
  $self->create_node( 'Mappings', "Location",
    [qw(summary EnsEMBL::Web::Component::Variation::Mappings)],
    { 'availability' => 1, 'concise' => 'Location' }
  );
  $self->create_node( 'Population', "Population genotypes and allele frequencies",
    [qw(summary EnsEMBL::Web::Component::Variation::PopulationGenotypes)],
    { 'availability' => 1, 'concise' => 'Population genotypes' }
  );
  $self->create_node( 'Individual', "Individual genotypes",
    [qw(summary EnsEMBL::Web::Component::Variation::IndividualGenotypes)],
    { 'availability' => 1, 'concise' => 'Individual genotypes' }
  );
  $self->create_node( 'Context', "Feature context",
    [qw(summary EnsEMBL::Web::Component::Variation::Context)],
    { 'availability' => 1, 'concise' => 'Feature context' }
  );



}

1;
