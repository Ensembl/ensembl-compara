# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Stats;

=head1 NAME

  GO::Stats

=head1 DESCRIPTION

Class that holds various statistics of a GO database.

=cut

use Exporter;
use base qw(Exporter);

use Carp;
use strict;
use GO::Model::Term;
use GO::SqlWrapper qw(get_result_column select_hashlist sql_quote);
use base qw(GO::Model::Root);



sub get_tags {
    my $self = shift;
    my $dbh = $self->apph->dbh;
    # maybe move these to sep method?
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
	push(@$tags, $dbname => ["select count(distinct association.id) from association, gene_product, dbxref, evidence where evidence.association_id = association.id and evidence.code != 'IEA' and association.gene_product_id = gene_product.id and gene_product.dbxref_id = dbxref.id and dbxref.xref_dbname = ".sql_quote($dbname), "select count(distinct gene_product.id) from gene_product, dbxref where gene_product.dbxref_id = dbxref.id and dbxref.xref_dbname = ".sql_quote($dbname)]);
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

sub output {
    my $self = shift;
    if (!$self->{tags}) {
        $self->{tags} = $self->apph->get_stat_tags;
    }
    my @tags = @{$self->{tags}};
    for (my $i=0; $i < @tags; $i+=2) {
	printf 
	  "%12s:%s\n",
	  $tags[$i],
	  $tags[$i+1];
    } @tags;
    
}

1;
