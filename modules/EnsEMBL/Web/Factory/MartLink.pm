package EnsEMBL::Web::Factory::MartLink;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use CGI qw(escapeHTML);

our @ISA = qw(  EnsEMBL::Web::Factory );

sub _sufficies {
  my $self = shift;
  return if $self->__data->{'sufficies'}{ 'core' };
  $self->__data->{'sufficies'}{ 'core' } = [ '_gene_ensembl', '_gene' ];
  $self->__data->{'sufficies'}{ 'snp'  } = [ '_snp',          ''  ];
  $self->__data->{'sufficies'}{ 'vega' } = [ '_gene_vega',    '' ];
}

sub _link {
  my( $self, %param ) = @_;
  my @E = ();
  foreach my $key (keys %param) {
    foreach (@{$param{$key}}) {
      push @E, "$key=".CGI::escapeHTML($_);
    }
  } 
  my $URL = "/Multi/martview?".join( ';',@E);
  return $self->problem( 'redirect', $URL );
}

sub createObjects { 
  my $self      = shift;    
  my $option    = $self->param( 'type' );
  my $method    = "_createObjects_$option";
  $self->_sufficies;
  if( $self->can( $method ) ) {
    my $res = $self->$method;
    if( $res ) {
      $self->problem( 'redirect', $res );
      return
    }
  }
  return $self->problem( 'Fatal', 'Unknown Link type', "Could not redirect to mart." );
}

sub _createObjects_gene_region { return $_[0]->_createObjectsLocation( 'core' ); }
sub _createObjects_snp_region  { return $_[0]->_createObjectsLocation( 'snp' ); }
sub _createObjects_vega_region { return $_[0]->_createObjectsLocation( 'vega' ); }

sub _createObjects_gene { return $_[0]->_createObjectsType( 'core' ); }
sub _createObjects_snp  { return $_[0]->_createObjectsType( 'snp' ); }
sub _createObjects_vega { return $_[0]->_createObjectsType( 'vega' ); }

sub _dataset {
  my( $self, $type ) = @_;
  if( $type eq 'snp' && ! $self->species_defs->databases->{'ENSEMBL_VARIATION'} ||
      $type eq 'vega' && ! $self->species_defs->databases->{'ENSEMBL_VEGA'} ) {
    $self->problem( 'fatal', 'Unknown dataset', qq(Do not know about dataset of type "$type" for this species) );
    return undef;
  }
  my $suffix = $self->__data->{'sufficies'}{$type}[0];
  unless($suffix) {
    $self->problem( 'fatal', 'Unknown dataset', qq(Do not know about dataset of type "$type" for this species) );
    return undef;
  }
  (my $dataset = lc($self->species)) =~ s/^([a-z])[a-z]+_/$1/;
  return "$dataset$suffix", $self->__data->{'sufficies'}{$type}[1];
}

sub _createObjectsType {
  my( $self, $type ) = @_;
  my( $DB, $TYPE ) = $self->_dataset( $type );
  return unless $DB;
  return $self->_link(
    'schema'            => [ 'default' ],
    'dataset'           => [ $DB ],
    'stage_initialised' => [ 'start' ],
    'stage'             => [ 'filter' ],
  );
}

sub _createObjectsLocation {
  my( $self, $type ) = @_;
  my( $DB, $TYPE ) = $self->_dataset( $type );
  return unless $DB;
  my($sr,$start,$end) = $self->param('l') =~ /^(\w+):(-?[.\w]+)-([.\w]+)$/;
  if( $DB =~ /(snp|vega)/ ) {
  return $self->_link(
    'schema'            => [ 'default' ],
    'dataset'           => [ $DB ],
    'stage_initialised' => [ 'start', 'filter' ],
    'stage'             => [ 'output' ],
    $DB.'_collection_chromosome' => [ 1 ],
    $DB.'_chr_name'     => [ $sr ],
    $DB.'_collection_chromosome_coordinates' => [ 1 ],
    $DB.'_chrom_start' => [ $start ],
    $DB.'_chrom_end'   => [ $end ]
  );
  } else {
  return $self->_link(
    'schema'            => [ 'default' ],
    'dataset'           => [ $DB ],
    'stage_initialised' => [ 'start', 'filter' ],
    'stage'             => [ 'output' ],
    $DB.'_collection_chromosome' => [ 1 ],
    $DB.'_chromosome_name'     => [ $sr ],
    $DB.'_collection_chromosome_coordinates' => [ 1 ],
    $DB.'_start' => [ $start ],
    $DB.'_end'   => [ $end ]
  );
  }
}

sub _createObjects_family {
  my $self = shift;
  my( $DB, $TYPE ) = $self->_dataset( 'core' );
  return unless $DB;
  return $self->_link( 
    'schema'            => [ 'default' ],
    'dataset'           => [ $DB ],
    'stage_initialised' => [ 'start', 'filter' ],
    'stage'             => [ 'output' ],
    $DB.'_collection_family_domain_id_list' => [ 1 ],
    $DB.'_protein_fam_id_filters'     => [ 'ensembl_family' ],
    $DB.'_protein_fam_id_filters_list' => [ $self->param('family_id') ]
  );
}

sub _createObjects_familyseq {
  my $self = shift;
  my( $DB, $TYPE ) = $self->_dataset( 'core' );
  return unless $DB;
  return $self->_link( 
    'schema'            => [ 'default' ],
    'dataset'           => [ $DB ],
    'stage_initialised' => [ 'start', 'filter' ],
    'stage'             => [ 'output' ],
    'outtype'           => [ 'sequences' ],
    $DB.'_collection_family_domain_id_list' => [ 1 ],
    $DB.'_protein_fam_id_filters'     => [ 'ensembl_family' ],
    $DB.'_protein_fam_id_filters_list' => [ $self->param('family_id') ]
  );
}

sub _createObjects_domain {
  my $self = shift;
  my( $DB, $TYPE ) = $self->_dataset( 'core' );
  return unless $DB;
  return $self->_link( 
    'schema'            => [ 'default' ],
    'dataset'           => [ $DB ],
    'stage_initialised' => [ 'start', 'filter' ],
    'stage'             => [ 'output' ],
    $DB.'_collection_family_domain_id_list' => [ 1 ],
    $DB.'_protein_fam_id_filters'     => [ 'interpro' ],
    $DB.'_protein_fam_id_filters_list' => [ $self->param('domain_id') ]
  );
}

sub _createObjects_xref {
  my $self = shift;
  my( $DB, $TYPE ) = $self->_dataset( 'core' );
  return unless $DB;
  return $self->_link( 
    'schema'            => [ 'default' ],
    'dataset'           => [ $DB ],
    'stage_initialised' => [ 'start', 'filter' ],
    'stage'             => [ 'output' ],
    $DB.'_collection_id_list_limit' => [ 1 ],
    $DB.'_id_list_limit_filters' => [ lc($self->param('db')) ],
    $DB.'_id_list_limit_filters_list'  => [ $self->param('id') ]
  );
}

1;
  
