package Bio::EnsEMBL::GlyphSet::variation;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
use Data::Dumper;

sub my_label { return "Variations"; }

sub features {
  my ($self) = @_;
 #    &eprof_start('function-a');
  my @vari_features = 
             map { $_->[1] } 
             sort { $a->[0] <=> $b->[0] }
             map { [ substr($_->consequence_type,0,2) * 1e9 + $_->start, $_ ] }
             grep { $_->map_weight < 4 } @{$self->{'container'}->get_all_VariationFeatures()};

  if(@vari_features) {
    $self->{'config'}->{'variation_legend_features'}->{'variations'} 
        = { 'priority' => 1000, 'legend' => [] };
  }
 #&eprof_start('function-a');
#&eprof_dump(\*STDERR);
  return \@vari_features;
}

sub href {
  my ($self, $f ) = @_;
  my( $chr_start, $chr_end ) = $self->slice2sr( $f->start, $f->end );
  my $id = $f->variation_name;
  $id =~ s/^rs//;
  my $source = $f->variation->source;
  my $chr_name = $self->{'container'}->seq_region_name();  # call seq region on slice

  return "/@{[$self->{container}{_config_file_name_}]}/variationview?snp=$id&source=$source&chr=$chr_name&vc_start=$chr_start";
}

sub image_label {
  my ($self, $f) = @_;
  return $f->{'_ambiguity_code'} eq '-' ? undef : ($f->{'_ambiguity_code'},'overlaid');
}

sub tag {
  my ($self, $f) = @_;
  if($f->start > $f->end ) {
    my $consequence_type = $f->consequence_type;
    return ( { 'style' => 'insertion', 
	       'colour' => $self->{'colours'}{"$consequence_type"} } );
  }
  else {
    return undef;
  }
}

sub colour {
  my ($self, $f) = @_;
  # Allowed values are: 'INTRONIC','UPSTREAM','DOWNSTREAM',
  #             'SYNONYMOUS_CODING','NON_SYNONYMOUS_CODING','FRAMESHIFT_CODING',
  #             '5PRIME_UTR','3PRIME_UTR','INTERGENIC'

  my $consequence_type = $f->consequence_type();
  unless($self->{'config'}->{'variation_types'}{$consequence_type}) {
    my %labels = (
         	  '_'                    => 'Other SNPs',
		  'INTRONIC'             => 'Intronic SNPs',
		  'UPSTREAM'             => 'Upstream',
		  'DOWNSTREAM'           => 'Downstream',
		  'SYNONYMOUS_CODING'    => 'Synonymous coding',
		  'NON_SYNONYMOUS_CODING'=> 'Non-synonymous coding',
		  'FRAMESHIFT_CODING'    => 'Frameshift coding SNP',
		  '5PRIME_UTR'           => '5\' UTR',
		  '3PRIME_UTR'           => '3\' UTR',
		  'INTERGENIC'           => 'Intergenic SNPs',
		 );
    push @{ $self->{'config'}->{'variation_legend_features'}->{'variations'}->{'legend'}},
     $labels{"$consequence_type"} => $self->{'colours'}{"$consequence_type"};
    $self->{'config'}->{'variation_types'}{$consequence_type} = 1;
  }
  return $self->{'colours'}{"$consequence_type"},
    $self->{'colours'}{"label$consequence_type"}, 
      $f->start > $f->end ? 'invisible' : '';

}


sub zmenu {
  my ($self, $f ) = @_;
  my( $chr_start, $chr_end ) = $self->slice2sr( $f->start, $f->end );
  my $allele = $f->allele_string;
  my $pos =  $chr_start;

  if($f->start > $f->end  ) {
    $pos = "between&nbsp;$chr_start&nbsp;&amp;&nbsp;$chr_end";
  }
  elsif($f->start < $f->end ) {
    $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
  }

  my $variation = $f->variation;
  my $status = join ", ", @{$variation->get_all_validation_states};
  my %zmenu = ( 
 	       caption               => "SNP: " . ($f->variation_name),
 	       '01:SNP properties'   => $self->href( $f ),
 	       "02:bp: $pos"         => '',
 	       "03:status: ".($status || '-') => '',
 	       "03:variation type: ".($f->var_class || '-') => '',
 	       "07:ambiguity code: ".$f->ambig_code => '',
 	       "08:alleles: ".$f->allele_string => '',
	      );

  foreach my $db (@{  $variation->get_all_synonym_sources }) {
    if( $db eq 'TSC-CSHL' || $db eq 'HGVBASE' || $db eq 'dbSNP' || $db eq 'WI' ) {
      $zmenu{"16:$db: ".$f->variation_name} =$self->ID_URL($db, $f->variation_name);
    }
  }

  my $consequence_type = $f->consequence_type;
  $zmenu{"57:Type: $consequence_type"} = "" unless $consequence_type eq '';  
  return \%zmenu;
}
1;
