# $Id$

package EnsEMBL::Web::Configuration::DAS;

use strict;

use EnsEMBL::Web::Document::Panel;

use base qw(EnsEMBL::Web::Configuration);

sub get_valid_action {
  my $self   = shift;
  my $action = shift;
  my $func   = shift;
  return $func ? "$action/$func" : "action";
}

sub stylesheet   { $_[0]->new_panel('DASSTYLE',    'EnsEMBL::Web::Component::DAS::Annotation::stylesheet');  }
sub features     { $_[0]->new_panel('DASGFF',      'EnsEMBL::Web::Component::DAS::features');                }
sub types        { $_[0]->new_panel('DASTYPES',    'EnsEMBL::Web::Component::DAS::types');                   }
sub sequence     { $_[0]->new_panel('DASSEQUENCE', 'EnsEMBL::Web::Component::DAS::Reference::sequence');     }
sub entry_points { $_[0]->new_panel('DASEP',       'EnsEMBL::Web::Component::DAS::Reference::entry_points'); } # Only applicable to a reference server
sub dna          { $_[0]->new_panel('DASDNA',      'EnsEMBL::Web::Component::DAS::Reference::dna');          } # Only applicable to a reference server


sub new_panel {
  my $self      = shift;
  my $page      = $self->page;
  my $das_panel = new EnsEMBL::Web::Document::Panel(
    hub     => $self->hub,
    builder => $self->builder,
    object  => $self->object,
    code    => 'das'
  );
  
  $page->set_doc_type('XML', shift);
  $das_panel->add_components('das_features', shift);
  $page->content->add_panel($das_panel);
}

1;
