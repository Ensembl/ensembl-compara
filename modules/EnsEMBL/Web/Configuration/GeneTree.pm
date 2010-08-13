package EnsEMBL::Web::Configuration::GeneTree;

use strict;
use base qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Image';
}

sub global_context { return $_[0]->_global_context }
sub ajax_content   { return $_[0]->_ajax_content;  }
sub local_context  { return $_[0]->_local_context; }
sub local_tools    { return $_[0]->_local_tools;   }
sub content_panel  { return $_[0]->_content_panel; }
sub context_panel  { return undef;                 }

sub caption { 
  my $self = shift;
  my $id = $self->model->hub->param('genetree_id');
  return "Gene Tree $id"; 
}

sub availability {
  my $self = shift;
  return $self->default_availability;
}

sub populate_tree {
  my $self  = shift;

  $self->create_node('Image', 'Gene Tree Image',
    [qw(image EnsEMBL::Web::Component::Gene::ComparaTree)],
    { 'availability' => 1 }
  );
}

1;
