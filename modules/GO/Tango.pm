# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Tango;

=head1 NAME

  GO::Tango - Tango ANnotates GO

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

THIS IS ALPHA CODE; API SUBJECT TO CHANGE

=head1 CREDITS

=head1 PUBLIC METHODS


=cut


use strict;
use base qw(GO::Model::Root);
use GO::Utils qw(rearrange);
use GO::IO::Blast;
use GO::SqlWrapper qw(:all);
use Carp;

sub _valid_params { qw(apph) };


=head2 new

  Usage   - $tango = GO::Tango->new({apph=>$apph})
  Returns - GO::Tango
  Args    -

=cut



=head2 xrefs_to_terms

  Usage   - $terms = $tango->xrefs_to_terms([$xref1, $xref2])
  OR      - $terms =
               $tango->xrefs_to_terms(-dbname=>"interpro",
                                      -xrefs=>["IPR00001", "IPR000002"])
  OR      - $terms =
               $tango->xrefs_to_terms(["interpro:IPR000001", "interpro:IPR000001"]);
  Usage   - $terms = $tango->xrefs_to_terms([$xref1, $xref2])
  Usage   - $terms = $tango->xrefs_to_terms([$xref1, $xref2])
  Returns - GO::Model::Term listref
  Args    - GO::Model::Xref list

=cut

sub xrefs_to_terms {
    my $self = shift;
    my ($inxrefs, $dbname, $include) =
      rearrange([qw(xrefs dbname include)], @_);

    my $apph =
      $self->apph || confess;

    my @xrefs =
      map {
          if (ref($_)) {
              if (UNIVERSAL::isa($_, "GO::Model::Xref")) {
                  $_;
              }
              else {
                  GO::Model::Xref->new($_);
              }
          }
          else {
              if ($dbname) {
                  GO::Model::Xref->new({xref_key=>$_,
                                        xref_dbname=>$dbname});
              }
              else {
                  if (/(\S+)\:(\S+)/) {
                      GO::Model::Xref->new({xref_key=>$2,
                                            xref_dbname=>$1});
                  }
                  else {
                      GO::Model::Xref->new({xref_key=>$_,
                                            xref_dbname=>"interpro"});
                  }
              }
          }
      } @$inxrefs;

    # DEFAULT STRATEGY -
    # inclusive approach, promote anything that matches

    if (@xrefs) {
        if (1 || $include) {
            my $dbh = $apph->dbh;
            my @q = ();
            foreach my $x (@xrefs) {
                my $z = sql_quote($x->{xref_dbname});
                push(@q, 
                     "(dbxref.xref_dbname = ".sql_quote($x->{xref_dbname}).
                     " AND ".
                     "dbxref.xref_key = ".sql_quote($x->{xref_key}).")"
                     );
            }
            my $hl =
              select_hashlist($dbh,
                              ["term", "dbxref", "term_dbxref"],
                              ["term.id = term_dbxref.term_id",
                               "dbxref.id = term_dbxref.dbxref_id",
                               "(".join(" OR ", @q).")",
                              ],
                              ["term.*", 
                               "dbxref.xref_key",
                               "dbxref.xref_dbname"]);
            my %byid=();
            my %xref = ();
            foreach my $h (@$hl) {
                my $xref =
                  $apph->create_xref_obj({xref_key=>$h->{xref_key},
                                          xref_dbname=>$h->{xref_dbname}});
                delete $h->{xref_key};
                delete $h->{xref_dbname};
                my $t = $byid{$h->{id}};
                if (!$t) {
                    $t = $apph->create_term_obj($h);
                    $byid{$t->id} = $t;
                    $t->dbxref_list([]);
                }
                $t->add_dbxref($xref);
            }
            return [values %byid];
            
        }
        else {
            my $terms =
              $apph->get_terms({dbxrefs=>\@xrefs});
            return $terms;
        }
    }
    else {
        return [];
    }
}


=head2 evaluate_guess

  Usage   -
  Returns -
  Args    -

=cut

sub evaluate_guess {
    my $self = shift;
    my ($guessh, $actualh) =
      rearrange([qw(guess actual)], @_);

    # get exact hits
    my $exact = 0;
    foreach my $k (keys %$guessh) {
        $exact++ if $actualh->{$k};
    }

    # how good are the guesses
    my @gks = (keys %$guessh);
    my @aks = (keys %$actualh);

    my @matrix; # dist matrix of guess x actual
    for (my $i=0; $i<@gks; $i++) {
        for (my $j=0; $j<@aks; $j++) {
            my $dist =
              $self->apph->get_distance($gks[$i],
                                        $aks[$j],
                                        1);
            $matrix[$i][$j] = $dist;
        }
    }

    my $fp = 0;  # false +ve
    my $tp = 0;  # true +ve
    my $missed = 0; # actual nodes missed
    my $score = 0;
    my @fplist = ();
    my @missedlist = ();

    my $matrixstr = "";
    for (my $i=0; $i<@gks; $i++) {
        my $bsc=0;
        $matrixstr .= "    ";
        for (my $j=0; $j<@aks; $j++) {
            my $sc = dist2score($matrix[$i][$j]);
            $matrixstr .= sprintf("%1d", $sc);
            if (!defined($bsc) || $sc > $bsc) {
                $bsc = $sc;
            }
        }
        $matrixstr .= "\n";

        if ($bsc == 0) {
            $fp++;
            push(@fplist, $gks[$i]);
        }
        if ($bsc > 0) {
            $tp++;
            $score += $bsc;
        }
    }
    for (my $i=0; $i<@aks; $i++) {
        my $bsc=0;
        for (my $j=0; $j<@gks; $j++) {
            my $sc = dist2score($matrix[$j][$i]);
            if (!defined($bsc) || $sc > $bsc) {
                $bsc = $sc;
            }
        }
        # treat all hits in the same recursive path the same
        if ($bsc == 0) {
            $missed++;
            push(@missedlist, $aks[$i]);
        }
        if ($bsc > 0) {
            # we have this one already
        }
    }
    
    if (1) {
        for (my $i=0; $i<@gks; $i++) {
            print "COL $i = $gks[$i]\n";
        }
        for (my $j=0; $j<@aks; $j++) {
            print "ROW $j = $aks[$j]\n";
        }
        print "\n$matrixstr\n";
    }

    # NOTE:
    # beware of fp (false positive) score
    #
    # this makes the "closed world assumption"
    # ie that if GO doesn't make statement X then
    # statement X is false
    #
    # the closed world assumption is erroneous in
    # this case but there is no real way to get around it
    # as GO does not currently provide a way of saying
    # "geneA has functions A and B ONLY"
    my $scoreh =
      {exact=>$exact,
       fp=>$fp,
       fplist=>join(" ", @fplist),
       missedlist=>join(" ", @missedlist),
       tp=>$tp,
       missed=>$missed,
       score=>$score,
       guesses=>scalar(@gks),
       actual=>scalar(@aks),
#       pic=>$matrixstr,
      };
    if (@gks) {
        $scoreh->{overpredict} = int(($fp/scalar(@gks)) * 100);
    }
    if (@aks) {
        $scoreh->{underpredict} = int(($missed/scalar(@aks)) * 100);
    }
    return $scoreh;
}

sub dist2score {
    my $dist = shift;
    my $score;
    if ($dist == -1) {
        $score = 0;
    }
    if ($dist == 0) {
        $score = 2;
    }
    if ($dist > 0) {
        $score = 1;
    }
    return $score;
}

sub prodcache {
    my $self = shift;
    $self->{_prodcache} = shift if @_;
    return $self->{_prodcache};
}

sub setuppc {
    my $self = shift;
    my $apph = $self->apph;
    my $pl =
      $apph->get_deep_products({term=>3674},
                               {seq_list=>'y'});
#    my $pl =
 #     $apph->get_products({},
  #                        {seq_list=>'y'});
    my @pp = ();
    my @pi= ();
    map {$pi[$_->id]=$_ ; $pp[$_->id] = {} } @$pl;
    my $dbh = $self->apph->dbh;
    # delibretely unclude IEAs
    # we want the control set to be as conservataive as possible
#    my $hl =
#      select_hashlist($dbh,
#                      ["association",
#                       "graph_path",
#                       "term",
#                       ],
#                      ["association.term_id = graph_path.term2_id",
#                       "term1_id = term.id",
#                       "term.term_type = 'function'",
#                       "gene_product_id in (".join(",", map {$_->id} @$pl).")",
#                       ],
#                      ["gene_product_id",
#                       "graph_path.term1_id AS parentid",
#                      ],
#                      );
#    printf STDERR "ROWS = %d\n", scalar(@$hl);
#    foreach my $h (@$hl) {
#        $pp[$h->{gene_product_id}]->{$h->{parentid}} = 1;
#    }
    my %domaincount = ();
    my %pdomaincount = ();

    printf STDERR "setting up domain counts for %d\n", scalar @$pl;

    foreach my $s ( grep {$_} map { $_->seq } @$pl ) {
        my @accs = map { $_->xref_key} @{$s->xref_list || []} ;
        # this gets all xrefs not just interpro
        map {$domaincount{$_}++} @accs;
        foreach my $x1 (@accs) {
            foreach my $x2 (@accs) {
                next if $x1 ge $x2;
                $pdomaincount{"$x1$x2"}++;
            }
        }
    }

    $self->prodcache({ids=>[map {$_->id} @$pl],
                      ind=>\@pi,
                      dc=>\%domaincount,
                      pdc=>\%pdomaincount,
                     });
#                      pp=>\@pp});
}

=head2 get_seq_xrefs_stats

  Usage   - $h = $apph->get_seq_xrefs_stats({term=>4888}, "InterPro");
  Returns - hashref
  Args    - constr [hash], dbname [str]

STATUS: ALPHA (subject to change)

returns a hashref keyed by accession nos with the count of each accession

eg the example query above will return a hash of interpro domain ids
with the total number of times that interpro domain occurs in all the
sequences of all products attached to or below transmembrane receptor

=cut

sub oldget_seq_xrefs_stats {
    my $self = shift;
    my $apph = $self->apph;
    my ($constr, $dbname, $neg) =
      rearrange([qw(constr dbname neg)], @_);

    my $termc = $constr->{term} || confess("term constraint only");

    my $pl =
      $apph->get_deep_products({term=>$termc, negoperator=>$neg}, {seq_list=>'y'});
    my @pl =
      grep {$_->seq} @$pl;
    my @accs =
      grep {
          lc($_->xref_dbname) eq lc($dbname)
      } map {
          @{$_->seq->xref_list || []};
      } @pl;
    my %h = ();
    map { $h{$_->xref_key}++ } @accs;
    return (\%h, \@pl);
}

sub get_seq_xrefs_stats {
    my $self = shift;
    my $apph = $self->apph;
    my ($pl, $dbname) =
      rearrange([qw(pl dbname)], @_);

    printf STDERR "Getting xref stats for %d prods [$dbname]\n", scalar @$pl;
    my @accs =
      grep {
          !$dbname || lc($_->xref_dbname) eq lc($dbname)
      } map {
          @{$_->seq->xref_list || []};
      } @$pl;
    my %h = ();
    map { $h{$_->xref_key}++ } @accs;
    return \%h;
}

sub get_paired_stats {
    my $self = shift;
    my $apph = $self->apph;
    my ($pl, $dbname) =
      rearrange([qw(pl dbname)], @_);

    printf STDERR "Getting paired stats for %d prods [$dbname]\n", scalar @$pl;
    my %h = ();
    my @accs = ();
    foreach my $p (@$pl) {
        if ($p->seq) {
            my @accs = 
              map {$_->xref_key}
                grep {!$dbname || lc($_->xref_dbname) eq lc($dbname)}
                  @{$p->seq->xref_list || []};
            foreach my $x1 (@accs) {
                foreach my $x2 (@accs) {
                    # only do diagonal;
                    # ensure ordering always the same
                    next if $x1 ge $x2;
                    $h{"$x1$x2"}++;
#                    print "PAIR $x1 $x2 = ".$h{"$x1$x2"}."\n";
                }
            }
        }
    }
    return \%h;
}


sub distinguish {
    my $self = shift;
    my ($term, $dbname) =
      rearrange([qw(term dbname)], @_);
    my $apph = $self->apph;
    my $dbh = $apph->dbh;

    $dbname = "interpro" unless defined($dbname);

    my %got = map { $_->xref_key => "*" } @{$term->dbxref_list || []};
    printf STDERR "CALCULATING FOR %s\n", $term->name;

    my @allids = @{$self->prodcache->{ids}};
    my @pi = @{$self->prodcache->{ind}};
    my %dc = %{$self->prodcache->{dc}};
    my %pdc = %{$self->prodcache->{pdc}};

    # find all products that could *POSSIBLY* be
    # annotated to term T
    # eg if annot(P, T2) and path(T, TI) and path(T2, TI)
    #
    # include IEAs for maxiumum conservatism (remember this is inverted!)

    my $tid = $term->id;

    # *actual* products annotated to T
    my $pl =
      $apph->get_deep_products({term=>$term}, {id=>'y'});
    my @pl =
      grep {$_ && $_->seq} map { $pi[$_->id] } @$pl;

    
    my @notpl = ();
    if (0) {
        my $hl =
          select_hashlist($dbh,
                          ["association",
                           "graph_path p1",
                           "graph_path p2",
                          ],
                          ["association.term_id = p1.term1_id",
                           "p1.term2_id = p2.term2_id",
                           "p2.term1_id = $tid",
                          ],
                          "distinct gene_product_id",
                         );
        printf "rows=%d\n", scalar @$hl;
        my %possh = map { $_->{gene_product_id} => 1 } @$hl;
        my @inv = 
          grep {
              !$possh{$_}
          } @allids;

        @notpl =
          grep {$_->seq} map { $pi[$_] } @inv;
    }

    my @rules = ();
    my %probh=();
    print "here we go....\n";
#    foreach my $neg ("yes", "no") {
    foreach my $neg ("yes") {
        my $pl = $neg eq "yes" ? \@pl : \@notpl;
        my $domainh =
          $self->get_seq_xrefs_stats($pl, $dbname);
        my $pdomainh =
          $self->get_paired_stats($pl, $dbname)
            if $neg eq "yes";
        my @k = sort {$domainh->{$b} <=> $domainh->{$a}} keys %$domainh;
        print STDERR "going through each key...\n";
        foreach my $k (@k) {
            print STDERR "    key=$k\n";
            next if $domainh->{$k} < 2;
            # bayes
            # p = (p(ipr|t) * p(t)) / p(ipr)
            my $prob =
              (($domainh->{$k} / scalar(@$pl)) * (scalar(@$pl) / scalar(@allids))) /
                ($dc{$k} / scalar(@allids));
            printf "$neg [$prob] %s $k $got{$k} $domainh->{$k} / %d\n", $term->name, scalar @$pl;
            if ($prob > 0.8 && $domainh->{$k} > 4) {
                push(@rules, $term->acc." $k $prob $domainh->{$k}/".(scalar @$pl));
            }
            $probh{$k} = $prob;
        }

        print STDERR "going through key pairs...\n";
        foreach my $k (@k) {
            next unless $neg eq "yes";
            print STDERR "    key1=$k\n";
            # combination D1 AND D2
            foreach my $k2 (@k) {
                next if $k ge $k2;
                next if $pdomainh->{"$k$k2"} < 2;
                my $pprob =
                  (($pdomainh->{"$k$k2"} / scalar(@$pl)) * 
                   (scalar(@$pl) / scalar(@allids))) /
                     ($pdc{"$k$k2"} / scalar(@allids));
                # dont bother unless combo gives us something
                # we cant get from individual
                # add 0.01 as floats are never equal
                next unless ($pprob > $probh{$k} +0.01);
                next unless ($pprob > $probh{$k2} +0.01);
                my $diff = $pprob -
                  ($probh{$k} < $probh{$k2} ? $probh{$k2} : $probh{$k});
                printf "$neg [$pprob] ($probh{$k} $probh{$k2}) ($diff) %s $k+$k2 $got{$k} $got{$k2} %d / %d\n", 
                  $term->name, 
                  $pdomainh->{"$k$k2"}, scalar @$pl;
                if ($pprob > 0.8 && $pdomainh->{"$k$k2"} > 3) {
                    push(@rules, 
                         sprintf("%s $k+$k2 $pprob %d/%d",
                                 $term->acc,
                                 $pdomainh->{"$k$k2"},
                                 scalar @$pl));
                }
            }
        }
    }
    return @rules;
}


=head1 FEEDBACK

Email cjm@fruitfly.berkeley.edu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself

=cut


1;


