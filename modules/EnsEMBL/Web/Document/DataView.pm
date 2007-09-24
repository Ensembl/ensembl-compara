package EnsEMBL::Web::Document::DataView;

## DEPRECATED MODULE - USE Document::Interface and associated modules instead


use EnsEMBL::Web::Document::WebPage;
use EnsEMBL::Web::DBSQL::ViewAdaptor;
use EnsEMBL::Web::DBSQL::SQL::Result;

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
  my $perform = 1;

  my $result = undef;
  if ($cgi->param('dataview_action')) {
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
        if ($result->get_success) {
          $self->map_relationships($definition, $incoming, $result, $user);
        }
      }
    } elsif ($action eq "edit") {
      if ($incoming->{'conditional'}) {
        my $condition = $incoming->{'conditional'};
        my $value = $definition->value_for_form_element($condition, 1);
        if (!$incoming->{$condition} eq $value) {
          warn "CONDITIONAL STATE NOT MET!";
          warn "FIELD: " . $condition;
          warn "EXPECT: " . $incoming->{$condition};
          warn "ACTUAL: " . $value;
          $self->redirect($definition->on_error);
          return 0;
        }
      }
      if ($incoming->{'record'}) {
        my $fields = $definition->data_definition->fields;
        my $edit_parameters = $self->parameters_for_fields($fields, $incoming);
        my $user = $self->verify_user_id($incoming); 

        $result = $adaptor->edit((
                                 set =>        $edit_parameters,
                                 definition => $fields,
                                 user =>       $user,
                                 id   =>       $incoming->{'id'},
                                 record =>     $incoming->{'type'},
                                 label =>      $incoming->{'ident'},
                                  type =>      'relationship'
                                ));

      } else {
        my $fields = $definition->data_definition->discover;
        my $multiple_ids = $definition->data_definition->ids;
        my $edit_parameters = $self->parameters_for_fields($fields, $incoming);
        my $user = $self->verify_user_id($incoming); 
        
        foreach my $key (keys %{ $definition->data_definition->where }) {
          foreach my $element (@{ $definition->data_definition->where->{$key} }) {
            my $where_result = $adaptor->fetch_by({ $key => $element });
            warn "MULTI UPDATE: " . $key . ": " . $element;
            my $count = 0;
            foreach my $new_id (keys %{ $where_result }) {
              $count++;
              warn "ADDING FOR UPDATE: " . $new_id;
              push @{ $multiple_ids }, $new_id;
            }
            if ($count == 0) {
              warn "NO RECORDS MATCHING " . $key . " = " . $element;
              $edit_parameters->{$key} = $element; ## will be removed before updates 
              $result = $adaptor->create(( set =>        $edit_parameters,
                                           definition => $fields, 
                                           user =>       $user
                                        ));
            }
          }
        }

        ## We don't want to to overwrite the fields we have selected the rows by
        ## in the forthcoming SQL updates, so remove them:

        foreach my $key (keys %{ $definition->data_definition->where }) {
          delete $edit_parameters->{$key};
          delete $fields->{$key};
        }

        foreach my $multi (@{ $multiple_ids }) {
          my $result = $adaptor->fetch_id($multi, 'id');
          if ($result->{$multi}) {
            warn $multi . " EXISTS: UPDATING";
          } else { 
            warn $multi . " NEEDS CREATING";
            $result = $adaptor->create(( set =>        $edit_parameters, 
                                         definition => $fields, 
                                         user =>       $user
                                      ));
          }
        }

        $result = $adaptor->edit((
                                 set =>     $edit_parameters,
                                 definition => $fields,
                                 user =>       $user,
                                 multiple_ids => $multiple_ids,
                                 id   =>       $incoming->{'id'}
                                ));
      }
    }

    my $send = "";

    if ($definition->send_params) {
      foreach my $key (keys %{ $definition->send_params }) {
        if ($definition->send_params->{$key} eq "yes") {
          if ($key eq "id" and $action eq "create") {
            $send .= "&id=" . $result->get_last_inserted_id; 
          } elsif ($key eq 'password' && $result->set_parameters->{'password'}) {
            $send .= "&key=" . $result->set_parameters->{'password'};
          } else { 
            $send .= "&$key=" . $incoming->{$key};
          }
        }
      }
      if ($send) {
        $send = "?" . $send;
      }
    }

    if ($result->get_success) {
      if ($definition->on_complete =~ /\?/) {
        $send =~ s/^\?/&/;
      }
      $self->redirect($definition->on_complete . $send);
    } else {
      $self->redirect($definition->on_error . $send);
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
    my $fields = $definition->data_definition->discover($relationship->link_table);
    my $relationship_parameters = $self->parameters_for_fields($fields, $incoming);
    my $from_id = $relationship->from . "_id";
    $relationship_parameters->{$from_id} = $result->get_last_inserted_id;
    $result = $adaptor->create(( 
                              set   => $relationship_parameters, 
                              table => $relationship->link_table,
                              user  => $user,
                              type  => "relationship"
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
