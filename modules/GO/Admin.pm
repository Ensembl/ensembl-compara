# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Admin;

=head1 NAME

  GO::Admin;

=head1 SYNOPSIS


=head1 DESCRIPTION

object to help administer GO dbs

use the script

  go-dev/scripts/go-manager.pl

=cut


use Carp qw(cluck confess);
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use GO::AppHandle;
use GO::SqlWrapper qw(:all);
use strict;
use vars qw(@ISA);
use FileHandle;

our $GZIP = 'gzip -f';

@ISA = qw(GO::Model::Root Exporter);


sub _valid_params {
    return qw(dbname dbhost dbms data_root releasename tmpdbname godevdir sqldir workdir swissdir speciesdir administrator);
}

sub distn {
    my $self = shift;
    $self->{_distn} = shift if @_;
    if ($self->{_distn}) {
	$self->throw("No distn");
    }
    return $self->{_distn};
}

sub tmpdbname {
    my $self = shift;
    $self->{_tmpdbname} = shift if @_;
    if (!$self->{_tmpdbname}) {
	return 'go_tmp';
    }
    return $self->{_tmpdbname};
}

sub sqldir {
    my $self = shift;
    $self->{_sqldir} = shift if @_;
    if (!$self->{_sqldir}) {
	return $self->godevdir.'/sql';
    }
    return $self->{_sqldir};
}

sub godevdir {
    my $self = shift;
    $self->{_godevdir} = shift if @_;
    if (!$self->{_godevdir}) {
	return $ENV{GO_ROOT};
    }
    return $self->{_godevdir};
}

sub workdir {
    my $self = shift;
    $self->{_workdir} = shift if @_;
    if (!$self->{_workdir}) {
	return '.';
    }
    return $self->{_workdir};
}

sub dbms {
    my $self = shift;
    $self->{_dbms} = shift if @_;
    if (!$self->{_dbms}) {
	return 'mysql';
    }
    return $self->{_dbms};
}

sub swissdir {
    my $self = shift;
    $self->{_swissdir} = shift if @_;
    if (!$self->{_swissdir}) {
	return 'proteomes';
    }
    return $self->{_swissdir};
}

sub speciesdir {
    my $self = shift;
    $self->{_speciesdir} = shift if @_;
    if (!$self->{_speciesdir}) {
	return 'ncbi';
    }
    return $self->{_speciesdir};
}

# drops a db
sub dropdb {
    my $self = shift;
    my $ar = $self->mysqlargs;
    my $h = $self->mysqlhostargs;
    my $d = $self->dbname;
    my $sqldir = $self->sqldir;
    my $err =
      $self->runcmds("*mysql $h -e 'DROP DATABASE $d'",
		    );
#    if ($err) {
#	$self->throw("Cannot create!");
#    }
}

# drops and recreates an empty db
sub newdb {
    my $self = shift;
    my $ar = $self->mysqlargs;
    my $h = $self->mysqlhostargs;
    my $d = $self->dbname;
    my $sqldir = $self->sqldir;
    my $err =
      $self->runcmds("*mysql $h -e 'DROP DATABASE $d'",
		     "mysql $h -e 'CREATE DATABASE $d'",
		    );
    if ($err) {
	$self->throw("Cannot create!");
    }
}

# loads SQL DDL from sqldir
sub load_schema {
    my $self = shift;
    my $ar = $self->mysqlargs;
    my $h = $self->mysqlhostargs;
    my $d = $self->dbname;
    my $dbms = $self->dbms;
    my $sqldir = $self->sqldir;
    my $err =
      $self->runcmds("$sqldir/compiledb -t $dbms $sqldir/go-tables-FULL.sql | mysql $h $d",
		    );
    if ($err) {
	$self->throw("Cannot load schema!");
    }
}


sub time_of_last_sp_update {
    my $self = shift;
    my $swissdir = $self->swissdir;
    my @f = split(/\n/, `ls $swissdir/*SPC`);
    my $t;
    foreach (@f) {
	my @stat = stat($_);
	if (!defined($t) || $stat[9] < $t) {
	    # least recent file
	    $t = $stat[9];
	}
    }
    return $t;
}

# downloads proteome sequence files from SwissProt - may take a while
sub updatesp {
    my $self = shift;
    my $swissdir = $self->swissdir;

    $self->runcmd("wget -r -np -nv ftp://ftp.ebi.ac.uk/pub/databases/SPproteomes/swissprot_files/proteomes/");
    if (! -d $swissdir) {
	runcmd("mkdir $swissdir");
    }
    $self->runcmds("cp ftp.ebi.ac.uk/pub/databases/SPproteomes/swissprot_files/proteomes/* $swissdir",
		   "chmod -R 777 $swissdir");
}

# creates a database from a tarball mysql dump file
# WARNING - overwrites current db!
# it will probably fail if not given an empty db; run $admin->newdb first
sub build_from_file {
    my $self = shift;
    my $f = shift;
    my $ar = $self->mysqlargs;
    if ($f =~ /(.*-tables)\.tar/) {
	my $tdir = $1;
	my @parts = split(/\//, $tdir);
	my $d = $parts[-1];
	my $args = "xvf";
	if ($f =~ /\.gz$/) {
	    $args = "z$args";
	}
	$self->runcmds("tar -$args $f",
		       "cat $d/*.sql | mysql $ar",
		       "mysqlimport $ar $d/*.txt");
    }
    elsif ($f =~ /(.*-data)/) {
#	my $tdir = $1;
#	my @parts = split(/\//, $tdir);
#	my $d = $parts[-1];
	my $cat = "cat";
	if ($f =~ /\.gz$/) {
	    $cat = "zcat";
	}
	$self->runcmds("$cat $f | mysql $ar");
    }
    else {
	die $f;
    }
}

sub released_files {
    my $self = shift;
    my $wd = $self->workdir;
    my @f = split(/\n/, `find $wd -follow -name '*gz'`);
    return @f;
}


sub mysqlargs {
    my $self = shift;
    my $args = $self->dbhost ? "-h ".$self->dbhost : "";
    $args .= " ".$self->dbname;
    $args;
}

sub mysqlhostargs {
    my $self = shift;
    my $args = $self->dbhost ? "-h ".$self->dbhost : "";
    $args;
}

sub refresh_data_root {
    my $self = shift;
    my $D = $_[0] ? "-D " . shift  : "";
    my $data_root = $self->data_root;
    if (!-d "$data_root/CVS") {
	$self->throw("no CVS in $data_root");
    }
    $self->runcmds("cd $data_root;cvs update -d $D");
}

sub makecoderelease {
    my $self = shift;
    my $D = $_[0] ? "-D " . shift  : "";
    my $distn = $self->releasename;
    my $godev = $self->godevdir;
    my $sqldir = $self->sqldir;
    my $dbms = $self->dbms;
    my $r = $self->releasename;
    my $host = $self->dbhost;
    my $schema = "$r-schema-$dbms.sql";
    my $html = "$r-schema-html";
    my $dtd = "$r.dtd";
    my $coderel = "$r-utilities-src";
    $ENV{CVS_RSH} = 'ssh';
    $self->runcmds("*cvs -d :pserver:anonymous\@cvs.geneontology.sourceforge.net:/cvsroot/geneontology checkout go-dev",
		   "*rm -rf $coderel",
		   "cp go-dev/xml/dtd/go.dtd $dtd",
		   "$GZIP $dtd",
		   "mv go-dev $coderel",
		   "*find $coderel -name CVS -exec rm -rf {} \\;",
		   "tar cf $coderel.tar $coderel",
		   "$GZIP $coderel.tar",
		   "$sqldir/compiledb -t $dbms $sqldir/go-tables-FULL.sql > $schema",
		   "$GZIP $schema",
		   # load into postgres
		   "*dropdb -h $host go_tmp",
		   "createdb -h $host go_tmp",
		   "$sqldir/compiledb -t pg $sqldir/go-tables-FULL.sql | psql -e -h $host go_tmp",
		   "perl $sqldir/postgresql_autodoc.pl -d go_tmp -h $host -F $html --no-uml",
		   "$GZIP $html",
		   );
}

sub make_release_tarballs {
    my $self = shift;
    my $suff = shift || $self->guess_release_type;
    my $distn = $self->releasename . '-' .$suff;
    my $t = $distn."-tables";
    my $td = $distn."-data";
    my $tt = $t.".tar";

    my $mysqlargs = $self->mysqlargs;

    $self->runcmds("mysql $mysqlargs -e 'delete from instance_data'",
		   "mysql $mysqlargs -e \"insert into instance_data (release_name, release_type) values ('".$self->releasename."', '$suff')\"");

#    chdir($self->workdir);
    if (-d $t) {
	my $time = time;
	$self->runcmds("mv $t OLD.$time.$t");	
    }
    eval {
	$self->runcmds("mkdir $t",
		       "chmod 777 $t",
		       "cd $t; chmod 777 .",
		       "mysqldump -T $t $mysqlargs",
		       
		       # some WEIRD problem with tar on the bdgp machines;
		       # it seems we need to sleep for a bit otherwise tar
		       # fails
		       "sleep 60",
		       "ls -alt $t > LISTING.$t",
		       "tar cvf $tt $t",
		       "$GZIP $tt",
		      );
    };
    
    $self->runcmds("mysqldump $mysqlargs > $td",
		   "$GZIP $td",
		  );
    my $report_file = $distn.'-summary.txt';
    open(F, ">$report_file") || $self->throw("can't open $report_file");
    print F $self->report;
    close(F);
    $self->runcmds("$GZIP $report_file");
}
*makedist = \&make_release_tarballs;

sub runcmds {
    my $self = shift;
    my @cmds = @_;
    my $cmd;
    while ($cmd = shift @cmds) {
	$self->runcmd($cmd);
    }
}



sub runcmd {
    my $self = shift;
    my $c = shift;
    my $fallible;
    if ($c =~ /^\*(.*)/) {
	$c = $1;
	$fallible = 1;
    }
    trace0("running:$c\n");
    my $err = system($c);
    if ($err) {
	if ($fallible) {
	    warn "error in:$c";
	}
	else {
	    confess "error in:$c";
	}
    }
    return $err;
}

sub loadp {
    my $self = shift;
    my $f = shift;
    open(F, $f) || $self->throw("Cannot open $f");
    while(<F>) {
	chomp;
	s/^ *//;
	s/ *$//;
	next if /^\#/;
	next unless $_;
	my ($p, @v) = split(/\s*:\s*/, $_);
	$self->$p(join(':', @v));
    }
    close(F);
}

sub savep {
    my $self = shift;
    my $f = shift;
    open(F, ">$f") || $self->throw("Cannot open $f for writing");
    my @p = $self->_valid_params;
    foreach (@p) {
	printf F "$_:".$self->$_()."\n";
    }
    close(F);
}

sub apph {
    my $self = shift;
    $self->{_apph} = shift if @_;
    if (!$self->{_apph}) {
	my @p = (-dbname=>$self->dbname);
	if ($self->dbhost) {
	    push(@p, -dbhost=>$self->dbhost);
	}
	if ($self->dbms) {
	    push(@p, -dbms=>$self->dbms);
	}
	eval {
	    $self->{_apph} =
	      GO::AppHandle->connect(@p);
	};
    }
    return $self->{_apph};
}

sub is_connected {
    my $self = shift;
    my $apph = $self->apph;
    if ($apph) {
	my $dbh = $apph->dbh;
	return $dbh->{Active};
    }
    return 0;
}

sub guess_release_type {
    my $self = shift;
    my $apph = $self->apph;
    my $dbh = $apph->dbh;
    my @t =
      qw(term
	 term_definition 
	 term_synonym    
	 graph_path      
	 association     
	 gene_product    
	 gene_product_count
	 seq
	 species);
    my %c =
      map {
	  $_ => 
	    select_val($dbh,
		       $_,
		       undef,
		       "count(*)");
      } @t;
    $c{iea} =
      select_val($dbh,
		 "evidence",
		 "code = 'IEA'",
		 "count(*)");
    my $type = "unknown";
    if (!$c{term_definition} ||
	!$c{term_synonym} ||
	!$c{term} ||
	!$c{graph_path}) {
	$type = "incomplete";
    }
    elsif (!$c{association}) {
	$type = "termdb";
    }
    elsif (!$c{gene_product} ||
	   !$c{gene_product_count}) {
	$type = "assocdb-incomplete";
    }
    elsif ($c{seq}) {
	$type = "seqdb";
	if (!$c{iea}) {
	    $type = "seqdblite";
	}
    }
    elsif (!$c{iea}) {
	$type = "assocdblite";
    }
    else {
	# everything bar seq is present
	$type = "assocdb";
    }

    if ($type ne 'termdb' && 
	!select_val($dbh,
		    "species",
		    "common_name is not null",
		    "count(*)")) {
	
	print STDERR "\nYOU NEED TO LOAD SPECIES\n\n";
    }
	
    return $type;
}

sub tcount {
    my $self = shift;
    require "DBIx/DBSchema.pm";
    my $dbh = $self->apph->dbh;
    my $schema = DBIx::DBSchema->new_native($dbh);
    my @table_names = sort $schema->tables;
    foreach (@table_names) {
	my $rows =
	  $dbh->selectcol_arrayref("SELECT COUNT(*) FROM $_");
	my $count = shift @$rows;
	if (!defined($count)) {
	    print STDERR "COULD NOT QUERY:$_\n";
	    exit 1;
	}
	print "$_: $count\n";
    }
}

sub stats {
    my $self = shift;
    my $dbh = $self->apph->dbh;

    my @types =
      @{select_vallist($dbh, "term", undef, "distinct term_type")};
    my @xdbs =
      @{select_vallist($dbh, "dbxref", undef, "distinct xref_dbname")};
    my @gpdbs =
      @{select_vallist($dbh, 
		       "dbxref INNER JOIN gene_product ON (dbxref_id=dbxref.id)", 
		       undef, 
		       "distinct xref_dbname")};
    my @evcodes =
      @{select_vallist($dbh, "evidence", undef, "distinct code")};
    my @stats =
      (
       ["Total GO Terms" =>
	select_val($dbh,
		   "term",
		   "term_type != 'relationship'",
		   "count(*)")],
       ["Total GO Terms (not obsolete)" =>
	select_val($dbh,
		   "term",
		   "term_type != 'relationship' AND is_obsolete = 0",
		   "count(*)")],
       (map {
	   ["Total $_" =>
	    select_val($dbh,
		       "term",
		       "term_type = '$_'",
		       "count(*)")]
       } @types),
       (map {
	   ["Total $_ (not obsolete)" =>
	    select_val($dbh,
		       "term",
		       "term_type = '$_' AND is_obsolete = 0",
		       "count(*)")]
       } @types),
       ["GO Terms with defs" =>
	select_val($dbh,
		   "term_definition",
		   undef,
		   "count(*)")],
       ["Synonyms" =>
	select_val($dbh,
		   "term_synonym",
		   "term_synonym.term_synonym not like 'GO:%'",
		   "count(*)")],
       ["Terms with dbxrefs" =>
	select_val($dbh,
		   "term_dbxref INNER JOIN dbxref ON (dbxref_id = dbxref.id)",
		   undef,
		   "count(distinct term_id)")],
       ["Associations" =>
	select_val($dbh,
		   "association",
		   undef,
		   "count(*)")],
       (map {
	   ["Associations type $_" =>
	    select_val($dbh,
		       "association INNER JOIN evidence ON (association.id = association_id)",
		       "code = '$_'",
		       "count(*)")]
       } @evcodes),
       
       (map {
	   ["Associations DB: $_" =>
	    select_val($dbh,
		       q[association 
			 INNER JOIN 
			 gene_product ON (gene_product.id = gene_product_id)
			 INNER JOIN
			 dbxref       ON (dbxref_id = dbxref.id)],
		       "dbxref.xref_dbname = '$_'",
		       "count(distinct association.id)")]
       } @gpdbs),
       
       (map {
	   ["Gene Products DB: $_" =>
	    select_val($dbh,
		       q[ 
			 gene_product
			 INNER JOIN
			 dbxref       ON (dbxref_id = dbxref.id)],
		       "dbxref.xref_dbname = '$_'",
		       "count(*)")]
       } @gpdbs),
       
       (map {
	   ["Seqs DB: $_" =>
	    select_val($dbh,
		       q[
			 gene_product_seq
			 INNER JOIN
			 gene_product ON (gene_product_id = gene_product.id)
			 INNER JOIN
			 dbxref       ON (dbxref_id = dbxref.id)],
		       "dbxref.xref_dbname = '$_'",
		       "count(distinct gene_product.id)")]
       } @gpdbs),
       
      );
    @stats;		  
}

sub report {
    my $self = shift;
    my $name = shift || $self->releasename . '_' . $self->guess_release_type;
    my @stats = $self->stats;
    push(@stats, ["GUESSED TYPE" => $self->guess_release_type]);
    sprintf("REPORT ON: $name\n==========\n%s\n",
	    join('', 
		 map {sprintf("%20s:%s\n", @$_)} @stats));
}

sub check_xml_rfile {
    my $self = shift;
    my $f = shift;
    my $fh;
    if ($f =~ /\.gz$/) {
	$fh = FileHandle->new("zcat $f|");
    }
    else {
	$fh = Filehandle->new($f);
    }
    $fh || die("cant open $f");
    # should do seperate proper xml check, validate
    my $nt = 0;
    my $nd = 0;
    my $na = 0;
    my $ns = 0;
    
    while(<$fh>) {
	/\<go:term[\>\s]/ && $nt++;
	/\<go:definition[\>\s]/ && $nd++;
	/\<go:association[\>\s]/ && $na++;
	/\<go:synonym[\>\s]/ && $ns++;
    }
    $fh->close;
    return
      sprintf("TERMS:     $nt\n".
	      "DEFS:      $nd\n".
	      "ASSOCS:    $na\n".
	      "SYNS:      $ns\n");
}

sub check_fasta_rfile {
    my $self = shift;
    my $f = shift;
    my $fh;
    if ($f =~ /\.gz$/) {
	$fh = FileHandle->new("zcat $f|");
    }
    else {
	$fh = Filehandle->new($f);
    }
    $fh || die("cant open $f");
    # should do seperate proper xml check, validate
    my $nseq = 0;
    
    while(<$fh>) {
	/^\>/ && $nseq++;
    }
    $fh->close;
    return
      sprintf("SEQS:      $nseq\n");
}

# IEAs take up a lot of space in db
sub remove_iea {
    my $self = shift;
    my $apph = $self->apph;
###    $apph->remove_associations(-evcode=>['IEA']);
    $apph->remove_iea;
}

sub load_termdb {
    my $self = shift;
    my $data_root = $self->data_root;
    $self->load_go('go-ontology', "$data_root/ontology/{function,process,component}.ontology");
    $self->load_go('go-defs', "$data_root/ontology/GO.defs");
    $self->load_go('go-xrefs', "$data_root/external2go/*2go");
}

sub load_assocdb {
    my $self = shift;
    my $extra = shift; 
    my $data_root = $self->data_root;
    my @files = glob("$data_root/gene-associations/gene_assoc*");
    # default option is to filter compugen; too many & redundant with SP
    @files = grep {$_ !~ /compugen/i} @files;
    @files = grep {$_ !~ /goa_human/i} @files;    # this is redundant with goa_sptr
    $self->load_go('go-assocs', "@files", "-fill_count", $extra);
}

sub load_go {
    my $self = shift;
    my $dt = shift;
    my $f = shift;
    my $extra = shift || '';
    my $dbname = $self->dbname;
    my $dbhost = $self->dbhost;
    $self->runcmd("load-go.pl -d $dbname -h $dbhost -datatype $dt $extra $f");
}

sub dumpxml {
    my $self = shift;
    my $suff = shift || $self->guess_release_type;
    my $f = $self->releasename . '-' .$suff . '.xml';
    my $dbname = $self->dbname;
    my $dbhost = $self->dbhost;
    $self->runcmds("go-dump-xml.pl -d $dbname -h $dbhost > $f",
		   "$GZIP $f");
}

sub dumpseq {
    my $self = shift;
    my $suff = shift || $self->guess_release_type;
    my $f = $self->releasename . '-' .$suff . '.fasta';
    my $dbname = $self->dbname;
    my $dbhost = $self->dbhost;
    $self->runcmds("get-seqs.pl -d $dbname -h $dbhost -all -fullheader -skipnogo -withname > $f",
		   "$GZIP $f");
}

sub load_seqs {
    my $self = shift;
    my $dbname = $self->dbname;
    my $dbhost = $self->dbhost;
    my $data_root = $self->data_root;
    my $swissdir = $self->swissdir || 'proteomes';
    $self->runcmd("load_sp.pl -d $dbname -h $dbhost -swissdir $swissdir -store $data_root/gp2protein/gp2protein.* $data_root/gene-associations/gene_association.{goa_human,goa_sptr}");
}

sub load_species {
    my $self = shift;
    my $dbname = $self->dbname;
    my $dbhost = $self->dbhost;
    my $data_root = $self->data_root;
    my $speciesdir = $self->speciesdir || 'ncbi';
    $self->runcmd("load-tax.pl -d $dbname -h $dbhost $speciesdir/names.dmp");
}

sub trace0 {
    my @m = @_;
    print STDERR "@m";
}

1;
