package EnsEMBL::Web::Component::Interface::OnSuccess;

### Module to create generic database feedback for Document::Interface and its associated modules

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Interface);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return $self->object->interface->caption('on_success') || 'Database Update Succeeded';
}

sub content {
  my $self = shift;
  my $html;

  my %content = $self->object->interface->panel_content;
  unless ($html = $content{'on_success'}) {
    my $script = $self->script_name($self->object);
    $html = qq(<p>Your changes were saved to the database.
<ul>
<li><a href="/$script?dataview=add">Add another record</a></li>
<li><a href="/$script?dataview=select_to_edit">Select a record to edit</a></li>
);
    if ($self->object->interface->permit_delete) {
      $html .= qq(<li><a href="/$script?dataview=select_to_delete">Select a record to delete</a></li>
);
    }
    $html .= '</ul>';
  }
  return $html;
}

1;
