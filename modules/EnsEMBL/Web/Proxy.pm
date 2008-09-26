package EnsEMBL::Web::Proxy;

use strict;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::RegObj;
use vars qw($AUTOLOAD);
use base qw( EnsEMBL::Web::Root );

sub new {
  ### Creates a new Proxy object. Usually called from {{EnsEMBL::Web::Proxy::Object}}.
  ###
  ### The {{EnsEMBL::Web::Factory}} of a particular Ensembl type (such as
  ### {{EnsEMBL::Web::Factory::User}} sets up necessary parameters in the 
  ### {{EnsEMBL::Web::Factory::User::createObjects}} style method. This method
  ### usually calls {{EnsEMBL::Web::Factory::dataObjects}}, setting a newly
  ### created {{EnsEMBL::Web::Proxy::Object}} as the Factory's data object.
  ###
  ### On creating a new {{EnsEMBL::Web::Proxy::Object}}, a data type (such as 'User'),
  ### an "object" and a set of data parameters are used to configure the new 
  ### data object are specified. These values are passed back to this method:
  ### <li> The data type is accessible as $type</li>
  ### <li> The data parameters are accessible as the $data hashref</li>
  ### <li> The "object" is accessible via the _object key of the 
  ###      %extra_elements hash</li> 
  ###
  ### The "object" can be a reference to any Perl type, blessed or unblessed, and
  ### is passed on to the Ensembl data type (such as Location, User etc) as part
  ### of a hashref with many other configuration settings (the SpeciesDefs object, 
  ### the user id, the script config settings), which may or may not have been set
  ### by default, or been configured in the data parameters passed in from the
  ### {{EnsEMBL::Web::Proxy::Object}} instantiation.
  ### 
  ### In essence, should you want a set of parameters to be sent 
  ### to a particular Ensembl data type for use in initialising an object
  ### of that type, these parameters should be sent as the "object" when a 
  ### new {{EnsEMBL::Web::Proxy::Object}} is defined in the type's Factory.
  ### 
  ### It is interesting to note that this instantiation process contains all the hall
  ### marks of a good Poirot novel: obfuscation, misdirection, intrege and murder.

  my( $class, $supertype, $type, $data, %extra_elements ) = @_;
  my $self  = [
    $type,
    {
      '_core_objects'    => $data->{_core_objects}    || undef,
      '_problem'         => $data->{_problem}         || [],
      '_species_defs'    => $data->{_species_defs}    || undef,
      '_ext_url_'        => $data->{_ext_url}         || undef,
      '_user'            => $data->{_user}            || undef,
      '_input'           => $data->{_input}           || undef,
      '_databases'       => $data->{_databases}       || undef,
      '_wsc_adaptor'     => $data->{_wsc_adaptor}     || undef,
      '_wuc_adaptor'     => $data->{_wuc_adaptor}     || undef,
      '_view_configs_' => $data->{_view_configs_} || {},
      '_user_details'    => $data->{_user_details}    || undef,
      '_web_user_db'     => $data->{_web_user_db}     || undef,
      '_apache_handle'   => $data->{_apache_handle}   || undef,
      '_type'            => $data->{_type}            || $ENV{'ENSEMBL_TYPE'},
      '_action'          => $data->{_action}          || $ENV{'ENSEMBL_ACTION'},
      '_function'        => $data->{_function}        || $ENV{'ENSEMBL_FUNCTION'},
      '_species'         => $data->{_species}         || $ENV{'ENSEMBL_SPECIES'},
      '_script'          => $data->{_script}          || $ENV{'ENSEMBL_SCRIPT'},
#      '_feature_types'   => $data->{_feature_types}   || [],
#      '_feature_ids'     => $data->{_feature_ids}   || [],
      'timer'            => $data->{timer}   || [],
#      '_group_ids'       => $data->{_group_ids}   || [],
      %extra_elements
    },
    [],
    $supertype 
  ];
  bless $self, $class;
  $ENSEMBL_WEB_REGISTRY->timer_push( "Adding all plugins... $supertype $type" );
  foreach my $root( @{$self->species_defs->ENSEMBL_PLUGIN_ROOTS}, 'EnsEMBL::Web' ) {
    my $class_name = join '::', $root, $supertype, $type;
    if( $self->dynamic_use( $class_name ) ) {
      push @{$self->__children}, ( new $class_name( $self->__data )||() );
    } else {
      (my $CS = $class_name ) =~ s/::/\\\//g;
      my $error = $self->dynamic_use_failure( $class_name );
      my $message = "^Can't locate $CS.pm in ";
      $self->problem( 'child_proxy_error', "$supertype failure: $class_name", qq(
<p>Unable to compile $supertype of type $type - due to the following error in the module $class_name:</p>
<pre>@{[$self->_format_error( $error )]}</pre>) ) unless $error =~ /$message/;
    }
  }
  $ENSEMBL_WEB_REGISTRY->timer_push( "Added all plugins... $supertype $type" );
  unless( @{$self->__children} ) {
    $self->problem( 'fatal', "$supertype failure: $type",qq( 
<p>
  Unable to compile any $supertype modules of type "<b>$type</b>".
</p>) );
  }
  $self->species_defs->{'timer'} = $data->{timer};
  return $self;
}

##
## Accessor functionality
##
sub species_defs         { $_[0][1]{'_species_defs'}  ||= EnsEMBL::Web::SpeciesDefs->new(); }
sub user_details         { $_[0][1]{'_user_details'}  ||= 1; } # EnsEMBL::Web::User::Details->new( $_[0]->{_web_user_db}); }

sub species {
### a
### sets/gets species
  my $self = shift;
  $self->[1]{_species} = shift if @_;
  return $self->[1]{_species};
}

sub script               { 
  ### a
  my $self = shift;
  $self->[1]{_script} = shift if @_;
  return $self->[1]{'_script'}; 
}

sub action               { 
  ### a
  my $self = shift;
  $self->[1]{_action} = shift if @_;
  return $self->[1]{'_action'}; 
}

sub function             { 
  ### a
  my $self = shift;
  $self->[1]{_function} = shift if @_;
  return $self->[1]{'_function'}; 
}

sub __supertype  :lvalue {
### a
### gets supertype of Proxy (i.e. Factory/Object;)
  my $self = shift;
  return $self->[3];
}

sub __objecttype :lvalue {
### a
### gets type of Object being proxied (e.g. Gene/Transcript/Location/...)
  my $self = shift;
  return $self->[0];
}

sub __children           {
### a
### returns a reference to the array of child (EnsEMBL::*::$supertype::$objecttype) objects
  my $self = shift;
  return $self->[2];
}

sub __data       :lvalue {
### a
### return data hash
  my $self = shift;
  return $self->[1];
}

sub timer_push {
  my $self = shift;
  return $self->[1]{'timer'}->push(@_);
}

sub timer {
  my $self = shift;
  return $self->[1]{'timer'};
}

sub has_a_problem     { return scalar(                               @{$_[0][1]{'_problem'}} ); }
sub has_fatal_problem { return scalar( grep {$_->isFatal}            @{$_[0][1]{'_problem'}} ); }
sub has_problem_type  { return scalar( grep {$_->get_by_type($_[1])} @{$_[0][1]{'_problem'}} ); }
sub get_problem_type  { return         grep {$_->get_by_type($_[1])} @{$_[0][1]{'_problem'}};   }
sub clear_problems    {                                                $_[0][1]{'_problem'} = []; }
sub problem {
  my $self = shift;
  push @{$self->[1]{'_problem'}}, EnsEMBL::Web::Problem->new(@_) if @_;
  return $self->[1]{'_problem'};
}

sub AUTOLOAD {
### Nasty Voodoo magic
###
### Loop through all the plugins and if they can perform the requested function
### action it on the child objects....
###
### If the function sets __data->{'_drop_through_'} to 1 then no further action
### is taken...
###
### If it sets it to a value other than one then this function is called after
### the function has been called on all the other children

  my $self   = shift;
  ( my $fn     = our $AUTOLOAD ) =~ s/.*:://;
  my @return = ();
  my @post_process = ();
  my $flag   = $fn eq 'DESTROY' ? 1 : 0;
  foreach my $sub ( @{$self->__children} ) {
    if( $sub->can( $fn ) ) {
      $self->__data->{'_drop_through_'} = 0;
      @return = $sub->$fn( @_ );
      $flag = 1;
      if( ! $self->__data->{'_drop_through_'} ) {
        last;
      } elsif( $self->__data->{'_drop_through_'} !=1 ) {
        push @post_process, [ $sub, $self->__data->{'_drop_through_'} ];
      }
    }
  }

  foreach my $ref (reverse @post_process) {
    my $sub = $ref->[0];
    my $fn  = $ref->[1];
    if( $sub->can($fn) ) {
      $sub->$fn( \@return, @_ );
    }
  }
  unless( $flag ) {
    my @T = caller(0);
    die "Undefined function $fn on Proxy::$self->[3] of type: $self->[0] at $T[1] line $T[2]\n";
  }
  return wantarray() ? @return : $return[0];
}

sub can {
### Nasty Voodoo magic (part II)
###
### Because we have an {{AUTOLOAD}} function all functions are possible and can will always
### return 1 - so we over-ride can to return 1 if any child can perform this function.
  my $self = shift;
  my $fn   = shift;
  foreach my $sub ( @{$self->__children} ) {
    return 1 if $sub->can($fn);
  }
  return 0;
}

sub ref {
### Nasty Voodoo magic (part III)
###
### Ref will just return that you have a Proxy object - but we don't want to to do
### so this function the underlying object type (and also what children are also

  my $self = shift;
  my $ref = ref( $self );
  my $object = join '::', 'EnsEMBL','Web',$self->__supertype,$self->__objecttype;
  return "$object (@{[map { ref($_) } @{$self->__children}]})";
};

sub DESTROY {}


1;
