package EnsEMBL::Web::Proxiable;

=head1 NAME

EnsEMBL::Web::Proxiable.pm

=head1 SYNOPSIS

Parent class for all proxiable objects/factories

=head1 DESCRIPTION

Base class of all "proxiable" objects, basically just contains the
"common hash" part of the proxiable object, which leaves tabs on:

 *  Web user config adaptor

 *  CGI object  

 *  ExtURL object

 *  Species defs object 

 *  Problem objects

=head1 LICENCE

This code is distributed under an Apache style licence. Please see
http://www.ensembl.org/info/about/code_licence.html for details

=head1 CONTACT

James Smith - js5@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::User;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::UserConfigAdaptor;
use EnsEMBL::Web::ScriptConfigAdaptor;
use EnsEMBL::Web::Document::DropDown::MenuContainer;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::DBSQL::UserDB;

our @ISA = qw( EnsEMBL::Web::Root );

=head2 new

  Arg [1]   : Hash ( shared information storage )
  Function  : Creates a new proxiable object
  Returntype: EnsEMBL::Web::Proxiable ( or sub class of )

=cut


sub new {
  my( $class, $data ) = @_;
  my $self = { 'data' => $data };
  bless $self, $class;
  return $self; 
}

=head2 __data

  Function  : Retrieves the common data hash
  Returntype: hash 

=cut

sub __data { return $_[0]{'data'}; }

=head2 input

  Arg [1]   : CGI (or equivalent) object (optional)
  Function  : Getter/setter for CGI object
  Returntype: CGI

=cut

sub input { 
  my $self = shift;
  $self->{'data'}{'_input'} = shift if @_;
  return $self->{'data'}{'_input'};
}

=head2 param

  Arg [1]   : string: parameter name
  Function  : This is designed to work in the same way as the
              param function in CGI.pm, if merges the values in
              the CGI object with those from the appropriate
              ScriptConfig object.
           
              (1) No parameter passed

              This returns an array of the parameters.

              (2) One parameter passed
 
              Returns the value of the parameter from either 
              the CGI object or the Script Config object.

              (3) Two+ parameters passed
 
              Sets and returns the value of the parameter from either
              the CGI object or the Script Config object.

  Returntype: wantarray ? list : scalar

=cut

sub param {
  my $self = shift;
  if( @_ ){ 
    my @T = $self->{'data'}{'_input'}->param(@_);
    if( @T ) {
      return wantarray ? @T : $T[0];
    }
    my $wsc = $self->get_scriptconfig( );
    if( $wsc ) {
      if( @_ > 1 ) { $wsc->set(@_); }
      my $val = $wsc->get(@_);
      my @val = ref($val) eq 'ARRAY' ? @$val : ($val);
      return wantarray ? @val : $val[0];
    }
    return wantarray ? () : undef;
  } else {
    my @params = $self->{'data'}{'_input'}->param();
    my $wsc    = $self->get_scriptconfig( );
    push @params, $wsc->options() if $wsc;
    my %params = map { $_,1 } @params;
    return keys %params;
  }
}

sub input_param  {
  my $self = shift;
  return $self->{'data'}{'_input'}->param(@_);
}

sub delete_param { my $self = shift;  $self->{'data'}{'_input'}->delete(@_); }

sub script  { return $_[0]{'data'}{'_script'}; }
sub species { return $_[0]{'data'}{'_species'}; }

=head2 DBConnection

  Arg [1]   : EnsEMBL::DB::DBConnection object (optional)
  Function  : Getter/setter for DBConnection object
  Returntype: EnsEMBL::DB::DBConnection
  Exceptions:
  Caller    :
  Example   :

=cut

sub DBConnection {
  $_[0]->{'data'}{'_databases'} ||= EnsEMBL::Web::DBSQL::DBConnection->new( $_[0]->species, $_[0]->species_defs );
}

=head2 database

 Arg[1]      : String
                Database type (core, est)
 Example     : $genedata->database('core')
 Description : lazy loader for database connections
 Return type : Database adaptor object

=cut

sub database {
  my $self = shift; 
  $self->DBConnection->get_DBAdaptor( @_ );
}

=head2 get_databases

 Arg[1]      : String
                Database type (core, est)
 Example     : $genedata->get_databases('core')
 Description : lazy loader for database connections
 Return type : Database adaptor object

=cut

sub get_databases {
  my $self = shift;
  $self->DBConnection->get_databases( @_ );
}

=head2 databases_species

 Arg[1]      : String
                Database type (core, est)
 Example     : $genedata->databases_species('core')
 Description : lazy loader for database connections (in other species)
 Return type : Database adaptor object

=cut

sub databases_species {
  my $self = shift; 
  $self->DBConnection->get_databases_species( @_ );
}

=head2 has_a_problem

 Example     : if ($genedata->has_a_problem){...}
 Description : flag to test if there has been a 'problem'
 Return type : bool (0:1)

=cut

sub has_a_problem     {
  my $self = shift;
  return scalar( @{$self->{'data'}{'_problem'}} );
}

=head2 has_fatal_problem

 Example     : if ($genedata->has_fatal_problem){...}
 Description : flag to test if there has been a fatal 'problem'
 Return type : bool (0:1)

=cut

sub has_fatal_problem {
  my $self = shift;
  return scalar( grep { $_->isFatal } @{$self->{'data'}{'_problem'}} );
}

=head2 get_problem_type

 Arg[1]      : type of problem you are looking for
 Example     : if ($genedata->has_problem_type( $type ) ){...}
 Description : flag to test if there has been a 'problem' of given type
 Return type : bool (0:1)

=cut

sub has_problem_type  {
  my( $self,$type ) = @_;
  return scalar( grep { $_->get_by_type($type) } @{$self->{'data'}{'_problem'}} );
}

=head2 get_problem_type

 Arg[1]          : type of problem you are looking for
 Example     : if ($genedata->get_problem_type){...}
 Description : flag to test if there has been a 'problem' of a given type
 Return type : bool (0:1)

=cut

sub get_problem_type  {
  my( $self,$type ) = @_;
  return grep { $_->get_by_type($type) } @{$self->{'data'}{'_problem'}};
}

=head2 problem

 Arg[1]      : String
                                A problem type
 Arg[2]      : String
                                Problem title
 Arg[3]      : String
                                Problem message
 Example     : $self->problem($problem)
 Description : gets and sets problem object (see EnsEMBL::Web::Problem)
 Return type : EnsEMBL::Web::Problem

=cut

sub problem {
  my $self = shift;
  push @{$self->{'data'}{'_problem'}}, EnsEMBL::Web::Problem->new(@_) if @_;
  return $self->{'data'}{'_problem'};
}

=head2 clear_problems 
 
 Example     : $self->clear_problems;
 Description : Clears the problems array
 Return type : NULL

=cut

sub clear_problems {
  my $self = shift;
  $self->{'data'}{'_problem'} = [];
}

=head2 user

 Example     : $OBJ->user
 Description : Returns the EnsEMBL::Web::User object
 Return type : EnsEMBL::Web::User object
=cut

sub user {
  $_[0]{'data'}{'_user'}         ||= EnsEMBL::Web::User->new();
}

=head2 species_defs

 Example     : $OBJ->species_defs
 Description : Returns the EnsEMBL::Web::SpeciesDefs object
 Return type : EnsEMBL::Web::SpeciesDefs object
=cut

sub species_defs    {
  $_[0]{'data'}{'_species_defs'} ||= EnsEMBL::Web::SpeciesDefs->new();
}

sub web_user_db {
  $_[0]{'data'}{'_web_user_db'}  ||= EnsEMBL::Web::DBSQL::UserDB->new( $_[0]->apache_handle );
}
sub apache_handle {
  $_[0]{'data'}{'_apache_handle'};
}
=head2 get_userconfig_adaptor

 Example     : $OBJ->get_userconfig_adaptor
 Description : Returns the EnsEMBL::Web::UserConfigAdaptor object
 Return type : EnsEMBL::Web::UserConfigAdaptor object
=cut

sub get_userconfig_adaptor {
  return $_[0]{'data'}{'_wuc_adaptor'} ||= EnsEMBL::Web::UserConfigAdaptor->new(
    $_[0]->species_defs->ENSEMBL_SITETYPE,
    $_[0]->web_user_db,
    $_[0]->apache_handle,
    $_[0]->ExtURL,
    $_[0]->species_defs
  );
}

=head2 get_userconfig  

 Arg[1]      : Name of web user config
 Example     : return $OBJ->get_userconfig( 'contigviewbottom' );
 Description : Returns the web user config for the image
               (see EnsEMBL::Web::UserConfig for documentation) 
 Return type : EnsEMBL::Web::UserConfig (sub class of)
=cut

sub get_userconfig  {
  my $self = shift;
  my $wuca = $self->get_userconfig_adaptor || return;
  return $wuca->getUserConfig( @_ );
}

=head2 get_scriptconfig_adaptor

 Example     : $OBJ->get_scriptconfig_adaptor
 Description : Returns the EnsEMBL::Web::ScriptConfigAdaptor object
 Return type : EnsEMBL::Web::ScriptConfigAdaptor object
=cut

sub get_scriptconfig_adaptor {
  return $_[0]{'data'}{'_wsc_adaptor'} ||= EnsEMBL::Web::ScriptConfigAdaptor->new(
    $_[0]->species_defs->ENSEMBL_PLUGIN_ROOTS,
    $_[0]->web_user_db,
    $_[0]->apache_handle
  );
}

=head2 get_scriptconfig

 Arg[1]      : Name of web user config
 Example     : return $OBJ->get_userconfig( 'contigviewbottom' );
 Description : Returns the web user config for the image
               (see EnsEMBL::Web::UserConfig for documentation)
 Return type : EnsEMBL::Web::UserConfig (sub class of)
=cut

sub get_scriptconfig  {
  my( $self, $key ) = @_;
  $key = $self->script unless defined $key;
  my $wsca = $self->get_scriptconfig_adaptor || return;
  return $self->{'data'}{'_script_configs_'}{$key} ||= $wsca->getScriptConfig( $key );
}

=head2 ExtURL

 Example     : $OBJ->ExtURL
 Description : Returns the ExtURL object
 Return type : ExtURL object
=cut

sub ExtURL {
  return $_[0]{'data'}{'_ext_url_'} ||= EnsEMBL::Web::ExtURL->new( $_[0]->species, $_[0]->species_defs );
}

=head2 get_ExtURL

 Arg[1]      : Name of external database to link to (string)
 Arg[2]      : Either the external identifier OR a hash of
               values used in the substitution (e.g. seq_region,
               start, end)
 Example     : return $OBJ->get_ExtURL( 'REFSEQ', 'XP_000001' );
 Description : Returns the URL related to the identifier in the 
               database (see ExtURL for documentation) 
 Return type : String
=cut

sub get_ExtURL      {
  my $self = shift;
  my $new_url = $self->ExtURL || return;
  return $new_url->get_url( @_ );
}

=head2 get_ExtURL_link

 Arg[1]      : Text for link
 Arg[2]      : Name of external database to link to (string)
 Arg[3]      : Either the external identifier OR a hash of
               values used in the substitution (e.g. seq_region,
               start, end)
 Example     : return $OBJ->get_ExtURL_link( 'refseq XP_000001', 'REFSEQ', 'XP_000001' );
 Description : Returns a formatted a href link to the URL related to the identifier in the
               database (see ExtURL for documentation)
 Return type : String
=cut


sub get_ExtURL_link {
  my $self = shift;
  my $text = shift;
  my $URL = $self->get_ExtURL(@_);
  return $URL ? qq(<a href="$URL">$text</a>) : $text;
}

sub user_config_hash {
  my $self = shift;
  my $key  = shift;
  my $type = shift || $key;
  $self->__data->{'user_configs'}{$key} ||= $self->get_userconfig( $type );
}

=head2 

Creating a new drop-down menu... <c>$object->new_menu_container( %params )</c>

To create a new menu-bar across the top of an image you need to create a new
<c>EnsEMBL::Web::Document::DropDown::MenuContainer</c> object populated with
<c>EnsEMBL::Web::Document::DropDown::Menu</c> objects. The <c>EnsEMBL::Web::Object</c>
has a simple wrapper function around the DropDown code

=over4

<c>$object->new_menu_container( %params )</c>

=back

The parameters that you can set are:

=over 4

=item <c>panel</c> - The name of the CGI variable which is passed if any changes are made to the drop down elements.

=item <c>configname</c> - The name of the appropriate web user config for drawing the image; or 

=item <c>config</c> - The appropriate web_user_config

=item <c>configs</c> - Additional configs which have an effect on the rendering/effected by the values of the dropdown.

=item <c>location</c> - The location of the page to submit this equest to,

=item <c>fields</c> - If ommitted uses results of query to $self->generate_query_hash();

=item <c>leftmenus</c> - an array ref of Menu submodule names

=item <c>rightmenus</c> - an array ref of Menu submodule names

=back 

=cut

sub new_menu_container {
  my($self, %params ) = @_;

#  foreach my $p (sort keys %params) {
#      warn ("$p => $params{$p}");
#  }

  my %N = (
    'species'      => $self->species,
    'script'       => $self->script,
    'scriptconfig' => $self->get_scriptconfig,
    'width'        => $self->param('image_width'),
    'object'    => $params{'object'}
  );

  $N{'location'} = $self->location if $self->can('location');
  $N{'panel'}    = $params{'panel'}    || $params{'configname'} || $N{'script'};
  $N{'fields'}   = $params{'fields'}   || ( $self->can('generate_query_hash') ? $self->generate_query_hash : {} );
  $N{'config'}   = $self->user_config_hash( $params{'configname'}, $params{'configname'} ) if $params{'configname'};
  $N{'config'}->set_species( $self->species );
  $N{'configs'}  = $params{'configs'};

  my $mc = EnsEMBL::Web::Document::DropDown::MenuContainer->new(%N);

  foreach( @{$params{'leftmenus'} ||[]} ) { $mc->add_left_menu( $_); }
  foreach( @{$params{'rightmenus'}||[]} ) { $mc->add_right_menu($_); }
  $mc->{'config'}->{'missing_tracks'} = $mc->{'missing_tracks'};
  return $mc;
}

1;

