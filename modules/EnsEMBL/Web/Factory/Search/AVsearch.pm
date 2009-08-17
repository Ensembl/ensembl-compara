package EnsEMBL::Web::Factory::Search::AltaVista;

use strict;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
our @ISA = qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self       = shift;    
  ### Parse parameters to get index names
  my $idx      = $self->param('type') || $self->param('idx') || 'all';
  ### Parse parameters to get Species names
  my $species  = $self->param('species') || $self->species || 'all';
  warn "SEARCHING USING ALTAVISTA TO FIND $idx in $species";
}

sub generic_search {
  my $self = shift;
  my @indexes = @{$_[0]||[]};
  my @species = @{$_[1]||[]};
  :q

}

sub search_ALL {
  my( $self, $species ) = @_;
  my $package_space = __PACKAGE__.'::';
  no strict 'refs';
  my @methods = map { /(search_\w+)/ && $1 ne 'search_ALL' ? $1 : () } keys %$package_space;
  warn @methods;
  my @ALL = ();
  foreach my $method (@methods) {
    push @ALL, $self->$method( $species ) if $self->can($method);
  }
  return @ALL;
}

 
sub search_DOMAIN {
  my( $self, $species ) = @_;
  #OLD CODE??: return { 'count' => 1, 'results' => [$keyword] } if ($keyword=~/IPR\d{6}/);
  return map {{
    'URL'       => "/$species/domainview?domain=$_->[0]",
    'idx'       => 'Domain',
    'subtype'   => 'Domain',
    'ID'        => $_->[0],
    'desc'      => '',
    'species'   => $species
  }} @{$self->selectall_arrayref( $species, 'core', qq(
    SELECT x.dbprimary_acc 
      FROM xref as x, external_db as e
     WHERE e.db_name = 'Interpro' and e.external_db_id = x.external_db_id and
           x.dbprimary_acc [[COMP]] '[[KEY]]'
    ))};
}
# IF NO RESULTS< USE THIS:
#    "SELECT    x.dbprimary_acc 
#           FROM xref as x, external_db as e
#          WHERE e.db_name = 'Interpro' and e.external_db_id = x.external_db_id and
#                    x.description $comparator '$keyword'
#                    $offset $limit"

sub xsearch_FAMILY {
  my( $self, $species ) = @_;
  return map {{
    'URL'       => "/$species/familyview?family=$_->[0]",
    'idx'       => 'Family',
    'subtype'   => 'Family',
    'ID'        => $_->[0],
    'desc'      => '',
    'species'   => $species
  }} @{$self->selectall_arrayref( $species, 'compara', qq(
  SELECT stable_id    
    FROM family 
   WHERE stable_id  [[COMP]] '[[KEY]]'"
     ))};
}


sub search_MARKER {
  my( $self, $species ) = @_;
  return map {{
    'URL'       => "/$species/markerview?marker=$_->[0]",
    'URL_extra' => [ 'C', 'View marker in ContigView', "/$species/contigview?marker=$_->[0]" ],
    'idx'       => 'Marker',
    'subtype'   => 'Marker',
    'ID'        => $_->[0],
    'desc'      => '',
    'species'   => $species
  }} @{$self->selectall_arrayref( $species, 'core', qq(
    SELECT distinct name
      from marker_synonym
     WHERE name [[COMP]] '[[KEY]]'
    ))}
}

sub xsearch_SNP {
  my( $self, $species ) = @_;
  # OLD CODE: return { 'count' => 0, 'results' => [] } unless $databases->{'SNP'};
  return map {{
    'URL'       => "/$species/snpview?snp=$_->[0]",
    'URL_extra' => [ 'C', 'View snp in ContigView', "/$species/contigview?snp=$_->[0]" ],
    'idx'       => 'SNP',
    'subtype'   => 'SNP',
    'ID'        => $_->[0],
    'desc'      => '',
    'species'   => $species
  }} @{$self->selectall_arrayref( $species, 'Variation', qq(
    SELECT distinct id
      from RefSNP
     WHERE id [[COMP]] '[[KEY]]'
    ))};
}

sub search_GENE {
  my( $self, $species ) = @_;

  my @databases = [ 'core',  'Ensembl Gene', 'Ensembl Transcript', 'Ensembl Peptide' ];
  push @databases, [ 'vega', 'Vega Loci', 'Vega Transcript', 'Vega Peptide' ] if $self->species_defs->get_config($species, 'databases')->{'DATABASE_VEGA'};
  push @databases, [ 'est',  'EST gene', 'EST Transcript', 'EST Peptide' ] if $self->species_defs->get_config($species, 'databases')->{'DATABASE_OTHERFEATURES'};

  my @RES = ();
  foreach my $db ( @databases ) {
    push @RES, map {{
      'URL'       => "/$species/geneview?gene=$_->[0];db=$db->[0]",
      'URL_extra' => [ 'C', 'View gene in ContigView', "/$species/contigview?gene=$_->[0];db=$db->[0]" ],
      'idx'       => 'Gene',
      'subtype'   => $db->[1],
      'ID'        => $_->[0],
      'desc'      => "$db->[1] $_->[0]",
      'species'   => $species
    }} @{$self->selectall_arrayref( $species, $db->[0], qq(
     SELECT stable_id FROM gene_stable_id WHERE stable_id [[COMP]] '[[KEY]]' ORDER BY stable_id
    ))};
    push @RES, map {{
      'URL'       => "/$species/transview?transcript=$_->[0];db=$db->[0]",
      'URL_extra' => [ 'C', 'View transcript in ContigView', "/$species/contigview?transcript=$_->[0];db=$db->[0]" ],
      'idx'       => 'Gene',
      'subtype'   => $db->[2],
      'ID'        => $_->[0],
      'desc'      => "$db->[2] $_->[0]",
      'species'   => $species
    }} @{$self->selectall_arrayref( $species, $db->[0], qq(
     SELECT stable_id FROM transcript_stable_id WHERE stable_id [[COMP]] '[[KEY]]' ORDER BY stable_id
    ))};
    push @RES, map {{
      'URL'       => "/$species/protview?peptide=$_->[0];db=$db->[0]",
      'URL_extra' => [ 'C', 'View peptide in ContigView', "/$species/contigview?peptide=$_->[0];db=$db->[0]" ],
      'idx'       => 'Gene',
      'subtype'   => $db->[2],
      'ID'        => $_->[0],
      'desc'      => "$db->[2] $_->[0]",
      'species'   => $species
    }} @{$self->selectall_arrayref( $species, $db->[0], qq(
     SELECT stable_id FROM translation_stable_id WHERE stable_id [[COMP]] '[[KEY]]' ORDER BY stable_id
    ))};
    push @RES, map {{
      'URL'       => "/$species/geneview?gene=$_->[0];db=$db->[0]",
      'URL_extra' => [ 'C', 'View in ContigView', "/$species/contigview?gene=$_->[0];db=$db->[0]" ],
      'idx'       => 'Gene',
      'subtype'   => $db->[1],
      'ID'        => $_->[0],
      'desc'      => "Identifier $_->[1] maps to $db->[1] $_->[0]",
      'species'   => $species
    }} @{$self->selectall_arrayref( $species, $db->[0], qq(
      SELECT gsi.stable_id, display_label from gene_stable_id as gsi, object_xref as ox, xref as x
       where gsi.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and
             ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'
       order by stable_id
    )),
    $self->selectall_arrayref( $species, $db->[0], qq(
       SELECT gsi.stable_id, display_label from gene_stable_id as gsi, object_xref as ox, xref as x
        where gsi.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')
        order by stable_id
    ))};
    push @RES, map {{
      'URL'       => "/$species/transview?transcript=$_->[0];db=$db->[0]",
      'URL_extra' => [ 'C', 'View in ContigView', "/$species/contigview?transcript=$_->[0];db=$db->[0]" ],
      'idx'       => 'Gene',
      'subtype'   => $db->[2],
      'ID'        => $_->[0],
      'desc'      => "Identifier $_->[1] maps to $db->[2] $_->[0]",
      'species'   => $species
    }} @{$self->selectall_arrayref( $species, $db->[0], qq(
      SELECT tsi.stable_id, display_label from transcript_stable_id as tsi, object_xref as ox, xref as x
       where tsi.transcript_id = ox.ensembl_id and ox.ensembl_object_type = 'Transcript' and
             ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'
       order by stable_id
    )),
    $self->selectall_arrayref( $species, $db->[0], qq(
       SELECT tsi.stable_id, display_label from transcript_stable_id as tsi, object_xref as ox, xref as x
        where tsi.transcript_id = ox.ensembl_id and ox.ensembl_object_type = 'Transcript' and
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')
        order by stable_id
    ))};
    push @RES, map {{
      'URL'       => "/$species/protview?peptide=$_->[0];db=$db->[0]",
      'URL_extra' => [ 'C', 'View in ContigView', "/$species/contigview?peptide=$_->[0];db=$db->[0]" ],
      'idx'       => 'Gene',
      'subtype'   => $db->[3],
      'ID'        => $_->[0],
      'desc'      => "Identifier $_->[1] maps to $db->[3] $_->[0]",
      'species'   => $species
    }} @{$self->selectall_arrayref( $species, $db->[0], qq(
      SELECT tsi.stable_id, display_label from translation_stable_id as tsi, object_xref as ox, xref as x
       where tsi.translation_id = ox.ensembl_id and ox.ensembl_object_type = 'Translation' and
             ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'
       order by stable_id
    )),
    $self->selectall_arrayref( $species, $db->[0], qq(
       SELECT tsi.stable_id, display_label from translation_stable_id as tsi, object_xref as ox, xref as x
        where tsi.translation_id = ox.ensembl_id and ox.ensembl_object_type = 'Translation' and
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')
        order by stable_id
    ))};
  }
  return EnsEMBL::Web::Proxy::Object->new( 'Search', \@RES, $self->__data );
}

## Result hash contains the following fields...
## 
## { 'URL' => ?, 'type' => ?, 'ID' => ?, 'desc' => ?, 'idx' => ?, 'species' => ?, 'subtype' =>, 'URL_extra' => [] }  
1;
