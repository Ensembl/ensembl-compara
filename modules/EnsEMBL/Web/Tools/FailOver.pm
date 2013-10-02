package EnsEMBL::Web::Tools::FailOver;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use EnsEMBL::Web::Tools::FileHandler;

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

sub endpoint_log {
  my ($self,$endpoint,$msg,$debug) = @_;

  return if $debug and not $self->debug;
  warn $self->{'prefix'}.": $endpoint : $msg\n";
}

sub go {
  my ($self,$payload) = @_;

  my $endpoints = $self->endpoints;
  $self->endpoint_log("ALL","got ".scalar(@$endpoints)." endpoints",1);
  foreach my $endpoint (@$endpoints) {
    $self->endpoint_log($endpoint,"Attempting $endpoint",1);
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
    return $out if($success);
    if($self->liveness_check($endpoint)) {
      # Is alive, probably just a daft query: rerun without timeout.
      $self->endpoint_log($endpoint,"Retrying as server seems up. Wish me luck!");
      return $self->attempt($endpoint,$payload,1);
    }
    $self->endpoint_log($endpoint,"Marking as dead");
    $self->is_dead($endpoint,1);
  }
  return undef;
}

1;
