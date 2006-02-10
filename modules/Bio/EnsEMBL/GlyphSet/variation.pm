package Bio::EnsEMBL::GlyphSet::variation;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
use Data::Dumper;
use Bio::EnsEMBL::Variation::VariationFeature;


sub my_label { return "SNPs"; }

sub features {
  my ($self) = @_;
  my $snps = $self->{'config'}->{'snpview'}->{'snps'} || [];
  if(@$snps) {
    $self->{'config'}->{'variation_legend_features'}->{'variations'} 
        = { 'priority' => 1000, 'legend' => [] };
  }

  return $snps;
}

sub href {
  my $self = shift;
  my $f    = shift;
  my $view = shift || 'snpview';

  my $id     = $f->variation_name;
  my $source = $f->source;
  my ($species, $start, $region, $oslice);

  if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
      ($oslice, $start)  = $self->{'container'}->get_original_seq_region_position( $f->{start} );
      $region = $oslice->seq_region_name();
      ($species = $self->{container}->genome_db->name) =~ s/ /_/g;
      
  } else {
      $start  = $self->slice2sr( $f->start, $f->end );
      $region = $self->{'container'}->seq_region_name();
      $species = "@{[$self->{container}{_config_file_name_}]}";
  }

  if ($view eq 'ldview' ){
    my $Config   = $self->{'config'};
    my $only_pop = $Config->{'_ld_population'};
    $start .= ";pop=$only_pop" if $only_pop;
  }

  return "/$species/$view?snp=$id;source=$source;c=$region:$start;w=20000";
}

sub image_label {
  my ($self, $f) = @_;
  my $ambig_code = $f->ambig_code;
  my @T = $ambig_code eq '-' ? undef : ($ambig_code,'overlaid');
  return @T;
}

sub tag {
  my ($self, $f) = @_;
  &eprof_start( 'tag' );
  my $so_that_I_can_eprof_tag;
  if($f->start > $f->end ) {    
    my $consequence_type = $f->get_consequence_type;
    $so_that_I_can_eprof_tag = ( { 'style' => 'insertion', 
	       'colour' => $self->{'colours'}{"$consequence_type"}[0] } );
  }

}

sub colour {
  my ($self, $f) = @_;
  my $consequence_type = $f->get_consequence_type();
  unless($self->{'config'}->{'variation_types'}{$consequence_type}) {
    push @{ $self->{'config'}->{'variation_legend_features'}->{'variations'}->{'legend'}},
      $self->{'colours'}{$consequence_type}[1],  $self->{'colours'}{$consequence_type}[0];

    $self->{'config'}->{'variation_types'}{$consequence_type} = 1;
  }
  return $self->{'colours'}{$consequence_type}[0],
    $self->{'colours'}{$consequence_type}[2],
      $f->start > $f->end ? 'invisible' : '';
}


sub zmenu {
  my ($self, $f ) = @_;
  &eprof_start('zmenu');
  my( $start, $end );
  my $allele = $f->allele_string;


  if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
      $start  = $self->{'container'}->get_original_seq_region_position( $f->start );
      $end  = $self->{'container'}->get_original_seq_region_position( $f->end );
  } else {
      ($start, $end) = $self->slice2sr( $f->start, $f->end );
  }

  my $pos =  $start;

  if($f->start > $f->end  ) {
    $pos = "between&nbsp;$start&nbsp;&amp;&nbsp;$end";
  }
  elsif($f->start < $f->end ) {
    $pos = "$start&nbsp;-&nbsp;$end";
  }

  my $status = join ", ", @{$f->get_all_validation_states};
  my %zmenu = ( 
 	       caption               => "SNP: " . ($f->variation_name),
 	       '01:SNP properties'   => $self->href( $f, 'snpview' ),
               ( $self->{'config'}->_is_available_artefact( 'database_tables ENSEMBL_VARIATION.pairwise_ld' ) ?
 	         ( '02:View in LDView'   => $self->href( $f, 'ldview' ) ) : ()
               ),
 	       "03:bp: $pos"         => '',
 	       "04:status: ".($status || '-') => '',
 	       "05:SNP type: ".($f->var_class || '-') => '',
 	       "07:ambiguity code: ".$f->ambig_code => '',
 	       "08:alleles: ".$f->allele_string => '',
 	       "09:source: ".$f->source => '',
	      );

 # foreach my $db (@{  $variation->get_all_synonym_sources }) {
  #  if( $db eq 'TSC-CSHL' || $db eq 'HGVBASE' || $db eq 'dbSNP' || $db eq 'WI' ) {
  #  }
  #}
  my $consequence_type = $f->get_consequence_type;
  my $label = $self->{'colours'}{$consequence_type}[1]; 
  $zmenu{"57:Type: $label"} = "" unless $consequence_type eq '';  
  eprof_end( 'zmenu' );
  return \%zmenu;
}
1;
