package EnsEMBL::Web::Text::Feature::SNP;

### Ensembl format for SNP data (e.g. for SNP Effect Predictor)

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);
use Bio::EnsEMBL::Variation::Utils::Sequence qw/unambiguity_code/;

sub new {
  my( $class, $args ) = @_;
  
  # pileup
  if(
	$args->[0] =~ /(chr)?\w+/ &&
	$args->[1] =~ /\d+/ &&
	$args->[2] =~ /^[ACGTN-]+$/ &&
	$args->[3] =~ /^[ACGTNRYSWKM*+\/-]+$/
  ) {
	my @new_args = ();
	
	# normal variation
	if($args->[2] ne "*"){
	  (my $var = unambiguity_code($args->[3])) =~ s/$args->[2]//ig;
	  if(length($var)==1){
		@new_args = ($args->[0], $args->[1], $args->[1], $args->[2]."/".$var, 1, undef);
	  }
	  else{
		for my $nt(split //,$var){
		  @new_args = ($args->[0], $args->[1], $args->[1], $args->[2]."/".$nt, 1, undef);
		  last; # we can only create one feature per line in pileup unforunately
		}
	  }
	}
	
	# indel
	else{
	  my @genotype=split /\//,$args->[3];
	  foreach my $allele(@genotype){
		if(substr($allele,0,1) eq "+") { #ins
		  @new_args = ($args->[0], $args->[1]+1, $args->[1], "-/".substr($allele,1), 1, undef);
		  last;
		}
		elsif(substr($allele,0,1) eq "-"){ #del
		  @new_args = ($args->[0], $args->[1], $args->[1]+length($args->[3])-4, substr($allele,1)."/-", 1, undef);
		}
	  }
	}
	
	$args = \@new_args;
  }
	
  # vcf
  elsif(
	$args->[0] =~ /(chr)?\w+/ &&
	$args->[1] =~ /\d+/ &&
	$args->[3] =~ /^[ACGTN-]+$/ &&
	$args->[4] =~ /^([\.ACGTN-]+\,?)+$/
  ) {
	
	# get relevant data
	my ($start, $end, $ref, $alt) = ($args->[1], $args->[1], $args->[3], $args->[4]);
	
	# adjust end coord
	$end += (length($ref) - 1);
	
	# find out if any of the alt alleles make this an insertion or a deletion
	my ($is_indel, $is_sub, $ins_count, $total_count);
	foreach my $alt_allele(split /\,/, $alt) {
	  $is_indel = 1 if $alt_allele =~ /D|I/;
	  $is_indel = 1 if length($alt_allele) != length($ref);
	  $is_sub = 1 if length($alt_allele) == length($ref);
	}
	
	# multiple alt alleles?
	if($alt =~ /\,/) {
	  if($is_indel) {
		
		my @alts;
		
		if($alt =~ /D|I/) {
		  foreach my $alt_allele(split /\,/, $alt) {
			# deletion (VCF <4)
			  if($alt_allele =~ /D/) {
			  push @alts, '-';
			}			
			elsif($alt_allele =~ /I/) {
			  $alt_allele =~ s/^I//g;
			  push @alts, $alt_allele;
			}
		  }
		}
		
		else {
		  $ref = substr($ref, 1);
		  $ref = '-' if $ref eq '';
		  $start++;
		  
		  foreach my $alt_allele(split /\,/, $alt) {
			$alt_allele = substr($alt_allele, 1);
			$alt_allele = '-' if $alt_allele eq '';
			push @alts, $alt_allele;
		  }
		}
		
		$alt = join "/", @alts;
	  }
	  
	  else {
		# for substitutions we just need to replace ',' with '/' in $alt
		$alt =~ s/\,/\//;
	  }
	}
	
	else {
	  if($is_indel) {
		# deletion (VCF <4)
		if($alt =~ /D/) {
		  my $num_deleted = $alt;
		  $num_deleted =~ s/\D+//g;
		  $end += $num_deleted - 1;
		  $alt = "-";
		  $ref .= ("N" x ($num_deleted - 1)) unless length($ref) > 1;
		}
		
		# insertion (VCF <4)
		elsif($alt =~ /I/) {
		  $ref = '-';
		  $alt =~ s/^I//g;
		  $start++;
		}
		
		# insertion or deletion (VCF 4+)
		else {
		  # chop off first base
		  $ref = substr($ref, 1);
		  $alt = substr($alt, 1);
		  
		  $start++;
		  
		  if($ref eq '') {
			# make ref '-' if no ref allele left
			$ref = '-';
		  }
		  
		  # make alt '-' if no alt allele left
		  $alt = '-' if $alt eq '';
		}
	  }
	}
	
	$args = [$args->[0], $start, $end, $ref."/".$alt, 1, ($args->[2] eq '.' ? undef : $args->[2])];
  }
  
  return bless { '__raw__' => $args }, $class;
}


sub seqname   	    { return $_[0]->{'__raw__'}[0]; }
sub allele_string   { return $_[0]->{'__raw__'}[3]; }
sub strand          { return $_[0]->{'__raw__'}[4]; }
sub extra           { return $_[0]->{'__raw__'}[5]; }
sub external_data   { return undef; }

sub rawstart { my $self = shift; return $self->{'__raw__'}[1]; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[2]; }
sub id       { my $self = shift; return $self->{'__raw__'}[3]; }

sub coords {
  my ($self, $data) = @_;
  return ($data->[0], $data->[1], $data->[2]);
}
 

1;
