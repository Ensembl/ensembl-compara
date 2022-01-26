=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Root;

### NAME: EnsEMBL::Web::Root
### Base class for many EnsEMBL::Web objects

### PLUGGABLE: No

### STATUS: Stable

### DESCRIPTION
### This module contains a lot of generic functionality needed throughout 
### the web code: url construction, data formatting, etc.

use strict;

use File::Path            qw(mkpath);
use File::Spec::Functions qw(splitpath);
use List::MoreUtils       qw(first_index);
use HTML::Entities        qw(encode_entities);
use JSON                  qw(to_json);
use Text::Wrap;
use Time::HiRes           qw(gettimeofday);
use URI::Escape           qw(uri_escape uri_unescape);
use Apache2::RequestUtil;

use parent qw(EnsEMBL::Root);

sub filters :lvalue { $_[0]->{'filters'}; }

# NOTE: The static_server and img_url functions assume $self->hub exists. If it doesn't, don't use these functions.
sub static_server { return ($_[0]->hub->species_defs->ENSEMBL_STATIC_SERVER || '') =~ s/^http://r; }
sub img_url       { return $_[0]->hub->species_defs->img_url =~ s/^http://r; }

sub url {
### Assembles a valid URL, adding the site's base URL and CGI-escaping any parameters
### returns a URL string
### This is a simple version, that can be extended in children as needed
# TODO: add site base url
  my ($self, $path, $param, $anchor) = @_;
  my $clean_params = $self->escape_url_parameters($param);
  return $self->reassemble_url($path, $clean_params, sprintf('%s', $anchor));
}

sub reassemble_url {
  my ($self, $path, $param, $anchor) = @_;
  if ($param) {
    $path .= $path =~ /\?/ ? ';' : '?';
    $path .= (join ';', @$param);
  }
  $path .= qq(#$anchor) if defined $anchor && $anchor ne '';
  return $path;
}

sub escape_url_parameters {
  my ($self, $param) = @_;
  my $clean_params;
  
  while (my ($k, $v) = each (%$param)) {
    if (ref $v eq 'ARRAY') {
      push @$clean_params, "$k=" . uri_escape($_) for @$v;
    } else {
      push @$clean_params, "$k=" . uri_escape($v);
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

sub requesting_country {
  my $self = shift;
  my $sd = $self->hub->species_defs;

  my $geocity_dat_file = $sd->GEOCITY_DAT;
  return unless ( $geocity_dat_file && -e $geocity_dat_file );

  my $r    = Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $ip = $r->headers_in->{'X-Forwarded-For'} || $r->connection->remote_ip;
  my ($record, $geo);

  eval {
          require Geo::IP;
          $geo = Geo::IP->open( $geocity_dat_file, 'GEOIP_MEMORY_CACHE' );
          $record = $geo->record_by_addr($ip) if $geo;
  };
  warn $@ if $@;
  return unless $record;

  return $record->country_code;
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

sub get_module_names {
  my ($self, $type, $arg1, $arg2) = @_;
  my @packages = $self->can('species_defs') ? (grep(/::/, @{$self->species_defs->ENSEMBL_PLUGINS}), 'EnsEMBL::Web') : ('EnsEMBL::Web');
  my @return;
  
  ### Check for all possible module permutations
  my @modules = ("::${type}::$arg1");
  push @modules, "::${type}::$arg2", "::${type}::${arg1}::$arg2", "::${type}::${arg2}::$arg1" if $arg2;
  
  foreach my $module_root (@packages) {
    my $module_name = [ map { $self->dynamic_use("$module_root$_") ? "$module_root$_" : () } @modules ]->[-1];
    
    if ($module_name && $module_name->can('new')) {      
      push @return, $module_name;
      last unless wantarray;
    } else {
      my $error = $self->dynamic_use_failure("$module_root$modules[-1]");
      warn $error unless $error =~ /^Can't locate/;
      $@ = undef;
    }
  }
  
  return wantarray ? @return : $return[0];
}

sub strip_HTML {
  my ($self, $string) = @_;
  $string =~ s/<[^>]+>//g;
  return $string;
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

  my @long_months  = ('', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');
  my @short_months = map { substr $_, 0, 3 } @long_months;
 
  my ($year, $mon, $day, $hour, $min, $sec);
  
  if ($datetime =~ / /) {
    my ($date, $time)   = split ' |T', $datetime;
    ($year, $mon, $day) = split '-',   $date;
    ($hour, $min, $sec) = split ':',   $time;
  } elsif ($datetime =~ /\-/) {
    ($year, $mon, $day) = split '-', $datetime;
  } elsif ($datetime =~ /[a-zA-Z]{3}[0-9]{4}/) {
    my $mname = substr $datetime, 0, 3;
       $mon   = first_index { $_ eq $mname } @short_months; 
       $year  = substr $datetime, 3, 4;
  } elsif ($datetime =~ /^\d+$/) {
    ($sec, $min, $hour, $day, $mon, $year) = localtime($datetime);
    $mon++;
    $year += 1900;
  }
  
  return '-' unless $year > 0;

  $day =~ s/^0//;
  
  if ($format && $format eq 'simple_datetime') {
    return sprintf '%02d/%02d/%s at %02d:%02d', $day, $mon, substr($year, 2, 2), $hour, $min;
  } elsif ($format && $format eq 'short') {
    return "$short_months[$mon] $year";
  } elsif ($format && $format eq 'daymon') {
    return "$long_months[$mon] $day";
  } else {
    return join ' ', grep $_, $day, $long_months[$mon], $year;
  }
}

# Splits camelcase "words" into a space-separated string
sub decamel {
  my ($self, $camel) = @_;
  my @words = $camel =~ /([A-Z][a-z]*)/g;
  my $string = join(' ', @words);
  return $string;
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
# TODO - check if this is actually used anywhere
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

sub new_bio_object {
## Create a simple wrapper around an API object 
## (or a generic wrapper if not implemented)
  my ($self, $type, $api_object, $hub) = @_;
  my $class = 'EnsEMBL::Web::Data::Bio::'.$type;
  if (!$self->dynamic_use($class)) {
    require EnsEMBL::Web::Data::Bio;
    return EnsEMBL::Web::Data::Bio->new($hub, $api_object);
  }
  else {
    return $class->new($hub, $api_object);
  }
}

sub new_object {
  my ($self, $module, $api_object) = @_;
  my $data = $self->deepcopy($_[-1]) || {};
  $data->{'_object'} = $api_object;
  return $self->new_module('Object', $module, $data);
}

sub new_factory {
  my ($self, $module) = @_;
  my $data = $self->deepcopy($_[-1]) || {};
  $data->{'_feature_IDs'} = [];
  $data->{'_dataObjects'} ||= {};
  return $self->new_module('Factory', $module, $data);
}

sub new_module {
  my ($self, $type, $module, $data) = @_;
  my $class = "EnsEMBL::Web::${type}::$module";
  
  $data->{'_objecttype'} = $module;
  delete $data->{'viewconfig'};
  
  if ($self->dynamic_use($class)) {
    return $class->new($data);
  } else {
    #warn "COULD NOT USE OBJECT MODULE $class";
    return undef;
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
