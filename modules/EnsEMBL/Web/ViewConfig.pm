package EnsEMBL::Web::ViewConfig;

use strict;
use Data::Dumper;
use EnsEMBL::Web::Form;
use CGI qw(escape unescape);

sub new {
  my($class,$type,$action,$adaptor) = @_;

  my $self = {
    '_db'                 => $adaptor->get_adaptor,
    '_species'            => $adaptor->get_species,
    '_species_defs'       => $adaptor->get_species_defs,
    '_r'                  => $adaptor->get_request || undef,
    'type'                => $type,
    'real'                => 0,
    'action'              => $action,
    'title'               => undef,
    '_classes'            => [],
    '_options'            => {},
    '_image_config_names' => {},
    '_default_config'     => '_page',
    '_can_upload'         => 0,
    '_form'               => undef,
    '_url'                => undef,
    'no_load'             => undef,
  };

  bless($self, $class);
  return $self;
}

sub default_config :lvalue {
### a
  $_[0]->{_default_config};
}

sub real :lvalue {
### a
  $_[0]->{'real'};
}

sub species :lvalue {
### a
  $_[0]->{'_species'};
}

sub species_defs :lvalue {
### a
  $_[0]->{'_species_defs'};
}

sub url :lvalue {
### a
  $_[0]->{'_url'};
}
sub title :lvalue {
### a
  $_[0]->{'title'};
}
sub storable :lvalue {
### a
### Set whether this ViewConfig is changeable by the User, and hence needs to
### access the database to set storable do $view_config->storable = 1; in SC code...
  $_[0]->{'storable'};
}

sub altered :lvalue {
### a
### Set to one if the configuration has been updated...
  $_[0]->{'altered'};
}

sub add_image_configs { ## Value indidates that the track can be configured for DAS (das) or not (nodas)
  my( $self, $hash_ref ) = @_;
  foreach( keys %$hash_ref ) {
    $self->{_image_config_names}{$_} = $hash_ref->{$_};
    $self->can_upload = 1 if $hash_ref->{$_} eq 'das';
    if ($hash_ref->{$_} ne 'das' && $hash_ref->{$_} !~ /^V/) {
      $self->has_images(1);
    }
  }
}

sub can_upload :lvalue {
  $_[0]->{'_can_upload'}
}
sub has_image_config {
  my $self = shift;
  my $config = shift;
  return exists $self->{_image_config_names}{$config};
}
sub has_image_configs {
  my $self = shift;
  return keys %{$self->{_image_config_names}||{}};
}

sub image_configs {
  my $self = shift;
  return %{$self->{_image_config_names}||{}};
}

sub _set_defaults {
  my $self = shift;
  my %defs = @_;# map( { ("format_$_", 'off')} qw(svg postscript pdf) ) );

  foreach my $key (keys %defs) {
    $self->{_options}{$key}{'default'} = $defs{$key};
  }
}

sub _clear_defaults {
  my $self = shift;
  $self->{_options} = {};
}

sub _remove_defaults {
### Clears the listed default values...
  my $self = shift;
  foreach my $key (@_) {
    delete $self->{_options}{$key};
  }
}

sub options { 
  my $self = shift;
  return keys %{$self->{'_options'}};
}

sub has_form {
  my $self = shift;
  return $self->{_form};
}

sub get_form {
  my $self = shift;
  $self->{_form}||=EnsEMBL::Web::Form->new( 'configuration', $self->url,'post' );
  return $self->{_form};
}

sub add_fieldset {
  my( $self, $legend, $layout ) = @_;
  my $fieldset = $self->get_form->add_fieldset('form'=>'configuration', 'layout' => $layout );
  $fieldset->legend($legend);
}

sub add_form_element {
  my($self,$hashref) = @_;
  my @extra;
  my $value = $self->get($hashref->{'name'});
  if( $hashref->{'type'} =~ /CheckBox/ ) {
    push @extra, 'checked' => $value eq $hashref->{'value'} ? 1 : 0;
  } elsif( !exists $hashref->{'value'} ) {
    push @extra, 'value' => $value;
  }
  $self->get_form->add_element(%$hashref,@extra);
}

sub update_config_from_parameter {
### Update the configuration from a pipe separated string...
  my( $self, $string ) = @_;
  my @array = split /\|/, $string;
  return unless @array;
  foreach( @array ) {
    next unless $_;
    my( $key, $value ) = split ':';
    $self->set( $key, $value );
  }
}

sub update_from_input {
### Loop through the parameters and update the config based on the parameters passed!
  my( $self, $input ) = @_;
  my $flag = 0;
  if( $input->param('reset') ) {
    return $self->reset;
  }
  foreach my $key ( $self->options ) {
    if( defined $input->param($key) && $input->param( $key ) ne $self->{'_options'}{$key}{'user'} ) {
      $flag = 1;
      my @values = $input->param( $key );
      if( scalar(@values) > 1 ) {
        $self->set( $key, \@values );
      } else {
        $self->set( $key, $input->param( $key ) );
      }
    }
  }
  if( $flag ) {
    $self->altered = 1;
  }
  return;
}

sub update_from_config_strings {
### Loop through the parameters and update the config based on the parameters passed!
  my( $self, $session, $r ) = @_;
  my $input = $session->input;
  my $flag = 0;
  my $params_removed;
  if( $input->param('config') ) {
    foreach my $v ( split /,/, $input->param('config') ) {
      my( $k,$t ) = split /=/, $v,2;
      $self->set($k,$t);
    }
    $params_removed = 1;
    $input->delete('config');
  }

  my $flag = 0;
  foreach my $name ( $self->image_configs ) {
    my $string = $input->param($name);
    my @values = split /,/, $input->param( $name );
    if(@values) {
      $input->delete($name); 
      $params_removed = 1;
    }
    if( ($name eq 'contigviewbottom'|| $name eq 'cytoview' ) ) {
      foreach my $v ( $input->param('data_URL') ) {
        push @values, "url.".escape($v).'=normal';
        $params_removed = 1; 
      }
      $input->delete('data_URL');
      foreach my $v ( $input->param('add_das_source') ) {
        my $server = $v =~ /url=(https?:[^ +]+)/  ? $1 : '';
        my $dsn    = $v =~ /dsn=(\w+)/       ? $1 : '';
# warn "$v > $server/$dsn";
        push @values, 'das.'.escape("$server/$dsn").'=labels' if $r;
        $params_removed = 1;
      }
      $input->delete('add_das_source');
    }

    if( @values ) {
      my $ic = $session->getImageConfig( $name,$name );
      next unless $ic;
      foreach my $v ( @values ) {
        my( $key,$render ) = split /=/,$v,2;
# warn ">> $v >> $key -- $render";
## Now we have to get the image_config... and modify it...
        if( $key =~ /^(\w+)[\.:](.*)$/ ) {
          my( $type, $p ) = ($1,$2);
# warn ".. $type - $p ..";
          if( $type eq 'url' ) {
            $p = unescape( $p );
## We have to create a URL upload entry in the session...
            use Digest::MD5 qw(md5_hex);
            my $code = md5_hex($ENV{'ENSEMBL_SPECIES'}.":".$p);
            my $n    =  $p =~ /\/([^\/]+)\/*$/ ? $1 : 'un-named';
            $session->set_data(
              'type'    => 'url',
              'url'     => $p,
              'species' => $ENV{'ENSEMBL_SPECIES'},
              'code'    => $code, 
              'name'    => $n
            );
## We then have to create a node in the user_config...
            $ic->_add_flat_file_track( undef, 'url', "url_$code", $n, 
              sprintf ( '
  Data retrieved from an external webserver.
  This data is attached to the %s, and comes from URL: %s', CGI::escapeHTML( $n ), CGI::escapeHTML( $p ) ),
              'url' => $p
            );
            my $nd = $ic->get_node( "url_$code" );
## Then we have to set the renderer...
            $flag += $nd->set_user( 'display', $render ) if $nd;
          } elsif( $type eq 'das' ) {
# warn "ADDING DAS FROM STRING..... $name $p $render";
            $p = unescape($p);
            if (my $error = $session->add_das_from_string( $p, {'ENSEMBL_IMAGE'=>$name}, {'display'=>$render} )) {
              warn $error;
            } else {
              $flag ++;
            }
          }
        } else {
          my $nd = $ic->get_node($key);
          $flag += $nd->set_user( 'display', $render ) if $nd;
        }
      }
    }
  }
  $self->altered = 1 if $flag;
  $session->store;
  return $params_removed ? $input->self_url : undef;
}

sub delete {
### Delete a key from the user settings
  my($self, $key ) = @_;
  return unless exists $self->{'_options'}{$key}{'user'};
  $self->altered = 1;
  delete $self->{'_options'}{$key}{'user'};
  return;
}

sub reset {
### Delete all keys from user settings
  my ($self) = @_;
  foreach my $key ( $self->options ) {
    next unless exists $self->{'_options'}{$key}{'user'};
    $self->altered = 1;
    delete $self->{'_options'}{$key}{'user'};
  }
  return;
}

sub push_class {
  my($self, $class) =@_;
  push @{$self->{'_classes'}}, $class;
}

sub has_images {
  my $self = shift;
  $self->{_has_images} = shift if @_;
  return $self->{_has_images};
}

sub form {
  my( $self, $object, $no_extra_bits ) = @_;
  foreach my $classname (@{$self->{'_classes'}}) {
    my $method = $classname.'::form';
    eval { no strict 'refs'; &$method( $self, $object ); };
    ## TODO: proper error exception
    warn $@ if $@;
  }
  return if $no_extra_bits;
  if( $self->has_images ) {
#       $ENV{'ENSEMBL_AJAX_VALUE'} =~ /^(en|dis)abled$/ && $self->has_form ) {
    $self->add_fieldset( 'Image width configurations' );
      $self->add_form_element({
        'type'     => 'DropDown', 'select' => 'select',
        'required' => 'yes',      'name'   => 'cookie_width',
        'values'   => [
          { 'value' => 'bestfit', 'name' => 'best fit' },
          map { { 'value' => $_, 'name' => "$_ pixels" } } map {$_*100} (5..20)
        ],
        'value'    => $ENV{'ENSEMBL_IMAGE_WIDTH'},
        'label'    => "Width of image",
      });
    }
#    if( $ENV{'ENSEMBL_AJAX_VALUE'} =~ /^(en|dis)abled$/ ) {
#      $self->add_form_element({
#        'type'     => 'DropDown', 'select' => 'select',
#        'required' => 'yes',      'name'   => 'cookie_ajax',
#        'values'   => [
#          { 'value' => 'enabled',  'name' => 'Enabled' },
#          { 'value' => 'disabled', 'name' => 'Disabled' },
#        ],
#        'value'    => $ENV{'ENSEMBL_AJAX_VALUE'},
#        'label'    => "Enable/disable use of AJAX in rendering"
#      });
#    }
  $self->add_form_element({
   'type' => 'Submit', 'value' => 'Update configuration'
  }) if $self->has_form;
}

sub set {
### Set a key for user settings
  my( $self, $key, $value, $force ) = @_;
  return unless $force || exists $self->{'_options'}{$key};
  return if $self->{'_options'}{$key}{'user'}  eq $value;
  $self->altered = 1;
  $self->{'_options'}{$key}{'user'}  = $value;
}



#sub set {
#  my( $self, $key, $value, $force ) = @_;
#  return unless $force || exists $self->{'_options'}{$key};
#  $self->{'_options'}{$key}{'user'}  = $value;
#}

sub get {
  my( $self, $key ) = @_;
  return undef unless exists $self->{'_options'}{$key};
  if( exists ($self->{'_options'}{$key}{'user'}) ) {
    if( ref($self->{'_options'}{$key}{'user'}) eq 'ARRAY' ) {
      return @{$self->{'_options'}->{$key}->{'user'}};
    }
    return $self->{'_options'}{$key}{'user'};
  }
  if( ref($self->{'_options'}{$key}{'default'}) eq 'ARRAY' ) {
    return @{$self->{'_options'}{$key}{'default'}};
  }
  return $self->{'_options'}{$key}{'default'};
}

sub is_option {
  my( $self, $key ) = @_;
  return exists $self->{'_options'}{$key};
}

sub set_user_settings {
### Set the user settings from a hash of key value pairs
  my( $self, $diffs ) = @_;
  if( $diffs ) {
    foreach my $key ( keys %$diffs ) {
      $self->{'_options'}{$key}{'user'} = $diffs->{$key};
    }
  }
}

sub get_user_settings {
  my $self = shift;
  my $diffs = {};
  foreach my $key ( $self->options ) {
    $diffs->{$key} = $self->{'_options'}{$key}{'user'} if exists($self->{'_options'}{$key}{'user'}) && $self->{'_options'}{$key}{'user'} ne $self->{'_options'}{$key}{'default'};
  }
  return $diffs;
}

sub load {
  my ($self) = @_;
  return;
}

sub save {
  my ($self) = @_;
  return;
}

sub dump {
  my ($self) = @_;
  local $Data::Dumper::Indent = 1;
  local $Data::Dumper::Terse  = 1;
  print STDERR Dumper($self)," ";;
}

sub _species_label {
  my( $self, $key ) = @_;
  return $self->species_defs->species_label( $key );
}
sub species_label {
  my( $self, $key ) = @_;
  return $self->species_defs->species_label( $key );
}
1;
