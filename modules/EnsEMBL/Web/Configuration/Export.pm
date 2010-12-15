# $Id$

package EnsEMBL::Web::Configuration::Export;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub populate_tree {
  my $self = shift; 
  my %config = ( availability => 1, no_menu_entry => 1 );
  
  foreach ('Location', 'Gene', 'Transcript', 'LRG') {
    $self->create_node("Configure/$_",  '', [ 'configure',   'EnsEMBL::Web::Component::Export::Configure' ], \%config);
    $self->create_node("Form/$_",       '', [], { command => 'EnsEMBL::Web::Command::Export::Form',           %config});
    $self->create_node("Formats/$_",    '', [ 'formats',     'EnsEMBL::Web::Component::Export::Formats' ],   \%config);
    $self->create_node("Alignments/$_", '', [ 'alignments', 'EnsEMBL::Web::Component::Export::Alignments' ], \%config) unless $_ eq 'Transcript';
  }
  
  $self->create_node('HaploviewFiles/Location', '', [], { command => 'EnsEMBL::Web::Command::Export::HaploviewFiles',  %config});
  $self->create_node('LDExcelFile/Location',    '', [], { command => 'EnsEMBL::Web::Command::Export::LDExcelFile',     %config});
  $self->create_node('LDFormats/Location',      '', [ 'ld_formats',  'EnsEMBL::Web::Component::Export::LDFormats' ],  \%config);
  
  $self->create_node('PopulationFormats/Transcript', '', [ 'pop_formats', 'EnsEMBL::Web::Component::Export::PopulationFormats' ], \%config);
}

sub modify_page_elements {
  my $self = shift;
  my $page = $self->page;
  
  $page->remove_body_element('tabs');
  $page->remove_body_element('navigation');
}

1;
