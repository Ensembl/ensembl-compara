package Bio::EnsEMBL::GlyphSet::_variation;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

use Bio::EnsEMBL::Variation::VariationFeature;


sub my_label { return "SNPs"; }

sub features {
  my ($self) = @_;
  my $Config = $self->{'config'};
  my $type = $self->check();
  my $max_length     = $Config->get( $type, 'threshold' )  || 1000;
  my $slice_length  = $self->{'container'}->length;
  if($slice_length > $max_length*1010) {
    $self->errorTrack('Variation features not displayed for more than '.$max_length.'Kb');
    return;
  }
  return $self->fetch_features;
}

sub fetch_features {
  my ($self) = @_;
  unless( exists( $self->{'config'}->{'snps'} ) ) {
    my %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;
    my $vf_ref = $self->{'container'}->get_all_VariationFeatures();
    my @vari_features =
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $ct{$_->display_consequence} * 1e9 + $_->start, $_ ] }
      grep { $_->map_weight < 4 } @$vf_ref;
    if(@vari_features && !$self->{'config'}->{'variation_legend_features'} ) {
      #warn "...................".ref($self)."........................";
      $self->{'config'}->{'variation_legend_features'}->{'variations'} = { 'priority' => 1000, 'legend' => [] };
    }
    $self->{'config'}->{'snps'} = \@vari_features;
  }
  my $snps = $self->{'config'}->{'snps'} || [];
  if(@$snps) {
    unless( $self->{'config'}->{'variation_legend_features'} ) {
      $self->{'config'}->{'variation_legend_features'}->{'variations'} = { 'priority' => 1000, 'legend' => [] };
    }
    foreach my $f (@$snps) {
warn $f,' ',$f->display_consequence;
      $self->colour( $f );
    }
  }
  return $snps;
}

sub href {
  my $self = shift;
  my $f    = shift;
  my $view = shift || 'snpview';
  my $pops;

  if ($view eq 'ldview') {
    my $Config   = $self->{'config'};
    my $config_pop = $Config->{'_ld_population'};
    
    return unless $config_pop;
    foreach ( @$config_pop ) {
      $pops .= "pop=$_;";
    }
  }

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

  return "/$species/$view?snp=$id;source=$source;c=$region:$start;w=20000;$pops";
}

sub image_label {
  my ($self, $f) = @_;
  my $ambig_code = $f->ambig_code;
  my @T = $ambig_code eq '-' ? undef : ($ambig_code,'overlaid');
  return @T;
}

sub tag {
  my ($self, $f) = @_;
  if($f->start > $f->end ) {    
    my $consequence_type = $f->display_consequence;
    return ( { 'style' => 'insertion', 'colour' => $self->{'colours'}{"$consequence_type"}[0] } );
  }
}

sub colour {
  my ($self, $f) = @_;

  my $consequence_type = $f->display_consequence();
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
  my $ldview_link =  $self->href( $f, 'ldview' );

  my $status = join ", ", @{$f->get_all_validation_states};
  my %zmenu = ( 
 	       caption               => "SNP: " . ($f->variation_name),
 	       '01:SNP properties'   => $self->href( $f, 'snpview' ),
               ( $ldview_link  ?
 	         ( '02:View in LDView'   => $ldview_link ) : ()
               ),
 	       "03:bp: $pos"         => '',
 	       "04:status: ".($status || '-') => '',
 	       "05:class: ".($f->var_class || '-') => '',
 	       "07:ambiguity code: ".$f->ambig_code => '',
 	       "08:alleles: ".$f->allele_string => '',
 	       "09:source: ".$f->source => '',
	      );

  my @label;
  map { push @label, $self->{'colours'}{$_}[1]; }  @{ $f->get_consequence_type || [] };
  $zmenu{"57:type: ".join ", ", @label} = "";
  return \%zmenu;
}

sub affy_features {
  my ($self) = @_;
  my $snps = $self->fetch_features;
  my $key = $self->_key();
  my $source_name = "Affy GeneChip $key Mapping Array";

  my @affy_snps;
  foreach my $vf (@$snps) {
    foreach  ( @{ $vf->get_all_sources || []}) {
      next unless $_ eq $source_name;
      push @affy_snps, $vf;
    }
  }
  return \@affy_snps;
}

1;
