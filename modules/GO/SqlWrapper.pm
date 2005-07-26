# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::SqlWrapper;

=head1 NAME

  GO::SqlWrapper

=head1 SYNOPSIS

  helper functions for creating sql statements

=head1 USAGE

  use GO::SqlWrapper qw(:all);
  use GO::SqlWrapper qw(make_sql_select 
			     make_sql_insert 
			     make_sql_update 
			     sql_delete
                	     db_null 
			     sql_quote);

=cut

use GO::DebugUtils qw(sqllog);
use Carp;

use Exporter;

@EXPORT_OK = qw(make_sql_select
		make_sql_insert
		make_sql_update 
		orterm
		andterm
		db_null 
		sqlin
		sql_quote
		get_iterator
		get_hashrow
		update_h
		insert_h 
		insert_hash 
		insert_hash_wp
		select_hashlist
                select_vallist
                select_structlist
                select_rowlist
		select_hash
		select_val
		select_row
		sql_delete
		get_result_column
		get_autoincrement_val);
%EXPORT_TAGS = (all=> [@EXPORT_OK]);
@GO::SqlWrapper::ISA = qw(Exporter);

use strict;

=head2 db_null

value to represent a database null column value

=cut

sub db_null {
    "NULL"
}



=head2 get_autoincrement_val

args: dbh

returns the id created for the latest insert
(serial cols under informix, auto_increment under mysql)

the default is informix; for this to work under mysql,
the env variable $DBMS must be set to "mysql"

=cut

sub get_autoincrement_val {
    my $dbh = shift;
    my $table = shift;
    my $dbms = $dbh->{private_dbms};
    if (!$ENV{DBMS} || lc($ENV{DBMS}) eq "mysql") {
	return $dbh->{mysql_insertid};
    }
    elsif (lc($dbms) eq "pg") {
        my $id;
        if (grep {$table eq $_}
            qw(
               term_dbxref
               term_synonym
              )) {
            return;
        }
        eval {
            my $h = 
              select_hash($dbh,
                          $table."_id_seq",
                          undef,
                          "last_value AS lv"); 
            confess unless $h->{lv};
            print STDERR "LAST VAL=$h->{lv}\n" if $ENV{SQL_TRACE};
            $id = $h->{lv};
        };
        if ($@) {
            warn("Couldn't get id for $table");
            return 0;
        }
        return $id;
    }
    else {
	return $dbh->{ix_sqlerrd}[1];
    }
}

=head2 make_sql_select

 usage: make_sql_select({select_arr=>\@columns,
			 table_arr=>\@tables,
			 where_arr=>\@and_clauses},
		         order_arr=>\@order_columns);

returns: sql string

will remove duplicate items in the above arrays

=cut

sub make_sql_select {

    my %query = %{shift || carp("No query hash specified")};
    
    if (!@{$query{table_arr}}) {
	confess("No table specified in query");
    }
    if (!@{$query{select_arr}}) {
	confess("No columns specified in query");
    }

    # first of all, we have to check for the scenario whereby
    # a table has been specified twice, once as an outer join
    # the other time as a normal table
    # - we replace this with a single entry (so remove duplicates
    #   below spots that they are the same), discarding the "outer"
    # it is presumed an outer join is not required, unless all instances
    # of that table in the {table_arr} are specified as outer
    my $i=0;
    for ($i=0; $i<@{$query{table_arr}}; $i++) {
	if ($query{table_arr}->[$i] =~ /outer /) {
	    my $actual_table_name = $query{table_arr}->[$i];
	    $actual_table_name =~ s/outer //;
	    my $j=0;
	    for ($j=0; $j<@{$query{table_arr}}; $j++) {
		if ($query{table_arr}->[$j] eq $actual_table_name) {
		    $query{table_arr}->[$i] = $actual_table_name;
		}
	    }
	}
    }

    # build the sql statement from the $query structure
    my @select_cols = remove_duplicates($query{select_arr});
    my $select_text = join(", ", @select_cols);
    if (!$select_text) {
	$select_text = "*";
    }
    if ($query{distinct}) {
	$select_text = "distinct $select_text";
    }
    my $sql = "select ".$select_text;
    $sql.= " from ".join(", ", 
			 remove_duplicates($query{table_arr}));
    my @where_arr = remove_duplicates($query{where_arr});
    if (@where_arr) {
	$sql.= " where ".join(" and ", @where_arr);
    }
    my @order_arr = @{$query{order_arr} || []};
    if (@order_arr) {
	$sql.= " order by ".join(", ", @order_arr);
    }
    return $sql;
}

=head2 sqlin

  Usage   -
  Returns -
  Args    -

=cut

sub sqlin {
    my $fld = shift;
    my @ids = @{shift || []};
    my $qt = shift;
    
    @ids = grep {$_} @ids;
    if (!@ids) {
        @ids = $qt ? ('') : (0);
    }
    if ($qt) {
        return "$fld in (".join(",",map {sql_quote($_)} @ids).")";
    }
    return "$fld in (".join(",",@ids).")";
}



=head2 sql_quote

escapes any quotes in a string, so that it can be passed
to a sql engine safely

usage: sql_quote($col_value)

=cut

sub sql_quote {
    my $string = shift;
    # escape real quotes by double-quoting
    if (!$string) {
	return "";
    }
    $string =~ s/\'/\'\'/g;

    # also escape any backslashes
    $string =~ s/\\/\\\\/g;

    return "'".$string."'";
}

=head2 make_sql_insert

 usage: my $sql_stmt = make_sql_insert($table, \%entry_h)

  given a list of name/values pairs for the entry hash, turns
  it into an SQL statement.

all values will be sql-quoted (surrounded by single quotes, actual
quotes are escaped by preceeding the quote with another quote). in
cases where you do not want the value quoted (e.g. if the values you
are inserting must be dynamically fetched with an sql statement), then
you should pass the values as a hash, rather than a string. the hash
keys should by 'type' and 'val'. if 'type' is char or varchar, the
string is quoted, other wise it is unquoted.

for example:

my $sql = make_sql_insert("seq2ext_db", 
			  {seq_id=>900,
			   name=>"AC000052",
			   ext_db_id=>{type=>"sql",
				       val=>"(select id from ext_db ".
				            "where name = 'genbank')"}});

will produce:

insert into seq2ext_db (seq_id, name, ext_db_id) values ('900',
'AC000052', (select id from ext_db where name = 'genbank'))

=cut

sub make_sql_insert {
  my ($table, $entry) = @_;
  
  my $key;
  my $names = "";
  my $values = "";

  foreach $key (keys %{$entry}) {
      if (!defined($entry->{$key})) {
	  delete $entry->{$key};
      }
  }

  $names = join(", ", keys %{$entry});
  $values = join(", ",
		 map {
		     if (ref($entry->{$_})) {
			 if ($entry->{$_}->{'type'} =~ /char/) {
			     sql_quote($entry->{$_}->{val});
			 }
			 else {
			     $entry->{$_}->{val}
			 }
		     }
		     else {
			 sql_quote($entry->{$_});
		     }
		 } keys %{$entry});

  my $sql = "insert into $table ";
  $sql .= "($names) values ($values);";

  return $sql;
}


=head2 make_sql_update

=cut

sub make_sql_update {
  my ($table, $entry, $where_r) = @_;
  
  my $key;
  my $names = "";
  my $values = "";

  # where clause can be ref to an array or the actual text of the clause
  my $where = $where_r;
  if (ref($where_r)) {
      $where = join(" and ", @{$where_r});
  }
  
  $names = join(", ", keys %{$entry});
  $values = join(", ",
		 map {
		     if (ref($entry->{$_})) {
			 if ($entry->{$_}->{'type'} =~ /char/) {
			     sql_quote($entry->{$_}->{val});
			 }
			 else {
			     $entry->{$_}->{val}
			 }
		     }
		     else {
			 sql_quote($entry->{$_});
		     }
		 } keys %{$entry});

  my $sql = "update $table set ";
  $sql .= "($names) = ($values) where $where;";

  return $sql;
}

=head2 select_hashlist

selects rows from the database and returns the results as an
array of hashrefs

parameters: dbh, tables, where, columns

the sql parameters can be either strings or arrays of strings

eg

  select_hashlist($dbh, "clone");     # gets all results from clone table

or
  
  select_hashlist($dbh, 
		  ["seq", "seq_origin"], 
		  ["seq.id" = "seq_origin.seq_id"],
		  ["seq.id"]);    # gets a list of all seq_ids with origin

=cut

sub select_hashlist {

    my $iterator = get_iterator(@_);
    my $hashr;
    my @hashes = ();
    while ($hashr = get_hashrow($iterator)) {
	push(@hashes, ($hashr));
    }
    return \@hashes;
}



=head2 select_hash

=cut

sub select_hash {

    my $hl = select_hashlist(@_);
    return $hl->[0];
}



=head2 select_structlist

  Usage   -
  Returns -
  Args    - dbh, name, tables, where, cols

=cut

sub select_structlist {
    my $dbh = shift;
    my $name = shift;
    my $hl =
      select_hashlist($dbh, @_);
    return [
            map {
                my $h = $_;
                [$name =>
                 [
                  map {
                     [$_ => $h->{$_}],
                 } keys %$h
                 ]
                ]
            } @$hl
           ];
}

=head2 select_vallist

  Usage   -
  Returns -
  Args    -

as select hashlist, returns a list of scalars

=cut

sub select_vallist {
    my $dbh = shift;
#    my $sth = get_iterator($dbh, @_);
    my ($sql, @bind) = get_sql(@_);
#    my $sth = get_iterator($dbh, @_);
    sqllog("$sql [@bind]");
    return $dbh->selectcol_arrayref($sql, {}, @bind);
}


=head2 select_val

  Usage   -
  Returns -
  Args    -

=cut

sub select_val {
    my $dbh = shift;
    my $vals = select_vallist($dbh, @_);
    return shift @$vals;
}

=head2 select_rowlist

  Usage   -
  Returns -
  Args    -

as select hashlist, returns a list of arrays

=cut

sub select_rowlist {
    my $dbh = shift;
    my $sth = get_iterator($dbh, @_);
    return $dbh->selectall_arrayref($sth);
}


=head2 get_hashrow

 parameters: statement handle

=cut

sub get_hashrow {

    my $sth = shift;
    my $hr = $sth->fetchrow_hashref;
    if ($hr) {
	return $hr;
    }
    else {
	if ($sth->err) {
	    confess($sth->err);
	}
	$sth->finish();
	return undef;
    }
}

=head2 get_iterator

 parameters: as for select_hashlist

gets a statement handle for a query. the results can be queried a row
at a time with get_hashrow

=cut

sub get_iterator {

    my ($dbh, $table_arr, $where_arr, $select_arr, $order_arr, $group_arr, $distinct) =
      rearrange(['dbh', 'tables', 'where', 'columns', 'order', 'group', 'distinct'], @_);

    if (!$table_arr) {
	confess("you must specify at least one table");
    }

    # either array or string
    if (!ref($table_arr)) {
	$table_arr = [$table_arr];
    }

    # either array or string
    if ($order_arr && !ref($order_arr)) {
	$order_arr = [$order_arr];
    }

    # either array or string
    if ($group_arr && !ref($group_arr)) {
	$group_arr = [$group_arr];
    }

    my @bind_vals = ();
    # either array or string
    if (!defined($where_arr)) {
	$where_arr = [];
    }
    if (!ref($where_arr)) {
	$where_arr = [$where_arr];
    }
    if (ref($where_arr) eq "HASH") {
	$where_arr =
	  [map {push(@bind_vals, $where_arr->{$_});"$_= ?"} keys %$where_arr];
    }

    if (!$select_arr) {
	$select_arr = ["*"];
    }
    elsif (!ref($select_arr)) {
	$select_arr = [$select_arr];
    }

#    my $sql = make_sql_select({select_arr=>$select_arr,
#			       where_arr=>$where_arr,
#			       table_arr=>$table_arr,
#			       order_arr=>$order_arr});
 
    my $sql = "select ";
    if ($distinct) {
        $sql.= "distinct ";
    }
    $sql .=
      join(", ", @$select_arr)." from ".join(", ", @$table_arr);
    if (@$where_arr) {
	$sql.= " where ".join(" and ", @$where_arr);
    }

    my @group_arr = @{$group_arr || []};
    if (@group_arr) {
	$sql.= " group by ".join(", ", @group_arr);
    }

    my @order_arr = @{$order_arr || []};
    if (@order_arr) {
	$sql.= " order by ".join(", ", @order_arr);
    }

    my $sth;
    sqllog($sql);
    $sth = $dbh->prepare($sql) ||
      confess "Err:".$dbh->errstr;

    @bind_vals && sqllog("   VALS: ".join(", ", map {$_ || ""} @bind_vals));
    # execute SQL
    $sth->execute(@bind_vals) ||
      confess $dbh->errstr;
    
    return $sth;
}

sub get_sql {

    my ($table_arr, $where_arr, $select_arr, $order_arr, $group_arr, $distinct, $limit) =
      rearrange(['tables', 'where', 'columns', 'order', 'group', 'distinct', 'limit'], @_);

    if (!$table_arr) {
	confess("you must specify at least one table");
    }

    # either array or string
    if (!ref($table_arr)) {
	$table_arr = [$table_arr];
    }

    # either array or string
    if ($order_arr && !ref($order_arr)) {
	$order_arr = [$order_arr];
    }

    # either array or string
    if ($group_arr && !ref($group_arr)) {
	$group_arr = [$group_arr];
    }

    my @bind_vals = ();
    # either array or string
    if (!defined($where_arr)) {
	$where_arr = [];
    }
    if (!ref($where_arr)) {
	$where_arr = [$where_arr];
    }
    if (ref($where_arr) eq "HASH") {
	$where_arr =
	  [map {push(@bind_vals, $where_arr->{$_});"$_= ?"} keys %$where_arr];
    }

    if (!$select_arr) {
	$select_arr = ["*"];
    }
    elsif (!ref($select_arr)) {
	$select_arr = [$select_arr];
    }

#    my $sql = make_sql_select({select_arr=>$select_arr,
#			       where_arr=>$where_arr,
#			       table_arr=>$table_arr,
#			       order_arr=>$order_arr});
 
    my $sql = "select ";
    if ($distinct) {
        $sql.= "distinct ";
    }
    $sql .=
      join(", ", @$select_arr)." from ".join(", ", @$table_arr);
    if (@$where_arr) {
	$sql.= " where ".join(" and ", @$where_arr);
    }

    my @order_arr = @{$order_arr || []};
    if (@order_arr) {
	$sql.= " order by ".join(", ", @order_arr);
    }

    my @group_arr = @{$group_arr || []};
    if (@group_arr) {
	$sql.= " group by ".join(", ", @group_arr);
    }
    if ($limit) {
	$sql .= " limit $limit";
    }

    return ($sql, @bind_vals);
}

=head2 sql_delete

 parameters: dbh, table, where

the "where" parameters can be either a string representing the where
clause, or an arrayref of clauses to be ANDed.

=cut

sub sql_delete {

    my ($dbh, $table, $where_arr) =
      rearrange(['dbh', 'table', 'where'], @_);

    if (!$table) {
	confess("you must specify a table");
    }

    # either array or string
    if (!defined($where_arr)) {
	$where_arr = [];
    }
    if (!ref($where_arr)) {
	$where_arr = [$where_arr];
    }

    my $sql = "delete from $table";
    if (@{$where_arr}) {
	$sql.= " where ".join(" and ", @{$where_arr});
    }
    
    my $sth;
    sqllog($sql);

    $sth = $dbh->prepare($sql) ||
      confess ($sql."\n\t".$dbh->errstr);

    # execute SQL
    $sth->execute() ||
      confess ($sql."\n\t".$dbh->errstr);
    
    return $sth;
}

=head2 insert_h

insert name/value pairs into a database table 

parameters: dbh, table, values (hashref of name/value pairs)

=cut

sub insert_h  {
    my ($dbh, $table, $values_hashref) =
      rearrange(['dbh', 'table', 'values'], @_);

    my @cols = keys %{$values_hashref};
    my @vals = values %{$values_hashref};
    my @qs = map { '?' } @cols;
    my $sth;
    my $sql = "insert into $table (".
      join(", ", @cols).
	") values (".
	  join(", ", @qs).
	    ")";

    sqllog($sql);
    $sth = $dbh->prepare($sql);
    if (!$sth) {
	confess ($sql."\n\t".$dbh->errstr);
    }
    sqllog("   VALS: ".join(", ", map {$_ || ""} @vals));
    $sth->execute(@vals) || confess($sql."\n\t".$sth->errstr);
#    return $dbh->{ix_sqlerrd}[1];
    return get_autoincrement_val($dbh, $table);
}

=head2 insert_hash_wp

synonym for insert_h

=cut

sub insert_hash_wp  {
    insert_h(@_);
}

=head2 insert_hash

parameters: dbh, table, values (hashref of name/value pairs)

returns: new primary key val (if the primary key is of type
informix-serial)

all values will be automatically sql-quoted (this may not be the
semantics you want - consider using insert_h() instead)

does not use DBI placeholders; the consequence of this is that it
cannot be used to insert BYTE or TEXT fields. Use insert_h()
instead. I would deprecate this method for the sake of aesthetics,
except a lot of code uses it.

note: 

=cut

sub insert_hash {

    my ($dbh, $table, $values_hashref) =
      rearrange(['dbh', 'table', 'values'], @_);
    my $sql = make_sql_insert($table, $values_hashref);
    sqllog($sql);
    my $sth = $dbh->prepare($sql) ||
      confess ($sql."\n\t".$dbh->errstr);

    $sth->execute() ||
      confess ($sql."\n\t".$dbh->errstr);

#    my $pkval = $dbh->{ix_sqlerrd}[1];
    my $pkval = get_autoincrement_val($dbh, $table);
    return $pkval;

}

=head2 update_h

update name/value pairs into a database table 

parameters: dbh, table, values (hashref of name/value pairs), where
(sql clause)

=cut

sub update_h  {
    my ($dbh, $table, $values_hashref, $where, $hints) =
      rearrange(['dbh', 'table', 'values', 'where', 'hints'], @_);

    my %vh = %{$values_hashref};

    # under informix, updates on text columns are forbidden
    # (sigh). the user of this method can specify in hints
    # that a column is text to use this jump-through-hoops way
    # of updating; requires _ldr table

    if ($hints 
	&& $hints->{text_column}
	&& defined($vh{$hints->{text_column}})
	&& ($ENV{DBMS} && lc($ENV{DBMS}) eq "informix")) {
	my $col = $hints->{text_column};
	my $pk = $hints->{primary_key} || 
	  confess("must set hints->{primary_key to use text_column");
	my $tmp_id = 
	  insert_h($dbh,
		   $table."_ldr",
		   {$col=>$vh{$col}});
	delete $vh{$col};
	my $sql = "update $table set $col = ".
	  "(select $col from $table"."_ldr where $pk=$tmp_id)".
	    " where $where";
	sqllog($sql);    
	my $sth = $dbh->prepare($sql) || confess($sql."\n\t".$dbh->errstr);
	$sth->execute() || confess($sql."\n\t".$sth->errstr);
	sql_delete($dbh, $table."_ldr", "$pk = $tmp_id");
    }
    
    my @cols = keys %vh;
    my @vals = values %vh;
    if (!@cols) {
	return;
    }
    my $sth;
#    my @qs = map { '?' } @cols;
#    my $sql = "update $table set (".
#      join(", ", @cols).
#	") = (".
#	  join(", ", @qs).
#	    ")";
#    $sql.= " where $where";
    my $sql = "update $table set ".
	join(", ", map {"$_=?"} @cols).
	    " where $where";
    sqllog($sql);    
    sqllog("   VALS: ".join(", ", @vals));
    $sth = $dbh->prepare($sql) || confess($sql."\n\t".$dbh->errstr);
    
    $sth->execute(@vals) || confess($sql."\n\t".$sth->errstr);
#    my $id = $dbh->{ix_sqlerrd}[1];  # this is probably pointless
    my $id = get_autoincrement_val($dbh, $table);

    return $id;
}

=head2 get_result_column

=cut

sub get_result_column {

    my ($dbh, $sql) = 
      rearrange(['dbh', 'sql'], @_);
    
    my $sth = $dbh->prepare($sql) ||
	confess ($sql."\n\t".$dbh->errstr);

    $sth->execute() ||
      confess $dbh->errstr;

    my $row = $sth->fetch();
    if (!$row) {
	if ($sth->err()) {
	    confess ($sql."\n\t".$sth->err())
	}
	return undef;
    }
    return $row->[0];
}

=head2 orterm

 usage: orterm($t1, $t2, $t3, ..);

=cut

sub orterm {
    return "(".join(" or ", @_).")";
}				

=head2 andterm

 usage: andterm($t1, $t2, $t3, ..);

=cut

sub andterm {
    return "(".join(" and ", @_).")";
}				

=head2 rearrange()

 Usage    : n/a
 Function : Rearranges named parameters to requested order.
 Returns  : @params - an array of parameters in the requested order.
 Argument : $order : a reference to an array which describes the desired
                     order of the named parameters.
            @param : an array of parameters, either as a list (in
                     which case the function simply returns the list),
                     or as an associative array (in which case the
                     function sorts the values according to @{$order}
                     and returns that new array.

 Exceptions : carps if a non-recognised parameter is sent

=cut

sub rearrange {
  # This function was taken from CGI.pm, written by Dr. Lincoln
  # Stein, and adapted for use in Bio::Seq by Richard Resnick.
  # ...then Chris Mungall came along and adapted it for BDGP
  my($order,@param) = @_;

  # If there are no parameters, we simply wish to return
  # an undef array which is the size of the @{$order} array.
  return (undef) x $#{$order} unless @param;

  # If we've got parameters, we need to check to see whether
  # they are named or simply listed. If they are listed, we
  # can just return them.
  return @param unless (defined($param[0]) && $param[0]=~/^-/);

  # Now we've got to do some work on the named parameters.
  # The next few lines strip out the '-' characters which
  # preceed the keys, and capitalizes them.
  my $i;
  for ($i=0;$i<@param;$i+=2) {
      if (!defined($param[$i])) {
	  carp("Hmmm in $i ".join(";", @param)." == ".join(";",@$order)."\n");
      }
      else {
	  $param[$i]=~s/^\-//;
	  $param[$i]=~tr/a-z/A-Z/;
      }
  }
  
  # Now we'll convert the @params variable into an associative array.
  my(%param) = @param;

  my(@return_array);
  
  # What we intend to do is loop through the @{$order} variable,
  # and for each value, we use that as a key into our associative
  # array, pushing the value at that key onto our return array.
  my($key);

  foreach $key (@{$order}) {
      $key=~tr/a-z/A-Z/;
      my($value) = $param{$key};
      delete $param{$key};
      push(@return_array,$value);
  }
  
  # catch user misspellings resulting in unrecognized names
  my(@restkeys) = keys %param;
  if (scalar(@restkeys) > 0) {
       carp("@restkeys not processed in rearrange(), did you use a
       non-recognized parameter name ? ");
  }
  return @return_array;
}


=head2 remove_duplicates

remove duplicate items from an array

 usage: remove_duplicates(\@arr)

affects the array passed in, and returns the modified array

=cut

sub remove_duplicates {
    
    my $arr_r = shift;
    my @arr = @{$arr_r};
    my %h = ();
    my $el;
    foreach $el (@arr) {
	$h{$el} = 1;
    }
    my @new_arr = ();
    foreach $el (keys %h) {
	push (@new_arr, $el);
    }
    @{$arr_r} = @new_arr;
    @new_arr;
}

1;
