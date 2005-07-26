# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Model::CrossProduct;

=head1 NAME

  GO::Model::CrossProduct;

=head1 SYNOPSIS

=head1 DESCRIPTION

for cross products - an intersection between another class/term and a
list of anonymous subclass over some restrictions

=cut


use Carp qw(cluck confess);
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use strict;
use vars qw(@ISA);

@ISA = qw(GO::Model::Root Exporter);


sub _valid_params {
    return qw(xp_acc parent_acc restriction_list);
}

sub get_restriction_values_for_property {
    my $self = shift;
    my $prop = shift;
    my @vals = 
      map {$_->value} grep {$_->property_name eq $prop} @{$self->restriction_list||[]};
    return \@vals;
}

sub add_restriction {
    my $self = shift;
    my $r = shift;
    if (!ref($r)) {
        $r = $self->apph->create_restriction_obj({property_name=>$r,
                                                  value=>shift});
    }
    my $rl = $self->restriction_list || [];
    $self->restriction_list([@$rl, $r]);
    
    $r;
}

sub all_parent_accs {
    my $self = shift;
    my $restrs = $self->restriction_list;
    return [
	    $self->parent_acc,
	    map { $_->value } @$restrs
	   ];
}

sub all_parent_relationships {
    my $self = shift;
    my $restrs = $self->restriction_list;
    my $xp_acc = $self->xp_acc;
    my @hashes =
      (
       {acc1=>$self->parent_acc,
	acc2=>$xp_acc,
	type=>'is_a'
       },
       map { 
	   ({
	     acc1=>$_->value,
	     acc2=>$xp_acc,
	     type=>$_->property_name
	    })
       } @$restrs
      );
      
    return [
	    map {
		$self->apph->create_relationship_obj($_)
	    } @hashes
	   ];
}

sub to_obo {
    my $self = shift;
    my $restrs = $self->restriction_list;
    return
      sprintf("cross_product: %s %s\n", 
              $self->parent_acc,
              join(' ',
                   map {sprintf("(%s %s)", 
                                $_->property_name, $_->value)} @$restrs));
              
    
}

sub equals {
    my $self = shift;
    my $xp = shift;
#    printf "TESTING FOR EQUALITY (%s):\n", $xp->xp_acc;
#    print $self->to_obo;
#    print $xp->to_obo;
    return 0 unless $self->parent_acc eq $xp->parent_acc;
    my @r1 = @{$self->restriction_list || []};
    my @r2 = @{$xp->restriction_list || []};
    return 0 unless scalar(@r1) == scalar(@r2);

    my @propnames = 
      map {$_->property_name} 
        @{$self->restriction_list||[]},
          @{$xp->restriction_list||[]};
    my %uniqpropnames = map{$_=>1} @propnames;
    
    my $ok = 1;
    foreach my $pn (keys %uniqpropnames) {
        
        my @vals1 =
          sort
            @{$self->get_restriction_values_for_property($pn)};
        my @vals2 =
          sort
            @{$xp->get_restriction_values_for_property($pn)};
        while (@vals1) {
            if (shift @vals1 ne shift @vals2) {
                $ok = 0;
            }
        }
        if (@vals2) {
            $ok = 0;
        }
        last unless $ok;
    }
    return $ok;
}


1;
