package GO::CGI::NameMunger;

use GO::Utils qw(rearrange);

=head1 GO::CGI::NameMunger

This is a helper module to take database abbreviations, 
and produce URLs, human readable names, etc.

Ideally this will soon be done with RDF.  For now
it remains a perl hack.

=head2 get_url

parameters: database_abbreviation, acc_no

returns: url to the entry

get_url takes a database abbreviation from GO and accession
and returns a url to get the page.

=cut

sub get_url {
  my $self = shift;
  my ($database, $acc_no) =
    rearrange(['database', 'acc_no'], @_);

  $database = lc($database);

  if ($database eq "interpro") {
      my @acc_no = split('\s', $acc_no);
      $acc_no = @acc->[0];
  } elsif ($database eq "tair") {
      $acc_no =~ s/^TAIR://;
  } elsif ($database eq "dros cdna") {
      $database =~ s/\ /\_/;
  }

  my %db_hash = ("sgd"=>"http://genome-www4.stanford.edu/cgi-bin/SGD/locus.pl?locus=$acc_no",
		 "mgi"=>"http://www.informatics.jax.org/searches/accession_report.cgi?id=$acc_no",
		 "fb"=>"http://flybase.bio.indiana.edu/.bin/fbidq.html?$acc_no",
		 "sp"=>"http://srs.ebi.ac.uk/srs6bin/cgi-bin/wgetz?-e+[SWALL-acc:$acc_no]",
		 "tr"=>"http://srs.ebi.ac.uk/srs6bin/cgi-bin/wgetz?-e+[SWALL-acc:$acc_no]",
		 "sptr"=>"http://srs.ebi.ac.uk/srs6bin/cgi-bin/wgetz?-e+[SWALL-acc:$acc_no]",
		 "wb"=>"http://www.wormbase.org/db/searches/basic?class=Any&query=$acc_no",
		 "interpro"=>"http://www.ebi.ac.uk/interpro/IEntry?ac=$acc_no",
		 "gr"=>"http://www.gramene.org/perl/protein_search?acc=$acc_no",
		 "ec"=>"http://ca.expasy.org/cgi-bin/nicezyme.pl?$acc_no",
		 "tair"=>"http://arabidopsis.org/servlets/TairObject?accession=$acc_no",
		 "genedb_tbrucei"=>"http://www.genedb.org/genedb/Search?organism=tryp&name=$acc_no",
		 "genedb_pfalciparum"=>"http://www.genedb.org/genedb/Search?organism=malaria&name=$acc_no",
		 "genedb_spombe"=>"http://www.genedb.org/genedb/Search?organism=pombe&name=$acc_no",
		 "ensembl"=>"http://www.ensembl.org/perl/protview?peptide=$acc_no",
		 "rgd"=>"http://rgd.mcw.edu/tools/genes/genes_view.cgi?id=$acc_no",
		 "dros_cdna"=>"http://weasel.lbl.gov/cgi-bin/EST/community_query/ctgReport.pl?db=estlabtrack&id_type=0&id_value=$acc_no",
		 "tigr_cmr"=>"http://www.tigr.org/tigr-scripts/CMR2/GenePage.spl?locus=$acc_no",
		 "tigrfams"=>"http://www.tigr.org/tigr-scripts/CMR2/hmm_report.spl?acc=$acc_no",
		 "tigr_ath1"=>"http://www.tigr.org/tigr-scripts/e2k1/euk_display.dbi?db=ath1&locus=$acc_no",
		 "genedb_lmajor"=>"http://www.genedb.org/genedb/Search?organism=leish&name=$acc_no",
		 "ddb"=>"http://dictybase.org/db/cgi-bin/DICTYBASE/locus.pl?locus=$acc_no"
	     );



  return %db_hash->{$database} || undef;

}

=head2 get_ref_url

parameters: database_abbreviation, acc_no

returns: url to the entry

This gets a link to evidence for gene product associations.
This is to a reference database, which in some organizations
is seperate from the main database (ie SGD).

Also, it does a little munging of IDs that dont come in right.

=cut

sub get_ref_url {
  my $self = shift;
  my ($database, $acc_no) =
    rearrange(['database', 'acc_no'], @_);

  $database = lc($database);

  if ($database eq "sgd") {
      $acc_no =~ s/\|.*$//;
  } elsif ($database eq "fb") {
      $acc_no =~ s/^fb/FB/;
  } elsif (lc($database) eq "dros cdna" ||
	   $database eq "image" 
	   ) {
      my $u_env = $ENV{GO_REF_URL};
      $url = $u_env ? $u_env.$acc_no :
	  "http://toy.lbl.gov:8888/cgi-bin/ex/exgo_report.pl?image_dbxref=$acc_no";
      return $url;
  }

  my %db_hash = ("sgd"=>"http://genome-www4.stanford.edu/cgi-bin/SGD/reference/reference.pl?refNo=$acc_no",
		 "pubmed"=>"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=$acc_no",
		 "pmid"=>"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Abstract&list_uids=$acc_no",
		 "mgi"=>"http://www.informatics.jax.org/searches/accession_report.cgi?id=$acc_no",
		 "fb"=>"http://flybase.bio.indiana.edu/.bin/fbidq.html?$acc_no",
		 "swall"=>"http://ca.expasy.org/cgi-bin/sprot-search-de?S=1&T=1&SEARCH=$acc_no",
		 "gr"=>"http://www.gramene.org/perl/pub_search?ref_id=$acc_no",
		 "ensembl"=>"http://www.ensembl.org/perl/protview?peptide=$acc_no",
		 "rgd"=>"http://rgd.mcw.edu/tools/references/references_view.cgi?id=$acc_no",
		 "tigr_cmr"=>"http://www.tigr.org/tigr-scripts/CMR2/GenePage.spl?locus=$acc_no",
		 "tigrfams"=>"http://www.tigr.org/tigr-scripts/CMR2/hmm_report.spl?acc=$acc_no",
		 "tigr_ath1"=>"http://www.tigr.org/tigr-scripts/e2k1/euk_display.dbi?db=ath1&locus=$acc_no",

		 );
		 




return %db_hash->{$database} || undef;

}

sub get_link_to {
  my $self = shift;
  my ($session, $extension) =
    rearrange(['session', 'extension'], @_);

  my $url;

  my $ref = $session->get_param('link_to');
  if ($ref) {
    return $ref.$extension;
  }
  return undef;
}

=head2 get_xref_image

parameters: database_abbreviation, acc_no

returns: path to the gif or png for each databases logo

This is the picture shown for the link that gets the reciprocal
terms for each xref.

=cut

sub get_xref_image {
  my $self = shift;
  my ($session, $database, $acc_no) =
    rearrange(['session', 'database', 'acc_no'], @_);

  my $image_dir = $session->get_param('image_dir') || "../images";


  my $url;
  if ($database eq "interpro") {
    $url = "$image_dir/interpro.gif";
  }
    return $url;
}

=head2 get_human_name

parameters: database_abbreviation

returns: Human readable name

get_url takes a database abbreviation from GO and accession
and returns a human freindly name to the datasource.

=cut

sub get_human_name {
  my $self = shift;
  my ($database) =
    rearrange(['database'], @_);
  
  my $dbs = {'fb'=>'FlyBase',
             'sp' => 'UNI-PROT/SWISS-PROT',
             'tr' => 'TrEMBL',
	     'sptr' => 'SPTr',
	     'sgd'=>'SGD',
	     'mgi'=>'MGI',
	     'pombase'=>'Pombase',
	     'cgen'=>'Compugen',
	     'wb'=>'Wormbase',
	     'ec'=>'NiceZyme',
	     'interpro'=>'InterPro',
	     'egad'=>'EGAD',
	     'tigr_role'=>'TIGR',
	     'tair'=>'TAIR',
	     'sp_kw'=>'UNI-PROT/SWISS-PROT Keyword',
	     'all'=>'All',
	     'genedb_spombe'=>'SPombe',
	     'ensembl'=>'Ensembl',
	     'ca'=>'All Curator Approved',
	     'rgd'=>'RGD',
	     'tigrfams'=>'TIGRFAMS',
	     'tigr_cmr'=>'TIGR_CMR',
	     'tigr_ath1'=>'TIGR_Ath1',
	     'gr' => 'Gramene',
	     'genedb_tsetse'=>'Tsetse',
	     'genedb_tbrucei'=>'Tbrucei',
	     'genedb_pfalciparum'=>'Pfalciparum',
	     genedb_lmajor=>'GeneDB_Lmajor',
	     'ddb'=>'dictyBase'
	     };
  
  return $dbs->{$database} || $database;
}

=head2 get_full_name

parameters: -acronym=>$acronym

returns: Full name

=cut

sub get_full_name {
  my $self = shift;
  my ($acronym) =
    rearrange(['acronym'], @_);

    my $acronyms = 
      {'IMP'=>'Inferred from Mutant Phenotype',
       'ISS'=>'Inferred from Sequence Similarity',
       'IGI'=>'Inferred from Genetic Interaction',
       'IPI'=>'Inferred from Physical Interaction',
       'IDA'=>'Inferred from Direct Assay',
       'IEP'=>'Inferred from Expression Pattern',
       'IEA'=>'Inferred from Electronic Annotation',
       'TAS'=>'Traceable Author Statement',
       'NAS'=>'Non-traceable Author Statement',
       'all'=>'All',
       'ca'=>'Curator Approved'
      };
  
  return $acronyms->{$acronym} || $acronym;
}
  
1;  
