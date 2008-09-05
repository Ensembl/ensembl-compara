package EnsEMBL::Web::Cache;

## This module overwrites several subroutines from Cache::Memcached
## to be able to track and monitor memcached statistics better
## this applies only when debug mode is on

use strict;
use warnings;
use Data::Dumper;
use EnsEMBL::Web::SpeciesDefs;
use base 'Cache::Memcached';
use fields qw(default_exptime levels);

sub new {
  my $class  = shift;
  my $caller = caller;
  my $species_defs = new EnsEMBL::Web::SpeciesDefs;
  my %memcached    = $species_defs->multiX('ENSEMBL_MEMCACHED');
  
  return undef
    unless %memcached;

  my $levels = $memcached{levels}
               || [qw(
                       PLUGGABLE_PATHS
                       STATIC_PAGES_CONTENT
                       WEBSITE_DB_DATA
                       USER_DB_DATA
                       TMP_IMAGES
                       AJAX_CONTENT
                       ORDERED_TREE
                  )];

  my %levels = map { $_ => 1 } @$levels;
     
  return undef if $caller->isa('EnsEMBL::Web::Apache::Handlers')
                  && !$levels{PLUGGABLE_PATHS};
  return undef if $caller->isa('EnsEMBL::Web::Apache::SendDecPage')
                  && !$levels{STATIC_PAGES_CONTENT};
  return undef if $caller->isa('EnsEMBL::Web::DBSQL::UserDBConnection')
                  && !$levels{USER_DB_DATA};
  return undef if $caller->isa('EnsEMBL::Web::DBSQL::WebDBConnection')
                  && !$levels{WEBSITE_DB_DATA};
  return undef if $caller->isa('EnsEMBL::Web::File::Driver::Memcached')
                  && !$levels{TMP_IMAGES};
  return undef if $caller->isa('EnsEMBL::Web::Apache::Image')
                  && !$levels{TMP_IMAGES};
  return undef if $caller->isa('EnsEMBL::Web::Magic')
                  && !$levels{AJAX_CONTENT};
  return undef if $caller->isa('EnsEMBL::Web::Configuration')
                  && !$levels{ORDERED_TREE};

  my %args = (
    servers         => $memcached{servers},
    debug           => $memcached{debug},
    default_exptime => $memcached{default_exptime},
    namespace       => $species_defs->ENSEMBL_BASE_URL,
    @,
  );

  my $default_exptime = delete $args{default_exptime};

  my $self = $class->SUPER::new(\%args);
  $self->enable_compress(0) unless $args{enable_compress};

  $self->{default_exptime} = $default_exptime;
  $self->{levels}          = \%levels;
  
  return $self;
}

sub levels :lvalue { $_[0]->{'levels'}; }

sub add_tags {
  my $self = shift;
  my $key  = shift;
  my @tags = @_;

  warn "EnsEMBL::Web::Cache->add_tags( $key, ".join(', ', @tags).')';

  my $sock = $self->get_sock($key);
  foreach my $tag (@tags) {
    my $cmd = "tag_add $tag $self->{namespace}$key\r\n";
    my $res = $self->_write_and_read($sock, $cmd);
    return 0 unless $res eq "TAG_STORED\r\n";
  }

  return 1;
}


##
## delete_by_tags(@tags)
## deletes all and only items which have ALL tags specified
##
sub delete_by_tags {
  my $self = shift;
  my @tags = (@_, $self->{namespace});
  my $sock = $self->get_sock($tags[0]);

#  if ($#tags) { ## if more than 1 tag
    my $cmd = 'tags_delete '.join(' ', @tags)."\r\n";
    my $res = $self->_write_and_read($sock, $cmd);
    if ($res =~ /^(\d+) ITEMS_DELETED/) {
      return $1;
    } else {
      return 0;
    }
#  } else { ## just 1 tag, better use tag_delete (faster)
#    my $cmd = 'tag_delete '.$tags[0]."\r\n";
#    my $res = $self->_write_and_read($sock, $cmd);
#    return $res eq "TAG_DELETED\r\n";
#  }
}

sub set {
  my $self = shift;
  my ($key, $value, $exptime, @tags) = @_;

  warn "EnsEMBL::Web::Cache->set($self->{namespace}$key)";
  
  $self->SUPER::set($key, $value, $exptime || $self->{default_exptime});
  $self->add_tags($key, $self->{namespace}, @tags);
}

sub get {
  my $self = shift;
  my $key  = shift;

  warn "EnsEMBL::Web::Cache->get($key)";
  
  return $self->SUPER::get($key);
}

sub delete {
  my $self = shift;
  my $key  = shift;

  warn "EnsEMBL::Web::Cache->delete($key)";

  return $self->SUPER::remove($key, @_);
}

*remove = \&delete;

1;