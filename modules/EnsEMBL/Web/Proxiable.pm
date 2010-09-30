package EnsEMBL::Web::Proxiable;

### NAME: Proxiable.pm
### Base class for data objects and factories

### PLUGGABLE: No - but part of Proxy plugin infrastructure

### STATUS: At Risk
### * duplicates Resource/Hub functionality 
### * multiple methods of plugin-handling are confusing!

### DESCRIPTION
### A Proxiable object contains both the data object (either
### an Object or a Factory) and all the 'connections' (db handles, 
### cgi parameters, web session, etc) needed to support 
use strict;

use EnsEMBL::Web::DBSQL::DBConnection;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $data) = @_;
  
  $data->{'_type'}     ||= $ENV{'ENSEMBL_TYPE'};
  $data->{'_action'}   ||= $ENV{'ENSEMBL_ACTION'};
  $data->{'_function'} ||= $ENV{'ENSEMBL_FUNCTION'}; 
  $data->{'_species'}  ||= $ENV{'ENSEMBL_SPECIES'};

  my $self = { data => $data };
  
  bless $self, $class;
  
  $self->{'data'}->{'timer'} ||= $self->hub->timer;
  
  return $self; 
}

sub __data       { return $_[0]->{'data'};                }
sub __objecttype { return $_[0]->{'data'}{'_objecttype'}; }
sub hub          { return $_[0]->{'data'}{'_hub'};        }
sub type         { return $_[0]->{'data'}{'_type'};       }
sub action       { return $_[0]->{'data'}{'_action'};     }
sub function     { return $_[0]->{'data'}{'_function'};   }
sub script       { return $_[0]->{'data'}{'_script'};     }
sub species      { return $_[0]->{'data'}{'_species'};    }

sub DBConnection      { return $_[0]->{'data'}{'_databases'} ||= new EnsEMBL::Web::DBSQL::DBConnection($_[0]->species, $_[0]->species_defs); }
sub get_databases     { my $self = shift; $self->DBConnection->get_databases(@_); }
sub databases_species { my $self = shift; $self->DBConnection->get_databases_species(@_); }

sub apache_handle   { return $_[0]->hub->apache_handle;       }
sub referer         { return $_[0]->hub->referer;             }
sub species_defs    { return shift->hub->species_defs(@_);    }
sub session         { return shift->hub->session(@_);         }
sub get_session     { return shift->hub->session(@_);         }
sub user            { return shift->hub->user(@_);            }
sub species_path    { return shift->hub->species_path(@_);    }
sub _url            { return shift->hub->url(@_);             }
sub redirect        { return shift->hub->redirect(@_);        }
sub param           { return shift->hub->param(@_);           }
sub input_param     { return shift->hub->input_param(@_);     }
sub multi_params    { return shift->hub->multi_params(@_);    }
sub database        { return shift->hub->database(@_);        }
sub ExtURL          { return shift->hub->ExtURL;              }
sub get_ExtURL      { return shift->hub->get_ExtURL(@_);      }
sub get_ExtURL_link { return shift->hub->get_ExtURL_link(@_); }
sub timer_push      { return shift->hub->timer_push(@_);      }
sub table_info      { return shift->hub->table_info(@_);      }
sub data_species    { return shift->hub->data_species(@_);    }
sub delete_param    { $_[0]->hub->input->delete(@_);          }

1;

