package EnsEMBL::Web::Controller::Command;

use strict;
use warnings;

use EnsEMBL::Web::Controller::Command::Filter;
use EnsEMBL::Web::Document::Interface;
use EnsEMBL::Web::Interface::InterfaceDef;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::RegObj;
use Class::Std;
use CGI qw(escapeHTML);


{

my %Filters :ATTR(:get<filters> :set<filters>);
my %Action :ATTR(:get<action> :set<action>);
my %Message  :ATTR(:get<message> :set<message>);
my %SpeciesDefs  :ATTR(:get<species_defs> :set<species_defs>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  if ($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY) {
    $self->set_species_defs($ENSEMBL_WEB_REGISTRY->species_defs);
  }
}

sub render_message {
  my $self = shift;

    my $webpage= new EnsEMBL::Web::Document::WebPage(
    'renderer'   => 'Apache',
    'outputtype' => 'HTML',
    'scriptname' => '',
    'objecttype' => 'User',
    'command'    => $self,
  );

  if( $webpage->has_a_problem() ) {
    $webpage->render_error_page( $webpage->problem->[0] );
  } else {
    foreach my $object( @{$webpage->dataObjects} ) {
      $webpage->configure( $object, 'message' );
    }
    $webpage->render();
  }
}

sub add_filter {
  my ($self, $class, $params) = @_;
  if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
    my $parameters = $params || {};
    my $filter = $class->new($parameters);
    my $filters = $self->get_filters || [];
    push @$filters, $filter;
    $self->set_filters($filters);
  } else {
    warn "Failed to add filter.";;
  }
}

sub not_allowed {
  ### Loops through array of filters and returns error message 
  ### for the first one which fails
  my $self = shift;
  my $filters = $self->get_filters || [];
  foreach my $f (@$filters) {
    if (!$f->allow) {
      $self->set_message($f->message);
      return $f->message;
    }
  }
  return undef;
}

sub url {
  ### Assembles a valid URL, adding the site's base URL
  ### and CGI-escaping any parameters
  ### returns a URL string
  my ($self, $script, $param) = @_;
  my $url = $script; # TO DO - add site base URL
 
  my $query_string = join ';', map { "$_=".escapeHTML($param->{$_}) } sort keys %$param;
  $url .= "?$query_string" if $query_string;

  return $url;
}

sub add_symbol_lookup {
  my ($self, $name) = @_;
  no strict;
  my $class = ref($self);

  unless (defined *{ "$class\::$name" }) {
    *{ "$class\::$name" } = $self->initialize_accessor($name);
  }
}

sub initialize_accessor {
  no strict;
  my ($self, $attribute) = @_;
  return sub {
    my $self = shift;
    my $new_value = shift;
    if (defined $new_value) {
      $self->set_value($attribute,  $new_value);
    }
    return $self->get_value($attribute);
  };
}

}

1;
