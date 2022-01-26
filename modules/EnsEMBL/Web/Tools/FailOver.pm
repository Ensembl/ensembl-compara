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

=head1 FailOver

=head2 Introduction

The FailOver module is designed to handle potentially unreliable resources,
probably from remote servers, by providing a common framework for
remembering that a resource was unavialable for a period of time, and so
minimising the impact of potentially expensive checks.

You write a subclass containing your checks and configuration and when
you've done that, this superclass will provide you with a pair of methods
to try the unreliable operation. One method, ->go, is for more complex
situations, and ->get_cached for simpler ones. You will only need to use
one of the two.

=head2 Simpler Method (get_cached)

For the simpler method, first override ->attempt. The call will be passed
two arguments. The first, endpoint, will be the string "only", unless
you have had reason to change it, and can safely be ignored (see "Multiple
Endpoints" if you are curious). The second, payload, is a copy of the
argument to the call to get_cached. This method should perform the risky
operation and return its result.

Then override ->successful. This will be passed the result of an attempt
and should return true or false values depending on whether the result
"looks like" a success or not.

Now create an object using a prefix unique to your implementation (this
is just a string which means files for failovers can all be stored in
the same directory).

You can now call ->get_cached. On the first attempt it will call your
attempt, and then test if it was a success or not by calling ->successful
with the result. If successful, the value will be returned, otherwise
undef will be returned. On later attempts, if early attempts failed then
undef will always be returned for some period of time.

Example:

  package EnsEMBL::Web::Tools::FailOver::My;
  use base qw(EnsEMBL::Web::Tools::FailOver);

  sub attempt {
    my ($endpoint,$payload) = @_;
    # Say this method returns a positive number if it's ok
    return do_the_thing_that_might_fail($payload); 
  }

  sub successful { return $_[1] > 0; }

Now you can do:

  my $fail = EnsEMBL::Web::Tools::FailOver::My->new("example");
  $payload = ... data for do_the_thing_that_might_fail() ...
  my $out = $fail->get_cached($payload);

$out will be the result of the operation if everything is up. If something
goes down, suuccessful returns a false value, and $out is set to undef.
For some time, $out then continues to return undef without even calling
attempt.

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
sub liveness_check { die "Must override alive if using ->go rather than ->get_cached"; }

# seconds to continue to cautiously test for deadness after initial reports
sub min_initial_dead { return 20; }

# seconds between which to report your upness, for confidence in syslog
sub report_up { return 3600; }

# Which directory to store failure files in?
sub failure_dir { return "/tmp"; }

# Local overrides (should be local disk)
sub override_failure_dir { return "/tmp"; }

# seconds to assume failed after initial uncertainy before checking again
sub fail_for { return 600; }

# Defined in subclasses
# return arrayref of endpoints to try
sub endpoints { return ['only']; }

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

sub _force_filename {
  my ($self,$dir,$suffix) = @_;

  return sprintf("%s/%s-%s",$dir,$self->{'prefix'},$suffix);
}

sub _force {
  my ($self,$suffix) = @_;

  my $filename = $self->_force_filename($self->failure_dir,$suffix);
  my $ov_filename =
    $self->_force_filename($self->override_failure_dir,$suffix);
  return (-e $filename) || (-e $ov_filename);
}

# 1 = Yes, 0 = No, -1 = Don't know
sub is_dead {
  my ($self,$endpoint,$set) = @_;

  my $failbase = $self->failure_dir;
  my $override_failbase = $self->override_failure_dir;
  return 0 unless $failbase;
  return 0 if $self->_force('ISGOOD');
  return 1 if $self->_force('ISBAD');
  my $timeout = $self->fail_for;
  my $now = time;
  my $filename = $failbase."/".$self->{'prefix'}."-".md5_hex($endpoint);
  my ($noticed,$expiry) = ($now,-1);
  if(-e $filename) {
    eval { 
      my $contents = file_get_contents($filename);
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
    $then = file_get_contents($filename);
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

