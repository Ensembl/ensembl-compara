# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.godatabase.org/dev
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::Handlers::StagOutHandler     - 

=head1 SYNOPSIS

  use GO::Handlers::StagOutHandler

=cut

=head1 DESCRIPTION

=head1 PUBLIC METHODS - 

=cut

# makes objects from parser events

package GO::Handlers::StagOutHandler;
use base qw(GO::Handlers::ObjHandler);
use GO::Handlers::DefHandler qw(lookup);
use FileHandle;
use Data::Stag;
use strict;

sub _valid_params { shift->SUPER::_valid_params, qw(w fh) }

sub writer {
    my $self = shift;
    $self->{_writer} = Data::Stag->getformathandler(shift) if @_;
    return $self->{_writer};
}


sub done {
    my $self = shift;
    $self->{_done} = shift if @_;
    return $self->{_done};
}


sub tblatts {
    ("gene_id int");
}

sub e_ontology {
    my $self = shift;
    my $g = $self->g;

    my $w = $self->writer;
    my @s = ();
    my $it = $g->create_iterator;
    my %done = ();

    $w->start_event("ontology");

    while (my $n = $it->next_node) {
        next if $done{$n->acc};
        $done{$n->acc} = 1;
        my $prels = $g->get_parent_relationships($n->acc);
        my @isa = 
          map {$g->get_term($_->acc1)} 
            grep {$_->type eq 'isa'} @$prels;
        @$prels = grep {$_->type ne 'isa'} @$prels;
        my @att = ();
        if ($n->definition) {
            @att = (                              
                    [def=>$n->definition]
                   );
        }
        $w->event("class" => [
                              [name=>safe($n->name)],
                              [acc=>$n->acc],
                              @att,
                              (map {
                                  [subclassof=>$_->name]
                              } @isa),
                              (map {
                                  [restriction=>[
                                                 [property=>$_->type],
                                                 [to=>$g->get_term($_->acc1)->name],
###implicit                                                 [type=>'existential'],
                                                ]
                                  ]
                              } @$prels),
                             ]
                 );
    }

    $w->end_event("ontology");
}

sub mktblterm {
    my $self = shift;
    my $n = shift;
    my $g = $self->g;

    my @s = ();

    return if $self->done->{$n->name};
    $self->done->{$n->name} = 1;

    my $atts = join(", ", tblatts);

    my $kids = $g->get_child_terms($n->acc);
    foreach my $kid (@$kids) {
        $self->mktblterm($kid);
    }
    $self->name_by_acc->{$n->acc} = $n->name;
    my $name = $self->mapname($n->name);

    my @kidnames = map {$self->mapname($_->name)} @$kids;
    push(@s, "CREATE TABLE b_$name ($atts)");
    push(@s, 
         "CREATE VIEW $name AS" .
         join(" UNION ",
              map {
                  "\n  SELECT * FROM $_"
              } "b_$name", @kidnames));
    
    push(@s, "INSERT INTO tblmap VALUES (".
         quote($name).", ".
         quote($n->name).")");
    
    my $fh = $self->fh;
    for (my $i=0; $i<@s; $i++) {
        print $fh "$s[$i];\n";
    }
}

sub e_prod {
    my $self = shift;
    my $dbh = $self->apph->dbh;
    my $tree = shift;
#    print STDERR Dumper $tree;
    my $fh = $self->fh;
    my ($prodacc, $symbol, $full_name, $prodtaxa) =
      map {
	lookup($tree, $_) || ""
       } 
        qw(prodacc prodsymbol prodname prodtaxa);
    my $gid = ++$self->{_nextgeneid};
    printf $fh
      "INSERT INTO gene VALUES (%d, %s, %s);\n",
        $gid,
          quote($symbol),
            quote($prodacc);

    my @assocs = lookup($tree, "assoc");
    foreach my $assoc (@assocs) {
        my $acc = lookup($assoc, "termacc");
        if (!$acc) {
            $self->message({msg=>"no termacc"});
            next;
        }
        my $name = $self->name_by_acc->{$acc};
        next unless $name;
        my $tbl = $self->{_tblmap}->{$name};
        printf $fh
          "INSERT INTO b_$tbl VALUES ($gid);\n";
    } 
}

sub name_by_acc {
    my $self = shift;
    $self->{_name_by_acc} = shift if @_;
    return $self->{_name_by_acc};
}


sub mapname {
    my $self = shift;
    my $n = shift;
    return $self->{_tblmap}->{$n} if  $self->{_tblmap}->{$n};
    my $mn = safe($n);
    if (length($mn) > 30) {
        $mn = "anon" . $self->{_nextid}++;
    }
    $self->{_tblmap}->{$n} = $mn;
    return $mn;
}

sub safe {
    my $word = shift;
    $word =~ s/ /_/g;
    $word =~ s/\-/_/g;
    $word =~ s/\'/prime/g;
    $word =~ tr/a-zA-Z0-9_//cd;
    $word =~ s/^([0-9])/_$1/;
    $word;
}

sub quote {
    my $word = shift;
    $word =~ s/\'//g;
    "'$word'";
}


1;
