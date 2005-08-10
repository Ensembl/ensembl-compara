package Bio::EnsEMBL::GlyphSet::alignment;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

sub my_label { 
    my ($self) = @_;
    return $self->{'container'}->{'species'}; 
}

sub features {
    my ($self) = @_;
    my $start = 0;

    my $amatch = $self->{'container'}->{alignmatch};
    my $emark = $self->{'container'}->{exons_markup};
    my $smark = $self->{'container'}->{snps_markup};

# Convert the sequence to the lower case and replace '-' with '_' so later we can distinguish between 
#  '-' that are in the middle of exon and those that are outside.
    my $seq = lc($self->{'container'}->seq);
    $seq =~ s/-/_/g;

# Reverse sequence if it is on the reverse strand
    my $strand = $self->strand;
    if($strand == -1 ) { $seq=~tr/acgt/tgca/; }

# now apply exon marking to the sequence: the exon bases are uppercased and _ symbols inside exons replaced with -
    foreach my $e (@$emark) {
	my $s1 = uc(substr($seq, $e->{start} -1, $e->{end}-$e->{start}+1));
	$s1 =~ s/_/-/g;
	substr($seq, $e->{start} -1, $e->{end} - $e->{start}+1) = $s1, 
    }

    my @features = map { 
       Bio::EnsEMBL::Feature->new(
	   -start   => ++$start,
	   -end     => $start,
           -strand  => $strand,
           -seqname => $_
       )
    } split //, $seq;

# bases that are inside exons (i.e - and A..Z) coloured in shades of blue and those that are outside (i.e _ and a .. z)  in pink.
    my $ind = 0;

    foreach (@features) {
	my $base = uc($_->seqname);

	if ($amatch->[$ind++]->{S} =~ /$base/) {
	    $_->{colour} = ord($_->seqname) < 90 ? 'lightsteelblue' : 'pink1';
	} else {
	    $_->{colour} = ord($_->seqname) < 90 ? 'aliceblue' : 'mistyrose1';
	}
# Go back to the normal way of displaying unknown bases
	$_->seqname('-') if ($_->seqname eq '_');
    }

# mark exon start and exon end
    foreach my $e (@$emark) {
	if ($e->{strand} < 0) {
	    ($features[$e->{start}-1])->{type} = 'mark_rexonstart' if ($e->{active_start});
	    ($features[$e->{end}-1])->{type} = 'mark_rexonend' if ($e->{active_end});;
	} else {
	    ($features[$e->{start}-1])->{type} = 'mark_exonstart' if ($e->{active_start});;
	    ($features[$e->{end}-1])->{type} = 'mark_exonend' if ($e->{active_end});;
	}
    }

# mark up SNPs
    foreach my $e (@$smark) {
	my $f = $features[$e->{start}-1];
	$f->{type} = ($f->{type} || 'mark').'_snp';
	$f->{source} = $e->{source}; 
	$f->{consequence_type} = $e->{consequence_type};
	$f->{variation_name} = $e->{variation_name};
	$f->{allele_string} = $e->{allele_string};
	$f->{ambig_code} = $e->{ambig_code};
	$f->{var_class} = $e->{var_class};
	my $cname = $f->{consequence_type};
#	$f->{label_colour} = $self->{'colours'}{$cname};
	$f->{colour} = $self->{'colours'}{$cname};
   }

    return \@features;
}

sub colour {
    my ($self, $f) = @_;
    return $f->{colour}, $f->{type} =~ /_snp/ ? 'white' : 'black', 'align';
}

sub image_label { 
    my ($self, $f ) = @_; 
    return $f->seqname(), $f->{type} || 'overlaid2'; 
}

sub href {
  my $self = shift;
  my $f    = shift;

  return undef unless $f->{type} =~ /_snp/;
  my $view = shift || 'alignsliceview';
  my $slice = $self->{'container'};
  my $start  = $slice->get_original_seq_region_position( $f->{start} );
  my $id     = $f->{variation_name};
  my $source = $f->{source};
  my $region = $self->{'container'}->seq_region_name();

  if ($view eq 'ldview' ){
    my $Config   = $self->{'config'};
    my $only_pop = $Config->{'_ld_population'};
    $start .= "&pop=$only_pop" if $only_pop;
  }
  return "/@{[$self->{container}{_config_file_name_}]}/$view?snp=$id&source=$source&c=$region:$start";
}

sub zmenu {
  my ($self, $f ) = @_;
  return undef unless $f->{type} =~ /_snp/;
  my( $start, $end ) = ( $f->start, $f->end );
  my $allele = $f->{allele_string};

  my $slice = $self->{'container'};
  &eprof_start('href'); 
  my $rpos  = $slice->get_original_seq_region_position( $f->{start} );

  my $pos =  $start;

  if($f->start > $f->end  ) {
    $pos = "between&nbsp;$start&nbsp;&amp;&nbsp;$end";
  }
  elsif($f->start < $f->end ) {
    $pos = "$start&nbsp;-&nbsp;$end";
  }

#  my $status = join ", ", @{$f->get_all_validation_states};
  my %zmenu = ( 
 	       caption               => "SNP: " . ($f->{variation_name}),
 	       '01:SNP properties'   => $self->href( $f, 'snpview' ),
               ( $self->{'config'}->_is_available_artefact( 'database_tables ENSEMBL_VARIATION.pairwise_ld' ) ?
 	         ( '02:View in LDView'   => $self->href( $f, 'ldview' ) ) : ()
               ),
 	       "03:bp: $rpos ($pos)"         => '',
# 	       "04:status: ".($status || '-') => '',
	       "05:SNP type: ".($f->{var_class}) => '',
 	       "07:ambiguity code: ".$f->{ambig_code} => '',
 	       "08:alleles: ".$allele => '',
	      );

#  $zmenu{"16:dbSNP: ".$f->variation_name} =
#    $self->ID_URL("dbSNP", $f->variation_name) if $f->source eq 'dbSNP';

  my $consequence_type = $f->{consequence_type};
  $zmenu{"57:Type: $consequence_type"} = "" unless $consequence_type eq '';  
  return \%zmenu;
}


1;
