=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Tools::FailOver;

use strict;
use warnings;

use EnsEMBL::Web::Utils::Syslog qw(syslog);
use Digest::MD5 qw(md5_hex);
use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents file_put_contents);

sub new {
  my ($proto,$prefix) = @_;

  my $class = ref($proto) || $proto;
  my $self = { prefix => $prefix };
  bless $self,$class;
  return $self;
}

# Defined in subclasses to check an endpoint is alive
# Usage: $self->liveness_check($endpoint).
# Returns: 1 = yes, 0 = no
sub liveness_check { die "Must override alive"; }

# seconds to continue to cautiously test for deadness after initial reports
sub min_initial_dead { return 20; }

# seconds between which to report your upness, for confidence in syslog
sub report_up { return 3600; }

# Which directory to store failure files in?
sub failure_dir { return "/tmp"; }

# seconds to assume failed after initial uncertainy before checking again
sub fail_for { return 600; }

# Defined in subclasses
# return arrayref of endpoints to try
sub endpoints { die "Must override endpoints"; }

# Defined in subclasses to attempt at one endpoint
# Usage: $self->attempt($endpoint,$payload,$tryhard)
# payload: as passed to ->go
# tryhard: we've tried already, then tested server and it seems fine, will
#           not attempt other endpoints after this as it looks like
#           suspicios data. Last chance.
# Returns: result, success evaluated by was_successful
sub attempt { die "Must override attempt"; }

# Does return value indicate success?
sub successful { return defined $_[1]; }

sub debug { return 0; }

# 1 = Yes, 0 = No, -1 = Don't know
sub is_dead {
  my ($self,$endpoint,$set) = @_;

  my $failbase = $self->failure_dir;
  return 0 unless $failbase;
  my $timeout = $self->fail_for;
  my $now = time;
  my $filename = $failbase."/".$self->{'prefix'}."-".md5_hex($endpoint);
  my ($noticed,$expiry) = ($now,-1);
  if(-e $filename) {
    eval { 
      my $contents = join("",file_get_contents($filename));
      my ($n,$e,$end) = split(/ /,$contents);
      ($noticed,$expiry) = ($n,$e) if defined($end) and $end eq 'END';
    };
  }
  if($set) {
    file_put_contents($filename,join(" ",$noticed,$now+$timeout,"END"));
    return 1;
  } else {
    return 0 unless -e $filename;
    return -1 if $expiry == -1;
    return -1 if $noticed + $self->min_initial_dead > $now;
    if($expiry < $now) {
      unlink $filename;
      return -1;
    }
    return 1; 
  }
}

# Periodically report being alive. Override with return 0 if you don't
# want this.
sub report_life {
  my ($self,$endpoint) = @_;

  my $failbase = $self->failure_dir;
  return 0 unless $failbase;
  my $filename = $failbase."/.ok-".$self->{'prefix'}."-".md5_hex($endpoint);
  my $then = 0;
  if(-e $filename) {
    $then = join('',file_get_contents($filename));
  }
  my $now = time;
  if(!$then or $then + $self->report_up < $now) {
    file_put_contents($filename,$now);
    return 1;
  }
  return 0;
}

sub endpoint_log {
  my ($self,$endpoint,$msg,$debug) = @_;

  return if $debug and not $self->debug;
  syslog($self->{'prefix'}.": $endpoint : $msg");
}

sub go {
  my ($self,$payload) = @_;

  my $endpoints = $self->endpoints;
  $self->endpoint_log("ALL","got ".scalar(@$endpoints)." endpoints",1);
  my @early_endpoints = @$endpoints;
  my $last_endpoint = pop @early_endpoints;
  foreach my $endpoint (@early_endpoints) {
    $self->endpoint_log($endpoint,"Attempting",1);
    my $is_dead = $self->is_dead($endpoint);
    if($is_dead == 1) {
      $self->endpoint_log($endpoint,"Ignoring due to recent reports of deadness");
      next;
    } elsif($is_dead == -1) {
      $self->endpoint_log($endpoint,"Liveness status uncertain, checking");
      if($self->liveness_check($endpoint)) {
        $self->endpoint_log($endpoint,"Alive");
      } else {
        $self->endpoint_log($endpoint,"Dead");
        $self->is_dead($endpoint,1);
        next;
      }
    }
    my $out = $self->attempt($endpoint,$payload,0);
    my $success = $self->successful($out);
    $self->endpoint_log($endpoint,"successful = $success",1);
    if($success) {
      if($self->report_life($endpoint)) {
        $self->endpoint_log($endpoint,"still operational");
      }
      return $out;
    }
    if($self->liveness_check($endpoint)) {
      # Is alive, probably just a daft query: rerun without timeout.
      $self->endpoint_log($endpoint,"Retrying as server seems up. Wish me luck!");
      return $self->attempt($endpoint,$payload,1);
    }
    $self->endpoint_log($endpoint,"Marking as dead");
    $self->is_dead($endpoint,1);
  }
  $self->endpoint_log($last_endpoint,"Attempting (no fallback)",1);
  return $self->attempt($last_endpoint,$payload,1);
}

sub get_cached {
  my ($self,$payload) = @_;

  my $endpoints = $self->endpoints;
  $self->endpoint_log("ALL","checking ".scalar(@$endpoints)." endpoints",1);
  foreach my $endpoint (@$endpoints) {
    $self->endpoint_log($endpoint,"Considering",1);
    my $is_dead = $self->is_dead($endpoint);
    if($is_dead == 1) {
      $self->endpoint_log($endpoint,"Assuming dead due to recent reports",1);
      next;
    }
    if($is_dead == -1) {
      $self->endpoint_log($endpoint,"Liveness status uncertain");
    } else {
      $self->endpoint_log($endpoint,"No record of problems",1);
    }
    my $out = $self->attempt($endpoint,$payload);
    if($self->successful($out)) {
      if($is_dead == -1 || $self->report_life($endpoint)) {
        $self->endpoint_log($endpoint,"Looks alive");
      } else {
        $self->endpoint_log($endpoint,"Got good result",1);
      }
      return $out;
    }
    $self->endpoint_log($endpoint,"Looks dead");
    $self->is_dead($endpoint,1);
  }
  return undef;
}

1;

