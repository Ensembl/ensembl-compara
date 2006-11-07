package EnsEMBL::Web::Document::DataView;

use EnsEMBL::Web::Document::WebPage;
use EnsEMBL::Web::DBSQL::ViewAdaptor;
use CGI;
our @ISA = qw(EnsEMBL::Web::Document::WebPage);

{


sub simple {
  my ($type, $definition) = @_;
  my $self = __PACKAGE__->new(('objecttype' => $type, 'doctype' => 'View'));
  my $cgi = CGI->new; 

  my $result = undef;

  if ($cgi->param('action')) {
    my $action = $definition->action;
    my $adaptor = $definition->data_definition->adaptor;
    my $user = undef;
    my $incoming = $cgi->Vars;
    if ($action eq "create") {
      my $fields = $definition->data_definition->discover;

      my $create_parameters = $self->parameters_for_fields($fields, $incoming);

      if ($ENV{'ENSEMBL_USER_ID'} eq $incoming->{'user_id'}) {
        $user = $incoming->{'user_id'};    
      }

      $result = $adaptor->create(( set =>        $create_parameters, 
                                   definition => $fields, 
                                   user =>       $user
                                ));
      if ($result) {
        $self->map_relationships($definition, $incoming, $result, $user);
      }
    } elsif ($action eq "edit") {
      my $fields = $definition->data_definition->discover;
      my $edit_parameters = $self->parameters_for_fields($fields, $incoming);
      if ($ENV{'ENSEMBL_USER_ID'} eq $incoming->{'user_id'}) {
        $user = $incoming->{'user_id'};    
      }
      $result = $adaptor->edit((
                                 set =>     $edit_parameters,
                                 definition => $fields,
                                 user =>       $user,
                                 id   =>       $incoming->{'id'}
                              ));
    }

    if ($result) {
      $self->redirect($definition->on_complete);
    } else {
      $self->redirect($definition->on_error);
    }

  } else {
    CGI::header;
    $self->page->render($definition);
  } 

}

sub map_relationships {
  my ($self, $definition, $incoming, $result, $user) = @_;

  my $adaptor = $definition->data_definition->adaptor;

  foreach my $relationship (@{ $definition->data_definition->relationships }) {
    warn "MAPPING " . $relationship->from . " " . $relationship->type . " " . $relationship->to;
    $fields = $definition->data_definition->discover($relationship->link_table);
    my $relationship_parameters = $self->parameters_for_fields($fields, $incoming);
    my $from_id = $relationship->from . "_id";
    $relationship_parameters->{$from_id} = $result;
    $result = $adaptor->create(( 
                              set   => $relationship_parameters, 
                              table => $relationship->link_table,
                              user  => $user
                            ));
  }
}

sub parameters_for_fields {
  my ($self, $fields, $incoming) = @_;
  my $parameters = {};
  foreach my $field (@{ $fields }) {
    my $field_name = $field->{'Field'};
    if ($incoming->{$field_name}) {
      $parameters->{$field_name} = $incoming->{$field_name};
    }
  } 
  return $parameters;
}

sub dataview_create {
  my $self = shift;
  my $adaptor = EnsEMBL::Web::DBSQL::ViewAdaptor->new;
}


}

1;
