# $Id$

package EnsEMBL::Web::Configuration::GeneTree;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Image';
}

sub caption { 
  my $self = shift;
  my $gt = $self->hub->param('gt');
  return "Gene Tree $gt"; 
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

sub modify_page_elements { $_[0]->page->remove_body_element('summary'); }

1;
