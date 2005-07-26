# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#!/usr/bin/perl -w
package GO::Browser::Parents;

use lib '.';
use strict;
use Carp;
use Exporter;
use FreezeThaw qw(thaw freeze);
use GO::AppHandle;
use GO::MiscUtils qw(dd);
# Get args
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

#$0 =~ /^(.*\/|)([^\/]*)/;
#my ($progdir, $progname) = ($1, $2);

#my $reset;
#while (@ARGV && $ARGV[0] =~ /^-/) {
#    my $opt = shift;
#}

sub new {
  my $class = shift;
  my $dbh = shift;
  my $self = {};
  $self->{dbh} = $dbh;
  $self->{topelement} = 3673;
  $self->{parents} = ();
  bless $self, $class;
  return $self;
}
  
sub _not_at_top {
  my $self = shift;
  my $parents_a = shift;
  my $parent_a;

  foreach $parent_a (@$parents_a) {
    if (! defined @$parent_a[0]) {
      return 0;
    } elsif ( %{@$parent_a[0]}->{acc} != $self->{topelement} ) {
      return 1;
    }
  }
  return 0;
}


sub set_parents {
  my $self = shift;
  my $acc = shift;
  my $parent_a;

  my $parent_accs =
    $self->{dbh}->get_relationships({acc2 => $acc});

  foreach my $par (@{$parent_accs}) {
    push my @my_array, $self->{dbh}->get_term({acc => $par->{acc1}});
    unshift @{$self->{parents}}, \@my_array;
  }

  while ($self->_not_at_top($self->{parents})) {
    foreach $parent_a (@{$self->{parents}}) {
      if (%{@$parent_a[0]}->{acc} != $self->{topelement}) {
	my $parentparents = 
	  $self->{dbh}->get_relationships({acc2 => %{@$parent_a[0]}->{acc}});
	my $counter = 0;
	foreach my $parent (@$parentparents) {
	  if ($counter == 0) {
	    unshift @$parent_a,  $self->{dbh}->get_term({acc => $parent->{acc1}});
	    ++$counter ;
	  } else {
	    unshift @{$self->{parents}}, thaw freeze $parent_a;
	    unshift @{$self->{parents}->[0]}, 
	      $self->{dbh}->get_term({acc => $parent->{acc1}});
	  }
	}
      }
    }
  }
  return $self->{parents};
}

sub get_parents {
  my $self=shift;
  return $self;
}


1;
