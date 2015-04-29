=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Text::Feature::VCF;

### VCF format for SNP data

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub rawstart  {return $_[0]->{'__raw__'}[1];}
sub rawend    {return $_[0]->{'__raw__'}[1];}

sub seqname {return $_[0]->{'__raw__'}[0];}
sub allele  {return $_[0]->{'__raw__'}[3];}
sub strand  {return $_[0]->{'__raw__'}[4];}
sub id      {return $_[0]->{'__raw__'}[5];}

sub coords {
  my ($self, $data) = @_;
  return ($data->[0], $data->[1], $data->[1]);
}

sub new {
  my( $class, $args ) = @_;
  
  # get relevant data
  my ($start, $end, $ref, $alt) = ($args->[1], $args->[1], $args->[3], $args->[4]);
  
  # adjust end coord
  $end += (length($ref) - 1);
  
  # find out if any of the alt alleles make this an insertion or a deletion
  my ($is_indel, $ins_count, $total_count);
  foreach my $alt_allele(split /\,/, $alt) {
	  $is_indel = 1 if $alt_allele =~ /D|I/;
	  $is_indel = 1 if length($alt_allele) != length($ref);
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
	    $alt =~ s/\,/\//g;
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
  
  $args->[0] =~ s/chr//g;
  
  $args = [$args->[0], $start, $end, $ref."/".$alt, 1, ($args->[2] eq '.' ? undef : $args->[2])];
  
  return bless { '__raw__' => $args }, $class;
}
 

1;
