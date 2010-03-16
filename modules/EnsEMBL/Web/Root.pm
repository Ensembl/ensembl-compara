package EnsEMBL::Web::Root;

### NAME: EnsEMBL::Web::Root
### Base class for many EnsEMBL::Web objects

### PLUGGABLE: No

### STATUS: Stable

### DESCRIPTION
### This module contains a lot of generic functionality
### needed throughout the web code: dynamic module loading,
### url construction, data formatting, etc.

use strict;

use Data::Dumper;
use Carp                  qw(cluck);
use File::Path            qw(mkpath);
use File::Spec::Functions qw(splitpath);
use HTML::Entities        qw(encode_entities);
use JSON                  qw(to_json);
use Text::Wrap;
use Time::HiRes           qw(gettimeofday);
use URI::Escape           qw(uri_escape uri_unescape);

our $failed_modules;

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;
  return $self;
}

sub filters :lvalue { $_[0]->{'filters'}; }

sub _parse_referer {
  my ($self, $uri) = @_;
  
  $uri ||= $ENV{'HTTP_REFERER'}; 
  $uri =~ s/^(https?:\/\/.*?)?\///i;
  $uri =~ s/[;&]$//;
  
  my ($url, $query_string) = split /\?/, $uri;
  my ($sp, $ot, $view, $subview) = split /\//, $url;

  my (@pairs) = split /[&;]/, $query_string;
  my $params = {};
  
  foreach (@pairs) {
    my ($param, $value) = split '=', $_, 2;
    
    next unless defined $param;
    
    $value = '' unless defined $value;
    $param = uri_unescape($param);
    $value = uri_unescape($value);
    
    push @{$params->{$param}}, $value unless $param eq 'time'; # don't copy time
  }

  if ($self->can('species_defs') && $self->species_defs->ENSEMBL_DEBUG_FLAGS & $self->species_defs->ENSEMBL_DEBUG_REFERER) {
    warn "\n";
    warn "------------------------------------------------------------------------------\n";
    warn "\n";
    warn "  SPECIES: $sp\n";
    warn "  OBJECT:  $ot\n";
    warn "  VIEW:    $view\n";
    warn "  SUBVIEW: $subview\n";
    warn "  QS:      $query_string\n";
    
    foreach my $param (sort keys %$params) {
      warn sprintf '%20s = %s\n', $param, $_ for sort @{$params->{$param}};
    }
    
    warn "\n";
    warn "  URI:     $uri\n";
    warn "\n";
    warn "------------------------------------------------------------------------------\n";
  }
  
  return {
    'ENSEMBL_SPECIES'  => $sp,
    'ENSEMBL_TYPE'     => $ot,
    'ENSEMBL_ACTION'   => $view,
    'ENSEMBL_FUNCTION' => $subview,
    'params'           => $params,
    'uri'              => "/$uri"
  };
}

sub url {
### Assembles a valid URL, adding the site's base URL and CGI-escaping any parameters
### returns a URL string
### This is a simple version, that can be extended in children as needed
# TODO: add site base url
  my ($self, $path, $param) = @_;

  my $clean_params = $self->escape_url_parameters($param);
  return $self->reassemble_url($path, $clean_params);
}

sub reassemble_url {
  my ($self, $path, $param) = @_;
  return $path unless $param;
  $path .= $path =~ /\?/ ? ';' : '?';
  return $path . (join ';', @$param);
}

sub escape_url_parameters {
  my ($self, $param) = @_;
  my $clean_params;
  
  while (my ($k, $v) = each (%$param)) {
    if (ref $v eq 'ARRAY') {
      push @$clean_params, "$k=" . encode_entities(uri_escape($_)) for @$v;
    } else {
      push @$clean_params, "$k=" . encode_entities(uri_escape($v));
    }
  }
  return $clean_params;
}

sub make_link_tag {
  my ($self, %args) = @_;
  if ($args{'url'}) {
    my $html = '<a href="'.$args{'url'}.'"';
    $html .= ' title="'.$args{'title'}.'"' if $args{'title'};
    $html .= '>'.$args{'text'}.'</a>';
  }
  else {
    return $args{'text'};
  }
}

# Format an error message by wrapping text to 120 columns
sub _format_error {
  my $self = shift;
  
  $Text::Wrap::columns = 120;
  
  my $out = qq{\n      <pre class="syntax-error">\n} .
            encode_entities(join "\n", map { Text::Wrap::wrap('        ', '        ... ', $_) } split /\n/, join '', @_) .
            qq{\n      </pre>};
            
  $out =~ s/^(\.{3} )/$1/gm;
  
  return $out;
}

# returns true if valid module name
sub is_valid_module_name {
  my ($self, $classname) = @_;
  return $classname =~ /^[a-zA-Z_]\w*(::\w+)*$/;
}

# Equivalent of USE - but used at runtime
sub dynamic_use {
  my ($self, $classname) = @_;
  
  if (!$classname) {
    my @caller = caller(0);
    my $error_message = "Dynamic use called from $caller[1] (line $caller[2]) with no classname parameter\n";
    warn $error_message;
    $failed_modules->{$classname} = $error_message;
    return 0;
  }
  
  return 0 if exists $failed_modules->{$classname};
  
  my ($parent_namespace, $module) = $classname =~ /^(.*::)(.*)$/ ? ($1, $2) : ('::', $classname);
  
  no strict 'refs';
  
  return 1 if $parent_namespace->{$module.'::'} && %{$parent_namespace->{$module.'::'}||{}}; # return if already used 
  
  eval "require $classname";
  
  if ($@) {
    my $module = $classname; 
    $module =~ s/::/\//g;
    
    cluck "EnsEMBL::Web::Root: failed to use $classname\nEnsEMBL::Web::Root: $@" unless $@ =~/^Can't locate $module/;
    
    $failed_modules->{$classname} = $@ || 'Unknown failure when dynamically using module';
    return 0;
  }
  
  $classname->import;
  return 1;
}

# Return error message cached if use previously failed
sub dynamic_use_failure {
  my ($self, $classname) = @_;
  return $failed_modules->{$classname};
}

# Loops through array of filters and returns the first one that fails
sub not_allowed {
  my ($self, $object, $caller) = @_;
  
  my $filters = $self->filters || [];
  
  foreach my $name (@$filters) {
    my $class = 'EnsEMBL::Web::Filter::'.$name;
    
    if ($self->dynamic_use($class)) {
      my $filter = $class->new({ object => $object });
      $filter->catch;
      return $filter if $filter->error_code;
    }  else {
      warn "COULD NOT USE FILTER MODULE $class";
    }
  }
  
  return undef;
}

# Returns seq-region name formatted neatly
sub neat_sr_name {
  my ($self, $type, $name) = @_;
  return $name if $name =~ /^$type/i;
  (my $neat_type = ucfirst(lc $type)) =~ s/contig/Contig/;
  return "$neat_type $name"; 
}

# Converts a MySQL datetime field into something human-readable
sub pretty_date {
  my ($self, $datetime, $format) = @_;
  
  my ($date, $time) = split ' ', $datetime;
  my ($year, $mon, $day) = split '-', $date;
  
  return '-' unless $year > 0;

  my @long_months  = ('', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');
  my @short_months = ('', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  
  $day =~ s/^0//;
  
  if ($format && $format eq 'short') {
    return $short_months[$mon] . ' ' . $year;
  } else {
    return $day . ' ' . $long_months[$mon] . ' ' . $year;
  }
}

# Retuns comma separated version of number
sub thousandify {
  my ($self, $value) = @_;
  local $_ = reverse $value;
  s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $_;
}

# Returns bp formatted neatly as either m/k
sub round_bp {
  my ($self, $value) = @_;
  return sprintf '%0.2fm', $value/1e6 if $value > 2e6;
  return sprintf '%0.2fk', $value/1e3 if $value > 2e3;
  return $self->thousandify($value);
}

# Reverse of round BP - takes a value with a K/M/G at the end and converts to integer value...
sub evaluate_bp {
  my ($self, $value) = @_;
  
  $value =~ s/,//g;
  
  return $value * 1e3 if $value =~ /K/i;
  return $value * 1e6 if $value =~ /M/i;
  return $value * 1e9 if $value =~ /G/i;
  return $value * 1;
} 

# Converts a number from roman (IV...) format to number
sub de_romanize {
  my ($self, $string) = @_;
  
  return 0 if $string eq '';
  return 0 unless $string =~ /^(?: M{0,3}) (?: D?C{0,3} | C[DM]) (?: L?X{0,3} | X[LC]) (?: V?I{0,3} | I[VX])$/ix;
  
  my %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);
  my $last_digit = 1000;
  my $arabic;
  
  foreach (split //, uc $string) {
    my $digit = $roman2arabic{$_};
    $arabic -= 2 * $last_digit if $last_digit < $digit;
    $arabic += ($last_digit = $digit);
  }
  
  return $arabic;
}

# Used to sort chromosomes into a sensible order
sub seq_region_sort {
  my ($self, $chr_1, $chr_2) = @_;
  
  if ($chr_1 =~ /^\d+/) {
    return $chr_2 =~ /^\d+/ ? ($chr_1 <=> $chr_2 || $chr_1 cmp $chr_2) : -1;
  } elsif ($chr_2 =~ /^\d+/) {
    return 1;
  } elsif (my $chr_temp_1 = $self->de_romanize($chr_1)) {
    if (my $chr_temp_2 = $self->de_romanize($chr_2)) {
      return $chr_temp_1 <=> $chr_temp_2;
    } else {
      return $chr_temp_1;
    }
  } elsif ($self->de_romanize($chr_2)) { 
    return 1;
  } else { 
    return $chr_1 cmp $chr_2;
  }
}

sub help_feedback {
  my ($self, $style, $id, %args) = @_;
  
  my $html = qq{
    <div style="$style">
      <form id="help_feedback_$id" class="std check" action="/Help/Feedback" method="get">
        <strong>Was this helpful?</strong>
        <input type="radio" class="autosubmit" name="help_feedback" value="yes" /><label>Yes</label>
        <input type="radio" class="autosubmit" name="help_feedback" value="no" /><label>No</label>
        <input type="hidden" name="record_id" value="$id" />
  };
  
  while (my ($k, $v) = each (%args)) {
    $html .= qq{
        <input type="hidden" name="$k" value="$v" />};
  }
  
  $html .= '
      </form>
    </div>';
  
  return $html;
}

# Returns a random ticket string
sub ticket {
  my $self = shift;
  my $date = time + shift;
  
  my @random_ticket_chars = ('A'..'Z','a'..'f');
  my ($sec, $msec) = gettimeofday;
  my $rand = rand 0xffffffff;
  my $fn = sprintf '%08x%08x%06x%08x', $date, $rand, $msec, $$;
  my $fn2 = '';
  
  while ($fn =~ s/^(.....)//) {
    my $T = hex($1);
    $fn2 .= $random_ticket_chars[$T>>15].
            $random_ticket_chars[($T>>10)&31].
            $random_ticket_chars[($T>>5)&31].
            $random_ticket_chars[$T&31];
  }
  
  return $fn2;
}

# assuming a ticket generated above the top-level directory cycles
# every 4.5 hrs, 2nd level every 4.5 minutes, extra character means
# that there will be 64 directories created in any period...
# on average there will be approximately 25,000 directories around at
# any one time (or 400 if we drop the 3rd slash...)
sub temp_file_name {
  my ($self, $extn, $template) = @_;
  
  $template ||= 'XXX/X/X/XXXXXXXXXXXXXXX';
  return $self->templatize($self->ticket, $template) . ($extn ? ".$extn" : ''); # Creates a random filename
}

# Creates a writeable directory - making sure all parents exist
sub make_directory {
  my ($self, $path) = @_;
  
  my ($volume, $dir_path, $file) = splitpath($path);
  mkpath($dir_path, 0, 0777);
  return ($dir_path, $file);
}

# Creates a temporary file name and makes sure its parent directory exists
sub temp_file_create {
  my $self = shift;
  
  my $FN = $self->temp_file_name(@_);
  (my $path = $FN) =~ s/\/[^\/]*$//;
  mkpath($self->species_defs->ENSEMBL_TMP_DIR . '/' . $path, 0, 0777);
  return $FN;
}

# Takes a string, and a template pattern and returns the string with "/" from the template inserted...
sub templatize {
  my ($self, $ticket, $template) = @_;
  
  $template =~ s/\/+/\//g;
  $ticket   =~ s/[^A-Za-z!_]//g;
  
  my @P = split //, $template ;
  my $fn = '';
  
  foreach (split //, $ticket) {
    $_ ||= '_';
    
    my $P = shift @P;
    
    if ($P eq '/') {
      $fn .= '/';
      $P = shift @P;
    }
    
    $fn .= $_;
  }
  
  return $fn;
}

sub is_available {
  my ($self, $value) = @_;
  
  return 1 unless $self->{'availability'};
  return $value if $value =~ /^\d+$/; # Return value if number
  
  my @keys = split /\s+/, $value;
  
  foreach (@keys) {
    my $val = 0;
    $val ||= $self->{'availability'}{$_} for split /\|/;
    return 0 unless $val;
  }
  
  return 1;
}

sub jsonify {
  my ($self, $content) = @_;
  return to_json($content);
}

sub new_object {
  my ($self, $module, $api_object) = @_;
  my $data = $self->deepcopy($_[-1]) || {};
  $data->{'_object'} = $api_object;
  return $self->new_proxy('Object', $module, $data);
}

sub new_factory {
  my ($self, $module) = @_;
  my $data = $self->deepcopy($_[-1]) || {};
  $data->{'_feature_IDs'} = [];
  $data->{'_dataObjects'} = [];
  return $self->new_proxy('Factory', $module, $data);
}

sub new_proxy {
  my ($self, $type, $module, $data) = @_;
  my $class = "EnsEMBL::Web::${type}::$module";
  
  $data->{'_objecttype'} = $module;
  delete $data->{'_viewconfig'};
  
  if ($self->dynamic_use($class)) {
    return $class->new($data);
  } else {
    warn "COULD NOT USE OBJECT MODULE $class";
  }
}

sub deepcopy {
  my $self = shift;
  if (ref $_[0] eq 'HASH') {
    return { map( {$self->deepcopy($_)} %{$_[0]}) };
  } elsif (ref $_[0] eq 'ARRAY') {
    return [ map( {$self->deepcopy($_)} @{$_[0]}) ];
  }
  return $_[0];
}

1;
