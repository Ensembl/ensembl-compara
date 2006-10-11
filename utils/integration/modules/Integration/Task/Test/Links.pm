package Integration::Task::Test::Links;

use strict;
use warnings;

use LWP::Simple;
use HTML::LinkExtor; 

use Integration::Task::Test;
our @ISA = qw(Integration::Task::Test);

{

my %Proxy_of;
my %List_of;
my %Cache_of;
my %Base_of;

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $Proxy_of{$self} = defined $params{proxy} ? $params{proxy} : "";
  $List_of{$self} = defined $params{list} ? $params{list} : "";
  $Cache_of{$self} = defined $params{cache} ? $params{cache} : [];
  $Base_of{$self} = defined $params{base} ? $params{base} : "head.ensembl.org";
  return $self;
}

sub process {
  ### Finds and returns a list of broken links 
  my $self = shift;
  open (my $fh, ">", $self->list);  
  print $fh "> " . $self->target . "\n";
  $self->check_links($self->target, $fh);
  foreach my $entry (@{ $self->cache }) {
    #print $fh $entry->{parent} . " -> " .$entry->{url} . ": " . $entry->{status} . "\n"; 
  }
  close $fh;
  return 1;
}

sub check_links {
  my ($self, $url, $fh) = @_;
  my $parser = HTML::LinkExtor->new(undef, $self->target);
  my $html = get($self->target);
  die "Can't fetch " . $self->target unless defined($html);
  $parser->parse($html);
  my @links = $parser->links;
  foreach my $link (@links) {
    my @element = @{ $link };
    my $element_type = shift @element;
    while (@element) {
      my ($key, $value) = splice(@element, 0, 2);
      if ($value->scheme =~ /\b(http)\b/) {
        if (head($value)) { 
          #if ($self->add_to_cache($url, $value, "OK")) {
          #  my $match = $self->base;
          #  if ($value !~ /\.[a-z]*$/ &&
          #      $value =~ /http:\/\/.*\/.*\/.*/ && 
          #      $value =~ /$match/) { 
          #   if ($value =~ /$match/) {
              #$self->check_links($value, $fh);
              print $fh "$value : OK\n";
          #  }
          #}
        } else {
          print $fh "$value : BAD\n";
          $self->add_to_cache($url, $value, "BAD");
          $self->add_error("Broken link from $url to $value");
        }
      }
    }
  }
}

sub add_to_cache {
  my ($self, $parent, $url, $status) = @_; 
  my $found = 0;
  my $return = 1;
  foreach my $entry (@{ $self->cache }) {
    if ($entry->{url} eq $url) {
      $found = 1;
      $return = 0;
      $entry->{status} = $status;
    }
  }
  if ($found == 0) {
    push @{ $self->cache }, { parent => $parent, url => $url, status => $status };
    $return = 1;
  }
  return $return;
}

sub proxy {
  ### a
  my $self = shift;
  $Proxy_of{$self} = shift if @_;
  return $Proxy_of{$self};
}

sub list {
  ### a
  my $self = shift;
  $List_of{$self} = shift if @_;
  return $List_of{$self};
}

sub cache {
  ### a
  my $self = shift;
  $Cache_of{$self} = shift if @_;
  return $Cache_of{$self};
}

sub base {
  ### a
  my $self = shift;
  $Base_of{$self} = shift if @_;
  return $Base_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $Proxy_of{$self};
  delete $List_of{$self};
  delete $Cache_of{$self};
  delete $Base_of{$self};
}

}

1;
