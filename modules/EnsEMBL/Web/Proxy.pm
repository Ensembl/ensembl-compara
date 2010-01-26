package EnsEMBL::Web::Proxy;

use strict;

use vars qw($AUTOLOAD);

use EnsEMBL::Web::Problem;
use EnsEMBL::Web::SpeciesDefs;

use base qw(EnsEMBL::Web::Root);

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

  my ($class, $supertype, $type, $data, %extra_elements) = @_;
  
  my $self = [
    $type, # Gene, Transcript, Location etc
    {
      _hub           => $data->{'_hub'}           || undef,
      _core_objects  => $data->{'_core_objects'}  || undef, 
      _problem       => $data->{'_problem'}       || {},    
      _species_defs  => $data->{'_species_defs'}  || undef, 
      _ext_url_      => $data->{'_ext_url'}       || undef,                    # EnsEMBL::Web::ExtURL object used to create external links
      _parent        => $data->{'_parent'}        || undef,                    # Information about the referer
      _user          => $data->{'_user'}          || undef,                    
      _input         => $data->{'_input'}         || undef,                    # extension of CGI
      _databases     => $data->{'_databases'}     || undef,                    # getting database handles
      _view_configs_ => $data->{'_view_configs_'} || {},
      _user_details  => $data->{'_user_details'}  || undef,
      _web_user_db   => $data->{'_web_user_db'}   || undef,
      _apache_handle => $data->{'_apache_handle'} || undef,
      _type          => $data->{'_type'}          || $ENV{'ENSEMBL_TYPE'},     # Parsed from URL -  Gene, Transcript, Location etc
      _action        => $data->{'_action'}        || $ENV{'ENSEMBL_ACTION'},   # View, Summary etc
      _function      => $data->{'_function'}      || $ENV{'ENSEMBL_FUNCTION'}, # Extra path info
      _species       => $data->{'_species'}       || $ENV{'ENSEMBL_SPECIES'},
      _script        => $data->{'_script'}        || $ENV{'ENSEMBL_SCRIPT'},   # name of script in this case action... ## deprecated
      timer          => $data->{'timer'}          || [],                       # Diagnostic object
      %extra_elements
    },
    [], 
    $supertype # Factory, Object etc
  ];
  
  bless $self, $class;
  
  $self->timer_push("Adding all plugins: $supertype $type");
  
  foreach my $root(@{$self->species_defs->ENSEMBL_PLUGIN_ROOTS}, 'EnsEMBL::Web') {
    my $class_name = join '::', $root, $supertype, $type;
    
    if ($self->dynamic_use($class_name)) {
      push @{$self->__children}, (new $class_name($self->__data) || ());
    } else {
      (my $CS = $class_name) =~ s/::/\\\//g;
      my $error = $self->dynamic_use_failure($class_name);
      my $message = "^Can't locate $CS.pm in ";
      
      if ($error !~ /$message/) {
        $self->problem('child_proxy_error', "$supertype failure: $class_name", sprintf(
          '<p>Unable to compile %s of type %s - due to the following error in the module %s:</p><pre>%s</pre>',
          $supertype, $type, $class_name, $self->_format_error($error)
        ));
      }
    }
  }
  
  $self->timer_push("Added all plugins: $supertype $type");
  
  $self->problem('fatal', "$supertype failure: $type", qq{<p>Unable to compile any $supertype modules of type "<b>$type</b>".</p>}) unless @{$self->__children};
  $self->species_defs->{'timer'} = $data->{'timer'};
  
  return $self;
}

# Accessor functionality
sub hub          :lvalue { $_[0][1]{'_hub'};  }
sub species      :lvalue { $_[0][1]{'_species'};  }
sub parent       :lvalue { $_[0][1]{'_parent'};   }
sub script       :lvalue { $_[0][1]{'_script'};   }
sub action       :lvalue { $_[0][1]{'_action'};   }
sub function     :lvalue { $_[0][1]{'_function'}; }

sub species_defs { return $_[0][1]{'_species_defs'} ||= new EnsEMBL::Web::SpeciesDefs; }
sub user_details { return $_[0][1]{'_user_details'} ||= 1; }
sub timer        { return $_[0][1]{'timer'}; }
sub timer_push   { return ref $_[0]->timer eq 'EnsEMBL::Web::Timer' ? $_[0]->timer->push(@_) : undef; }

sub __supertype  :lvalue { $_[0][3]; }
sub __objecttype :lvalue { $_[0][0]; }
sub __data       :lvalue { $_[0][1]; }
sub __children   { return $_[0][2];  } # returns a reference to the array of child (EnsEMBL::*::$supertype::$objecttype) objects

sub has_a_problem      { return scalar keys %{$_[0][1]{'_problem'}}; }
sub has_fatal_problem  { return scalar @{$_[0][1]{'_problem'}{'fatal'}||[]}; }
sub has_problem_type   { return scalar @{$_[0][1]{'_problem'}{$_[1]}||[]}; }
sub get_problem_type   { return @{$_[0][1]{'_problem'}{$_[1]}||[]}; }
sub clear_problem_type { $_[0][1]{'_problem'}{$_[1]} = []; }
sub clear_problems     { $_[0][1]{'_problem'} = {}; }

sub problem {
  my $self = shift;
  push @{$self->[1]{'_problem'}{$_[0]}}, new EnsEMBL::Web::Problem(@_) if @_;
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

  my $self = shift;
  
  (my $fn  = our $AUTOLOAD) =~ s/.*:://;
  my $flag = $fn eq 'DESTROY' ? 1 : 0;
  my (@return, @post_process);
  
  foreach my $sub (@{$self->__children}) {
    if ($sub->can($fn)) {
      $self->__data->{'_drop_through_'} = 0;
      @return = $sub->$fn(@_); # can set $self->__data->{'_drop_through_'} internally
      $flag   = 1;
      
      if (!$self->__data->{'_drop_through_'}) {
        last;
      } elsif ($self->__data->{'_drop_through_'} != 1) {
        push @post_process, [ $sub, $self->__data->{'_drop_through_'} ];
      }
    }
  }

  foreach my $ref (reverse @post_process) {
    my $sub = $ref->[0];
    my $fn  = $ref->[1];
    
    $sub->$fn(\@return, @_) if $sub->can($fn);
  }
  
  if (!$flag) {
    my @T = caller(0);
    die "Undefined function $fn on Proxy::$self->[3] of type: $self->[0] at $T[1] line $T[2]\n";
  }
  
  return wantarray ? @return : $return[0];
}

sub can {
  ### Nasty Voodoo magic (part II)
  ###
  ### Because we have an {{AUTOLOAD}} function all functions are possible and can will always
  ### return 1 - so we over-ride can to return 1 if any child can perform this function.
  
  my $self = shift;
  my $fn   = shift;
  
  foreach my $sub (@{$self->__children}) {
    return 1 if $sub->can($fn);
  }
  
  return 0;
}

sub ref {
  ### Nasty Voodoo magic (part III)
  ###
  ### Core::ref will just return that you have a Proxy object, which is unhelpful
  ### so this function returns the underlying object type and that of the children

  my $self   = shift;
  my $object = join '::', 'EnsEMBL','Web', $self->__supertype, $self->__objecttype;
  
  return sprintf '%s (%s)', $object, join ', ', map ref $_, @{$self->__children};
};

sub DESTROY {}

1;
