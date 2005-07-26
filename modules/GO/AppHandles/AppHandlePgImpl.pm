# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::AppHandles::AppHandlePgImpl;

=head1 NAME

GO::AppHandles::AppHandlePgImpl

=head1 SYNOPSIS

you should never use this class directly. Use GO::AppHandle
(All the public methods calls are documented there)

=head1 DESCRIPTION

implementation of AppHandle for a GO postgres relational database

=head1 FEEDBACK

Email cjm@fruitfly.berkeley.edu

=cut

use strict;
use Carp;
use FileHandle;
use Carp;
use DBI;
use GO::Utils qw(rearrange pset2hash dd);
use GO::SqlWrapper qw(:all);
use GO::Model::Xref;
use GO::Model::Term;
use GO::Model::Association;
use GO::Model::GeneProduct;
use GO::Model::Relationship;
use GO::Model::Graph;
use Exporter;
use base qw(GO::AppHandleSqlImple);
use vars qw($AUTOLOAD $PATH);

$PATH="graph_path";

# should only be instantiated via GO::AppHandle
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my $init_h = shift;
    $self->dbh($self->get_handle($init_h));
    $self->filters({evcodes=>["!IEA"]});
    $self->dbms("Pg");
    $self->init;
    return $self;
}

sub init {
    my $self = shift;

    $self->{rtype_by_id} = {};
    my $hl =
      select_hashlist($dbh,
                      "relationship_type");
    foreach my $h (@$hl) {
        $self->{rtype_by_id}->{$h->{relationship_type_id}} = $h->{type_name};
    }
}


# private accessor: boolean indicating if DB has transactions
sub is_transactional {
    1;
}


# private method: makes the connection to the database
sub get_handle {
    my $self = shift;
    my $init_h = shift || {};
    $init_h->{dbms} = "Pg";
    return $self->SUPER::get_handle($init_h);
}

sub add_term {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($termh, $user) =
      rearrange([qw(term user)], @_);
    my @storep =
    ($term->name,
     $term->type,
     $term->acc,
     $term->is_obsolete,
     $term->is_root);
    return $term;
}

sub update_term {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($term, $user, $update_type) =
	rearrange([qw(term user create)], @_);

    my $mod_flag = $update_type =~ /create/;
    
    if ($term->definition) {
	$mod_flag |= $self->add_definition(
				    {definition=>$term->definition,
				     term_id=>$term->id},
				     undef,
				    $user);
    }
    map {
	$mod_flag |= $self->add_synonym (
				  {term_id=>$term->id},
				  $_,
				  $user);

    } @{$term->synonym_list || []};
    return $term;
}

sub check_term {
    my $self = shift;
    my $dbh = $self->dbh;
    my $termh = shift;
    my $h = 
      select_hash($dbh,
		  "term",
		  $termh,
		  "count(*) AS c");
    if ($h->{c} < 1) {
	return 0;
    }
    elsif ($h->{c} > 1) {
	return 0;
    }
    else {
	return 1;
    }
}

sub add_synonym {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($termh, $synonym, $user) =
      rearrange([qw(term synonym user)], @_);

    if ($synonym) {
	my $term_id = $termh->{term_id};
	if (!$term_id) {
	    my $term = $self->get_term($termh);
	    if (!$term) {
		warn("Can't add synonym for a term that doesn't exist yet!\n");
		return 0;
	    }
	    $term_id = $term->id;
	}
	my @constr_arr;
	push (@constr_arr, "term_id = $term_id");
	push (@constr_arr, "term_synonym = ".sql_quote($synonym));
	my $h =
	    select_hash($dbh,
			"term_synonym",
			\@constr_arr);
	if (!$h) {
	    insert_h($dbh,
		     "term_synonym",
		     {term_id=>$term_id,
		      term_synonym=>$synonym});
	    return 1;
	}
    }
    return 0;
}

# adds dbxref if not present;
# fills in id if it is present
sub add_dbxref {
    my $self = shift;
    my $xref = shift;
    my $update = shift;
    my $dbh = $self->dbh;

    my $h = 
      select_hash($dbh,
                  "dbxref",
                  {xref_key=>$xref->xref_key,
                   xref_dbname=>$xref->xref_dbname});
    my $updateh =
      {xref_key=>$xref->xref_key || "",
       xref_keytype=>$xref->xref_keytype || "acc",
       xref_dbname=>$xref->xref_dbname,
       xref_desc=>$xref->xref_desc,
      }; 
    my $id;
    if ($h) {
        $id = $h->{id};
        if ($update) {
            update_h($dbh,
                     "dbxref",
                     $updateh,
                     "id=$id");
        }
    }
    else {
        $id =
          insert_h($dbh,
                   "dbxref",
                   $updateh,
                  );
    }
    $xref->id ($id);
    $xref;
}

sub add_term_dbxref {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($term, $xrefh, $user) =
      rearrange([qw(term xref user)], @_);
    if (!$term->id) {
        confess("Can't add dbxref to a term that doesn't exist yet!");
    }
    my $xref = GO::Model::Xref->new($xrefh);
    $xref->xref_key || confess("must specify key for xref");

    $self->add_dbxref($xref, 1);

    my @constr_arr = ();
    push (@constr_arr, "term_id = ".$term->id);
    push (@constr_arr, "dbxref_id = ".$xref->id);
    my $t2x = select_hash($dbh,
			  "term_dbxref",
			  \@constr_arr);
    if (!$t2x) {
	insert_h($dbh,
		 "term_dbxref",
		 {term_id=>$term->id,
		  dbxref_id=>$xref->id});
    }
    return $xref;
}

#



sub add_relationship_type {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($type, $desc, $user) =
      rearrange([qw(type desc user)], @_);
    my $hl =
      select_hashlist($dbh,
                      "relationship_type",
                      "type_name=".sql_quote($type));
    my $id;
    if (@$hl) {
        if (@$hl>1) {
            confess("Assertion error - rel type");
        }
        $id = $hl->[0]->{id};
    }
    else {
        $desc = "" unless $desc;
        $id =
          insert_h($dbh,
                   "relationship_type",
                   {type_name=>$type,
                    type_desc=>$desc});
        $self->{rtype_by_id}->{$id} = $type;
    }
    return $id;
}

# synonym
sub add_relation {
    my $self = shift;
    $self->add_relationship(@_);
}

sub add_relationship {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($relh, $user) =
      rearrange([qw(relationship user)], @_);
    my $rel =
      GO::Model::Relationship->new($relh);

    # this is the parent
    my $t1 =
	select_hash($dbh,
		    "term",
		    "acc=$rel->{acc1}");
    # this is the child
    my $t2 =
	select_hash($dbh,
		    "term",
		    "acc=$rel->{acc2}");

    my $typeid =
      $self->add_relationship_type($rel->type);
    eval {
        insert_h($dbh,
                 "term2term",
                 {term1_id=>$t1->{id},
                  term2_id=>$t2->{id},
                  #	      is_inheritance=>($rel->is_inheritance ? 1:0),
                  #              relationship_type=>uc($rel->type),
                  relationship_type_id=>$typeid,
                  is_obsolete=>$rel->is_obsolete,
                 });
    };
    if ($@) {
        warn($@);
    }
    return $rel;
}

sub add_association {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($assoch, $user) =
      rearrange([qw(association user)], @_);

    my $assoc = $self->create_association_obj($assoch);
    $assoc->gene_product($assoch->{product});
    $assoc->role_group($assoch->{role_group});

    my $assoc_insert_h = 
      {gene_product_id=>$assoch->{product}->id,
       term_id=>$assoch->{term}->id};
#    $assoc_insert_h->{is_not} = $assoc->is_not if (defined($assoc->is_not));
    $assoc_insert_h->{is_not} = $assoc->is_not ? 1 : 0;
    $assoc_insert_h->{role_group} = $assoc->role_group if (defined($assoc->role_group));
    sql_delete($dbh,
	       "association",
	       ["gene_product_id=".$assoch->{product}->id,
		"term_id=".$assoch->{term}->id]);
    my $id =
      insert_h($dbh,
	       "association",
	       $assoc_insert_h);

    $assoc->id($id);
    $assoc;
}

sub OLD_add_association {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($assoch, $user) =
      rearrange([qw(association user)], @_);

    my $gene_acc = $assoch->{acc};

    my $term = $self->create_term_obj();
    $term->public_acc($assoch->{goacc});
    $term = $self->get_term({acc=>$term->acc}, {id=>'y'});
    if (!$term) {
	confess("There is no term with go_id/acc $assoch->{goacc}\n");
    }
    my $assoc_hash = $term->association_hash;
    my $assoc;
    my $product;
    my $evidence;

    if ($assoc_hash->{$gene_acc}) {
	$assoc = $assoc_hash->{$gene_acc};
	$product = $assoc->gene_product;
	print "already have association ".$assoc->{id}.
	      " from ".$term->name." to ".
	       $product->symbol."\n";
    }
    else {
	# add_product actually does a select first
	# and only adds it if it isn't already there
	$product = $self->add_product(
					  {symbol=>$assoch->{symbol},
					   acc=>$assoch->{acc},
					   full_name=>$assoch->{full_name},
					   synonym_list=>$assoch->{synonym_list},
					   speciesdb=>$assoch->{speciesdb}});
	
	$assoc = $self->create_association_obj({});
	$assoc->gene_product($product);
	print "adding gene ".$product->symbol." id=".$product->id."\n";
	my $ah = {gene_product_id=>$product->id,
		  term_id=>$term->id};
	$ah->{is_not} = $assoc->is_not if (defined($assoc->is_not));

	my $id = insert_h($dbh, "association", $ah);
	$assoc->id($id);
    }
    # this adds it to the model, but not yet to the db
    $evidence = GO::Model::Evidence->new({code=>$assoch->{ev_code},
					  seq_acc=>$assoch->{seq_acc},
					  reference=>$assoch->{reference},
				      });
    $assoc->add_evidence ($evidence);

    my $xref_id = 0;
    my $h =
	select_hash($dbh,
		    "dbxref",
		    ["xref_key=".
		     sql_quote($evidence->xref->xref_key || ""),
		     "xref_dbname=".
		     sql_quote($evidence->xref->xref_dbname)]);
    $xref_id = $h->{id};
    if (!$xref_id) {
	$xref_id =
	    insert_h($dbh,
		     "dbxref",
		     {xref_key=>$evidence->xref->xref_key || "",
		      xref_dbname=>$evidence->xref->xref_dbname});
	print "Adding dbxref to ".$evidence->xref->xref_dbname.
	    ":".$evidence->xref->xref_key."\n";
    }
    $evidence->xref->id($xref_id);
    my $ev_select_l = ["association_id=".$assoc->id,
		       "code=".sql_quote($assoch->{ev_code}),
		       "dbxref_id=".$xref_id];
    my $ev_h = {};
    $ev_h->{code} = $evidence->code;
    $ev_h->{seq_acc} = $evidence->seq_acc if ($evidence->seq_acc);
    $ev_h->{association_id} = $assoc->id;
    $ev_h->{dbxref_id} = $evidence->xref->id;

    my $ev_id;
    $h = select_hash($dbh, "evidence", $ev_select_l);
    $evidence->id($h->{id});
    if (!$evidence->id) {
	my $ev_id = insert_h($dbh, "evidence", $ev_h);
	$evidence->id($ev_id);
	print "Adding evidence ".$evidence->code."\n";
    }
    return $assoc;
}

sub add_evidence {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($evh, $user) =
      rearrange([qw(evidence user)], @_);
    my $evidence =
      GO::Model::Evidence->new({code=>$evh->{code},
				seq_acc=>$evh->{seq_acc},
				reference=>$evh->{reference},
			       });
    my $seq_acc = $evidence->seq_acc if ($evidence->seq_acc);
    my $xref_id;
    if ($evidence->xref) {
	my $h =
	  select_hash($dbh,
		      "dbxref",
		      ["xref_key=".
		       sql_quote($evidence->xref->xref_key || ""),
		       "xref_dbname=".
		       sql_quote($evidence->xref->xref_dbname)]);
	$xref_id = $h->{id};
	if (!$xref_id) {
	    $xref_id =
	      insert_h($dbh,
		       "dbxref",
		       {xref_key=>$evidence->xref->xref_key || "",
			xref_dbname=>$evidence->xref->xref_dbname});
	}
	$evidence->xref->id($xref_id);
    }
    my $id =
      insert_h($dbh, 
	       "evidence", 
	       {code=>$evidence->code,
		seq_acc=>($seq_acc),
		association_id=>$evh->{assoc}->id,
		dbxref_id=>$xref_id});
    $evidence->id($id);
    $evidence;
}

sub add_definition {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($defh, $xrefh, $user) =
      rearrange([qw(definition xref user)], @_);
    my $term = $self->create_term_obj();
    if (!$defh->{term_id}) {
	$term->public_acc($defh->{goid});
	$term = 
	  $self->get_term(
			  {acc=>$term->acc});
	if (!$term) {
	    confess("There is no term with go_id/acc $defh->{goid}\n");
	}
    }
    else {
	$term->id($defh->{term_id});
    }

    sql_delete($dbh,
	       "term_definition",
	       "term_id = ".$term->id);
    insert_h($dbh,
	     "term_definition",
	     {term_id=>$term->id,
	      term_definition=>$defh->{definition}
	     });

    if ($xrefh) {
	$self->add_term_dbxref($term, $xrefh, $user);
    }

    return 1;
}



sub add_product {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($producth, $user) =
      rearrange([qw(product user)], @_);

    my $product;
    $product = $self->get_product($producth);
    if ($product) {
	my $hl =
	  select_hashlist($dbh,
			  "association",
			  "gene_product_id=".$product->id,
			  ["id"]);
	map {
	    sql_delete($dbh,
		       "evidence",
		       "association_id=$_->{id}");
	} @$hl;
	sql_delete($dbh,
		   "gene_product",
		   "id=".$product->id);
	sql_delete($dbh,
		   "gene_product_synonym",
		   "gene_product_id=".$product->id);
	sql_delete($dbh,
		   "association",
		   "gene_product_id=".$product->id);
    }

    $product = $self->create_gene_product_obj($producth);
#    $product->speciesdb || confess("product $product ".$product->acc." has no speciesdb");
    my $xref_h = 
      select_hash($dbh,
		  "dbxref",
		  {"xref_key"=>$product->acc,
		   "xref_dbname"=>$product->speciesdb});
    
    my $xref_id;
    if ($xref_h) {
	$xref_id = $xref_h->{id};
    }
    else {
	$xref_id =
	  insert_h($dbh,
		   "dbxref",
		   {xref_key=>$product->acc,
		    xref_keytype=>"acc",
		    xref_dbname=>$product->speciesdb}
		  );
    }
    my $gh = {symbol=>$product->symbol,
	      dbxref_id=>$xref_id};
    $gh->{full_name} = $product->full_name if defined($product->full_name);
    
    my $id = insert_h($dbh, "gene_product", $gh);
    $product->id($id);

    my @syn_list = @{$product->synonym_list || []};
    foreach my $syn (@syn_list) {
	if ($syn) {
	    my $h =
	      select_hash($dbh,
			  "gene_product_synonym",
			  {product_synonym=>$syn,
			   gene_product_id=>$id});
	    if (!$h) {
		insert_h($dbh,
			 "gene_product_synonym",
			 {product_synonym=>$syn,
			  gene_product_id=>$id
			 });
	    }
	}
    }
    return $product;
}

sub remove_associations_by_speciesdb {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($speciesdb, $user) =
      rearrange([qw(speciesdb user)], @_);
    my $hl =
      select_hashlist($dbh,
                      ["association AS a",
                       "gene_product AS p",
                       "dbxref AS x"],
                      ["x.id = p.dbxref_id",
                       "a.gene_product_id = p.id",
                       "x.xref_dbname = ".sql_quote($speciesdb)],
                      "a.id AS id");
    my @aids = map {$_->{id}} @$hl;
    sql_delete($dbh,
               "evidence",
               "association_id in (".join(", ", @aids).")") if @aids;
    $hl =
      select_hashlist($dbh,
                      ["gene_product AS p",
                       "dbxref AS x"],
                      ["x.id = p.dbxref_id",
                       "x.xref_dbname = ".sql_quote($speciesdb)],
                      "p.id AS id");
    my @pids = map {$_->{id}} @$hl;
    $hl =
      select_hashlist($dbh,
                      "gene_product_seq",
                      "gene_product_id in (".join(", ", @pids).")",
                      "seq_id");
    my @seqids = map {$_->{seq_id}} @$hl;
    sql_delete($dbh,
               "gene_product",
               "id in (".join(", ", @pids).")");
    sql_delete($dbh,
               "gene_product_synonym",
               "gene_product_id in (".join(", ", @pids).")");
    sql_delete($dbh,
               "gene_product_seq",
               "gene_product_id in (".join(", ", @pids).")");
    sql_delete($dbh,
               "seq",
               "id in (".join(", ", @seqids).")") if @seqids;
    sql_delete($dbh,
               "gene_product_count");
    
}

sub set_product_seq {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($producth, $seqh, $user) =
      rearrange([qw(product seq user)], @_);
#    my $product = 
#	(ref($producth) eq "HASH") ? $self->create_gene_product_obj($producth) : $producth;
    my $seq = 
	(ref($seqh) eq "HASH") ? $self->create_seq_obj($seqh) : $seqh;
    my $product = $producth;
    if (!$product->id) {
	$self->get_product($producth);
    }
    if (!$seq->id) {
	$seq = $self->add_seq($seq);
    }
    my $gps_h = select_hash($dbh, 
                            "gene_product_seq", 
             {gene_product_id=>$product->id,
              seq_id=>$seq->id});                                                                      
    if (!$gps_h) { 
      insert_h($dbh,
	     "gene_product_seq",
	     {gene_product_id=>$product->id,
	      seq_id=>$seq->id});
    }   
}

sub add_seq {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($seqh, $user) =
      rearrange([qw(seq user)], @_);
    my $seq = $self->get_seq({display_id=>$seqh->display_id});
    my $is_insert = 0;
    if (!$seq) {
	$seq = 
	    (ref($seqh) eq "HASH") ? $self->create_seq_obj($seqh) : $seqh;
	$is_insert = 1;
    }
    else {

    }
    my $i_h =
    {
	display_id=>$seq->display_id,
	seq=>$seq->seq,
	md5checksum=>$seq->md5checksum,
	description=>$seq->desc,
	seq_len=>$seq->length
	};
    if ($is_insert) {
	my $id = 
	    insert_h($dbh, "seq", $i_h);
	$seq->id($id);
    }
    else {
	update_h($dbh,
		 "seq",
		 $i_h,
		 "id=".$seq->id);
    }
    sql_delete($dbh,
               "seq_dbxref",
               "seq_id=".$seq->id);
    my %done = ();
    foreach my $xref (@{$seq->xref_list || []}) {
        next if $done{$xref->as_str};
        $self->add_dbxref($xref);
        insert_h($dbh,
                 "seq_dbxref",
                 {seq_id=>$seq->id,
                  dbxref_id=>$xref->id});
        $done{$xref->as_str} = 1;
    }
    $seq;
}



#
sub _delete_term {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($constr, $user) =
      rearrange([qw(constraints user)], @_);
    if (!$user->{authority} ||
	$user->{authority} < 10) {
	confess("Don't have authority! (".$user->{authority}.")");
    }
    my $term = 
      $self->get_term($constr);
    
    sql_delete($dbh,
	       "term_definition",
	       "term_id=".$term->{id});
    sql_delete($dbh,
	       "term_synonym",
	       "term_id=".$term->{id});
    sql_delete($dbh,
	       "term2term",
	       "term1_id=".$term->{id});
    sql_delete($dbh,
	       "term2term",
	       "term2_id=".$term->{id});
    sql_delete($dbh,
	       "term",
	       "id=".$term->{id});
}



sub fill_path_table {
    my $self = shift;
    my $dbh = $self->dbh;
    sql_delete($dbh, "$PATH");
    my $root = $self->get_root_term(-template=>{id=>'y'});
    my $graph = 
      $self->get_graph(-acc=>$root->acc,
                       -depth=>-1,
                       -template=>{terms=>{id=>'y', acc=>'y'}});
    my @nodes = @{$graph->get_all_nodes};
    my $it = $graph->create_iterator({direction=>"up"});
    foreach my $node (@nodes) {
        $it->reset_cursor($node->acc);
        while (my $ni = $it->next_node_instance) {
            insert_h($dbh,
                     "$PATH",
                     {term1_id=>$ni->term->id,
                      term2_id=>$node->id,
                      distance=>$ni->depth});
        }
    }
    $self->has_path_table(1);
}

sub has_word_table {
    my $self = shift;
    $self->{_has_word_table} = shift if @_;
    if (!defined($self->{_has_word_table})) {
        eval {
            my $h=
              select_hash($self->dbh,
                          "wordunit2term",
                          undef,
                          "count(*) AS c");
            $self->{_has_word_table} = $h->{c} ? 1:0;
        };
        if ($@) {
            $self->{_has_word_table} = 0;
        }
    }
    return $self->{_has_word_table};
}

sub fill_word_table {
    my $self = shift;
    my $dbh = $self->dbh;
    sql_delete($dbh, "wordunit2term");
    my @wstruct =
      $self->get_wordstruct;
    foreach my $ws (@wstruct) {
        my $id = shift @$ws;
        my $type = shift @$ws;
        if (!@$ws) {
            warn("fill_word_table: $id $type has no words");
            next;
        }

        foreach my $w (@$ws) {
            my $h =
              {"term_id"=>$id,
               "is_synonym"=>($type eq "synonym" ? 1 : 0),
               "is_definition"=>($type eq "definition" ? 1 : 0),
               "wordunit"=>sql_quote($w)};
            if ($self->dbms eq "mysql") {
                $h->{wordsound} = "soundex(wordunit)";
            }
            my @k = keys %$h;
            my $sql =
              "insert into wordunit2term (".join(", ", @k).") ".
                "values (".
                  join(", ", map {$h->{$_}} @k).")";
            $dbh->do($sql);
        }
    }
    $self->has_word_table(1);
}

########### select distinct(wordunit), count(term_id) c from wordunit2term group by wordunit order by c;
########### select u1.wordunit AS w1, u2.wordunit AS w2 from wordunit2term u1, wordunit2term u2 where u1.wordsound = u2.wordsound and u1.wordunit != u2.wordunit

sub get_wordstruct {
    my $self = shift;
    my $dbh = $self->dbh;
    my $splitexpr = shift || '[\W\d_]';
    my $thl = 
      select_hashlist($dbh,
                      "term",
                      [],
                      ["name AS phrase",
                       "id AS id",
                       "'term' AS type"]);
    my $shl = 
      select_hashlist($dbh,
                      "term_synonym",
                      [],
                      ["term_synonym AS phrase",
                       "term_id AS id",
                       "'synonym' AS type"]);
    my $dhl = 
      select_hashlist($dbh,
                      "term_definition",
                      [],
                      ["term_definition AS phrase",
                       "term_id AS id",
                       "'definition' AS type"]);

    my @ws = ();
    foreach my $h (@$thl, @$shl, @$dhl) {
        my $ph = $h->{phrase};
        my @words = split(/$splitexpr/, $ph);
        @words = grep {$_} @words;
        push(@ws, [$h->{id}, $h->{type}, @words]);
    }
    return @ws;
}

sub has_path_table {
    my $self = shift;
    $self->{_has_path_table} = shift if @_;
    if (!defined($self->{_has_path_table})) {
        eval {
            my $h=
              select_hash($self->dbh,
                          "$PATH",
                          undef,
                          "count(*) AS c");
            $self->{_has_path_table} = $h->{c} ? 1:0;
        };
        if ($@) {
            $self->{_has_path_table} = 0;
        }
    }
    return $self->{_has_path_table};
}

sub fill_count_table {
    my $self = shift;
    my $dbh = $self->dbh;
    my $evcodes = shift;

    # if an argument is passed, this is used as the
    # list of evcode combinations to use.
    # if there is no argument, only one combination,
    # the current filter, is used
    if (!defined($evcodes)) {
        $evcodes = [$self->filters->{evcodes}];
    }

    my $oldcodes = $self->filters->{evcodes};
    my $oldspdb = $self->filters->{speciesdb};

    if (@$evcodes > 1) {
        confess("For now you can only populate gpc with one evcode combination");
    }

    # we only fill the count table for non IEAs and for all evcodes
    foreach my $ev (@$evcodes) {
        
        my $evstr = $ev;
        if (ref($ev)) {
            $evstr = join(";", sort @{$ev || []});
        }
#        sql_delete($dbh, 
#                   "gene_product_count",
#                   $evstr ? "code=".sql_quote($evstr) : "code is null");
        sql_delete($dbh, 
                   "gene_product_count");
        my $spdbh = $self->get_speciesdb_dict;
        my $r = $self->get_root_term(-template=>{id=>'y', acc=>'y'});
        my $g = $self->get_graph_by_terms([$r], -1, {terms=>{id=>'y'}});
        my $nodes = $g->get_all_nodes;
        foreach my $spdb (keys %$spdbh) {
            if ($ev) {
                $self->filters->{evcodes} = $ev;
            }
            else {
                delete $self->filters->{evcodes};
            }
            $self->filters->{speciesdbs}=$spdb;
            #        my $countl =
            #          $self->get_product_count({per_term=>1, terms=>[]});
            #        our @deep = ();
            #        our @nprods = ();
        
            #        map {
            #            $nprods[$_->{term_id}] = $_->{"c"};
            #        } @$countl;
            #        sub rcount {
            #            my $node = shift;
            #            my $children = $g->get_child_terms($node->acc);
            #            my $sum = 0;
            #            map {$sum += rcount($_)} @$children;
            #            $sum += $nprods[$node->id];
            #            $deep[$node->id] = $sum;
            #            return $sum;
            #        }

            #        rcount($r);
            my $nodes = $g->get_all_nodes;
            foreach my $n (@$nodes) {
                my $pc = 
                  $self->get_products(-constraints=>{deep=>1, term=>$n},
                                      -options=>{count=>1});
                insert_h($dbh,
                         "gene_product_count",
                         {term_id=>$n->id,
                          #########                      product_count=>$deep[$n->id],
                          product_count=>($pc || 0),
                          speciesdbname=>$spdb,
                          code=>$evstr});
            }
        }
    }

    # restore settings
    $self->filters->{evcodes} = $oldcodes;
    $self->filters->{speciesdb} = $oldspdb;
    $self->has_count_table(1);

}

sub has_count_table {
    my $self = shift;
    $self->{_has_count_table} = shift if @_;
    if (!defined($self->{_has_count_table})) {
        eval {
            my $h=
              select_hash($self->dbh,
                          "gene_product_count",
                          undef,
                          "count(*) AS c");
            $self->{_has_count_table} = $h->{c} ? 1:0;
        };
        if ($@) {
            $self->{_has_count_table} = 0;
        }
    }
    return $self->{_has_count_table};
}

sub get_distance {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($t1, $t2, $nosiblings) =
      rearrange([qw(term1 term2 nosiblings)], @_);

    # be very liberal in what we accept
    ($t1, $t2) =
      map {
          if (ref($_)) {
              if (ref($_) eq "HASH") {
                  if ($_->{acc}) {
                      $_->{acc};
                  }
                  else {
                      $self->get_term($_)->acc;
                  }
              }
              else {
                  $_->acc;
              }
          }
          elsif (int($_)) {
              $_;
          }
          else {
              confess("Don't know what to do with param:$_");
          }
      } ($t1, $t2);

    # t1 and t2 should now be acc numbers

    my $h;
    if ($nosiblings) {
        $h=
          select_hash($dbh,
                      ["$PATH",
                       "term AS t1",
                       "term AS t2"],
                      ["t1.acc = $t1",
                       "t2.acc = $t2",
                       "(($PATH.term1_id = t1.id AND ".
                       "  $PATH.term2_id = t2.id) OR ".
                       " ($PATH.term1_id = t2.id AND ".
                       "  $PATH.term2_id = t1.id))"
                      ],
                      "min($PATH.distance) AS dist");
        return -1 unless $h;
    }
    else {
        $h=
          select_hash($dbh,
                      ["$PATH AS path1", 
                       "$PATH AS path2", 
                       "term AS t1", 
                       "term AS t2"],
                      ["t1.acc = $t1",
                       "t2.acc = $t2",
                       "path1.term2_id = t1.id",
                       "path2.term2_id = t2.id",
                       "path1.term1_id = path2.term1_id"],
                      "min(path1.distance + path2.distance) AS dist");
    }
    if ($h) {
        return defined($h->{dist}) ? $h->{dist} : -1;
    }
    else {
        confess("Assertion error: Can't find distance $t1 to $t2");
    }
}

sub get_term {
    my $self = shift;
    my $dbh = $self->dbh;
    my $terms = $self->get_terms(@_);
#    if (scalar(@$terms ) > 1) {
#	warn("get_term(",join(", ", @_).") returned >1 term");
#    }
    return $terms->[0];   # returns undef if empty
}


# only returns terms that have associations attached
sub get_terms_with_associations {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($inconstr, $template) =
      rearrange([qw(constraints template)], @_);
    my $interms = $self->get_terms($inconstr, {id=>'y'});
    $template = $template || {};
    $template->{association_list} = [];
    my $graph =
      $self->get_graph_by_terms($interms,
                                -1,
                                {terms=>{id=>'y'},
                                 with_associations=>1,
                                 traverse_up=>0});
    my @ids = map { $_->id } @{$graph->get_all_nodes};
    my @lookup = ();
    my $terms = $self->get_terms({idlist=>\@ids,
                                  with_associations=>1},
                                 $template);
    foreach (@$terms) { $lookup[$_->id] = $_ }
    my $it = $graph->create_iterator;
    # now order the terms
    my @o_terms = ();
    while (my $n = $it->next_node) {
        if ($lookup[$n->id]) {
            push(@o_terms, $lookup[$n->id]);
        }
    }
    return \@o_terms;
}



sub get_terms {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($inconstr, $template) =
      rearrange([qw(constraints template)], @_);
    $template = GO::Model::Term->get_template($template);
    my $constr = pset2hash($inconstr);
    my @where_arr = ();
    my @table_arr = ("term");


    my $fetch_all = 0;

    # allow API users to pass in
    # an accession no as alternate
    # to hashref
    if ($constr && !ref($constr)) {
        if ($constr =~ /^\d+$/) {
            $constr = {"acc"=>int($constr)};
        }
        elsif ($constr eq "*") {
            $constr = {};
        }
        else {
            $constr = {"name"=>$constr};
        }
    }

    my $with_associations = 0;
    if ($constr->{with_associations}) {
        delete $constr->{with_associations};
        $with_associations = 1;
    }

    if (!$constr || !%{$constr || {}}) {
        $fetch_all = 1;
    }

    my $accs = $constr->{acc} || $constr->{accs};
    if ($accs) {
        # allow either single acc or list of accs
        if (!ref($accs)) {
            $accs = [$accs];
        }
        map {
            # turn acc from GO:nnnnnnn to integer
            if (/GO:(\d+)/) {
                $_ = $1;
            }
        } @$accs;
        my $orq = "acc in (".join(", ", @$accs).")";
#        my $orq = join(" OR ", map {"acc = $_"} @$accs);
#        if (@$accs > 1) {
#            $orq = "($orq)";
#        }
        push(@where_arr, $orq) if @$accs;
        delete $constr->{acc};
        delete $constr->{accs};
    }

    # this boolean determines whether
    # we are adding selected associations
    # to the terms during creation
    my $add_select_assocs = 0;

    my $hl;

    if ($constr->{search} && $constr->{search} eq "*") {
        delete $constr->{search};
        $fetch_all = 1;
    }
    if ($constr->{search}) {
	my $srch = $constr->{search};
        my $fieldsstr = 
          $constr->{search_fields} || "";
        my @fields = split(/[\,\:\;]/, $fieldsstr);
        my @yes =  grep {$_ !~ /^\!/} @fields;
        my @no =  grep {/^\!/} @fields;
        if (!@yes) {
            @yes = ("name", "synonym", "definition", "dbxref");
        }
        my $selected = {};
        map {$selected->{$_} = 1} @yes;
        map {$selected->{substr($_, 1)} = 0} @no;
        my $srch_l = [$srch];
        if (ref($srch) eq "ARRAY") {
            # allow api users to pass in
            # single term of list of terms
            $srch_l = $srch;
        }
#	$srch =~ tr/A-Z/a-z/;
	map {s/\*/\%/g} @$srch_l;

        # we have to do these in seperate
        # queries and merge in-memory; this is
        # because some terms don't have an
        # entry in the many-1 relations so
        # we could have to use an outer join
        # which is slow
        my ($hl1, $hl2, $hl3, $hl4) = ([],[],[],[]);
        if ($selected->{name}) {
            $hl1=
              select_hashlist($dbh,
                              "term",
                              join(" OR ",
                                   map {
                                       "term.name like ".sql_quote($_)
                                   } @$srch_l));
        }
        if ($selected->{synonym}) {
            $hl2=
              select_hashlist($dbh,
                              ["term", "term_synonym"],
                              ["(".
                               join(" OR ",
                                    map {
                                        "term_synonym.term_synonym like ".
                                          sql_quote($_)
                                      } @$srch_l).
                               ")",
                               "term.id=term_synonym.term_id",
                              ],
                              "term.*");
        }
        if ($selected->{definition}) {
            my $hl3=
              select_hashlist($dbh,
                              ["term", "term_definition"],
                              ["(".
                               join(" OR ",
                                    map {
                                        "term_definition.term_definition like ".
                                          sql_quote($_)
                                      } @$srch_l).
                               ")",
                               "term.id=term_definition.term_id",
                               #			   "term.name not like ".sql_quote($srch),
                              ],
                              "term.*");
        }
        if ($selected->{dbxref}) {
	
            $hl4=
              select_hashlist($dbh,
                              ["term", "term_dbxref", "dbxref"],
                              ["(".
                               join(" OR ",
                                    map {
                                        if (/(.*):(.*)/) {
                                            # ignore DB part of dbxref
                                            $_ = $2;
                                        }
                                        "dbxref.xref_key like ".
                                          sql_quote($_)
                                      } @$srch_l).
                               ")",
                               "term.id=term_dbxref.term_id",
                               "dbxref.id=term_dbxref.dbxref_id",
                              ],
                              "term.*");
        }
	
	$hl = [];
	my @id_lookup = ();
	map {
	    dd($_) if $ENV{DEBUG};
	    if (!$id_lookup[$_->{id}]) {
		$id_lookup[$_->{id}] = 1;
		push(@$hl, $_);
	    }
	} (@$hl1, @$hl2, @$hl3, @$hl4);
	
    }

    else {
	# dynamically generate SQL
	# for query

        # prepare selected columns
	my @select_arr = ("distinct term.*");

	if ($constr->{synonym}) {
	    push(@table_arr, "term_synonym");
	    push(@where_arr,
		 "term.id=term_synonym.term_id",
		 "term_synonym.term_synonym = ".
		 sql_quote($constr->{synonym}));
	    delete $constr->{synonym};
	}

	if ($constr->{dbxref}) {
            $constr->{dbxrefs} = [$constr->{dbxref}];
            delete $constr->{dbxref};
        }
	if ($constr->{dbxrefs}) {
	    my $dbxrefs = $constr->{dbxrefs};

            my @q =
              map {
                  if (ref($_)) {
                      "(dbxref.xref_dbname = ".sql_quote($_->{xref_dbname}).
                        " AND ".
                          "dbxref.xref_key = ".sql_quote($_->{xref_key}).")";
                  }
                  else {
                      if ($_ =~ /(.*):(.*)/) {
                          "(dbxref.xref_dbname = ".sql_quote($_->{xref_dbname}).
                            " AND ".
                              "dbxref.xref_key = ".sql_quote($_->{xref_key}).")";
                      }
                      else {
                          confess("$_ not a valid dbxref");
                      }
                  }
              } @$dbxrefs;
            if (@q) {
                push(@table_arr, "term_dbxref", "dbxref");
                push(@where_arr,
                     "term.id=term_dbxref.term_id",
                     "term_dbxref.dbxref_id = dbxref.id",
                     "(".join(" OR ", @q).")");
            }

	    delete $constr->{dbxrefs};
	}
	if ($constr->{dbxref_key}) {
	    push(@table_arr, "term_dbxref", "dbxref");
	    push(@where_arr,
		 "term.id=term_dbxref.term_id",
		 "term_dbxref.dbxref_id = dbxref.id",
		 "dbxref.xref_key=".
		 sql_quote($constr->{dbxref_key}));
	    delete $constr->{dbxref_key};
	}
	if ($constr->{dbxref_dbname}) {
	    push(@table_arr, "term_dbxref", "dbxref");
	    push(@where_arr,
		 "term.id=term_dbxref.term_id",
		 "term_dbxref.dbxref_id = dbxref.id",
		 "dbxref.xref_dbname = ".
		 sql_quote($constr->{dbxref_dbname}));
	    delete $constr->{dbxref_dbname};
	}
	if ($constr->{idlist}) {
	    my @ids = @{$constr->{idlist}};
	    if (!@ids) {@ids=(0)}
	    push(@where_arr,
                 "id in (".join(", ", @ids).")");
	    delete $constr->{idlist};
	}

	# allow api users to specify
	# a stringlist for product accs
	# for convenience
	if ($constr->{product_accs}) {
	    $constr->{products} =
		[
		 map {
		     {xref_key=>$_}
		 } @{$constr->{product_accs}}
		 ];
	    delete $constr->{product_accs};
	}

	# use same code for product/products
	if ($constr->{products}) {
	    $constr->{product} = $constr->{products};
	    delete $constr->{products};
	}

	# constrain terms by products
	if ($constr->{product}) {

            # include the products
            # constrained upon to the
            # term objects
            $add_select_assocs = 1;

	    # join gene_product, association
	    # and (optionally) dbxref
	    my $prods = [$constr->{product}];
	    if (ref($constr->{product}) eq "ARRAY") {
		$prods = $constr->{product};
	    }
	    if (!@$prods) { $prods = [{id=>0}] } # fake this for empty list
	    my @orq = ();
	    my $use_dbxref_table = 0;

            my $constr_sp = $constr->{speciesdb} || $self->filters->{speciesdb};
            if ($constr_sp) {
                if (!ref($constr_sp)) {
                    $constr_sp = [$constr_sp];
                }
                my @yes = grep {$_ !~ /^\!/} @$constr_sp;
                my @no = grep {/^\!/} @$constr_sp;
                map {s/^\!//} @no;
                $use_dbxref_table = 1;
                if (@yes) {
                    push(@where_arr,
                         "gp_dbxref.xref_dbname in ".
                         "(".join(", ", map {sql_quote($_)} @yes).")");
                }
                if (@no) {
                    push(@where_arr,
                         "gp_dbxref.xref_dbname not in ".
                         "(".join(", ", map {sql_quote($_)} @no).")");
                }
                delete $constr->{speciesdb};
            }
            
            #evidence
            my $constr_ev = $constr->{evcodes} || $self->filters->{evcodes};
            if ($constr_ev) {
                # hmm we have some redundant code here;
                # doing the same kind of thing as get_products
                # i think a little redundancy is ok balanced against
                # even more complex o/r code
                if (!ref($constr_ev)) {
                    $constr_ev = [$constr_ev];
                }
                my @yes = grep {$_ !~ /^\!/} @$constr_ev;
                my @no = grep {/^\!/} @$constr_ev;
                map {s/^\!//} @no;
                if (@$constr_ev) {
                    push(@table_arr, "evidence");
                    push(@where_arr,
                         "evidence.association_id = association.id");
                }
                if (@yes) {
                    push(@where_arr,
                         "evidence.code in ".
                         "(".join(", ", map {sql_quote($_)} @yes).")");
                }
                if (@no) {
                    push(@where_arr,
                         "evidence.code not in ".
                         "(".join(", ", map {sql_quote($_)} @no).")");
                }
                delete $constr->{evcodes};
            }
	    foreach my $prod (@$prods) {
		if (!ref($prod)) {
		    $prod = {"symbol"=>$prod};
		}
#                if (ref($prod) eq "HASH") {
#                    $prod = $self->create_gene_product_obj($prod);
#                }
		my @w = ();
                my %phash;
                
                # if the user is passing in a product object,
                # use the ID
                # otherwise use the keys they pass in
                if (ref($prod) ne "HASH") {
                    $prod->isa("GO::Model::GeneProduct") || 
                      confess("assertion error");
                    if ($prod->id) {
                        %phash = (id=>$prod->id);
                    }
                    else {
                        %phash = (xref=>$prod->xref);
                    }
                }
                else {
                    %phash = %$prod;
                }
		map {

		    if (/^acc$/ || /^xref$/) {
                        if (ref($prod->{$_})) {
                            push(@w,
                                 "gp_dbxref.xref_key = ".
                                 sql_quote($prod->{$_}->{xref_key}),
                                 "gp_dbxref.xref_dbname = ".
                                 sql_quote($prod->{$_}->{xref_dbname}),
                                );
                        }
                        else {
                            push(@w,
                                 "gp_dbxref.xref_key = ".
                                 sql_quote($prod->{$_}))
                        }
			$use_dbxref_table = 1;
		    }
		    elsif (/^xref/) {
			push(@w,
			     "gp_dbxref.$_ = ".sql_quote($prod->{$_}));
			$use_dbxref_table = 1;
		    }
		    else {
                        if (/apph/) {
                            # skip non queryable/peristent fields
                        }
                        else {
                            my $op = "=";
                            my $val = $prod->{$_};
                            if ($val =~ /\*/) {
                                $val =~ s/\*/\%/g;
                                $op = "like";
                            }
                            push(@w, "gene_product.$_ $op ".sql_quote($val));
                        }
		    }
		} keys %phash;
		my $q =
		    join(" AND ", @w);
		if (scalar(@w) > 1) {
		    push(@orq, "($q)");
		}
		else {
		    push(@orq, "$q");
		}
	    }
	    push(@table_arr,
		 qw(association gene_product));
	    push(@where_arr, 
		 ("term.id = association.term_id",
		  "gene_product.id = association.gene_product_id"));
	    push(@where_arr, 
		 "(".join(" OR ", @orq).")");
	    if (1 || $use_dbxref_table) {
		push(@table_arr,
		     "dbxref gp_dbxref");
		push(@where_arr, 
		     "gene_product.dbxref_id = gp_dbxref.id");
	    }
            push(@select_arr,
                 "association.id a_id",
                 "association.term_id",
                 "association.gene_product_id",
                 "association.is_not",
                 "association.role_group",
                 "gp_dbxref.xref_key gp_xref_key",
                 "gp_dbxref.xref_dbname gp_xref_dbname",
                 "gene_product.symbol",
                 "gene_product.full_name");

	    delete $constr->{product};
	}

        
        if ($constr->{synonym}) {
            $constr->{term_synonym} = $constr->{synonym};
            delete $constr->{synonym};
        }
        if ($constr->{type}) {
            $constr->{term_type} = $constr->{type};
            delete $constr->{type};
        }
	
	# guess any unconsumed keys
	if (keys %$constr) {
	    push(@where_arr, 
		 map {"$_ = ".sql_quote($constr->{$_})} grep {defined($constr->{$_})} keys %$constr);
	}

	# do the dynamically generated sql
	if ($ENV{GO_EXPERIMENTAL_OJ}) {
	    # question: we could get dbxrefs/syns/defs here
	    # using left outer joins;
	    # but is it any more efficient?
	    my @ojs =
		("term_synonym ts",
		 "term_definition td",
		 "term_dbxref tx");
	    push(@table_arr,
		 map {/(\w+)$/;
		      "left outer join $_ on $1.term_id=term.id"
		      } @ojs,
		 "dbxref dbx");
	    push(@where_arr,
		 "dbx.id=tx.dbxref_id");
	    # todo - use these rows
	}
        # -- end of experimental section --

        if ($add_select_assocs) {
        }

	$hl =
          select_hashlist($dbh,
                          \@table_arr,
                          \@where_arr,
                          \@select_arr);
    }

    my @term_l = ();

    my @term_lookup = (); # use array as lookup for speed
    my @term_ids = ();
    foreach my $h (@$hl) {
        my $term = $term_lookup[$h->{id}];
        if (!$term) {
            $term = $self->create_term_obj($h);
            $term_lookup[$term->id] = $term;
            my $id = $term->id;
            push(@term_ids, $id);
            push(@term_l, $term);
        }
    }

    # if the search was constrained by assocs/products,
    # adorn the term with selected products
    if ($add_select_assocs) {
        # we have associations
        my $assocs = $self->create_assocs_from_hashlist($hl, $constr);
        foreach my $assoc (@$assocs) {
            $term_lookup[$assoc->{term_id}]->add_selected_association($assoc);
        }
	# remove terms without assocs
	# (rational: we got here by doing a product-based query;
	#  some of these should be filtered as the evidence didnt
	#  match the criteria)
	@term_l = ();
	foreach (@term_ids) {
	    my $term = $term_lookup[$_];
	    if (@{$term->selected_association_list || []}) {
		push(@term_l, $term);
	    }
	}
	@term_ids = map {$_->id} @term_l;
    }

    # now lets populate our GO::Model::Term objects with
    # other adornments such as synonyms, dbxrefs and defintions
    # (it's faster to do this as a seperate step; unfortunately we
    #  can't do *everything* in a single SQL statement as this would
    #  require outer joins, as the relationship of term to other tables
    #  is ZERO to many)
    if (@term_ids) {
        my @where = ();
	if (%$template && $template->{association_list}) {
            # clear old associations
            map { $_->association_list( [] ) } @term_l;
	    my $al=
		$self->get_direct_associations(\@term_l);
	    
            map {
                $term_lookup[$_->{term_id}]->add_association($_);
            } @$al;
            if ($with_associations) {
                # weed out all terms without assocs
                @term_ids = 
                  grep { @{$term_lookup[$_]->association_list} } @term_ids;
                @term_l =
                  grep { @{$_->association_list} } @term_l;
            }
	}
        unless ($fetch_all) {
            @where = ("term_id in (".join(", ", @term_ids).")");
        }
        if ($fetch_all) {
            $self->{_term_count} = scalar(@term_ids);
        }
        if (!%$template || $template->{synonym_list}) {
            my $sl =
              select_hashlist($dbh,
                              "term_synonym",
                              \@where);
            map {
                $term_lookup[$_->{term_id}]->add_synonym($_->{term_synonym});
            } @$sl;
        }
	if (!%$template || $template->{definition}) {
	    my $dl =
	      select_hashlist($dbh,
                              "term_definition",
                              \@where);
            map {
                $term_lookup[$_->{term_id}]->definition($_->{term_definition});
            } @$dl;
	}
	if (!%$template || $template->{n_deep_products}) {
            my $c = {per_term=>1};
            unless ($fetch_all) { $c->{terms} = \@term_l }
	    my $countl =
              $self->get_deep_product_count($c);
	    
            map {
                if ($term_lookup[$_->{term_id}]) { 
                    $term_lookup[$_->{term_id}]->n_deep_products($_->{"c"});
                }
            } @$countl;
	}
	if (%$template && $template->{n_products}) {
	    my $countl =
              $self->get_product_count({terms=>\@term_l,
                                        per_term=>1});
	    
            map {
                if ($term_lookup[$_->{term_id}]) { 
                    $term_lookup[$_->{term_id}]->n_products($_->{"c"});
                }
            } @$countl;
	}
	if (%$template && $template->{n_associations}) {
	    my $al =
	      select_hashlist($dbh,
                              "association",
                              \@where,
                              "term_id, count(association.id) AS n",
                              undef,
                              "term_id",
                             );
            map {
                $term_lookup[$_->{term_id}]->n_associations($_->{"n"});
            } @$al;
	}
	if (!%$template || $template->{dbxref_h} || $template->{dbxref_list}) {
	    my $xl=
	      select_hashlist($dbh,
			      ["term_dbxref", "dbxref"],
			      [@where,
			       "term_dbxref.dbxref_id = dbxref.id"],
			      ["dbxref.*", "term_id"],
                              ["dbxref.xref_dbname", "dbxref.xref_key", "dbxref.xref_desc"]);
	    map {	
                $term_lookup[$_->{term_id}]->add_dbxref(GO::Model::Xref->new($_));
	    } @$xl;
	}
    }

    return \@term_l;
}

sub get_terms_by_product_symbols {
    my $self = shift;
    my $dbh = $self->dbh;

    my ($syms, $constr, $template) =
      rearrange([qw(symbols constraints template)], @_);
    $constr = $constr || {};
    $constr->{products} = $syms;
    return $self->get_terms($constr, $template);
    
}

sub get_term_by_acc {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($acc, $attrs) =
      rearrange([qw(acc attributes)], @_);
    return $self->get_term({acc=>$acc});
}


sub get_terms_by_search {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($search, $attrs) =
      rearrange([qw(search attributes)], @_);
    return $self->get_terms({search=>$search});
}

sub get_root_term {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($template) =
      rearrange([qw(template)], @_);

    # yuck, ugly way to do this,
    # but mysql has no subselects
    # so this is the easiest way for now
#    return 
#      $self->get_term(-constraints=>{name=>"Gene_Ontology"},
#		      -template=>$template);

    my $root =
      $self->get_term(-constraints=>{term_type=>'root'},
                      -template=>$template);
    return $root if ($root);
    return
      $self->get_term(-constraints=>{name=>"Gene_Ontology"},
		      -template=>$template);
}

sub get_ontology_root_terms {
    my $self = shift;
    my $dbh = $self->dbh;

    # yuck, ugly way to do this,
    # but mysql has no subselects
    # so this is the easiest way for now
    my $root = $self->get_root_term(-template=>{acc=>1});
    return $self->get_child_terms($root, @_);
}

sub get_association_count {
    my $self = shift;
    my ($termh, $constr, $templ, $o) =
      rearrange([qw(term constraints template options)], @_);
    $self->get_direct_associations($termh, $constr, $templ, {count=>1, %{$o||{}}});
}

sub get_direct_associations {
    my $self = shift;
    my ($termh, $constr, $templ, $o) =
      rearrange([qw(term constraints template options)], @_);
    $self->get_associations($termh, $constr, $templ, {direct=>1, %{$o||{}}});
}

sub get_all_associations {
    my $self = shift;
    my ($termh, $constr, $templ, $o) =
      rearrange([qw(term constraints template options)], @_);
    $self->get_associations($termh, $constr, $templ, {direct=>0, %{$o||{}}});
}

sub get_associations {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($termh, $constr, $templ, $options) =
      rearrange([qw(term constraints template options)], @_);
    if (!$templ) {$templ = {};}
    if (!$options) {$options = {};}
    if (!$constr) {$constr = {};}
    my $terms;
    if (ref($termh) eq "ARRAY") {
	$terms= $termh;
    }
    elsif (ref($termh) eq "HASH" || !$termh->id) {
	my $tt = $templ->{term_template} || "shallow";
	$terms= $self->get_terms($termh, $tt);
    }
    else {
	$terms = [$termh];
    }
    my @term_ids = map {$_->id} @$terms;
    if ($constr->{all}) {
	my $hl=select_hashlist($dbh, "term", undef, "id");
	@term_ids = map {$_->{id}} @$hl;
    }
    if (!$options->{direct}) {
	# make sure the subgraph doesnt get associations or 
	# we get into a cycle!
	my $g = 
	    $self->get_graph_by_terms($terms, 
				  -1, 
				  {traverse_up=>0,
				   terms=>{acc=>1,id=>1}});
	@term_ids = map {$_->id} @{$g->get_all_nodes || []};
    }
    
    my $tc = "term_id in (".join(", ", @term_ids).")";

    my @tables =
      ("association", 
       "gene_product", 
       "dbxref", 
       "evidence", 
       "dbxref evdbxref");
    my @where =
      ($tc,
       "gene_product.id = association.gene_product_id",
       "dbxref.id = gene_product.dbxref_id",
       "evidence.association_id = association.id",
       "evidence.dbxref_id = evdbxref.id");
    my @cols =
      ("association.id",
       "association.term_id",
       "association.gene_product_id ",
       "association.is_not",
       "association.role_group",
       "dbxref.xref_key",
       "dbxref.xref_dbname",
       "gene_product.symbol",
       "gene_product.full_name",
       "evidence.code",
       "evidence.seq_acc",
       "evdbxref.xref_key AS evdbxref_acc",
       "evdbxref.xref_dbname AS evdbxref_dbname",
      );


    my $filters = $self->filters || {};
    my $spdbs = 
      $constr->{speciesdb} ||
        $constr->{speciesdbs} ||
          $filters->{speciesdb} ||
            $filters->{speciesdbs};

    if ($spdbs) {
        if (!ref($spdbs)) {
            $spdbs = [$spdbs];
        }

	my @wanted = grep {$_ !~ /^\!/} @$spdbs;
	my @unwanted = grep {/^\!/} @$spdbs;

	if (@wanted) {
	    push(@where,
		 "(".join(" OR ", 
			  map{"dbxref.xref_dbname=".sql_quote($_,1)} @wanted).")");
	}
	if (@unwanted) {
	    push(@where,
		 map{"dbxref.xref_dbname!=".sql_quote(substr($_,1))} @unwanted);
	}
    }
    if ($constr->{acc}) {
        push(@where,
             "dbxref.xref_acc = ".sql_quote($constr->{acc}));
    }

    if ($options->{count}) {
	@cols = "count(distinct association.id) n"
    }


    my $evcodes = $constr->{evcodes} || $filters->{evcodes};
    my @w=();
    if ($evcodes) {
        my @wanted = grep {$_ !~ /^\!/} @$evcodes;
        my @unwanted = grep {/^\!/} @$evcodes;
        
        if (@wanted) {
            push(@w,
                 "(".join(" OR ", 
                          map{"evidence.code=".sql_quote($_,1)} @wanted).")");
        }
        if (@unwanted) {
            push(@w,
                 map{"evidence.code!=".sql_quote(substr($_,1))} @unwanted);
        }
        unshift(@where,
                "evidence.association_id = association.id", 
                @w);
    }


    my $hl = 
	select_hashlist($dbh, \@tables, \@where, \@cols);

    if ($options->{count}) {
	return $hl->[0]->{n};
    }

    if (!@$hl) {
	return [];
    }

### TODO - this code is duplicated in create_assocs_from_hashlist
######### OLD    my $assocs = $self->create_assocs_from_hashlist($hl, $constr);

    my @assocs = ();
    my @assoc_lookup = ();
    my @assoc_ids = ();
    foreach my $h (@$hl) {
        if ($h->{a_id}) {
            $h->{id} = $h->{a_id};
        }
        if ($h->{gp_xref_key}) {
            $h->{xref_key} = $h->{gp_xref_key};
        }
        if ($h->{gp_xref_dbname}) {
            $h->{xref_dbname} = $h->{gp_xref_dbname};
        }
	my $assoc = $assoc_lookup[$h->{id}];
        if (!$assoc) {
            $assoc =
              $self->create_association_obj($h);
            $assoc_lookup[$assoc->id] = $assoc;
            $assoc->{term_id} = $h->{term_id};
            push(@assoc_ids, $assoc->id);
            push(@assocs, $assoc);
        }

	my $ev = GO::Model::Evidence->new({
                                           code=>$h->{code},
                                           seq_acc=>$h->{seq_acc},
                                          });
	$ev->xref(GO::Model::Xref->new({xref_key=>$h->{evdbxref_acc},
                                        xref_dbname=>$h->{evdbxref_dbname}}));
	$assoc->add_evidence($ev);

	if (!$assoc->gene_product){
            dd($h);confess("assertion err")
        }
    }

    if (!@assoc_ids) {
        return [];
    }
    return \@assocs;
}

sub create_assocs_from_hashlist {
    my $self = shift;
    my $dbh = $self->dbh;
    my $hl = shift;
    my $constr = shift || {};

    my @assocs = ();
    my @assoc_lookup = ();
    my @assoc_ids = ();
    foreach my $h (@$hl) {
        if ($h->{a_id}) {
            $h->{id} = $h->{a_id};
        }
        if ($h->{gp_xref_key}) {
            $h->{xref_key} = $h->{gp_xref_key};
        }
        if ($h->{gp_xref_dbname}) {
            $h->{xref_dbname} = $h->{gp_xref_dbname};
        }
	my $assoc = $assoc_lookup[$h->{id}];
        if (!$assoc) {
            $assoc =
              $self->create_association_obj($h);
            $assoc_lookup[$assoc->id] = $assoc;
            $assoc->{term_id} = $h->{term_id};
            push(@assoc_ids, $assoc->id);
        }
	if (!$assoc->gene_product){
            dd($h);confess("assertion err")
        }
    }

    if (!@assoc_ids) {
        return [];
    }
    my $idq = "association_id in (".join(", ", @assoc_ids).")";

#    join(" OR ", map{"association_id = $_"} @assoc_ids);


    # filter based on evidence if requested
    my $filters = $self->filters || {};
    my $evcodes = $constr->{evcodes} || $filters->{evcodes};
    my @w=();
    if ($evcodes) {
	
	my @wanted = grep {$_ !~ /^\!/} @$evcodes;
	my @unwanted = grep {/^\!/} @$evcodes;

	if (@wanted) {
	    push(@w,
		 "(".join(" OR ", 
			  map{"code=".sql_quote($_,1)} @wanted).")");
	}
	if (@unwanted) {
	    push(@w,
		 map{"code!=".sql_quote(substr($_,1))} @unwanted);
	}
    }

    my $el = select_hashlist($dbh,
			     ["evidence", "dbxref"],
			     ["($idq)",
			      @w,
			      "evidence.dbxref_id = dbxref.id"],
			      "*",
			     );

    foreach my $evh (@$el) {
	my $assoc =
	    $assoc_lookup[$evh->{association_id}];
        if (!@{$assoc->evidence_list || []}) {
            # only include an association if
            # it has allowable evidence
            push(@assocs, $assoc);
        }
	my $ev = GO::Model::Evidence->new($evh);
	$ev->xref(GO::Model::Xref->new($evh));
	$assoc->add_evidence($ev);
    }
    return \@assocs;
}

sub get_relationships {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($constr) =
      rearrange([qw(constraints)], @_);

    my @constr_arr = ();
    if (!ref($constr)) {
	confess("constraints must be hashref!");
#	$constr = {"term.name"=>$constr};
    }

    # allow parent/child to be used as synonym for acc1/acc2
    map {
	if ($_ eq "parent") {
	    $constr->{acc1} = $constr->{$_}->acc;
	    delete $constr->{$_};
	}
	if ($_ eq "child") {
	    $constr->{acc2} = $constr->{$_}->acc;
	    delete $constr->{$_};
	}
	if ($_ eq "parent_acc") {
	    $constr->{acc1} = $constr->{$_};
	    delete $constr->{$_};
	}
	if ($_ eq "child_acc") {
	    $constr->{acc2} = $constr->{$_};
	    delete $constr->{$_};
	}
    } keys %$constr;

    my @tables = ("term2term", "term term1", "term term2");
    push(@constr_arr,
	 "term1.id = term2term.term1_id");
    push(@constr_arr,
	 "term2.id = term2term.term2_id");
    my @select_arr = "term2term.*";
    push(@select_arr, "term1.acc AS acc1");
    push(@select_arr, "term2.acc AS acc2");
    if ($constr->{acc1}) {
	push(@constr_arr,
	     "term1.acc = $constr->{acc1}");
	delete $constr->{acc1};
    }
    if ($constr->{acc2}) {
	push(@constr_arr,
	     "term2.acc = $constr->{acc2}");
	delete $constr->{acc2};
    }
    push(@constr_arr, 
	 map {"$_ = ".sql_quote($constr->{$_})} keys %$constr);
    my $hl=
      select_hashlist($dbh,
		      \@tables,
		      \@constr_arr,
		      \@select_arr);
    foreach my $h (@$hl) {
        # support old and new ways of
        # doing rtypes
        if ($h->{relationship_type_id}) {
            $h->{type} =
              $self->{rtype_by_id}->{$h->{relationship_type_id}};
            delete $h->{relationship_type_id};
        }
    }
    my @rels =
      map {GO::Model::Relationship->new($_)} @{$hl};
    return \@rels;
}

sub get_parent_terms {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($node) =
      rearrange([qw(term)], @_);
    my @constr_arr = ();
    my @tables = ("term2term", "term term1", "term term2");
    push(@constr_arr,
	 "term2.id = term2term.term2_id",
	 "term1.id = term2term.term1_id");
    my @select_arr = "term1.*";
    push(@constr_arr,
	 "term2.acc = ".$node->{acc});
    my $hl=
      select_hashlist($dbh,
		      \@tables,
		      \@constr_arr,
		      \@select_arr);
    my @terms =
      map {$self->create_term_obj($_)} @{$hl};
    return \@terms;
}

sub get_child_terms {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($node, $template) =
      rearrange([qw(term template)], @_);
    my @constr_arr = ();
    my @tables = ("term2term", "term term1", "term term2");
    push(@constr_arr,
	 "term2.id = term2term.term2_id",
	 "term1.id = term2term.term1_id");
    my @select_arr = "term2.*";
    if (!ref($node) && int($node)) {
        $node = {acc=>$node};
    }
    $node->{acc} || confess("must specify valid obj/hash - you said $node");
    push(@constr_arr,
	 "term1.acc = ".$node->{acc});
    my $hl=
      select_hashlist($dbh,
		      \@tables,
		      \@constr_arr,
		      \@select_arr);
    my @terms =
      map {$self->create_term_obj($_)} @{$hl};
    return \@terms;
}

sub get_node_graph {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($acc, $max_depth, $template, $termh) =
      rearrange([qw(acc depth template termh)], @_);
    $template = $template || {};
    my $term_template = $template->{terms} || undef;

    my $term;
    # be liberal in what we accept:
    # either an accession as an ID or
    # a query constraint hash
    $acc = $acc || $termh;
    if (!$acc) {
        # no acc specified - get graph from root
        $term = $self->get_root_term(-template=>$term_template);
    }
    elsif (ref($acc)) {
        $term = $self->get_term($acc, $term_template);
    }
    else {
        $term = $self->get_term({acc=>$acc}, $term_template);
    }
    my @terms = ($term);
    if (!$term) {@terms = () }
    my $graph = 
      $self->get_graph_by_terms([@terms], $max_depth, $template);
    return $graph;
}

sub graph_template {
    my $self = shift;
    my $t = shift || {};
    if ($t eq "all") {
        $t = {terms=>"all"};
    }
    return $t;
}

sub get_graph {
    my $self = shift;
    my $dbh = $self->dbh;
    $self->get_node_graph(@_);
}


sub extend_graph {
    my $self = shift;

    my ($graph, $acc, $max_depth, $template, $termh) =
      rearrange([qw(graph acc depth template termh)], @_);
    my $g2 = $self->get_graph(
                              -acc=>$acc,
                              -depth=>$max_depth,
                              -template=>$template,
                              -termh=>$termh,
                             );

    $graph->merge($g2);
}


sub get_graph_below {
    my $self = shift;
    my ($acc, $max_depth, $template, $termh) =
      rearrange([qw(acc depth template termh)], @_);
    my %t = %{$self->graph_template($template) || {}};
    $t{traverse_down} = 1;
    $t{traverse_up} = 0;
    $self->get_graph($acc, $max_depth, \%t, $termh);
}


sub get_graph_above {
    my $self = shift;
    my ($acc, $max_depth, $template, $termh) =
      rearrange([qw(acc depth template termh)], @_);
    my %t = %{$self->graph_template($template) || {}};
    $t{traverse_down} = 0;
    $t{traverse_up} = 1;
    $self->get_graph($acc, $max_depth, \%t, $termh);
}

sub get_graph_by_acc {
    my $self = shift;
    my $dbh = $self->dbh;
    $self->get_node_graph(@_);
}


sub get_graph_by_terms {
    my $self = shift;
    my ($terms, $max_depth, $template, $close_below) =
      rearrange([qw(terms depth template close_below)], @_);

    my $g;
    if ($self->has_path_table) {
        $g = $self->_get_graph_by_terms_denormalized(-terms=>$terms,
                                                     -depth=>$max_depth,
                                                     -template=>$template);
    }
    else {
        $g = $self->_get_graph_by_terms_recursive(-terms=>$terms,
                                                  -depth=>$max_depth,
                                                  -template=>$template);
    }
    if ($close_below) {
        $g->close_below($close_below);
    }
    return $g;
}

sub _get_graph_by_terms_denormalized {
    my $self = shift;

    my ($terms, $max_depth, $template) =
      rearrange([qw(terms depth template)], @_);

    $template = $template || {};
    my $term_template = $template->{terms} || {};

    my $dbh = $self->dbh;

    my $traverse_up = 1;
    if (defined($template->{traverse_up})) {
	$traverse_up = $template->{traverse_up};
    }

    my $traverse_down = 1;
    if (defined($template->{traverse_down})) {
	$traverse_down = $template->{traverse_down};
    }
    my $graph = $self->create_graph_obj;

    my $fetch_all = 0;
    my $all = $self->{_term_count};
    if ($all && scalar(@$terms) == $all) {
        $fetch_all = 1;
    }
    else {
        if (!@$terms) { return $graph }
    }

    my @rhl;
    if ($traverse_down &&
        !(defined($max_depth) && $max_depth == 0)) {
        my @cl = ();
        unless ($fetch_all) {
            @cl =
              "(".
                join(" OR ",
                     map {"$PATH.term1_id=".$_->id} @$terms).
                       ")";
        }
        push(@cl,
             "$PATH.term2_id=term2term.term1_id");
        if (defined($max_depth) && $max_depth > -1) {
            push(@cl, "distance <= ".($max_depth-1));
        }
        my $hl =
          select_hashlist($dbh,
                          ["term2term", "$PATH"],
                          \@cl,
                          "distinct term2term.*");
        @rhl = @$hl;
    }
    else {
        @rhl = ();
    }

    if ($traverse_up) {
        my @cl = ();
        unless ($fetch_all) {
            @cl = 
              "(".
                join(" OR ",
                     map {"$PATH.term2_id=".$_->id} @$terms).")";
        }
        push(@cl,
             "$PATH.term1_id=term2term.term2_id");
        my $hl =
          select_hashlist($dbh,
                          ["term2term", "$PATH"],
                          \@cl,
                          "distinct term2term.*");
        push(@rhl, @$hl);
    }

    # keep a fast array lookup table, keyed by db id
    my @term_lookup = ();

    # fill it with what we already know
    map {$term_lookup[$_->id] = $_} @$terms;

    # todo : use an array for speed
    my %ids_to_get = ();
    foreach my $rh (@rhl) {
        foreach my $id ($rh->{term1_id}, $rh->{term2_id}) {
            if (!$term_lookup[$id] && !$ids_to_get{$id}) {
                $ids_to_get{$id} =1
            }
        }
    }
    my %extra_h = ();
    my $new_terms = 
      $self->get_terms({idlist=>[keys %ids_to_get],
                       %extra_h},
                       $term_template);
    map {$term_lookup[$_->id] = $_} @$new_terms;
        
    my @all_terms = (@$terms, @$new_terms);
    map {$graph->add_term($_)} @all_terms;

    # now lets add the arcs to the graph

    foreach my $rh (@rhl) {
        my $type = $rh->{type};
        my $t1 = $term_lookup[$rh->{term1_id}];
        my $t2 = $term_lookup[$rh->{term2_id}];
        if ($t2) {
            $t1 || confess("assertion error");
            my $rel =
              GO::Model::Relationship->new({acc1=>$t1->acc,
                                            acc2=>$t2->acc});
            $rel->is_inheritance($rh->{is_inheritance});
            $type && $rel->type($type);
            if ($rh->{relationship_type_id}) {
                $rel->type($self->{rtype_by_id}->{$rh->{relationship_type_id}});
            }
            $graph->add_relationship($rel);
        }
        else {
            $graph->add_trailing_edge($t1->acc, $rh->{term2_id});
        }
    }

    $graph->focus_nodes([@$terms]);

    if (0) {
        # populate leaf node counts
        map {$_->n_deep_products(-1)} @{$graph->get_all_nodes};
        my $leafs = $graph->get_leaf_nodes;
        my $countl = $self->get_deep_product_count({terms=>$leafs, per_term=>1});
        foreach my $c (@$countl) {
            $term_lookup[$c->{term_id}]->n_deep_products($c->{"c"});
        }
    }
    return $graph;
}


# recusrively fetch a graph
sub _get_graph_by_terms_recursive {
    my $self = shift;

    my ($terms, $max_depth, $template) =
      rearrange([qw(terms depth template)], @_);

    $template = $template || {};
    my $term_template = $template->{terms} || undef;
    my $dbh = $self->dbh;

    my $traverse_up = 1;
    if (defined($template->{traverse_up})) {
	$traverse_up = $template->{traverse_up};
    }
    my $traverse_down = 1;
    if (defined($template->{traverse_down})) {
	$traverse_down = $template->{traverse_down};
    }
    my $graph = $self->create_graph_obj;

#    my @upnodes = 
#      map {{depth=>0, acc=>$_->acc}} @$terms;

    my @donenodes = ();
    if (@$terms && $traverse_up) {
        # OK, I'm sacrificing clarity in favour of fast
        # retrieval here;
        # ascend the DAG first of all purely by using the 
        # term2term table; then fetch all the term objects

        # get the starting points
        my @nodes =
          map {$_->id} @$terms;
        
        # keep a list of all node ids
        my @allnodes = ();

        # lookup table of node->parents
        # (use array rather than hash for speed)
        # the table is indexed by child node database id;
        # the entry is actually a length-two array
        # of [type, parentnode_database_id]
        my @parentnode_lookup = ();

        # depth we have traversed so far
	# (since we are traversing upwards this
	#  is really height)
        my $depth = 0;

        # keep going while we have node ids to search
        while (@nodes && $traverse_up) {
	    
	    # filter out ones we already
	    # know the parents for
	    @nodes =
		grep {
		    !$parentnode_lookup[$_]
		} @nodes;

	    if (!@nodes) {
		next;
	    }
	    # keep running total
            push(@allnodes, @nodes);

            # lets grab the next level up in one fell swoop...
            my $hl =
              select_hashlist($dbh,
                              "term2term",
                              join(" OR ", 
                                   map {"term2_id = $_"} @nodes));
            # should we split this in case of
            # whole-graph retrievals?

            my @next_nodes = ();    # up one level
            foreach my $h (@$hl) {
                # add to the lookup table
                if (!$parentnode_lookup[$h->{term2_id}]) {
                    $parentnode_lookup[$h->{term2_id}] = 
                      [[$h->{relationship_type},
                        $h->{relationship_type_id},
			$h->{term1_id}]];
                }
                else {
                    push(@{$parentnode_lookup[$h->{term2_id}]},
                         [$h->{relationship_type},
                          $h->{relationship_type_id},
			  $h->{term1_id}]);
                }
                # we may have duplicates here but thats fine
                push(@next_nodes, $h->{term1_id});
            }
        #depth 20 is not enough to flybase Anatomy Ontology
	    if ($depth > 95) {
		# crappy way to detect cycles....
		confess("GRAPH CONTAINS CYCLE");
	    }
	    # lets continue up to the next level
            @next_nodes = 
              grep { !$donenodes[$_] } @next_nodes;
	    @nodes = @next_nodes;
            map { $donenodes[$_] = 1 } @next_nodes;
            $depth++;
        }
        # ok, now lets get the terms

        # keep a fast array lookup table, keyed by db id
        my @term_lookup = ();

        # fill it with what we already know
        map {$term_lookup[$_->id] = $_} @$terms;

        # 
        my @ids_to_get = ();
        foreach my $nodeid (@allnodes) {
            if (!$term_lookup[$nodeid]) {
                push(@ids_to_get, $nodeid);
            }
        }
        my $new_terms = 
          $self->get_terms({idlist=>\@ids_to_get}, $term_template);
        map {$term_lookup[$_->id] = $_} @$new_terms;
        
        my @all_terms = (@$terms, @$new_terms);
        map {$graph->add_term($_)} @all_terms;
        # now lets add the arcs to the graph

        foreach my $term (@all_terms) {
            foreach my $entry (@{$parentnode_lookup[$term->id]}) {
                my ($type, $type_id, $id) = @$entry;
                my $t2 = $term_lookup[$id];
                if ($t2) {
                    my $rel =
                      GO::Model::Relationship->new({acc1=>$t2->acc,
                                                    acc2=>$term->acc});
                    $rel->type($type);
                    # we have to support both ways of doing rtypes
                    # to support old schemas
                    if ($type_id) {
                        $rel->type($self->{rtype_by_id}->{$type_id});
                    }
                    $graph->add_relationship($rel);
                }
                else {
                }
            }
        }
    }

    if (@$terms && $traverse_down) {
        # OK, I'm sacrificing clarity in favour of fast
        # retrieval here;
        # descend the DAG first of all purely by using the 
        # term2term table; then fetch all the term objects

        # get the starting points
        my @nodes =
          map {$_->id} @$terms;
        
        # keep a list of all node ids
        my @allnodes = ();

        # array index of all nodes that have been traversed
        my @doneindex = ();
        # lookup table of node->children
        # (use array rather than hash for speed)
        # the table is indexed by parent node database id;
        # the entry is actually a length-two array
        # of [type, childnode_database_id]
        my @childnode_lookup = ();

        # depth we have traversed so far
        my $depth = 0;

	if (defined($max_depth) && $max_depth > -1 && !$max_depth) {
	    # done!
	    @nodes = ();
	}
        # keep going while we have node ids to search
        while (@nodes && $traverse_down) {
            push(@allnodes, @nodes);
            map { $doneindex[$_] = 1 } @nodes;
            # lets grab the next level down in one fell swoop...
            my $hl =
              select_hashlist($dbh,
                              "term2term",
                              join(" OR ", 
                                   map {"term1_id = $_"} @nodes));
            # should we split this in case of
            # whole-graph retrievals?

            my @next_nodes = ();    # down one level
            foreach my $h (@$hl) {
                # add to the lookup table
                if (!$childnode_lookup[$h->{term1_id}]) {
                    $childnode_lookup[$h->{term1_id}] = 
                      [[$h->{relationship_type},
                        $h->{relationship_type_id},
			$h->{term2_id}]];
                }
                else {
                    push(@{$childnode_lookup[$h->{term1_id}]},
                         [$h->{relationship_type},
                          $h->{relationship_type_id},
			  $h->{term2_id}]);
                }
                # we may have duplicates here but thats fine
                push(@next_nodes, $h->{term2_id});
            }
            if (defined($max_depth) && $max_depth >-1 && 
		$depth >= $max_depth) {
                # done!
                @nodes = ();
            }
            else {
                # lets continue to the next level
                # make sure we don't follow cycles:
                @nodes = grep { !$donenodes[$_] } @next_nodes;
                map {$donenodes[$_]=1 } @nodes;
            }
            $depth++;
        }
        # ok, now lets get the terms

        # keep a fast array lookup table, keyed by db id
        my @term_lookup = ();

        # fill it with what we already know
        map {$term_lookup[$_->id] = $_} @$terms;

        # 
        my @ids_to_get = ();
        foreach my $nodeid (@allnodes) {
            if (!$term_lookup[$nodeid]) {
                push(@ids_to_get, $nodeid);
            }
        }
        my %extra_h = ();
        my $new_terms = 
          $self->get_terms({idlist=>\@ids_to_get,
                            %extra_h},
                           $term_template);
        map {$term_lookup[$_->id] = $_} @$new_terms;
        
        my @all_terms = (@$terms, @$new_terms);
        map {$graph->add_term($_)} @all_terms;
        # now lets add the arcs to the graph

        foreach my $term (@all_terms) {
            foreach my $entry (@{$childnode_lookup[$term->id]}) {
                my ($type, $type_id, $id) = @$entry;
                my $t2 = $term_lookup[$id];
                if ($t2) {
                    my $rel =
                      GO::Model::Relationship->new({acc1=>$term->acc,
                                                    acc2=>$t2->acc});
                    $rel->type($type);
                    # we have to support both ways of doing rtypes
                    # to support old schemas
                    if ($type_id) {
                        $rel->type($self->{rtype_by_id}->{$type_id});
                    }
#                    printf STDERR "%s %s %s\n",
#                      $t2->acc, $rel->type, $term->acc;
                    $graph->add_relationship($rel);
                }
                else {
                }
            }
        }
        # phew! we're done
    }
    else {
    }
    $graph->focus_nodes([@$terms]);
    return $graph;
}

sub get_graph_by_search {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($srch, $max_depth, $template) =
      rearrange([qw(search depth template)], @_);

    $template = $template || {};
    my $term_template = $template->{terms} || undef;

    my $term_l = 
      $self->get_terms({search=>$srch}, $term_template);
    my $graph =
      $self->get_graph_by_terms($term_l, $max_depth, $template);
    return $graph;
}

sub get_product_count {
    my $self = shift;
    my $constr = shift;
    my $c = 
      $self->get_products(-constraints=>$constr,
                          -options=>{count=>1});
    return $c;
}

sub get_deep_product_count {
    my $self = shift;
    my $constr = shift || {};
    my $dbh = $self->dbh;
    if (!$self->has_count_table) {
        if ($constr->{per_term}) {
            return [];
        }
        else {
            return 0;
        }
    }
    my $filters = $self->filters || {};
    my $termconstr = $constr->{terms} || $constr->{term};
    if (!ref($termconstr) || ref($termconstr) ne "ARRAY") {
        $termconstr = [$termconstr];
    }
    my @terms = 
      map {
          if (ref($_) eq "HASH") {
              $self->get_term($_);
          }
          elsif (ref($_)) {
              # already is a term object
              $_;
          }
          else {
              $self->get_term({acc=>$_});
          }
      } @$termconstr;
    my @tables = qw(gene_product_count);
    my @where = ();
    my $spdbs = 
      $filters->{speciesdb} ||
        $filters->{speciesdbs} ||
          $constr->{speciesdb} ||
            $constr->{speciesdbs};

    if ($spdbs) {
        if (!ref($spdbs)) {
            $spdbs = [$spdbs];
        }
        
        my @wanted = grep {$_ !~ /^\!/} @$spdbs;
        my @unwanted = grep {/^\!/} @$spdbs;
        
        if (@wanted) {
            push(@where,
                 "(".join(" OR ", 
                      map{"speciesdbname=".sql_quote($_,1)} @wanted).")");
        }
        if (@unwanted) {
            push(@where,
                 map{"speciesdbname!=".sql_quote(substr($_,1))} @unwanted);
        }
    }

    if (@terms) {
        my @termids = map {$_->id} @terms;
        push(@where,
             "term_id in (".join(", ", @termids).")");
    }

    my $hl =
      select_hashlist(-dbh=>$dbh,
                      -tables=>\@tables,
                      -where=>\@where,
                      -columns=>["term_id",
                                 "sum(product_count) AS c"],
                      -group=>["term_id"]);
    if (!$constr->{per_term}) {
        return $hl->[0]->{"c"};
    }
    return $hl;
}

sub get_product {
    my $self = shift;
    my $pl = $self->get_products(@_);
    return shift @$pl;
}

sub get_deep_products {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($inconstr, $template, $options) =
      rearrange([qw(constraints template options)], @_);
    return $self->get_products({%$inconstr, deep=>1}, $template, $options);
}

sub get_products {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($inconstr, $template, $options) =
      rearrange([qw(constraints template options)], @_);
    my $constr = {%{$inconstr || {}}};        # make copy
    my @constr_arr =  ();
    $template = $template || {};
    my $filters = $self->filters || {};

    # usually the sql ensures uniqueness of results;
    # if >1 term is being queried we could get same 
    # product twice, in which case we flag this
    # and we make sure there are no duplicates at
    # the end
    my $ensure_unique = 0;

    push (@constr_arr, "gene_product.dbxref_id = dbxref.id");
    my @tables_arr = ("gene_product", "dbxref");
    if (!ref($constr)) {
        # be liberal in what we accept; user should
        # really pass in a hashref, but we accept GO IDs etc
        my $term = $self->get_term($constr, {acc=>1});
        if (!$term) {
            $term = $self->get_term({search=>$constr}, {acc=>1});
        }
        if (!$term) {
            confess("$constr is illegal as a first argument for get_products()");
        }
        $constr = {id=>$term->id};
    }
    if ($constr->{xref}) {
	$constr->{acc} = $constr->{xref}->{xref_key};
	$constr->{speciesdb} = $constr->{xref}->{xref_dbname};
    }
    if ($constr->{term}) {
        $constr->{terms} = [$constr->{term}];
    }
    if ($constr->{terms}) {
        my $op = $constr->{operator} || "or";
        my $n = 1;
        if ($op eq "and") {
            $n = scalar(@{$constr->{terms}});
        }
        my $terms = $constr->{terms};
        for (my $i=0; $i<$n; $i++) {
            my $sfx = $op eq "and" ? $i : "";
            my $assoc_table = "association$sfx";
            my $evid_table = "evidence$sfx";
            my $path_table = "$PATH$sfx";
            my $term_table = "term$sfx";
            if ($op eq "and") {
                $terms = [$constr->{terms}->[$i]];
            }
            push(@constr_arr, 
                 "$assoc_table.gene_product_id = gene_product.id");
            push(@tables_arr, 
                 "association AS $assoc_table");
            if ($constr->{deep}) {
                # this part could be speeded up...
                my @terms =
                  map {
                      if (ref($_) eq "HASH") {
                          $self->get_term($_);
                      } elsif (ref($_)) {
                          # already is a term object
                          $_;
                      } else {
                          $self->get_term($_);
                      }
                  } @$terms;
                # speed up the above!!!

                if ($self->has_path_table) {
                    # the path table has been filled;
                    # we can take advantage of this
                    # denormalisation and not do
                    # a recursive query
                    my $negop = $constr->{negoperator} || "";
                    unless ($negop) {

                        my $orq = 
                          join(",", map {$_->id} @terms);
                        
                        if ($orq) {
                            push(@tables_arr,
                                 "$PATH as $path_table");
                            push(@constr_arr,
                                 "$path_table.term2_id = $assoc_table.term_id",
                                 "$path_table.term1_id $negop in ($orq)");
                        }
                    }
                    else {
                        # fetch everything that is NOT IN termlist
                        # AND _could not_ be in term list
                        # (eg any parent of anything in termlist)
                        confess("alpha code - requires postgres");
                    }
                } else {
                    # there is no denormalised path table;
                    # we have to do this recursively
                    my $g = 
                      $self->get_graph_by_terms(\@terms, 
                                                -1,
                                                {traverse_up=>0,
                                                 terms=>{acc=>1,id=>1}});
                    my @term_ids = map {$_->id} @{$g->get_all_nodes || []};
                    $ensure_unique = 1;
                    my $orq = 
                      join(" OR ", map {"$assoc_table.term_id = $_"} @term_ids);
                    if ($orq) {
                        push(@constr_arr, "($orq)");
                    }
                }
            } else {
                # non-deep; ie directly attached to term

                if (@$terms > 1) {
                    $ensure_unique = 1;
                }
                push(@constr_arr,
                     "$assoc_table.gene_product_id = gene_product.id");
            
                # list of terms to constrain by;
                # we are liberal in what we expect;
                # can be a list of objects, refs,
                # GO IDs or names
                my @ors = ();
                foreach my $t (@$terms) {
                    my $c = "";
                    if (ref($t)) {
                        if ($t->{id}) {
                            $c = "$term_table.id = $t->{id}";
                        } elsif ($t->{acc}) {
                            $c = "$term_table.acc = $t->{acc}";
                        } elsif ($t->{name}) {
                            $c = "$term_table.name = ".sql_quote($t->{name});
                        } else {
                            confess("$t contains no keyable atts");
                        }
                    } else {
                        if (int($t)) {
                            $c = "$term_table.acc = $t";
                        } else {
                            $c = "$term_table.name = ".sql_quote($t);
                        }
                    }
                    push(@ors, $c);
                }
                if (@ors) {
                    push(@constr_arr,
                         "(".join(" OR ", @ors).")");
                    push(@tables_arr,
                         "term $term_table");
                    push(@constr_arr,
                         "$assoc_table.term_id=$term_table.id");
                }
            }                   # -- end of term fetching

            # --- EVIDENCE CODES ---
            # uhoh - duplicated code; could do with refactoring
            my $evcodes = $constr->{evcodes} || $filters->{evcodes};
            my @w=();
            if ($evcodes) {
            
                my @wanted = grep {$_ !~ /^\!/} @$evcodes;
                my @unwanted = grep {/^\!/} @$evcodes;

                if (@wanted) {
                    push(@w,
                         "(".join(" OR ", 
                                  map{"$evid_table.code=".sql_quote($_,1)} @wanted).")");
                }
                if (@unwanted) {
                    push(@w,
                         map{"$evid_table.code!=".sql_quote(substr($_,1))} @unwanted);
                }
                push(@tables_arr,
                     "evidence $evid_table");
                unshift(@constr_arr, 
                        "$evid_table.association_id = $assoc_table.id", 
                        @w);
            }
        }
        # end of terms constraint
    }
    map {
	if (defined($constr->{$_})) {
            my $op = "=";
            my $v = $constr->{$_};
            if ($v =~ /\*/) {
                $v =~ s/\*/\%/g;
                $op = "like";
            }
	    push(@constr_arr, "gene_product.$_ $op ".sql_quote($v));
	}
    } qw(symbol full_name id);

        # CONSTRAIN BY SPECIESDB
        my $spdbs = 
          $filters->{speciesdb} ||
            $filters->{speciesdbs} ||
              $constr->{speciesdb} ||
                $constr->{speciesdbs};

        if ($spdbs) {
            delete $constr->{speciesdb};
            delete $constr->{speciesdbs};

            if (!ref($spdbs)) {
                $spdbs = [$spdbs];
            }
            
            my @wanted = grep {$_ !~ /^\!/} @$spdbs;
            my @unwanted = grep {/^\!/} @$spdbs;
            
            if (@wanted) {
                push(@constr_arr,
                     "(".join(" OR ", 
                              map{"dbxref.xref_dbname=".sql_quote($_,1)} @wanted).")");
            }
            if (@unwanted) {
                push(@constr_arr,
                     map{"dbxref.xref_dbname!=".sql_quote(substr($_,1))} @unwanted);
            }
        }

    if ($constr->{acc}) {
        push (@constr_arr, "dbxref.xref_key = ".sql_quote($constr->{acc}));
    }

    my @cols = ("gene_product.*", 
                "dbxref.xref_key AS acc", "dbxref.xref_dbname AS speciesdb");

#    if ($template->{seq_list}) {
#        push(@tables_arr,
#             "gene_product_seq");
#        push(@constr_arr,
#             "gene_product_seq.gene_product_id = gene_product.id");
#        push(@cols, "seq_id");
#    }

    if ($options && $options->{count}) {
#        if (!grep {/dbxref\./ && 
#                     $_ !~ /gene_product\.dbxref_id/} @constr_arr) {
#            @tables_arr = grep {$_ ne "dbxref"} @tables_arr;
#            @constr_arr = grep {$_ !~ /dbxref/} @constr_arr;
#            # remove unneeded join for speed
#        }
        # we don't need gene_product table itself
#        @tables_arr = grep {$_ ne "gene_product"} @tables_arr;
#        @constr_arr = grep {$_ !~ /gene_product/} @constr_arr;
        
        if ($constr->{per_term}) {
            my $groupcol = "$PATH.term1_id";
            if (grep {/$PATH/} @tables_arr) {
                if (!$self->has_path_table) {
                    confess("must build path table");
                }
            }
            else {
                $groupcol = "association.term_id";
            }

            @cols = 
              ("$groupcol term_id", "count(distinct gene_product_id) AS c");

            if (!grep{/association/} @tables_arr) {
                push(@tables_arr, "association");
            }
            my $hl = 
              select_hashlist(-dbh=>$dbh,
                              -tables=>\@tables_arr,
                              -where=>\@constr_arr,
                              -columns=>\@cols,
                              -group=>["$groupcol"]);
            return $hl;
        }
        else {
            @cols = ("count(distinct gene_product_id) AS c");
            my $h = 
              select_hash(-dbh=>$dbh,
                          -tables=>\@tables_arr,
                          -where=>\@constr_arr,
                          -columns=>\@cols,
                          );
            return $h->{'c'};
        }
    }
    my $hl = 
      select_hashlist(-dbh=>$dbh,
		      -tables=>\@tables_arr,
		      -where=>\@constr_arr,
                      -distinct=>1,
		      -columns=>\@cols);
    
    my @pl = ();
    my $get_term_ids;
    if (grep {/association/} @tables_arr) {
        $get_term_ids = 1;
    }


    foreach my $h (@$hl) {
	push(@pl,  $self->create_gene_product_obj($h));

	if ($get_term_ids) {
            $pl[$#pl]->{term_id} = $h->{term_id};
        }
    }
    if ($template->{seq_list} && @pl) {
        map {$_->seq_list([])} @pl;
        my @pi = ();
        map {$pi[$_->id] = $_ } @pl;
        my $hl =
          select_hashlist($dbh,
                          "gene_product_seq",
                          "gene_product_id in (".
                          join(",", 
                               map {$_->id} @pl).")",
                         );
        my %seqid2gpid = ();
        foreach my $h (@$hl) {
            if ($seqid2gpid{$h->{seq_id}}) {
                warn("Code makes assumption gps may not share seq ($seqid2gpid{$h->{seq_id}} and $h->{gene_product_id})");
            }
            $seqid2gpid{$h->{seq_id}} = $h->{gene_product_id};
        }
        if (%seqid2gpid) {
            my $seqs = $self->get_seqs({ids=>[keys %seqid2gpid]});
            foreach my $seq (@$seqs) {
                $pi[$seqid2gpid{$seq->id}]->add_seq($seq);
            }
        }
    }
    return \@pl;
}

sub get_seqs {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($constr, $attrs) =
      rearrange([qw(constraints attributes)], @_);
    
    my @table_arr = ("seq");
    my @constr_arr = ();
    if (!ref($constr)) {
	confess("constraints must be hashref!");
    }
    foreach my $att (qw(seq md5checksum id display_id desc)) {
	if (ref($constr) eq "HASH") {
	    if (defined($constr->{$att})) {
		push(@constr_arr, "seq.$att = ".sql_quote($constr->{$att}));
	    }
	}
	else {
	    if (defined($constr->$att())) {
		push(@constr_arr, "seq.$att = ".sql_quote($constr->$att()));
	    }
	}
    }
    if ($constr->{ids}) {
        push(@constr_arr, "id in (".join(",", @{$constr->{ids}}).")");
    }
    if ($constr->{product}) {
        my $product = $constr->{product};
        push(@table_arr, "gene_product_seq");
        if ($product->id) {
            push(@constr_arr,
                 "gene_product_seq.seq_id=seq.id",
                 "gene_product_seq.gene_product_id=".$product->id,
                );
        }
    }
    my @seqs = ();
    my $hl =
      select_hashlist($dbh,
                      \@table_arr,
                      \@constr_arr,
                      "seq.*");
    my @byid = ();
    foreach my $h (@$hl) {
	my $seq = $self->create_seq_obj($h);
	push(@seqs, $seq);
        $byid[$seq->id] = $seq;
    }
    if (@byid) {
        $hl =
          select_hashlist($dbh,
                          ["dbxref", "seq_dbxref"],
                          ["dbxref.id = dbxref_id",
                           "seq_id in (".join(", ", map {$_->id} @seqs).")"],
                          "dbxref.*, seq_id");
        map {
            $byid[$_->{seq_id}]->add_xref(GO::Model::Xref->new($_));
        } @$hl;
    }
                         
    return \@seqs;
}

sub get_seq {
    my $self = shift;
    my $pl = $self->get_seqs(@_);
    return shift @$pl;
}



sub get_species {
    my $sl = shift->get_species_list(@_);
    return $sl->[0];
}

sub get_species_list {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($constr) =
	rearrange([qw(constraints)], @_);
    require "Bio/Species.pm";  # use require in case bp not installed

    if (!$constr) {
        $constr = {};
    }
    my @constr_arr = ();
    if (!ref($constr)) {
        $constr->{speciesdb} = $constr;
    }
    if (defined($constr->{speciesdb})) {
	push(@constr_arr, "xref_dbname = ".sql_quote($constr->{speciesdb}));
    }

    # check its in db
    my $hl =
	select_hashlist($dbh,
			["dbxref", "gene_product"],
			["dbxref.id=gene_product.dbxref_id",
			 @constr_arr],
			"distinct dbxref.xref_dbname AS speciesdb");
    my @sl=();
    foreach my $h (@$hl) {
	my $n = lc($h->{speciesdb});
	$n =~ s/sgd/budding yeast/;
	$n =~ s/fb/fruitfly/;
	$n =~ s/pom.*/fission yeast/;
	$n =~ s/mgi/mouse/;
	$n =~ s/tair/arabidopsis/;
	my $s = 
	  Bio::Species->new;
        $s->common_name($n);
	push(@sl,$s);
    }
    return \@sl;
}

sub get_speciesdb_dict {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($constr) =
	rearrange([qw(constraints)], @_);
    require "Bio/Species.pm";  # use require in case bp not installed

    if (!$constr) {
        $constr = {};
    }
    my @constr_arr = ();
    if (!ref($constr)) {
        $constr->{speciesdb} = $constr;
    }
    if (defined($constr->{speciesdb})) {
	push(@constr_arr, "xref_dbname = ".sql_quote($constr->{speciesdb}));
    }

    # check its in db
    my $hl =
	select_hashlist($dbh,
			["dbxref", "gene_product"],
			["dbxref.id=gene_product.dbxref_id",
			 @constr_arr],
			"distinct dbxref.xref_dbname AS speciesdb");
    my %sd=();
    foreach my $h (@$hl) {
	my $n = lc($h->{speciesdb});
	$n =~ s/sgd/budding yeast/;
	$n =~ s/fb/fruitfly/;
	$n =~ s/pom.*/fission yeast/;
	$n =~ s/mgi/mouse/;
	$n =~ s/tair/arabidopsis/;
	my $s = 
	  Bio::Species->new;
        $s->common_name($n);
        $sd{$h->{speciesdb}} = $s;
    }
    return \%sd;
}

sub get_speciesdbs {
    my $self = shift;
    my $h = $self->get_speciesdb_dict(@_);
    return [keys %$h];
}

sub get_dbxrefs {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($constr) =
	rearrange([qw(constraints)], @_);
    my @constr_arr = ();
    if (!ref($constr)) {
	confess("constraints must be hashref!");
    }
    my @tables = ("dbxref");
    my @select_arr = "*";
    if ($constr->{xref_key}) {
	push(@constr_arr,
	     "xref_key = ".sql_quote($constr->{xref_key}));
	delete $constr->{xref_key};
    }
    if ($constr->{xref_dbname}) {
	push(@constr_arr,
	     "xref_dbname = ".sql_quote($constr->{xref_dbname}));
	delete $constr->{xref_dbname};
    }
    if ($constr->{xref_keytype}) {
	push(@constr_arr,
	     "xref_keytype = ".sql_quote($constr->{xref_keytype}));
	delete $constr->{xref_keytype};
    }
#    push(@constr_arr, 
#	 map {"$_ = ".sql_quote($constr->{$_})} keys %$constr);
    my $hl=
	select_hashlist($dbh,
			\@tables,
			\@constr_arr,
			\@select_arr);
    my @xref_l =
	map {GO::Model::Xref->new($_)} @{$hl};
    return \@xref_l;
}

sub show {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($constr) =
      rearrange([qw(constraints)], @_);
    my $id_h = {};
    my $term  = $self->get_term($constr);
    
}

# maybe usefor for some
# clients to sneakily bypass
# interface into sql
sub _tunnel {
    my $self = shift;
    my $sql = shift;
    my $dbh = $self->dbh;
    if ($sql =~ /^select/) {
	return $dbh->selectall_arrayref($sql);
    }
    return $dbh->do("$sql");
}

sub get_statistics {
    my $self = shift;

    require GO::Stats;
    my $s = GO::Stats->new;
    $s->apph($self);
    $s;
}

sub get_stat_tags {
    my $self = shift;
    my $dbh = $self->dbh;

    my $tags = 
      [
       "gene products"=>"select count(id) from gene_product",
      ];

    map {
	push(@$tags,
	     "$_"=>"select count(id) from term where term_type = '$_'");
    } GO::Model::Term->_valid_types;


    my $hl =
      select_hashlist($dbh,
		      ["dbxref", "gene_product"],
		      "dbxref.id = gene_product.dbxref_id",
		      "distinct dbxref.xref_dbname");
    foreach my $h (@$hl) {
	my $dbname = $h->{"xref_dbname"};
	push(@$tags, $dbname => ["select count(association.id) from association, gene_product, dbxref where association.gene_product_id = gene_product.id and gene_product.dbxref_id = dbxref.id and dbxref.xref_dbname = ".sql_quote($dbname), "select count(gene_product.id) from gene_product, dbxref where gene_product.dbxref_id = dbxref.id and dbxref.xref_dbname = ".sql_quote($dbname)]);
    }
    
    my @rtags = ();
    for (my $i=0; $i < @$tags; $i+=2) {
	my @vals;
	if (ref($tags->[$i+1]) eq "ARRAY") {
	    @vals =
	      map {
		  get_result_column($dbh, $_);
	      } @{$tags->[$i+1]};
	}
	else {
	    @vals=(get_result_column($dbh, $tags->[$i+1]));
	}
	push(@rtags, ($tags->[$i]=>join(" / ", @vals)));
    }
    return \@rtags;
}

sub get_distances {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($termh1, $termh2) =
      rearrange([qw(term1 term2)], @_);
    my $term1 = 
      (ref($termh1) eq "HASH" || !$termh1->id)
	? $self->get_term($termh1, "shallow") : $termh1;
    my $term2 = 
      (ref($termh2) eq "HASH" || !$termh2->id)
	? $self->get_term($termh2, "shallow") : $termh2;
    if ($self->has_path_table) {
        my $hl =
          select_hashlist($dbh,
                          "$PATH",
                          ["term1_id = ".$term1->id,
                           "term2_id = ".$term2->id],
                          "distance");
        return [map {$_->{distance}}@$hl];
    }
    else {
        confess("NOT IMPLEMENTED");
    }
}

sub get_paths_to_top {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($termh, $template) =
      rearrange([qw(term template)], @_);
    my $term =
      (ref($termh) eq "HASH" || !$termh->id)
	? $self->get_term($termh, $template) : $termh;
    my $graph = $self->get_graph_to_top($term->acc, $template);
    return $graph->paths_to_top($term->acc);
}

sub get_graph_to_top {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($acc, $templ) = 
      rearrange([qw(term template)], @_);

    my %t = %{$self->graph_template($templ) || {}};
    $t{traverse_down} = 0;
    $t{traverse_up} = 1;
    $self->get_graph($acc, 0, \%t);
}

sub new_acc {
    my $self = shift;
    my $dbh = $self->dbh;
    my $h =
      select_hash($dbh,
                  "term",
                  undef,
                  "max(acc)+1 AS acc",
                  );
    my $acc = $h->{acc};
    confess unless $acc;
    return $acc;

}

# temp hack
sub __fix_interpro {
    my $self = shift;
    my $dbh = $self->dbh;

    my $hl=
      select_hashlist($dbh,
                      "dbxref",
                      {xref_dbname=>"InterPro"});
    foreach my $h (@$hl) {
        if ($h->{xref_key} =~ /(IPR\d+) (.*)/) {
            my ($k, $d) = ($1, $2);
            my $got =
              select_hash($dbh,
                          "dbxref",
                          {xref_key=>$k,
                           xref_dbname=>"interpro"});
            if ($got) {
                eval {
                    update_h($dbh,
                             "term_dbxref",
                             {dbxref_id=>$got->{id}},
                             "dbxref_id=$h->{id}");
                };
                sql_delete($dbh,
                           "dbxref",
                           "id=$h->{id}");
            }
            else {
                update_h($dbh,
                         "dbxref",
                         {xref_key=>$k,
                          xref_desc=>$d},
                         "id=$h->{id}");
            }
        }
    }
}

1;
