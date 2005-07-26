# makes objects from parser events

package GO::Handlers::PgStoreHandler;
use GO::SqlWrapper qw (:all);
use base qw(GO::DefHandler);

use strict;

sub _valid_params { qw(apph) }

sub g {
    my $self = shift;
}

# flattens tree to a hash;
# only top level, not recursive
sub t2fh {
    my $tree = shift;
    return $tree if !ref($tree) || ref($tree) eq "HASH";
    my $h = {map { @$_ } @$tree};
    return $h;
}

sub e_ontology {
    my $self = shift;

}

sub e_term {
    my $self = shift;
    my $tree = shift;
    my %h = ();

    # turn single valued params (terminals)
    # into a hash - these are attributes of
    # current relation;
    # keep the remainder
    my @left =
      grep {
          my($k,$v)=@$_;
          if (ref($v)) {
              1;
          }
          else {
              $h{$k} = $v;
              0;
          }
      } @$tree;
    $h{term_type} = $self->{ontology_type} || die;
    my $id =
      $self->store("term", \%h);
    $self->{term_id} = $id;
    map {
        $self->r("term", $_);
    } @left;
    $id;
}

sub r {
    my $self = shift;
    my ($tree) = @_;
    use Data::Dumper;
    print STDERR Dumper $tree;
}

sub e_xref {
    my $self = shift;
    my $tree = shift;
    $self->store("xref", $tree);
}

sub e_synonym {
    my $self = shift;
    my $syn = shift;
    $self->storelink("term_synonym",
                     {term_synonym=>$syn});
}

sub storelink {
    my $self = shift;
    my $tbl = shift;
    my $tree = shift;
    my $dbh = $self->apph->dbh;
    my $h = t2fh($tree);
    insert_h($dbh,
             $tbl,
             {%$h, "term_id"=>$self->{term_id}});
}


sub store {
    my $self = shift;
    my $tbl = shift;
    my $tree = shift;
    my $dbh = $self->apph->dbh;
    my $h =
      select_hash($dbh,
                  $tbl,
                  t2fh($tree));
#    my $pk = $tbl."_id";
    my $pk = "id";
    my $id;
    if ($h) {
        $id = $h->{$pk}; pe
    }
    else {
        $id =
          insert_h($dbh,
                   $tbl,
                   t2fh($tree));
    }
    $id or die $pk;
    $id;
}

1;
