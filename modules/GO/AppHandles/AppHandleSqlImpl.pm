# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::AppHandles::AppHandleSqlImpl;

=head1 NAME

GO::AppHandles::AppHandleSqlImpl

=head1 SYNOPSIS

you should never use this class directly. Use GO::AppHandle
(All the public methods calls are documented there)

=head1 DESCRIPTION

implementation of AppHandle for a GO relational database

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
use base qw(GO::AppHandle);
use vars qw($AUTOLOAD $PATH $GPPROPERTY);

$PATH="graph_path";
$GPPROPERTY="gene_product_property";

# should only be instantiated via GO::AppHandle
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my $init_h = shift;
    $self->dbh($self->get_handle($init_h));
    $self->filters({evcodes=>["!IEA"]});
    $self->init;
    return $self;
}

sub init {
    my $self = shift;

    # during november, the path table changed
    # its name to graph_path to make it
    # postgres compatible
    # we should support old and new dbs...
    # (if only mysql had views....)

    my $dbh = $self->dbh;
    eval {
        select_hash($dbh, "graph_path", "id=1");
    };
    if ($@) {
        print STDERR "(You are using a deprecated schema...\n";
        print STDERR "consider upgrading your go db)\n";
        # looks like we are using a pre december release
        # version of the schema
        $PATH="path";
    }

    # thanks to James Smith at Sanger for the optimisation tip..
    $self->{rtype_by_id} = {};
    my $hl = select_hashlist($dbh,
			     "term2term", "1",
			     "distinct term2term.relationship_type_id as I"
			    );
    if (@$hl) {
	my $where = join ',', map $_->{'I'}, @$hl;
	$hl = select_hashlist( $dbh, "term", "id in ($where)", "id, name" );
	foreach my $h (@$hl) {
	    $self->{rtype_by_id}->{$h->{id}} = $h->{name};
	}
    }
    else {
	# empry db
    }
}

# private accessor: the DBI handle
sub dbh {
    my $self = shift;
    $self->{_dbh} = shift if @_;
    return $self->{_dbh};
}

# private accessor: DBMS (mysql/ifx/oracle/etc)
sub dbms {
    my $self = shift;
    if (@_) {
	$self->{_dbms} = shift;
	$ENV{DBMS} = $self->{_dbms};
    }
    return $self->{_dbms};
}

# private accessor: boolean indicating if DB has transactions
# (Default: no; we assume mysql as default)
sub is_transactional {
    my $self = shift;
    $self->{_is_transactional} = shift if @_;
    return $self->{_is_transactional} || 
      ($self->dbms && (lc($self->dbms) ne "mysql"));
}


# private method: makes the connection to the database
sub get_handle {
    my $self = shift;
    my $init_h = shift || {};

    # precedence level 1: resource config file
    my $rcfile = $init_h->{rcfile} || "$ENV{HOME}/.geneontologyrc";
    if (-f $rcfile) {
        my $fh = FileHandle->new($rcfile);
        if ($fh) {
            while(<$fh>) {
                chomp;
                if (/^\#/) { next}
                if (/^$/) { next}
                if (!(/^(\w+)[\s+](.*)$/)) {die}
                unless (defined($init_h->{$1})) {$init_h->{$1} = $2};
            }
            $fh->close;
        }
    }

    my $database_name = 
	$init_h->{dbname} || "go";
    my $dbms = $ENV{DBMS} || $init_h->{'dbms'} || "mysql"; 
    $self->dbms($dbms);
    $dbms =~ s/pg/Pg/;
    my $dsn = $init_h->{dsn} || "dbi:$dbms:$database_name";
    if ($database_name =~ /\@/) {
	my ($dbn,$host) = split(/\@/, $database_name);
	$dsn = "dbi:$dbms:database=$dbn;host=$host";
    }
    elsif ($init_h->{dbhost}) {
	$dsn = "dbi:$dbms:database=$database_name;host=$init_h->{dbhost}";
    }
    if ($dbms eq "Pg") {
        $dsn =~ s/database=/dbname=/;
    }
    
    my $dbiproxy = $init_h->{dbiproxy} || $ENV{DBI_PROXY};
    if ($dbiproxy) {
	$dsn = "dbi:Proxy:$dbiproxy;dsn=$dsn";
    }
    if ($init_h->{port}) {
	$dsn .= ";port=$init_h->{port}";
    }

    if ($init_h->{dsn}) {
	$dsn = $init_h->{dsn};
    }
    if($ENV{SQL_TRACE}) {print STDERR "DSN=$dsn\n"};
    my @params = ();
    if ($init_h->{dbuser}) {
	push(@params,
	     $init_h->{dbuser});
	push(@params,
	     $init_h->{dbauth});
        if($ENV{SQL_TRACE}) {print STDERR "PARAMS=@params\n"};
    }
    my $dbh;
    if ($init_h->{dbh}) {
	$dbh = $init_h->{dbh};
    }
    else {
warn "CONNECTING TO GO $$";
	$dbh = DBI->connect($dsn, @params) || confess($DBI::errstr);
    }
##    my $dbh = DBI->connect($dsn);
##    $dbh->{RaiseError} = 1;
    $dbh->{private_database_name} = $database_name;
    $dbh->{private_dbms} = $dbms;

    if ($dbms eq "mysql") {
    }
    else {
        $self->is_transactional(1);
    }
    $dbh->begin_work if $self->is_transactional;

#    elsif (lc($dbms) eq "pg") {
#        # postgres wont query if there are exceptions
#	$dbh->{AutoCommit} = 1;
#    }
#    else {
#	$dbh->{AutoCommit} = 0;
#    }

    # default behaviour should be to chop trailing blanks;
    # this behaviour is preferable as it makes the semantics free
    # of physical modelling issues
    # e.g. if we have some code that compares a user supplied string
    # with a database varchar, this code will break if the varchar
    # is changed to a char, unless we chop trailing blanks
    $dbh->{ChopBlanks} = 1;
    return $dbh;
}

sub timestamp {
    my $self = shift;
    my $dbh = $self->dbh;

}

sub GO::AppHandles::AppHandleSqlImpl::commit {
    my $self = shift;
    if ($self->is_transactional) {
	$self->dbh->commit;
    }
}

sub DESTROY {
  my $self = shift;
warn "DESTROYING GO CONNECTION $$";
  $self->disconnect;
}

sub disconnect {
    my $self = shift;
    if ($self->dbh) { $self->dbh->disconnect} 
}

sub set {
    my $self = shift;
    my ($readonly) =
      rearrange([qw(readonly)], @_);
    if ($readonly) {
	$self->set_isolation_level("read uncommitted");    # Use ANSI standard
    }
}


# set the isolation level (must be ANSI standard)
sub set_isolation_level {
    my $self = shift;
    my $dbh = $self->dbh;
    my $isolation_level = shift;
    if ($self->is_transactional) {
      my $sth = 
	  $dbh->prepare("set transaction isolation level $isolation_level") ||
	  confess $dbh->errstr;

      $sth->execute() ||
	confess $dbh->errstr;
    }

}


# not ready yet...
sub store_term {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($termh, $user) =
      rearrange([qw(term user)], @_);
    my $dbterm =
      $self->get_term($termh);
    if ($dbterm) {
	my $term = 
	  $self->create_term_obj($termh);
	update_h($dbh,
		 {name=>$term->name,
		  acc=>$term->acc,
		  is_obsolete=>$term->is_obsolete,
		  type=>$term->type,
		  is_root=>$term->is_root});
		 
    }
    else {
	$self->add_term($termh, $user);
    }

}

sub generate_goid {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($user) =
      rearrange([qw(term user)], @_);

    my $acch = 
	select_hash($dbh,
		    "term",
		    [],
		    "max(acc) AS m");
    return (int($acch->{'m'} || "0") +1);
}

sub add_term {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($termh, $user) =
      rearrange([qw(term user)], @_);
    if (!ref($termh)) {
	$termh = {name=>$termh};
    }
#    if (!$termh->{acc}) {
#	$termh->{acc} = $self->generate_goid ($user);
#    }
    my $term = 
      $self->create_term_obj($termh);
    my $h = select_hash($dbh, "term", "acc=".$term->acc);
    my $id;
    my $update_h =
    {name=>$term->name,
     acc=>$term->acc,
     term_type=>$term->type,
     is_obsolete=>$term->is_obsolete,
     is_root=>$term->is_root};
    if ($h) {
	# we already have the term
	$id = $h->{id};
	update_h($dbh,
		 "term",
		 $update_h,
		 "id=$id");
    }
    else {
	$id =
	    insert_h($dbh,
		     "term",
		     $update_h);
    }
    $id or confess("id $id is false");
    $term->id($id);
    $self->update_term ($term, $user, "create");

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
    my ($speciesdb, $user, $max) =
      rearrange([qw(speciesdb user max)], @_);
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
    if ($max) {
	@aids = splice(@aids, 0, $max);
    }
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

sub remove_associations {
    my $self = shift;
    while ($self->remove_associations_partial(@_)) {
	print STDERR "removing assocs....\n";
    }
}

sub remove_associations_partial {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($evcode, $speciesdb) =
      rearrange([qw(evcode speciesdb)], @_);
    my $LIMIT = 50000;
    my @q = ();
    my @t = ();
    if ($evcode) {
	push(@q,
	     sqlin("e.code", $evcode, 1),
	     "e.association_id = a.id");
	push(@t, "evidence AS e");
    }
    if ($speciesdb) {
	push(@q,
	     sqlin("x.xref_dbname", $speciesdb, 1),
	     "x.id = p.dbxref_id",
	     "a.gene_product_id = p.id",
	    );
	push(@t, 
	     "gene_product AS p",
	     "dbxref AS x");
    }
    my $asids =
      select_vallist($dbh,
		     -tables=>["association AS a",
		      @t],
		     -where=>\@q,
		     -columns=>"a.id",
		     -limit=>$LIMIT);
    printf STDERR "GOT:%d\n", scalar(@$asids);
#    if ($max) {
#	@aids = splice(@aids, 0, $max);
#    }
    sql_delete($dbh,
               "evidence",
	       sqlin("association_id", $asids));
    my $pids =
      select_vallist($dbh,
                      ["association AS a",
		       "gene_product AS p",
		      ],
                      ["a.gene_product_id = p.id",
		       sqlin("a.id", $asids)],
                      "p.id");
    my $sids =
      select_vallist($dbh,
		     "gene_product_seq",
		     sqlin("gene_product_id", $pids),
		     "seq_id");
    sql_delete($dbh,
               "gene_product",
               sqlin("id", $pids));
    sql_delete($dbh,
               "association",
               sqlin("id", $asids));
    sql_delete($dbh,
               "gene_product_synonym",
               sqlin("gene_product_id", $pids));
    sql_delete($dbh,
               "gene_product_seq",
               sqlin("gene_product_id", $pids));
    sql_delete($dbh,
               "seq_dbxref",
               sqlin("seq_id", $sids));
    sql_delete($dbh,
               "seq_property",
               sqlin("seq_id", $sids));
    sql_delete($dbh,
               "seq",
               sqlin("id", $sids));
    unless (!$speciesdb && $evcode && scalar(@$evcode) == 1 &&
	    $evcode->[0] eq 'IEA') {
	sql_delete($dbh,
		   "gene_product_count");
    }
    return scalar(@$asids);
}

sub remove_iea {
    my $self = shift;
    my $dbh = $self->dbh;
    my $LIMIT = 250000;

    sql_delete($dbh,
	       "evidence",
	       "code='IEA'");

    my %valid_asidh =
      map {$_=>1}
	@{select_vallist($dbh,
			 "evidence",
			 undef,
			 "distinct association_id")};
    my @togo =
      grep {
	  !$valid_asidh{$_}
      }
	@{select_vallist($dbh,
			 "association",
			 undef,
			 "id")};

    while (@togo) {
	my @ids = splice(@togo, 0, $LIMIT);
	sql_delete($dbh,
		   "association",
		   sqlin("id", \@ids));
    }
    
    my %valid_gpidh =
      map {$_=>1}
	@{select_vallist($dbh,
			 "association",
			 undef,
			 "distinct gene_product_id")};
    my @gptogo =
      grep {
	  !$valid_gpidh{$_}
      }
	@{select_vallist($dbh,
			 "gene_product",
			 undef,
			 "id")};
    while (@gptogo) {
	my $pids = [splice(@gptogo, 0, $LIMIT)];
	my $sids =
	  select_vallist($dbh,
			 "gene_product_seq",
			 sqlin("gene_product_id", $pids),
			 "seq_id");
	sql_delete($dbh,
		   "gene_product",
		   sqlin("id", $pids));
	sql_delete($dbh,
		   "gene_product_synonym",
		   sqlin("gene_product_id", $pids));
	sql_delete($dbh,
		   "gene_product_seq",
		   sqlin("gene_product_id", $pids));
#	sql_delete($dbh,
#		   "seq_dbxref",
#		   sqlin("seq_id", $sids));
#	sql_delete($dbh,
#		   "seq_property",
#		   sqlin("seq_id", $sids));
#	sql_delete($dbh,
#		   "seq",
#		   sqlin("id", $sids));
    }
    return;
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

sub store_species {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($taxid, $binom, $common) =
      rearrange([qw(taxid binom common)], @_);
    my ($genus, @sp) = split(' ', $binom);
    my $species = join(' ', @sp);
    my $id = select_val($dbh, "species", "ncbi_taxa_id=$taxid");
    if ($id) {
	return
	update_h($dbh,
		   "species",
		   {
		    genus=>$genus,
		    species=>$species,
		    common_name=>$common,
		   },
		 "ncbi_taxa_id=$taxid");
    }
    else {
	return
	  insert_h($dbh,
		   "species",
		   {ncbi_taxa_id=>$taxid,
		    genus=>$genus,
		    species=>$species,
		    common_name=>$common,
		   });
    }
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

#false = no such a table or table is empty
sub has_gp_property_table {
    my $self = shift;
    $self->{_has_gp_property_table} = shift if @_;
    if (!defined($self->{_has_gp_property_table})) {
        eval {
            my $h=
              select_hash($self->dbh,
                          "$GPPROPERTY",
                          undef,
                          "count(*) AS c");
            $self->{_has_gp_property_table} = $h->{c} ? 1:0;
        };
        if ($@) {
            $self->{_has_gp_property_table} = 0;
        }
    }
    return $self->{_has_gp_property_table};
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

    sql_delete($dbh, 
               "gene_product_count");
    # we only fill the count table for non IEAs and for all evcodes
    foreach my $ev (@$evcodes) {
        
        my $evstr = $ev;
        if (ref($ev)) {
            $evstr = join(";", sort @{$ev || []});
        }
#        sql_delete($dbh, 
#                   "gene_product_count",
#                   $evstr ? "code=".sql_quote($evstr) : "code is null");
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


sub get_term_loadtime {
    my $self = shift;
    my $dbh = $self->dbh;
    my $acc = shift;

    my $t = select_val($dbh,
		       ["term_audit",
			"term"],
		       ["term.id = term_id",
			"term.acc = ".sql_quote($acc)],
		       "term_loadtime");
    return $t;
}


sub source_audit {
    my $self = shift;
    my $dbh = $self->dbh;

    my $hl =
      select_hashlist($dbh,
		      "source_audit");
    return $hl;
}


sub instance_data {
    my $self = shift;
    my $dbh = $self->dbh;

    my $h =
      select_hash($dbh,
		  "instance_data");
    return $h;

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
	      sprintf("GO:%07d", $_);
          }
          else {
	      $_;
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
                      ["t1.acc = '$t1'",
                       "t2.acc = '$t2'",
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
                      ["t1.acc = '$t1'",
                       "t2.acc = '$t2'",
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
            # HACK! turn acc from integer to GO:nnnnnnn
            if (/^\d+$/) {
                $_ = sprintf("GO:%07d", $_);
            }
        } @$accs;
        my $orq = "acc in (".join(", ", 
                                  map {sql_quote($_) }
                                  @$accs).")";
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
            @yes = ("name", "synonym", "definition", "dbxref", "comment");
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
        if ($selected->{definition} ||
	    $selected->{comment}) {
            $hl3=
              select_hashlist($dbh,
                              ["term", "term_definition"],
                              ["(".
                               join(" OR ",
                                    map {
                                        ($selected->{definition} ? 
					 ("term_definition.term_definition like ".
					  sql_quote($_)) : (),
					 $selected->{comment} ?
					 ("term_definition.term_comment like ".
					  sql_quote($_)) : ())
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

        # negation not dealt with properly...
        if ($constr->{tree}) {
#            no strict "vars";
#            my $t = "term";
#            my $deep;
#            if ($constr->{deep}) {
#                $deep = 1;
#                $t = "superterm";
#                push(@table_arr, 
#                     "term superterm",
#                     "graph_path");
#                push(@where_arr, 
#                     "superterm.id = graph_path.term1_id",
#                     "graph_path.term2_id = term.id");
#            }
#            # eg [and [[not [acc 3677]] [or [[acc 1] [acc 2]]]]]
#            my $tree = $constr->{tree};
#            delete $constr->{tree};
#            delete $constr->{deep};
#            sub r {
#                my $tree = shift;
#                confess($tree) unless ref $tree;
#                my ($n, $v) = @$tree;
#                $n = lc($n);
#                if ($n eq "or") {
#                    return "(".join(" OR ", map {r($_)} @$v).")";
#                }
#                elsif ($n eq "and") {
#                    return "(".join(" AND ", map {r($_)} @$v).")";
#                }
#                elsif ($n eq "not") {
#                    return "(NOT (".r($v)."))";
#                }
#                else {
#                    return "$t.$n = ".sql_quote($v);
#                }
#            }
#            my $where = r($tree);
#            push(@where_arr, $where);
#            use strict "vars";
        }

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
	    my $use_tax_table = 0;

            my $constr_sp = $constr->{speciesdb} || $self->filters->{speciesdb};
            my $constr_taxid = $constr->{taxid} || $self->filters->{taxid};

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

            if ($constr_taxid) {
                if (!ref($constr_taxid)) {
                    $constr_taxid = [$constr_taxid];
                }
                my @yes = grep {$_ !~ /^\!/} @$constr_taxid;
                my @no = grep {/^\!/} @$constr_taxid;
                map {s/^\!//} @no;
                $use_tax_table = 1;
                if (@yes) {
                    push(@where_arr,
                         "gp_tax.ncbi_taxa_id in ".
                         "(".join(", ", @yes).")");
		}
		if (@no) {
                    push(@where_arr,
                         "gp_tax.ncbi_taxa_id in ".
                         "(".join(", ", @no).")");
                }
                delete $constr->{taxid};
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
                #constrain by evidence dbxrefs (only support id for now)
                #reasoning: get terms in association for certain evidence
                #e.g. evidence from one experiment
                #only make sense when constrained by product and evidence code?
                if ($constr->{evidence_dbxref}) {
                    $constr->{evidence_dbxrefs} = $constr->{evidence_dbxref};
                    delete $constr->{evidence_dbxref};
                }
                if ($constr->{evidence_dbxrefs}) {
                    my $e_dbxrefs = $constr->{evidence_dbxrefs};
                    delete $constr->{evidence_dbxrefs};
                    $e_dbxrefs = [$e_dbxrefs] unless (ref($e_dbxrefs) eq 'ARRAY');
                    if ($e_dbxrefs->[0] =~ /^\d+$/) {
                        push(@where_arr,
                             "evidence.dbxref_id in ".
                             "(".join(', ', @$e_dbxrefs).")");
                    } else {
                        confess("Support evidence dbxref id only for now ".$e_dbxrefs->[0]);
                    }
                }
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

		    if (/^synonym$/) {
			my $syn = $prod->{$_};
			my $op = '=';
			if ($syn =~ /\*/) {
			    $syn =~ s/\*/\%/g;
			    $op = 'like';
			}
			$syn = sql_quote($syn);
			push(@table_arr,
			     "gene_product_synonym");
			push(@w,
			     "gene_product_synonym.gene_product_id = gene_product.id",
			     "gene_product_synonym.product_synonym $op $syn");
		    }
		    elsif (/^acc$/ || /^xref$/) {
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
	    if ($use_tax_table) {
		push(@table_arr,
		     "species AS gp_tax");
		push(@where_arr, 
		     "gene_product.species_id = gp_tax.id");
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
                $term_lookup[$_->{term_id}]->comment($_->{term_comment});
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
			      ["dbxref.*", "term_id", "is_for_definition"],
                              ["dbxref.xref_dbname", "dbxref.xref_key", "dbxref.xref_desc", "is_for_definition"]);
	    map {	
		my $isdef = $_->{is_for_definition};
		delete $_->{is_for_definition};
		my $term = $term_lookup[$_->{term_id}];
		if ($isdef) {
		    $term->add_definition_dbxref(GO::Model::Xref->new($_));
		}
		else {
		    $term->add_dbxref(GO::Model::Xref->new($_));
		}
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
      $self->get_term(-constraints=>{is_root=>1},
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
       "gene_product.species_id",
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

    # NCBI Taxa IDs
    my $taxids = 
      $constr->{taxid} ||
        $constr->{taxids} ||
          $filters->{taxid} ||
            $filters->{taxids};

    if ($taxids) {
        if (!ref($taxids)) {
            $taxids = [$taxids];
        }

	push(@tables, "species");
	push(@where, "species.id = gene_product.species_id");

	my @wanted = grep {$_ !~ /^\!/} @$taxids;
	my @unwanted = grep {/^\!/} @$taxids;

	if (@wanted) {
	    push(@where,
		 "(".join(" OR ", 
			  map{"species.ncbi_taxa_id=$_"} @wanted).")");
	}
	if (@unwanted) {
	    push(@where,
		 map{"species.ncbi_taxa_id!=$_"} @unwanted);
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
    my @pl;
    map {
	my $p = $_->gene_product;
	push (@pl, $p) if ($p);
    } @assocs;
    if ($self->has_gp_property_table) {
        $self->_get_product_property(\@pl);
    }
    $self->_get_product_synonyms(\@pl);
    $self->_get_species(\@pl);
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
    my %ph = ();
    foreach (@assocs) {
	$ph{$_->gene_product->id} = $_->gene_product;
    }
    my @ps = values %ph;
    $self->_get_species(\@ps);
    $self->_get_product_synonyms(\@ps);
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
	     "term1.acc = ".sql_quote($constr->{acc1}));
	delete $constr->{acc1};
    }
    if ($constr->{acc2}) {
	push(@constr_arr,
	     "term2.acc = ".sql_quote($constr->{acc2}));
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
	 "term2.acc = ".sql_quote($node->{acc}));
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
	 "term1.acc = ".sql_quote($node->{acc}));
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
                              "term1_id in (".
                              join(",", @nodes).")");
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
              my $t = $_;
              if (!$t->id) {
                  $t = $self->get_term({acc=>$t->acc});
              }
              $t;
          }
          else {
              $self->get_term({acc=>$_});
          }
      } @$termconstr;
    my @tables = qw(gene_product_count);
    my @where = ();
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
                        if ($t =~ /^(\d+)$/ || $t =~ /^GO:(\d+)$/) {
                            $c = "$term_table.acc = ".sql_quote(sprintf("GO:%07d", $1));
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

    # CONSTRAIN BY SEQ ACCESSION
    if ($constr->{seq_acc} ||
	$constr->{seq_name}) {
	my $seq_acc = $constr->{seq_acc};
	my $seq_name = $constr->{seq_name};
	push(@tables_arr,
	     qw(seq gene_product_seq));
	push(@constr_arr,
	     "seq.id = gene_product_seq.seq_id",
	     "gene_product_seq.gene_product_id = gene_product.id");
	if ($seq_acc) {
	    push(@tables_arr,
		 "seq_dbxref", "dbxref AS seqxref");
	    push(@constr_arr,
		 "seq.id = seq_dbxref.seq_id",
		 "seqxref.id = seq_dbxref.dbxref_id",
		 "seqxref.xref_key = ".sql_quote($seq_acc));
	}
	if ($seq_name) {
	    push(@constr_arr,
		 "seq.display_id = ".sql_quote($seq_name));
	}
    }

    # CONSTRAIN BY GENE PRODUCT SYNONYM
    if ($constr->{synonym}) {
	my $synonym = $constr->{synonym};
	push(@tables_arr,
	     qw(gene_product_synonym));
	my $op = '=';
	if ($synonym =~ /\*/) {
	    $op = 'like';
	    $synonym =~ s/\*/\%/g;
	}
	push(@constr_arr,
	     "gene_product_synonym.product_synonym $op ".sql_quote($synonym),
	     "gene_product_synonym.gene_product_id = gene_product.id");
    }

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
    
    # CONSTRAIN BY NCBI Taxa ID
    my $taxids = 
      $filters->{taxid} ||
	$filters->{taxids} ||
	  $constr->{taxid} ||
	    $constr->{taxids};
    
    if ($taxids) {
	delete $constr->{taxid};
	delete $constr->{taxids};
	
	if (!ref($taxids)) {
	    $taxids = [$taxids];
	}
	
	my @wanted = grep {$_ !~ /^\!/} @$taxids;
	my @unwanted = grep {/^\!/} @$taxids;
	
	push(@tables_arr,
	     qw(species));
	push(@constr_arr,
	     "species.id = gene_product.species_id");

	if (@wanted) {
	    push(@constr_arr,
		 "(".join(" OR ", 
			  map{"species.ncbi_taxa_id=$_"} @wanted).")");
	}
	if (@unwanted) {
	    push(@constr_arr,
		 map{"species.ncbi_taxa_id!=$_"} @unwanted);
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
	$pl[$#pl]->{species_id} = $h->{species_id};
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
    # -- GET SPECIES --
    if (@pl) {
	my @spids = map {$_->{species_id}} @pl;
	my %uspids = map {$_=>1} @spids;
	my $hl =
	  select_hashlist($dbh,
			  "species",
			  "id in (".join(",",keys %uspids).")");
	foreach my $h (@$hl) {
	    my $sp = $self->create_species_obj($h);
	    $uspids{$h->{id}} = $sp;
	}
	foreach my $p (@pl) {
	    my $spid = $p->{species_id};
	    delete $p->{species_id};
	    $p->species($uspids{$spid});
	}
    }
    $self->_get_product_property(\@pl);
    $self->_get_product_synonyms(\@pl);
    return \@pl;
}

sub get_all_product_with_seq_ids {
    my $self = shift;
    my $dbh = $self->dbh;
    my $ids = select_vallist($dbh,
			     "gene_product_seq",
			     undef,
			     "distinct gene_product_id");
    return $ids;
}

# internal method:
# sometimes the assoc files don't have
# a one-to-one mapping between accession and symbol
sub get_duplicate_products {
    my $self = shift;
    my $dbh = $self->dbh;
    my $pairs =
      select_rowlist($dbh,
		     "gene_product",
		     undef,
		     "id, dbxref_id");
    my %c = ();
    
    my @xids = ();
    map {
	if ($c{$_->[1]}) {
	    push(@xids, $_->[1]);
	}
	$c{$_->[1]} = 1;
    } @$pairs;
    my $xrefs =
      select_hashlist($dbh,
		      "dbxref",
		      sqlin("id", \@xids));
    return $xrefs;
}

sub _get_product_property {
    my $self = shift;
    my $pds = shift || return;

    $pds = [$pds] unless (ref($pds) eq 'ARRAY');
    if ($self->has_gp_property_table && @{$pds || []}) {
        my %gp_h = ();
        map {push @{$gp_h{$_->id}}, $_}@$pds; #m objs for one gene product id!!
        #check properties have ever been set to prevent from double get--could be expensive
        my (%ids);
        map {$ids{$_->id}++ unless ($_->properties)}@$pds;
        my $p_ids = join(',', keys %ids);
        return unless $p_ids;
        my $p_hl = select_hashlist
          ($self->dbh,
           "$GPPROPERTY",
           ["gene_product_id in ($p_ids)"],
          );
        map {
            my $id = $_->{gene_product_id};
            my $ps = $gp_h{$id};
            foreach my $p (@{$ps || []}) {
                $p->set_property($_->{property_key}, $_->{property_val});
            }
        } @{$p_hl || []};
    }
    return $pds;
}

sub _get_product_synonyms {
    my $self = shift;
    my $pds = shift || return;

    $pds = [$pds] unless (ref($pds) eq 'ARRAY');

    return unless $pds;

    my %ph = map {$_->id=>$_} @$pds;
    my @pids = keys %ph;
    return unless @pids;
    my $hl =
      select_hashlist($self->dbh,
		      "gene_product_synonym",
		      "gene_product_id in (".join(',', @pids).")");
    foreach (@$hl) {
	$ph{$_->{gene_product_id}}->add_synonym($_->{product_synonym});
    }
    return;
}

sub _get_species {
    my $self = shift;
    my $pds = shift || return;

    $pds = [$pds] unless (ref($pds) eq 'ARRAY');

    return unless $pds;

    my %taxid = grep {$_} map {$_->{species_id} => 1} @$pds;
    my @taxids = keys %taxid;
    if (!@taxids) {
	return;
    }

    my $hl =
      select_hashlist($self->dbh,
		      "species",
		      "id in (".join(',', @taxids).")");
    foreach (@$hl) {
	$taxid{$_->{id}} =
	  $self->create_species_obj($_);
    }
    foreach (@$pds) {
	$_->species($taxid{$_->{species_id}});
    }
    return;
}

# lowercases db/acc
sub get_taxa_id_lookup {
    my $self = shift;
    my $dbh = $self->dbh;
    my $hl =
      select_hashlist($dbh,
		      ["dbxref",
		       "gene_product",
		       "species"],
		      ["dbxref.id = gene_product.dbxref_id",
		       "species_id = species.id"],
		      ["xref_dbname", "xref_key", "ncbi_taxa_id"]);
    my %look =
      map {
	  my $k = lc("$_->{xref_dbname}:$_->{xref_key}");
	  ($k => $_->{ncbi_taxa_id})
      } @$hl;
    return \%look;
}

sub get_taxa_id_for_product_acc {
    my $self = shift;
    my $pracc = shift;
    my $dbh = $self->dbh;
    my ($db, @acc) = split(/:/, $pracc);
    my $acc = join(":",@acc);
    my $h =
      select_hash($dbh,
		  ["dbxref",
		   "gene_product",
		   "species"],
		  ["dbxref.id = gene_product.dbxref_id",
		   "species_id = species.id",
		   "xref_dbname = ".sql_quote($db),
		   "xref_key = ".sql_quote($acc)],
		  ["ncbi_taxa_id"]);
    return $h->{ncbi_taxa_id};
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
    my $hl =
	select_hashlist($dbh,
			["species", "gene_product"],
			["species.id=gene_product.species_id"],
			"distinct species.*");
    my @sl =
      map {
	  GO::Model::Species->new($_);
      } @$hl;
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
    if (!$term) {
	return;
    }
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

sub get_matrix {
    my $self = shift;
    my $terms = shift;

    my $dbh = $self->dbh;

    my @term1_ids = map {$_->id} @$terms;
    my $hl =
      select_hashlist($dbh,
                      "graph_path",
                      "term1_id in (".
                      join(",",@term1_ids).")",
                     );
    my $acchl =
      select_hashlist($dbh,
                      "term");
    my %acch=();
    $acch{$_->{id}}  = $_->{acc} foreach @$acchl;

    my %matrix = ();
    foreach my $h (@$hl) {
        my $acc1 = $acch{$h->{term1_id}};
        my $acc2 = $acch{$h->{term2_id}};
        my $distance = $h->{distance};
        $matrix{$acc2} = [] unless $matrix{$acc2};
        push(@{$matrix{$acc2}},
             [$acc1, $distance]);
    }
    return \%matrix;
}

sub map_to_slim {
    my $self = shift;
    my $dbh = $self->dbh;
    my ($slimgraph) =
      rearrange([qw(slimgraph)], @_);
    my $terms = $slimgraph->get_all_nodes;
    my @accs = map {$_->acc} @$terms;
    $terms = $self->get_terms({acc=>[@accs]},
                              {id=>1});

    my %matrix = %{$self->get_matrix($terms)};

    my %fmatrix = ();
    foreach my $acc2 (keys %matrix) {
        my $n1;
        my $m = $matrix{$acc2};
        my @acc1m =
          sort {$a->[1] <=> $b->[1]} @$m;
        # hash of all possible slimterms for this acc
        my %acc1h = map { $_->[0] => 1 } @acc1m;
        my @corr = ();
        while (@acc1m) {
            my $m1 = shift @acc1m;
            my ($acc1, $distance) = @$m1;
            if ($distance == 0) {
                $n1 = $slimgraph->get_term($acc1);
                push(@corr, $n1);
            }
            else {
                my $crs = $slimgraph->get_child_relationships($acc1);
                my @b = grep {$_->type eq "bucket"} @$crs;
                if (@b) {
                    if (grep { $acc1h{$_->acc2} } @$crs) {
                        # no need to put it in a bucket;
                        # term already exists in slim
                    }
                    else {
                        if (scalar(@b) > 1) {
                            warn("odd; >1 @b buckets for $acc1 [from $acc2 $distance]");                    
                        }
                        # map this node to a bucket term
                        $n1 = $slimgraph->get_term($b[0]->{acc2});
                        push(@corr, $n1);
                    }
                }
                else {
                    # corresponds to a leaf node in slim
                    $n1 = $slimgraph->get_term($acc1);
                    if ($slimgraph->is_leaf_node($n1)) {
                        push(@corr, $n1);
                    }
                }
            }
        }
        if (@corr > 1) {
#            warn(">1 correspondence for $acc2: ".
#                 join(" ", map{$_->acc} @corr));
        }
        if (!@corr) {
#            warn("0 correspondence for $acc2: ");
        }
        else {
            my @accs = map {$_->acc} @corr;
            my %u = map {$_=>1} @accs;
            $fmatrix{$acc2} = [keys %u];
#            printf "CORR $acc2 -> @accs\n";
        }
    }                
    return \%fmatrix;
}

sub get_pairs {
    my $self = shift;
    my $dbh = $self->dbh;

    my $rows =
      select_rowlist($dbh,
		     "term2term, term t1, term t2, term rt",
		     "term1_id = t1.id AND t2.id= term2_id AND rt.id = relationship_type_id",
		     "rt.name, t2.acc, t1.acc");
    return $rows;
}

sub get_closure {
    my $self = shift;
    my $dbh = $self->dbh;

    my $root_term = $self->get_root_term;
    my $root_id = $root_term->id;

    my $closure =
      select_rowlist($dbh,
		     ["graph_path AS graph_path",
		      "term2term r",
		      "term p", 
		      "term c", 
		      "term rt",
		     ],
		     [
		      "r.term1_id = p.id",
		      "c.id= r.term2_id",
		      "rt.id = relationship_type_id",
		      "graph_path.term1_id = $root_id",
		      "graph_path.term2_id = r.term2_id",
		     ],
		     [qw(graph_path.term2_id graph_path.id rt.name c.acc p.acc)],
		     [qw(graph_path.term2_id graph_path.id graph_path.distance)],
#		     [qw(graph_path.id)],
		    );
    my @paths = ();
    my $last_path_id = 0;
    foreach my $c (@$closure) {
	if ($c->[0] != $last_path_id) {
	    push(@paths, []);
	}
	$last_path_id = shift @$c;
	push(@{$paths[-1]}, $c);
    }
    return \@paths;
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
