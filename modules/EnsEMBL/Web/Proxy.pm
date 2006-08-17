package EnsEMBL::Web::Proxy;

use strict;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::Root;
use vars qw($AUTOLOAD);
our  @ISA = qw( EnsEMBL::Web::Root );

sub new {
  my( $class, $supertype, $type, $data, %extra_elements ) = @_;

  my $self  = [
    $type,
    {
      '_problem'         => $data->{_problem}         || [],
      '_species_defs'    => $data->{_species_defs}    || undef,
      '_ext_url_'        => $data->{_ext_url}         || undef,
      '_user'            => $data->{_user}            || undef,
      '_input'           => $data->{_input}           || undef,
      '_databases'       => $data->{_databases}       || undef,
      '_wsc_adaptor'     => $data->{_wsc_adaptor}     || undef,
      '_wuc_adaptor'     => $data->{_wuc_adaptor}     || undef,
      '_script_configs_' => $data->{_script_configs_} || {},
      '_user_details'    => $data->{_user_details}    || undef,
      '_web_user_db'     => $data->{_web_user_db}     || undef,
      '_apache_handle'   => $data->{_apache_handle}   || undef,
      '_species'         => $data->{_species}         || $ENV{'ENSEMBL_SPECIES'},
      '_script'          => $data->{_script}          || $ENV{'ENSEMBL_SCRIPT'},
      '_feature_types'   => $data->{_feature_types}   || [],
      '_feature_ids'     => $data->{_feature_ids}   || [],
      'timer'     => $data->{timer}   || [],
      '_group_ids'       => $data->{_group_ids}   || [],
      %extra_elements
    },
    [],
    $supertype 
  ];
  bless $self, $class;
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
sub species :lvalue      { $_[0][1]{'_species'}; }
sub script               { $_[0][1]{'_script'};  }
sub __supertype  :lvalue { $_[0][3]; }
sub __objecttype :lvalue { $_[0][0]; }
sub __data       :lvalue { $_[0][1]; }
sub __children           { return $_[0][2]; }

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
  my $self = shift;
  my $fn   = shift;
  foreach my $sub ( @{$self->__children} ) {
    return 1 if $sub->can($fn);
  }
  return 0;
}

sub ref {
  my $self = shift;
  my $ref = ref( $self );
  my $object = join '::', 'EnsEMBL','Web',$self->__supertype,$self->__objecttype;
  return "$object (@{[map { ref($_) } @{$self->__children}]})";
};

sub DESTROY {}


1;
