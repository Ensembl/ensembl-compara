package EnsEMBL::Web::Factory::UniSearch;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
our @ISA = qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self       = shift;    
  my $idx      = $self->param('type') || $self->param('idx') || 'all';
  ## Action search...
  my $search_method = "search_".uc($idx);
  if( $self->param('q') ) {
    if( $self->can($search_method) ) {
      $self->{to_return} = 30;
      $self->{_result_count} = 0;
      $self->{_results}      = [];
      $self->$search_method();
      $self->DataObjects( new EnsEMBL::Web::Proxy::Object( 'UniSearch', { 'idx' => $idx , 'q' => $self->param('q'), 'results' => $self->{results} }, $self->__data ));
    } else {
      $self->problem( 'fatal', 'Unknown search method', qq(
      <p>
        Sorry do not know how to search for features of type "$idx"
      </p>) );
    }
  } else {
    $self->DataObjects( new EnsEMBL::Web::Proxy::Object( 'UniSearch', { 'idx' => $idx , 'q' => '', 'results' => {} }, $self->__data ));
  }
}

sub terms {
  my $self = shift;
  my @list = ();
  foreach my $kw ( split /\s+/, join ' ',$self->param('q') ) {
    my $seq = $kw =~ s/\*+$/%/ ? 'like' : '=';
    push @list, [ $seq, $kw ];
  }
  return @list;
}

sub count {
  my( $self, $db, $sql, $comp, $kw ) = @_;

  my $dbh = $self->database($db);
  return 0 unless $dbh;
  $kw = $dbh->dbc->db_handle->quote($kw);
  (my $t = $sql ) =~ s/'\[\[KEY\]\]'/$kw/g;
               $t =~ s/\[\[COMP\]\]/$comp/g;
  #warn $t;
  #my( $res ) = $dbh->db_handle->selectrow_array( $t );
  my( $res ) = $dbh->dbc->db_handle->selectrow_array( $t );
  return $res;
}

sub _fetch {
  my( $self, $db, $search_SQL, $comparator, $kw, $limit ) = @_;
  my $dbh = $self->database( $db );
  return unless $dbh;
  $kw = $dbh->dbc->db_handle->quote($kw);
  (my $t = $search_SQL ) =~ s/'\[\[KEY\]\]'/$kw/g;
  $t =~ s/\[\[COMP\]\]/$comparator/g;
  #warn "$t limit $limit";
  #my $res = $dbh->db_handle->selectall_arrayref( "$t limit $limit" );
  my $res = $dbh->dbc->db_handle->selectall_arrayref( "$t limit $limit" );
  push @{$self->{_results}}, @$res;
}

sub search_ALL {
  my( $self, $species ) = @_;
  my $package_space = __PACKAGE__.'::';
  no strict 'refs';
  my @methods = map { /(search_\w+)/ && $1 ne 'search_ALL' ? $1 : () } keys %$package_space;

    ## Filter by configured indices
  my $SD = EnsEMBL::Web::SpeciesDefs->new();
  my @idxs = @{$SD->ENSEMBL_SEARCH_IDXS};
  my @valid_methods;

  if (scalar(@idxs) > 0) {
    foreach my $m (@methods) {
      (my $index = $m) =~ s/search_//;
      foreach my $i (@idxs) {
        if (lc($index) eq lc($i)) {
          push @valid_methods, $m;
          last;
        }
      }
    }
  }
  else {
    @valid_methods = @methods;
  }

  my @ALL = ();
  
  foreach my $method (@valid_methods) {
    $self->{_result_count} = 0;
    $self->{_results}      = [];
    $self->{to_return} = 10;
    if( $self->can($method) ) {
      $self->$method;
    }
  }
  return @ALL;
}

sub _fetch_results {
  my $self = shift;
  my @terms = $self->terms();
  foreach my $query (@_) {
    my( $db, $subtype, $count_SQL, $search_SQL ) = @$query;
    foreach my $term (@terms ) {
      my $count_new = $self->count( $db, $count_SQL, $term->[0], $term->[1] );
      if( $count_new ) {
        if( $self->{to_return} > 0) {
          my $limit = $self->{to_return} < $count_new ? $self->{to_return} : $count_new; 
          $self->_fetch( $db, $search_SQL, $term->[0], $term->[1], $limit );
          $self->{to_return} -= $count_new;
        }
        $self->{'_result_count'} += $count_new;
      }
    }
  }
}

sub search_SNP {
  my $self = shift;
  $self->_fetch_results(
   [ 'variation' , 'SNP',
     "select count(*) from variation as v where name = '[[KEY]]'",
   "select s.name as source, v.name
      from source as s, variation as v
     where s.source_id = v.source_id and v.name = '[[KEY]]'" ],
   [ 'variation', 'SNP',
     "select count(*) from variation as v, variation_synonym as vs
       where v.variation_id = vs.variation_id and vs.name = '[[KEY]]'",
   "select s.name as source, v.name
      from source as s, variation as v, variation_synonym as vs
     where s.source_id = v.source_id and v.variation_id = vs.variation_id and vs.name = '[[KEY]]'"
  ]);
  
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'idx'     => 'SNP', 
      'subtype' => "$_->[0] SNP",
      'ID'      => $_->[1],
      'URL'     => "/@{[$self->species]}/snpview?source=$_->[0];snp=$_->[1]",
      'desc'    => '',
      'species' => $self->species
    };
  }
  $self->{'results'}{'SNP'} = [ $self->{_results}, $self->{_result_count} ];
}

sub search_GENOMICALIGNMENT {
  my $self = shift;
  $self->_fetch_results(
    [
      'core', 'DNA',
      "select count(distinct analysis_id, hit_name) from dna_align_feature where hit_name [[COMP]] '[[KEY]]'",
      "select a.logic_name, f.hit_name, 'Dna', 'core',count(*)  from dna_align_feature as f, analysis as a where a.analysis_id = f.analysis_id and f.hit_name [[COMP]] '[[KEY]]' group by a.logic_name, f.hit_name"
    ],
    [
      'core', 'Protein',
      "select count(distinct analysis_id, hit_name) from protein_align_feature where hit_name [[COMP]] '[[KEY]]'",
      "select a.logic_name, f.hit_name, 'Protein', 'core',count(*) from protein_align_feature as f, analysis as a where a.analysis_id = f.analysis_id and f.hit_name [[COMP]] '[[KEY]]' group by a.logic_name, f.hit_name"
    ],
    [
      'vega', 'DNA',
      "select count(distinct analysis_id, hit_name) from dna_align_feature where hit_name [[COMP]] '[[KEY]]'",
      "select a.logic_name, f.hit_name, 'Dna', 'vega', count(*) from dna_align_feature as f, analysis as a where a.analysis_id = f.analysis_id and f.hit_name [[COMP]] '[[KEY]]' group by a.logic_name, f.hit_name"
    ],
    [
      'est', 'DNA',
      "select count(distinct analysis_id, hit_name) from dna_align_feature where hit_name [[COMP]] '[[KEY]]'",
      "select a.logic_name, f.hit_name, 'Dna', 'est', count(*) from dna_align_feature as f, analysis as a where a.analysis_id = f.analysis_id and f.hit_name [[COMP]] '[[KEY]]' group by a.logic_name, f.hit_name"
    ]
  );
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'idx'     => 'GenomicAlignment',
      'subtype' => "$_->[0] $_->[2] alignment feature",
      'ID'      => $_->[1],
      'URL'     => "/@{[$self->species]}/featureview?type=$_->[2]AlignFeature;db=$_->[3];id=$_->[1]",
      'desc'    => "This $_->[2] alignment feature hits the genome in $_->[4] place(s).",
      'species' => $self->species
    };
  }
  $self->{'results'}{'GenomicAlignments'} = [ $self->{_results}, $self->{_result_count} ];
}

sub search_DOMAIN {
  my $self = shift;
  $self->_fetch_results(
    [ 'core', 'Domain',
      "select count(*) from xref as x, external_db as e 
        where e.external_db_id = x.external_db_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "select x.dbprimary_acc, x.description
         FROM xref as x, external_db as e
        WHERE e.db_name = 'Interpro' and e.external_db_id = x.external_db_id and
              x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
    [ 'core', 'Domain',
      "select count(*) from xref as x, external_db as e 
        where e.external_db_id = x.external_db_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "SELECT x.dbprimary_acc, x.description
         FROM xref as x, external_db as e
        WHERE e.db_name = 'Interpro' and e.external_db_id = x.external_db_id and
              x.description [[COMP]] '[[KEY]]'" ],
  );
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'URL'       => "/@{[$self->species]}/domainview?domain=$_->[0]",
      'idx'       => 'Domain',
      'subtype'   => 'Domain',
      'ID'        => $_->[0],
      'desc'      => $_->[1],
      'species'   => $self->species
    };
  }
  $self->{'results'}{'Domain'} = [ $self->{_results}, $self->{_result_count} ];
}

sub search_FAMILY {
  my( $self, $species ) = @_;
  $self->_fetch_results(
    [ 'compara', 'Family',
      "select count(*) from family where stable_id [[COMP]] '[[KEY]]'",
      "select stable_id, description FROM family WHERE stable_id  [[COMP]] '[[KEY]]'" ],
    [ 'compara', 'Family',
      "select count(*) from family where description [[COMP]] '[[KEY]]'",
      "select stable_id, description FROM family WHERE description [[COMP]] '[[KEY]]'" ] );
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'URL'       => "/@{[$self->species]}/familyview?family=$_->[0]",
      'idx'       => 'Family',
      'subtype'   => 'Family',
      'ID'        => $_->[0],
      'desc'      => $_->[1],
      'species'   => $self->species
    };
  }
  $self->{'results'}{ 'Family' }  = [ $self->{_results}, $self->{_result_count} ];
}


sub search_SEQUENCE {
  my $self = shift;
  $self->_fetch_results( 
    [ 'core', 'Sequence',
      "select count(*) from seq_region where name [[COMP]] '[[KEY]]'",
      "select sr.name, cs.name, sr.length, 'region' from seq_region as sr, coord_system as cs where cs.coord_system_id = sr.coord_system_id and sr.name [[COMP]] '[[KEY]]'" ],
    [ 'core', 'Sequence',
      "select count(distinct misc_feature_id) from misc_attrib where value [[COMP]] '[[KEY]]'",
      "select ma.value, group_concat( distinct ms.name ), seq_region_end-seq_region_start, 'miscfeature'
         from misc_set as ms, misc_feature_misc_set as mfms,
              misc_feature as mf, misc_attrib as ma, 
              attrib_type as at,
              (
                select distinct ma2.misc_feature_id
                  from misc_attrib as ma2, attrib_type as at2
                 where ma2.attrib_type_id = at2.attrib_type_id and
                       at2.code in ('name','clone_name','embl_acc','synonym','sanger_project') and
                       ma2.value [[COMP]] '[[KEY]]'
              ) as tt
        where ma.misc_feature_id   = mf.misc_feature_id and 
              mfms.misc_feature_id = mf.misc_feature_id and
              mfms.misc_set_id     = ms.misc_set_id     and
              ma.misc_feature_id   = tt.misc_feature_id and
              ma.attrib_type_id    = at.attrib_type_id  and
              at.code in ('name','clone_name','embl_acc','synonym','sanger_project')
        group by mf.misc_feature_id" ]
  );
  foreach ( @{$self->{_results}} ) {
    my $KEY =  $_->[2] < 1e6 ? 'contigview' : 'cytoview';
    $KEY = 'cytoview' if $self->species_defs->NO_SEQUENCE;
    $_ = {
      'URL'       => (lc($_->[1]) eq 'chromosome' && length($_->[0])<10) ? "/@{[$self->species]}/mapview?chr=$_->[0]" :
                        "/@{[$self->species]}/$KEY?$_->[3]=$_->[0]" ,
      'idx'       => 'Sequence',
      'subtype'   => ucfirst( $_->[1] ),
      'ID'        => $_->[0],
      'desc'      => '',
      'species'   => $self->species
    };
  }
  $self->{'results'}{ 'Sequence' }  = [ $self->{_results}, $self->{_result_count} ]
}

sub search_OLIGOPROBE {
  my $self = shift;
  $self->_fetch_results(
    [ 'core', 'OligoProbe',
      "select count(distinct probeset) from oligo_probe where probeset [[COMP]] '[[KEY]]'",
      "select ap.probeset, group_concat(distinct aa.name order by aa.name separator ' ') from oligo_probe ap, oligo_array as aa
        where ap.probeset [[COMP]] '[[KEY]]' and ap.oligo_array_id = aa.oligo_array_id group by ap.probeset" ],
  );
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'URL'       => "/@{[$self->species]}/featureview?type=OligoProbe;id=$_->[0]",
      'idx'       => 'OligoProbe',
      'subtype'   => 'OligoProbe',
      'ID'        => $_->[0],
      'desc'      => 'Is a member of the following arrays: '.$_->[1],
      'species'   => $self->species
    };
  }
  $self->{'results'}{ 'OligoProbe' }  = [ $self->{_results}, $self->{_result_count} ];
}

sub search_QTL {
  my $self = shift;
  $self->_fetch_results(
  [ 'core', 'QTL',
"select count(*)
  from qtl_feature as qf, qtl as q
 where q.qtl_id = qf.qtl_id and q.trait [[COMP]] '[[KEY]]'",
"select q.trait, concat( sr.name,':', qf.seq_region_start, '-', qf.seq_region_end ),
       qf.seq_region_end - qf.seq_region_start
  from seq_region as sr, qtl_feature as qf, qtl as q
 where q.qtl_id = qf.qtl_id and qf.seq_region_id = sr.seq_region_id and q.trait [[COMP]] '[[KEY]]'" ],
  [ 'core', 'QTL',
"select count(*)
  from qtl_feature as qf, qtl_synonym as qs ,qtl as q
 where qs.qtl_id = q.qtl_id and q.qtl_id = qf.qtl_id and qs.source_primary_id [[COMP]] '[[KEY]]'",
"select q.trait, concat( sr.name,':', qf.seq_region_start, '-', qf.seq_region_end ),
       qf.seq_region_end - qf.seq_region_start
  from seq_region as sr, qtl_feature as qf, qtl_synonym as qs ,qtl as q
 where qs.qtl_id = q.qtl_id and q.qtl_id = qf.qtl_id and qf.seq_region_id = sr.seq_region_id and qs.source_primary_id [[COMP]] '[[KEY]]'" ]
  );

  foreach ( @{$self->{_results}} ) {
    $_ = {
      'URL'       => "/@{[$self->species]}/cytoview?l=$_->[1]",
      'idx'       => 'QTL',
      'subtype'   => 'QTL',
      'ID'        => $_->[0],
      'desc'      => '',
      'species'   => $self->species
    };
  }
  $self->{'results'}{'QTL'} = [ $self->{_results}, $self->{_result_count} ];
}


sub search_MARKER {
  my $self = shift;
  $self->_fetch_results( 
    [ 'core', 'Marker',
      "select count(distinct name) from marker_synonym where name [[COMP]] '[[KEY]]'",
      "select distinct name from marker_synonym where name [[COMP]] '[[KEY]]'" ]
  );

  foreach ( @{$self->{_results}} ) {
    my $KEY =  $_->[2] < 1e6 ? 'contigview' : 'cytoview';
    $KEY = 'cytoview' if $self->species_defs->NO_SEQUENCE;
    $_ = {
      'URL'       => "/@{[$self->species]}/markerview?marker=$_->[0]",
      'URL_extra' => [ 'C', 'View marker in ContigView', "/@{[$self->species]}/$KEY?marker=$_->[0]" ],
      'idx'       => 'Marker',
      'subtype'   => 'Marker',
      'ID'        => $_->[0],
      'desc'      => '',
      'species'   => $self->species
    };
  }
  $self->{'results'}{'Marker'} = [ $self->{_results}, $self->{_result_count} ];
}

sub search_GENE {
  my $self = shift;

  my @databases = ('core');
  push @databases, 'vega' if $self->species_defs->databases->{'DATABASE_VEGA'};
  push @databases, 'est' if $self->species_defs->databases->{'DATABASE_OTHERFEATURES'};
  foreach my $db (@databases) {
  $self->_fetch_results( 
    [ $db, 'Gene',
      "select count(*) from gene_stable_id WHERE stable_id [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, g.description, '$db', 'geneview', 'gene' FROM gene_stable_id as gsi, gene as g WHERE gsi.gene_id = g.gene_id and gsi.stable_id [[COMP]] '[[KEY]]'" ],
    [ $db, 'Gene',
      "select count(*) from transcript_stable_id WHERE stable_id [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, g.description, '$db', 'transview', 'transcript' FROM transcript_stable_id as gsi, transcript as g WHERE gsi.transcript_id = g.transcript_id and gsi.stable_id [[COMP]] '[[KEY]]'" ],
    [ $db, 'Gene',
      "select count(*) from translation_stable_id WHERE stable_id [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, x.description, '$db', 'protview', 'peptide' FROM translation_stable_id as gsi, translation as g, transcript as x WHERE g.transcript_id = x.transcript_id and gsi.translation_id = g.translation_id and gsi.stable_id [[COMP]] '[[KEY]]'" ],

    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Gene' and ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, concat( display_label, ' - ', g.description ), '$db', 'geneview', 'gene' from gene_stable_id as gsi, gene as g, object_xref as ox, xref as x
        where gsi.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and gsi.gene_id = g.gene_id and
              ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Gene' and ox.xref_id = x.xref_id and
              x.display_label [[COMP]] '[[KEY]]' and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT gsi.stable_id, concat( display_label, ' - ', g.description ), '$db', 'geneview', 'gene' from gene_stable_id as gsi, gene as g, object_xref as ox, xref as x
        where gsi.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and gsi.gene_id = g.gene_id and
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ],
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Transcript' and ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, concat( display_label, ' - ', g.description ), '$db', 'transview', 'transcript' from transcript_stable_id as gsi, transcript as g, object_xref as ox, xref as x
        where gsi.transcript_id = ox.ensembl_id and ox.ensembl_object_type = 'Transcript' and gsi.transcript_id = g.transcript_id and
              ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Transcript' and ox.xref_id = x.xref_id and
              x.display_label [[COMP]] '[[KEY]]' and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT gsi.stable_id, concat( display_label, ' - ', g.description ), '$db', 'transview', 'transcript' from transcript_stable_id as gsi, transcript as g, object_xref as ox, xref as x
        where gsi.transcript_id = ox.ensembl_id and ox.ensembl_object_type = 'Transcript' and gsi.transcript_id = g.transcript_id and
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ],
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Translation' and ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, concat( display_label ), '$db', 'protview', 'peptide' from translation_stable_id as gsi, object_xref as ox, xref as x
        where gsi.translation_id = ox.ensembl_id and ox.ensembl_object_type = 'Translation' and 
              ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Translation' and ox.xref_id = x.xref_id and
              x.display_label [[COMP]] '[[KEY]]' and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT gsi.stable_id, concat( display_label ), '$db', 'protview', 'peptide' from translation_stable_id as gsi, object_xref as ox, xref as x
        where gsi.translation_id = ox.ensembl_id and ox.ensembl_object_type = 'Translation' and 
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ]
  );
  }
  foreach ( @{$self->{_results}} ) {
    my $KEY =  $_->[2] < 1e6 ? 'contigview' : 'cytoview';
    $KEY = 'cytoview' if $self->species_defs->NO_SEQUENCE;
    $_ = {
      'URL'       => "/@{[$self->species]}/$_->[3]?db=$_->[2];$_->[4]=$_->[0]",
      'URL_extra' => [ 'C', 'View marker in ContigView', "/@{[$self->species]}/$KEY?db=$_->[2];$_->[4]=$_->[0]" ],
      'idx'       => 'Gene',
      'subtype'   => ucfirst($_->[4]),
      'ID'        => $_->[0],
      'desc'      => $_->[1],
      'species'   => $self->species
    };
  }
  $self->{'results'}{'Gene'} = [ $self->{_results}, $self->{_result_count} ];
}

## Result hash contains the following fields...
## 
## { 'URL' => ?, 'type' => ?, 'ID' => ?, 'desc' => ?, 'idx' => ?, 'species' => ?, 'subtype' =>, 'URL_extra' => [] }  
1;
