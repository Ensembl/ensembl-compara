# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.godatabase.org/dev
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::Handlers::DbStoreHandler     - 

=head1 SYNOPSIS

  use GO::Handlers::DbStoreHandler

=cut

=head1 DESCRIPTION

=head1 PUBLIC METHODS - 

=cut

# makes objects from parser events

package GO::Handlers::DbStoreHandler;
use GO::SqlWrapper qw (:all);
use GO::Handlers::DefHandler;
use base qw(GO::Handlers::DefHandler);

use strict;
use Carp;
use Data::Dumper;
use Data::Stag qw(:all);

sub apph {
    my $self = shift;
    $self->{_apph} = shift if @_;
    return $self->{_apph};
}

sub placeholder_h {
    my $self = shift;
    $self->{_placeholder_h} = shift if @_;
    return $self->{_placeholder_h};
}

sub curr_acc {
    my $self = shift;
    $self->{_curr_acc} = shift if @_;
    return $self->{_curr_acc};
}

sub rels {
    my $self = shift;
    $self->{_rels} = shift if @_;
    return $self->{_rels};
}


sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    if (!defined($self->strictorder)) {
        $self->strictorder(1);
    }
    $self->curr_acc(0);
    $self->placeholder_h({});
    $self->rels([]);
}

sub id_h {
    my $self = shift;
    $self->{_id_h} = shift if @_;
    if (!$self->{_id_h}) {
	my $dbh = $self->apph->dbh;
	my $pairs =
	  select_rowlist($dbh,
			 "term",
			 undef,
			 "acc, id");
	$self->{_id_h} =
	  {map {@$_} @$pairs };

    }
    return $self->{_id_h};
}


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

sub make_or_find_term {
    my $self = shift;
    my $acc = shift;
    my $dbh = $self->apph->dbh;
    my $h =
      select_hash($dbh,
                  "term",
                  {acc=>$acc},
                  "id");
    return $h->{id} if $h;
    if ($self->strictorder) {
        $self->throw("No such term as $acc");
    }
    else {
        my $term_id =
          $self->insert("term",
                        {acc=>$acc},
                        "id");
        $self->id_h->{$acc} = $term_id;
        $self->placeholder_h->{$acc} = 1;
        return $term_id;
    }
}

sub e_ontology {
    my $self = shift;
    my $dbh = $self->apph->dbh;
#    printf STDERR "n rels:%d\n", scalar(@{$self->rels});
    my @terms_not_found = ();
    foreach my $r (@{$self->rels}) {
        my ($subj_id, $obj_id, $rid) =
          map {$self->id_h->{$_}} @$r;
        if (!$obj_id) {
            eval {
                $obj_id =
                  $self->make_or_find_term($r->[1]);
            };
            if ($@) {
                $self->message("term not found: $r->[1]");
                push(@terms_not_found, $r->[1]);
                next;
            }
        }
        my $stmt = "@$r";
        next if $self->id_h->{$stmt};
        my $h = select_hash($dbh,
                            "term2term",
                            {term2_id=>$subj_id,
                             term1_id=>$obj_id,
                             relationship_type_id=>$rid});
        if (!$h) {
            my $id =
              $self->insert("term2term",
                            {term2_id=>$subj_id,
                             term1_id=>$obj_id,
                             relationship_type_id=>$rid});
            $self->id_h->{$stmt} = $id;
        }
    }
    return [];
}

sub e_source {
    my $self = shift;
    my $tree = shift;
    my %insert = stag_pairs($tree);

    my $dbh = $self->apph->dbh;
    insert_h($dbh,
	     "source_audit",
	     \%insert);
    return [];
}

sub e_term {
    my $self = shift;
    my $tree = shift;

    my @kids = stag_kids($tree);

    my $dbh = $self->apph->dbh;

    my $t = time;

    my @isas = stag_get($tree, 'is_a');
    stag_unset($tree, 'is_a');

    my $acc = stag_get($tree, 'id') || die stag_xml($tree);
    $self->curr_acc($acc);

    my %h =
      (name => stag_sget($tree, "name"),
       term_type => stag_sget($tree, "term_type"),
       is_root => stag_sget($tree, "is_root"),
       is_obsolete => stag_sget($tree, "is_obsolete"),
       acc => $acc);

    my @xsyns = stag_get($tree, "synonym");
    my @syns = map {ref($_) ? stag_findval($tree, "synonymstr") : $_} @xsyns;
    stag_unset($tree, "synonym");

    if ($self->id_h->{$acc}) {
        if ($self->placeholder_h->{$acc}) {
            update_h($dbh,
                     "term",
                     \%h,
                     "acc=".sql_quote($acc));
            delete $self->placeholder_h->{$acc};
        }
        else {
            return;
        }
    }
    else {
        if (!$h{term_type}) {
            $h{term_type} = $self->{ontology_type} || "UNKNOWN";
        }
        my $id =
          $self->store("term", \%h, "id");
        $self->throw("no id for $acc") unless $id;
        $self->id_h->{$acc} = $id;
    }
    my $id = $self->id_h->{$self->curr_acc};
    sql_delete($dbh, "term_synonym", "term_id=$id");
    sql_delete($dbh, "term_dbxref", "term_id=$id");
    sql_delete($dbh, "term_audit", "term_id=$id");
    insert_h($dbh, "term_audit",
	     {term_id=>$id,
	      term_loadtime=>$t});
    $self->storetermlink($_)
      foreach stag_subnodes($tree);
    $self->storetermlink(Data::Stag->new(synonym=>$_)) foreach @syns;
    $self->storetermlink(Data::Stag->new(relationship=>[[type=>'is_a'],
							[to=>$_]])) foreach @isas;

    $self->apph->commit;
    return [];
}

sub e_typedef {
    return;
}

sub storetermlink {
    my $self = shift;
    my $tree = shift;
    my $id = $self->id_h->{$self->curr_acc};
    $id or $self->throw("no id for curr acc ".$self->curr_acc);
    my ($n, $v) = @$tree;
    $n =~ s/secondary.*id/synonym/;
    if ($n eq "dbxref") {
        my $dbxref_id =
          $self->store($n,
                       $v,
                       "id");
        $self->insert("term_dbxref",
                      {term_id=>$id,
                       dbxref_id=>$dbxref_id}
                        );
    }
    elsif ($n eq 'relationship') {
	my $to = stag_get($tree, "to");
	$to = stag_get($tree, "obj") unless $to;
	my $type = stag_get($tree, "type");
        $self->add_rel($self->curr_acc, 
                       $to, $type);
    }
    elsif ($n eq "synonym") {
	eval {
	    $self->insert("term_synonym",
			  {term_id=>$id,
			   term_synonym=>$v});
	};
	if ($@) {
#	    print STDERR $@;
	}
    }
    elsif ($n eq "") {
    }
}

sub store_dbxref {
    my $self = shift;
    my $dbxref = shift;
    my $id;
    if ($dbxref =~ /(\w+):?(\S+)/) {
	my @desc = ();
	my ($db, $acc) = ($1, $2);
	if ($db =~ /interpro/i) {
	    if ($acc =~ /(\S+)\s+(.*)/) {
		$acc = $1;
		@desc = (xref_desc => $2);
	    }
	}
        $id =
          $self->store("dbxref",
                       {xref_key=>$acc,
                        xref_dbname=>$db,
			@desc,
		       },
                       "id");
    }
    else {
    }
    return $id;
}

sub add_rel {
    my $self = shift;
    my ($s, $o, $r) = @_;

    # make a new term for the relationship type
    my $racc = "GO:$r";
    if (!$self->id_h->{$racc}) {
        my $id =
          $self->store("term", {acc=>$racc,
                                name=>$r,
                                term_type=>"relationship"},
                       "id");
        $self->id_h->{$racc} = $id;
        $self->apph->{rtype_by_id}->{$id} = $r;
    }
    push(@{$self->rels}, [$s, $o, $racc]);
    return;
}

sub insert {
    my $self = shift;
    my $dbh = $self->apph->dbh;
    insert_h($dbh,
             @_);
}

sub store {
    my $self = shift;
    my $tbl = shift;
    my $tree = shift;
    my $pk = shift;
    my $nostag_get = shift;

    my $dbh = $self->apph->dbh;
    my $selh = t2fh($tree);
    foreach my $k (keys %$selh) {
        delete $selh->{$k} if !defined($selh->{$k});
    }
    my $h;
    unless ($nostag_get) {
	$h =
	  select_hash($dbh,
		      $tbl,
		      $selh);
    }
    my $id;
    if ($h) {
        if ($pk) {
            $id = $h->{$pk};
        }
    }
    else {
        $id =
          insert_h($dbh,
                   $tbl,
                   t2fh($tree));
    }
    $id;
}

# end of definition
sub e_def {
    my $self = shift;
    my $tree = shift;
    my $dbh = $self->apph->dbh;
    my $acc = stag_get($tree, "godef-goid");
    my $term_id = $self->make_or_find_term($acc);
    my $def = stag_get($tree, "godef-definition");

    my $comment = stag_get($tree, "godef-comment");
    my $xref_id;
    my $dbxref = stag_get($tree, "godef-definition_reference");
    if ($dbxref) {
        $xref_id = $self->store_dbxref($dbxref);
    }

    sql_delete($dbh,
               "term_definition",
               "term_id=$term_id");
    sql_delete($dbh,
               "term_dbxref",
               "term_id=$term_id AND is_for_definition = 1");
    my @refs = stag_get($tree, "godef-definition_reference");
    foreach my $ref (@refs) {
	my $def_xref_id = $self->store_dbxref($ref);
	insert_h($dbh,
		 "term_dbxref",
		 {dbxref_id=>$def_xref_id,
		  term_id=>$term_id,
		  is_for_definition=>1});
    }
    insert_h($dbh,
             "term_definition",
             {term_definition=>$def,
              term_comment=>$comment,
              dbxref_id=>$xref_id,
              term_id=>$term_id});
    $self->apph->commit;
    return [];
}

sub e_termdbxref {
    my $self = shift;
    my $tree = shift;
    my $dbh = $self->apph->dbh;
    my $acc = stag_get($tree, "termacc");
    my $dbxref = stag_get($tree, "dbxref");
    my $xref_key = stag_get($dbxref, "xref_key");
    my $xref_dbname = stag_get($dbxref, "xref_dbname");
    my $dbxref_id =
      $self->store("dbxref",
                   {xref_key=>$xref_key,
                    xref_dbname=>$xref_dbname},
                   "id");
    eval {
	my $term_id = $self->make_or_find_term($acc);
	$self->store("term_dbxref",
		     {term_id=>$term_id,
		      dbxref_id=>$dbxref_id},
		    );
	$self->apph->commit;
    };
    if ($@) {
	$self->message("could not find term: $acc");
    }
    return [];
}

sub e_proddb {
    my $self = shift;
    $self->proddb(shift->data);
    return [];
}

sub e_prod {
    my $self = shift;
    my $dbh = $self->apph->dbh;
    my $tree = shift;
#    print STDERR Dumper $tree;
    my ($prodacc, $symbol, $full_name, $prodtaxa) =
      map {
	stag_get($tree, $_) || ""
       } qw(prodacc prodsymbol prodname prodtaxa);
#    print STDERR "prodtaxa = $prodtaxa\n";
    $prodtaxa =~ s/taxonid://i;
    $prodtaxa =~ s/taxon://i;
#    print STDERR "prodtaxa = $prodtaxa\n";
    my $xref_id =
      $self->store("dbxref",
                   {xref_key=>$prodacc,
                    xref_dbname=>$self->proddb},
                   "id");
#    print STDERR "xref_id = $xref_id\n";
    my $species_id =
      $self->store("species",
                   {ncbi_taxa_id=>$prodtaxa},
                   "id");
#    print STDERR "species_id = $species_id\n";
    my $prodh =
      select_hash($dbh,
		  "gene_product",
		  {dbxref_id=>$xref_id});

    my @syns = stag_get($tree, "prodsyn");

    my $prod_id;
    if ($prodh) {
	$prod_id = $prodh->{id};
	if ($prodh->{symbol} ne $symbol) {
	    push(@syns, $symbol);
	}
    }
    else {
	$prod_id =
	  insert_h($dbh,
		   "gene_product",
		   {symbol=>$symbol,
		    full_name=>$full_name,
		    dbxref_id=>$xref_id,
		    species_id=>$species_id,
		   });
    }
    foreach (@syns) {
	eval {
	    $self->store("gene_product_synonym",
			 {gene_product_id=>$prod_id,
			  product_synonym=>$_},
			 undef,
			 1);
	};
	if ($@) {
	    $self->message("Attempted to store duplicate synonym: $_ for $symbol $prodacc");
	}
    }
    my @assocs = stag_get($tree, "assoc");
    foreach my $assoc (@assocs) {
        my $acc = stag_get($assoc, "termacc");
        if (!$acc) {
            $self->message({msg=>"no termacc"});
            next;
        }
        my $term_id = $self->id_h->{$acc};
        if (!$term_id) {
            if (!defined($term_id)) {
                my $h =
                  select_hash($self->apph->dbh,
                              "term",
                              "acc=".sql_quote($acc));
                if (!$h) {
                    # check for obsolete ids
                    $h =
                      select_hash($self->apph->dbh,
                                  ["term","term_synonym"],
                                  ["term.id = term_synonym.term_id",
                                   "term_synonym=".sql_quote($acc)]);
                }
                # fetch from db;
                # cache result; a 0 means not present
                # undef means not searched for
                $term_id = $h ? $h->{id} : 0;
                $self->id_h->{$acc} = $term_id;
            }
        }
        if (!$term_id) {
            $self->message({msg=>"no term with acc $acc"});
            next;
        }
        my $is_not = stag_get($assoc, "is_not");
        my $source_db = stag_get($assoc, "source_db");
        my $assocdate = stag_get($assoc, "assocdate");
	my $source_db_id;
	if ($source_db) {
	    $source_db_id = 
	      $self->store("db",
			   {name=>$source_db},
			   "id");
	}
        if ($is_not) { $is_not = 1 }
        my $assoc_id =
          $self->store("association",
                       {term_id=>$term_id,
                        is_not=>$is_not,
			assocdate=>$assocdate,
			source_db_id=>$source_db_id,
                        gene_product_id=>$prod_id},
                       "id",
                       1);
        my @evs = stag_get($assoc, "evidence");
        foreach my $ev (@evs) {
            my $pubxref_id;
            my @seq_xrefs = stag_get($ev, "seq_acc"),
            my @refs = stag_get($ev, "ref");
            if (@refs) {
                my $ref = $refs[0];
		if ($ref =~ /(\S+?):(.*)/) {
		    $pubxref_id =
		      $self->store("dbxref",
				   {xref_key=>$2,
				    xref_dbname=>$1},
				   "id");
		}
            }
            my $code = stag_get($ev, "evcode");
            my $ev_id;
	    eval {
		$ev_id =
		  $self->store("evidence",
			       {association_id=>$assoc_id,
				code=>$code,
				dbxref_id=>$pubxref_id,
				seq_acc=>join('|',
					      @seq_xrefs),
			       },
			       "id",
			       1);
	    };
	    if ($@) {
		$self->message("Duplicate evidence $prodacc $acc ev=$code [ @seq_xrefs ]");
		next;
	    }
	    foreach (@seq_xrefs) {
		if (/(\S+?):(.*)/) {
		    my $id =
		    $self->store("dbxref",
				   {xref_key=>$2,
				    xref_dbname=>$1},
				   "id");
		    $self->store("evidence_dbxref",
				 {evidence_id=>$ev_id,
				  dbxref_id=>$id},
				 undef,
				 1);
		}
	    }
        }
    }
    $self->apph->commit;
 
#    print STDERR "********\nE_PROD:\n";
#    print STDERR Dumper $self->{node};
#    print STDERR "********\n";

    return;
}

1;
