package EnsEMBL::Web::Document::DataView;

use EnsEMBL::Web::Document::WebPage;
use EnsEMBL::Web::DBSQL::ViewAdaptor;
use CGI;
use strict;
our @ISA = qw(EnsEMBL::Web::Document::WebPage);

{


sub simple {
  my ($type, $definition, $parameter) = @_;
  my $self = __PACKAGE__->new(('objecttype' => $type, 'doctype' => 'View', 'access' => $parameter->{'access'}));

  ## Configure menus
  if (my $context = $parameter->{'context'}) {
    $self->configure($type, @$context);
  }

  my $cgi = CGI->new; 

  my $result = undef;

  if ($cgi->param('action')) {
    my $action = $definition->action;
    my $adaptor = $definition->data_definition->adaptor;
    my $user = undef;
    my $incoming = $cgi->Vars;
    if ($action eq "create") {
      if ($incoming->{'record'}) {
        ## create user record
        my $fields = $definition->data_definition->fields;
        my $record_data = $self->parameters_for_fields($fields, $incoming);
        my $user = $self->verify_user_id($incoming); 

        $result = $adaptor->create(( set =>        $record_data, 
                                     definition => $fields, 
                                     user =>       $user,
                                     record =>     $incoming->{'type'}
                                  ));
      } else {
        my $fields = $definition->data_definition->discover;
        my $create_parameters = $self->parameters_for_fields($fields, $incoming);
        my $user = $self->verify_user_id($incoming); 

        $result = $adaptor->create(( set =>        $create_parameters, 
                                     definition => $fields, 
                                     user =>       $user
                                  ));
        if ($result) {
          $self->map_relationships($definition, $incoming, $result, $user);
        }
      }
    } elsif ($action eq "edit") {
      if ($incoming->{'record'}) {
        my $fields = $definition->data_definition->fields;
        my $edit_parameters = $self->parameters_for_fields($fields, $incoming);
        my $user = $self->verify_user_id($incoming); 

        $result = $adaptor->edit((
                                 set =>        $edit_parameters,
                                 definition => $fields,
                                 user =>       $user,
                                 id   =>       $incoming->{'id'},
                                 record =>     $incoming->{'type'}
                                ));

      } else {
        my $fields = $definition->data_definition->discover;
        my $edit_parameters = $self->parameters_for_fields($fields, $incoming);
        my $user = $self->verify_user_id($incoming); 
        $result = $adaptor->edit((
                                 set =>     $edit_parameters,
                                 definition => $fields,
                                 user =>       $user,
                                 id   =>       $incoming->{'id'}
                                ));
      }
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
    my $fields = $definition->data_definition->discover($relationship->link_table);
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

sub verify_user_id {
  my ($self, $incoming) = @_;
  my $user = undef;
  if ($ENV{'ENSEMBL_USER_ID'} eq $incoming->{'user_id'}) {
    $user = $incoming->{'user_id'};    
  }
  return $user;
}

sub dataview_create {
  my $self = shift;
  my $adaptor = EnsEMBL::Web::DBSQL::ViewAdaptor->new;
}


}

1;
