package EnsEMBL::Web::QueryStore::Cache;

use strict;
use warnings;

use JSON;
use Digest::MD5 qw(md5_base64);

my $DEBUG = 0;
my $CODE_BOOK = undef;

sub _class_key {
  my ($self,$class) = @_;

  my $key = md5_base64($class);
  $key =~ s#/#_#g; # For filenames
  return $key;
}

sub _remove_undef {
  my ($self,$obj) = @_;

  if(ref($obj) eq 'HASH') {
    foreach my $k (keys %$obj) {
      if(defined $obj->{$k}) {
        $self->_remove_undef($obj->{$k});
      } else {
        delete $obj->{$k};
      }
    }
  } elsif(ref($obj) eq 'ARRAY') {
    $self->_remove_undef($_) for @$obj;
  }
}

sub _key {
  my ($self,$args,$class) = @_; 

  $args = {%$args};
  $self->_remove_undef($args->{'args'});
  my $json = JSON->new->canonical(1)->encode($args);
  warn "$json\n" if $DEBUG > 1;
  my $key = md5_base64($json);
  if($class) {
    $key .= ".".$self->_class_key($class);
  }
  warn "$key\n" if $DEBUG > 1;
  $key =~ s#/#_#g; # For filenames
  if($CODE_BOOK) { # For debugging
    open(CODE,'>>',$CODE_BOOK);
    print CODE "$json -> $key\n";
    close CODE;
  }
  return $key;
}

sub cache_close {}
sub cache_open {}

1;
