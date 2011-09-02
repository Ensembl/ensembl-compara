# $Id$ 

package EnsEMBL::Web::Configuration::Phenotype;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub caption { return 'Phenotype'; }

sub modify_page_elements { $_[0]->page->remove_body_element('summary'); }

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = 'Locations'; 
}

sub populate_tree {
  my $self = shift;
  my $hub  = $self->hub;
  
#  $self->create_node('All', 'List of Phenotypes',
#    [qw(all_phenotypes EnsEMBL::Web::Component::Phenotype::All )],
#    { 'availability' => 1 },
#  );

  $self->create_node('Locations', 'Location on Genome',
    [qw(locations EnsEMBL::Web::Component::Phenotype::Locations )],
    { 'availability' => 1 },
  );

}

1;
