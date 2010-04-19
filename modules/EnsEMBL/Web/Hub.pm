package EnsEMBL::Web::Hub;

### NAME: EnsEMBL::Web::Hub 
### A centralised object giving access to data connections and the web environment 

### STATUS: Under development
### Currently being developed, along with its associated moduled E::W::Resource,
### as a replacement for Proxy/Proxiable code

### DESCRIPTION:
### Hub is intended as a replacement for both the non-object-specific
### portions of Proxiable and the global variable ENSEMBL_WEB_REGISTRY
### It uses the Flyweight design pattern to create a single object that is 
### passed around between all other objects that require data connectivity.
### The Hub stores information about the current web page and its environment, 
### including cgi parameters, settings parsed from the URL, browser session, 
### database connections, and so on.

use strict;

use Carp;
use URI::Escape qw(uri_escape);

use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::SpeciesDefs;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, %args) = @_;

  my $type = $args{'_type'} || $ENV{'ENSEMBL_TYPE'}; # Parsed from URL:  Gene, UserData, etc
  $type = 'DAS' if $type =~ /^DAS::.+/;

  my $self = {
    _apache_handle => $args{'_apache_handle'} || undef,
    _input         => $args{'_input'}         || undef,                        # extension of CGI
    _species       => $args{'_species'}       || $ENV{'ENSEMBL_SPECIES'},    
    _type          => $type,
    _action        => $args{'_action'}        || $ENV{'ENSEMBL_ACTION'},       # View, Summary etc
    _function      => $args{'_function'}      || $ENV{'ENSEMBL_FUNCTION'},     # Extra path info
    _script        => $args{'_script'}        || $ENV{'ENSEMBL_SCRIPT'},       # name of script in this case action... ## deprecated
    _species_defs  => $args{'_species_defs'}  || new EnsEMBL::Web::SpeciesDefs, 
    _cache         => $args{'_cache'}         || new EnsEMBL::Web::Cache(enable_compress => 1, compress_threshold => 10000),
    _problem       => $args{'_problem'}       || {},    
    _ext_url       => $args{'_ext_url'}       || undef,                        # EnsEMBL::Web::ExtURL object used to create external links
    _user          => $args{'_user'}          || undef,                    
    _tabs          => $args{'_tabs'}          || {},
    _tab_order     => $args{'_tab_order'}     || [],
    _view_configs  => $args{'_view_configs_'} || {},
    _user_details  => $args{'_user_details'}  || 1,
    _timer         => $args{'_timer'}         || $ENSEMBL_WEB_REGISTRY->timer, # Diagnostic object
    _session       => $ENSEMBL_WEB_REGISTRY->get_session,
  };

  bless $self, $class;

  ## Get database connections 
  my $api_connection = $self->species ne 'common' ? new EnsEMBL::Web::DBSQL::DBConnection($self->species, $self->species_defs) : undef;
  $self->{'_databases'} = $api_connection;

  $self->species_defs->{'timer'} = $args{'_timer'};

  return $self;
}

# Accessor functionality
sub species   :lvalue { $_[0]{'_species'};   }
sub script    :lvalue { $_[0]{'_script'};    }
sub type      :lvalue { $_[0]{'_type'};      }
sub action    :lvalue { $_[0]{'_action'};    }
sub function  :lvalue { $_[0]{'_function'};  }
sub parent    :lvalue { $_[0]{'_parent'};    }
sub session   :lvalue { $_[0]{'_session'};   }
sub databases :lvalue { $_[0]{'_databases'}; } 
sub cache     :lvalue { $_[0]{'_cache'};     }
sub user      :lvalue { $_[0]{'_user'};      }

sub tab_order :lvalue { $_[0]{'_tab_order'}; }
sub tabs      { return $_[0]{'_tabs'}; }

sub add_tab   { 
  my ($self, $tab) = @_;
  $self->{'_tabs'}{$tab->{'type'}} = $tab; 
}

sub input         { return $_[0]{'_input'};         }
sub delete_param  { my $self = shift; $self->{'_input'}->delete(@_); }
sub core_types    { return $_[0]{'_core_types'};   }
sub core_params   { return $_[0]{'_core_params'};   }
sub apache_handle { return $_[0]{'_apache_handle'}; }
sub species_defs  { return $_[0]{'_species_defs'} ||= new EnsEMBL::Web::SpeciesDefs; }
sub user_details  { return $_[0]{'_user_details'} ||= 1; }
sub timer         { return $_[0]{'_timer'}; }
sub timer_push    { return ref $_[0]->timer eq 'EnsEMBL::Web::Timer' ? $_[0]->timer->push(@_) : undef; }

sub ExtURL        { return $_[0]->{'_ext_url'} ||= new EnsEMBL::Web::ExtURL($_[0]->species, $_[0]->species_defs); } 

sub has_a_problem      { return scalar keys %{$_[0]{'_problem'}}; }
sub has_fatal_problem  { return scalar @{$_[0]{'_problem'}{'fatal'}||[]}; }
sub has_problem_type   { return scalar @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub get_problem_type   { return @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub clear_problem_type { $_[0]{'_problem'}{$_[1]} = []; }
sub clear_problems     { $_[0]{'_problem'} = {}; }

sub problem {
  my $self = shift;
  push @{$self->{'_problem'}{$_[0]}}, new EnsEMBL::Web::Problem(@_) if @_;
  return $self->{'_problem'};
}

# The whole problem handling code possibly needs re-factoring 
# Especially the stuff that may end up cyclic! (History/UnMapped)
# where ID's don't exist but we have a "gene" based display
# for them.
sub handle_problem {
  my $self = shift;

  my $url;

  if ($self->has_problem_type('redirect')) {
    my ($p) = $self->get_problem_type('redirect');
    $url  = $p->name;
  } elsif ($self->has_problem_type('mapped_id')) {
    my $feature = $self->__data->{'objects'}[0];

    $url = sprintf '%s/%s/%s?%s', $self->species_path, $self->type, $self->action, join ';', map { "$_=$feature->{$_}" } keys %$feature;
  } elsif ($self->has_problem_type('unmapped')) {
    my $id   = $self->param('peptide') || $self->param('transcript') || $self->param('gene');
    my $type = $self->param('gene') ? 'Gene' : $self->param('peptide') ? 'ProteinAlignFeature' : 'DnaAlignFeature';

    $url = sprintf '%s/%s/Genome?type=%s;id=%s', $self->species_path, $self->type, $type, $id;
  } elsif ($self->has_problem_type('archived')) {
    my ($view, $param, $id) =
      $self->param('peptide')    ? ('Transcript/Idhistory/Protein', 'p', $self->param('peptide'))    :
      $self->param('transcript') ? ('Transcript/Idhistory',         't', $self->param('transcript')) :
                                   ('Gene/Idhistory',               'g', $self->param('gene'));

    $url = sprintf '%s/%s?%s=%s', $self->species_path, $view, $param, $id;
  } else {
    my $p = $self->problem;
    my @problems = map @{$p->{$_}}, keys %$p;
    return \@problems;
  }
 
  if ($url) {
    $self->redirect($url);
    return 'redirect';
  }
}

sub species_path      { my $self = shift; $self->species_defs->species_path(@_); }

sub database {
  my $self = shift;

  if ($_[0] =~ /compara/) {
    return Bio::EnsEMBL::Registry->get_DBAdaptor('multi', $_[0]);
  } else {
    return $self->{'_databases'}->get_DBAdaptor(@_);
  }
}

sub is_core  { 
  my ($self, $name) = @_;
  return unless $name;
  return $self->{'_core_types'}->{$name};
}

sub core_param  { 
  my $self = shift;
  my $name = shift;
  return unless $name;
  $self->{'_core_params'}->{$name} = @_ if @_;
  return $self->{'_core_params'}->{$name};
}

sub set_core_types {
  ### Used by Builder to initialise core types hash
  my ($self, @types) = @_;
  my %core_types = map { $_ => 1 } @types;
  $self->{'_core_types'} = \%core_types;
}

sub set_core_params {
  ### Used by Builder to initialise core parameter hash from CGI parameters
  my $self = shift;
  my $core_params = {};

  foreach (@{$self->species_defs->core_params}) {
    my @param = $self->param($_);
    $core_params->{$_} = scalar @param == 1 ? $param[0] : \@param;
  }

  $self->{'_core_params'} = $core_params;
}

sub filename {
### Creates a generic filename for miscellaneous exports
  my $self = shift;
  my $name = sprintf '%s-%d-%s_%s',
    $self->species,
    $self->species_defs->ENSEMBL_VERSION,
    $self->type,
    $self->action;

  $name =~ s/[^-\w\.]/_/g;
  return $name;
}


# Does an ordinary redirect
sub redirect {
  my ($self, $url) = @_;
  $self->{'_input'}->redirect($url);
}

sub url {
  my $self = shift;
  my $params = shift || {};

  Carp::croak("Not a hashref while calling _url ($params @_)") unless ref $params eq 'HASH';

  my $species = exists $params->{'species'}  ? $params->{'species'}  : $self->species;
  my $type    = exists $params->{'type'}     ? $params->{'type'}     : $self->type;
  my $action  = exists $params->{'action'}   ? $params->{'action'}   : $self->action;
  my $fn      = exists $params->{'function'} ? $params->{'function'} : $action eq $self->action ? $self->function : undef;
  my %pars    = %{$self->core_params};

  # Remove any unused params
  foreach (keys %pars) {
    delete $pars{$_} unless $pars{$_};
  }

  if ($params->{'__clear'}) {
    %pars = ();
    delete $params->{'__clear'};
  }

  delete $pars{'t'}  if $params->{'pt'};
  delete $pars{'pt'} if $params->{'t'};
  delete $pars{'t'}  if $params->{'g'} && $params->{'g'} ne $pars{'g'};
  delete $pars{'time'};

  foreach (keys %$params) {
    next if $_ =~ /^(species|type|action|function)$/;

    if (defined $params->{$_}) {
      $pars{$_} = $params->{$_};
    } else {
      delete $pars{$_};
    }
  }

  my $url  = sprintf '%s/%s/%s', $self->species_defs->species_path($species), $type, $action . ($fn ? "/$fn" : '');
  my $flag = shift;

  return [ $url, \%pars ] if $flag;

  $url .= '?' if scalar keys %pars;

  # Sort the keys so that the url is the same for a given set of parameters
  foreach my $p (sort keys %pars) {
    next unless defined $pars{$p};

    # Don't escape :
    $url .= sprintf '%s=%s;', uri_escape($p), uri_escape($_, "^A-Za-z0-9\-_.!~*'():") for ref $pars{$p} ? @{$pars{$p}} : $pars{$p};
  }

  $url =~ s/;$//;

  return $url;
}

sub param {
  my $self = shift;

  if (@_) {
    my @T = map _sanitize($_), $self->input->param(@_);
    return wantarray ? @T : $T[0] if @T;
    my $view_config = $self->viewconfig;

    if ($view_config) {
      $view_config->set(@_) if @_ > 1;
      my @val = $view_config->get(@_);
      return wantarray ? @val : $val[0];
    }

    return wantarray ? () : undef;
  } else {
    my @params = map _sanitize($_), $self->input->param;
    my $view_config = $self->viewconfig;
    push @params, $view_config->options if $view_config;
    my %params = map { $_, 1 } @params; # Remove duplicates

    return keys %params;
  }
}

sub input_param  {
  my $self = shift;
  return _sanitize($self->param(@_));
}

sub multi_params {
  my $self = shift;
  my $realign = shift;

  my $input = $self->input;

  my %params = defined $realign ?
  map { $_ => $input->param($_) } grep { $realign ? /^([srg]\d*|pop\d+|align)$/ && !/^[rg]$realign$/ : /^(s\d+|r|pop\d+|align)$/ && $input->param($_) } $input->param :
  map { $_ => $input->param($_) } grep { /^([srg]\d*|pop\d+|align)$/ && $input->param($_) } $input->param;

  return \%params;
}

sub _sanitize {
  my $T = shift;
  $T =~ s/<script(.*?)>/[script$1]/igsm;
  $T =~ s/\s+on(\w+)\s*=/ on_$1=/igsm;
  return $T;
} 

### VIEWCONFIGS

# Returns the named (or one based on script) {{EnsEMBL::Web::ViewConfig}} object
sub get_viewconfig {
  my ($self, $type, $action) = @_;
  my $session = $self->session;
  return undef unless $session;
  my $T = $session->getViewConfig( $type || $self->type, $action || $self->action );
  return $T;
}

# Store default viewconfig so we don't have to keep getting it from session
sub viewconfig {
  my $self = shift;
  $self->{'_viewconfig'} ||= $self->get_viewconfig;
  return $self->{'_viewconfig'};
}

# Returns the named (or one based on script) {{EnsEMBL::Web::ImageConfig}} object
sub get_imageconfig  {
  my ($self, $key) = @_;
  my $session = $self->session || return;
  my $T = $session->getImageConfig($key); # No second parameter - this isn't cached
  $T->_set_core_info($self->{'_tabs'});
  return $T;
}

# Retuns a copy of the script config stored in the database with the given key
sub image_config_hash {
  my ($self, $key, $type, @species) = @_;

  $type ||= $key;

  my $session = $self->session;
  return undef unless $session;
  my $T = $session->getImageConfig($type, $key, @species);
  return unless $T;
  $T->_set_core_info($self->{'_tabs'});
  return $T;
}

sub attach_image_config {
  my ($self, $key, $image_key) = @_;
  my $session = $self->session;
  return undef unless $session;
  my $T = $session->attachImageConfig($key, $image_key);
  return $T;
}

#----------------------- EXTERNAL URLs -----------------------------

sub get_ExtURL {
  my $self = shift;
  my $new_url = $self->ExtURL || return;
  return $new_url->get_url(@_);
}

sub get_ExtURL_link {
  my $self = shift;
  my $text = shift;
  my $url = $self->get_ExtURL(@_);
  return $url ? qq(<a href="$url">$text</a>) : $text;
}

# use PFETCH etc to get description and sequence of an external record
sub get_ext_seq {
  my ($self, $id, $ext_db) = @_;
  my $indexer = new EnsEMBL::Web::ExtIndex($self->species_defs);

  return unless $indexer;

  my $seq_ary;
  my %args;
  $args{'ID'} = $id;
  $args{'DB'} = $ext_db ? $ext_db : 'DEFAULT';

  eval { $seq_ary = $indexer->get_seq_by_id(\%args); };
 
  if (!$seq_ary) {
    warn "The $ext_db server is unavailable: $@";
    return '';
  } else {
    my $list = join ' ', @$seq_ary;
    return $list =~ /no match/i ? '' : $list;
  }
}

sub get_tracks {
  my ($self, $key) = @_;
  my $data = $self->fetch_userdata_by_id($key);
  my $tracks = {};

  if (my $parser = $data->{'parser'}) {
    while (my ($type, $track) = each(%{$parser->get_all_tracks})) {
      my @A = @{$track->{'features'}};
      my @rows;
      foreach my $feature (@{$track->{'features'}}) {
        my $data_row = {
          'chr'     => $feature->seqname(),
          'start'   => $feature->rawstart(),
          'end'     => $feature->rawend(),
          'label'   => $feature->id(),
          'gene_id' => $feature->id(),
        };
        push (@rows, $data_row);
      }
      $tracks->{$type} = {'features' => \@rows, 'config' => $track->{'config'}};
    }
  }
  else {
    while (my ($analysis, $track) = each(%{$data})) {
      my @rows;
      foreach my $f (
        map { $_->[0] }
        sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
        map { [$_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20 , $_->{'region'},
$_->{'start'}] }
        @{$track->{'features'}}
        ) {
        my $data_row = {
          'chr'       => $f->{'region'},
          'start'     => $f->{'start'},
          'end'       => $f->{'end'},
          'length'    => $f->{'length'},
          'label'     => $f->{'label'},
          'gene_id'   => $f->{'gene_id'},
        };
        push (@rows, $data_row);
      }
      $tracks->{$analysis} = {'features' => \@rows, 'config' => $track->{'config'}};
    }
  }

  return $tracks;
}

sub fetch_userdata_by_id {
  my ($self, $record_id) = @_;

  return unless $record_id;

  my $user = $self->user;
  my $data = {};

  my ($status, $type, $id) = split '-', $record_id;

  if ($type eq 'url' || ($type eq 'upload' && $status eq 'temp')) {
    my ($content, $format);

    my $tempdata = {};
    if ($status eq 'temp') {
      $tempdata = $self->session->get_data('type' => $type, 'code' => $id);
    } else {
      my $record = $user->urls($id);
      $tempdata = { 'url' => $record->url };
    }
   
    my $parser = new EnsEMBL::Web::Text::FeatureParser($self->species_defs);

    if ($type eq 'url') {
      my $response = get_url_content($tempdata->{'url'});
      $content = $response->{'content'};
    } else {
      my $file = new EnsEMBL::Web::TmpFile::Text(filename => $tempdata->{'filename'});
      $content = $file->retrieve;
      return {} unless $content;
    }
   
    $parser->parse($content, $tempdata->{'format'});
    $data = { 'parser' => $parser };
  } 
  else {
 my $fa = $self->databases('userdata', $self->species)->get_DnaAlignFeatureAdaptor;
    my @records = $user->uploads($id);
    my $record = $records[0];

    if ($record) {
      my @analyses = ($record->analyses);

      foreach (@analyses) {
        next unless $_;
        $data->{$_} = {'features' => $fa->fetch_all_by_logic_name($_), 'config' => {}};
      }
    }
  }

  return $data;
}


1;
