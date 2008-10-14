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

sub ajax_zmenu {
  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj  = $self->object; 
  my $dest = $obj->action().'/'.$obj->function();
  my $variation_id = $obj->name;
  my $location = $obj->var_location;
  my $status = join ", ", @{$obj->status}; 
  my ($seq_region, $start, $end) = split(/:|-/, $obj->var_location);
  my $pos =  $start;

  if($start > $end  ) {
    $pos = "between&nbsp;$start&nbsp;&amp;&nbsp;$end";
  }
  elsif($start < $end ) {
    $pos = "$start&nbsp;-&nbsp;$end";
  }

  
  
  
  $panel->{'caption'} = $obj->short_caption;  

  $panel->add_entry({
    'label'    => 'Variation Properties',
    'link'     => $obj->_url({'type'=>'Variation', 'action'=>'Summary', 'v'=>$variation_id}),
    'priority' => 195
  });

  $panel->add_entry({
    'type'     => 'bp:',
    'label'    => $pos,
    'priority' => 185
  });

  $panel->add_entry({
    'type'     => 'status:',
    'label'    => $status || '-',
    'priority' => 175
  });

  $panel->add_entry({
    'type'     => 'class:',
    'label'    => $obj->Obj->var_class,
    'priority' => 175
  });

  $panel->add_entry({
    'type'     => 'ambiguity code:',
    'label'    => $obj->Obj->ambig_code,
    'priority' => 155
  });

  $panel->add_entry({
    'type'     => 'alleles:',
    'label'    => $obj->alleles,
    'priority' => 145
  });

  $panel->add_entry({
    'type'     => 'source:',
    'label'    => $obj->Obj->source,
    'priority' => 135
  });

  $panel->add_entry({
    'type'     => 'type:',
    'label'    => $obj->consequence_type,
    'priority' => 125
  });

 
 return;
}

sub populate_tree {
  my $self = shift;

  $self->create_node( 'Summary', "Summary",
    [qw(summary EnsEMBL::Web::Component::Variation::VariationSummary
        flanking EnsEMBL::Web::Component::Variation::FlankingSequence )],
    { 'availability' => 1, 'concise' => 'Variation summary' }
  );
  $self->create_node( 'Mappings', "Gene/Transcript",
    [qw(summary EnsEMBL::Web::Component::Variation::Mappings)],
    { 'availability' => 1, 'concise' => 'Gene/Transcript' }
  );
  $self->create_node( 'Population', "Population genotypes and allele frequencies",
    [qw(summary EnsEMBL::Web::Component::Variation::PopulationGenotypes)],
    { 'availability' => 1, 'concise' => 'Population genotypes and allele frequencies' }
  );
  $self->create_node( 'Individual', "Individual genotypes",
    [qw(summary EnsEMBL::Web::Component::Variation::IndividualGenotypes)],
    { 'availability' => 1, 'concise' => 'Individual genotypes' }
  );
  $self->create_node( 'Context', "Context",
    [qw(summary EnsEMBL::Web::Component::Variation::Context)],
    { 'availability' => 1, 'concise' => 'Context' }
  );



}

1;
