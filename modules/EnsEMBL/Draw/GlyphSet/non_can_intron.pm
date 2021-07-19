=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::non_can_intron;

### Draws non-canonical splicings on Transcript/SupportingEvidence

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
    my ($self) = @_;
    my $wuc  =   $self->{'config'};
    my $length  = $wuc->container_width();
    my $colour  = $self->my_colour('non_can_intron');
    my $trans_obj = $wuc->cache('trans_object');
    return unless $trans_obj->{'non_can_introns'};
    foreach my $intron (@{$trans_obj->{'non_can_introns'}}) {
	next unless defined $intron;
	my $exon_names = $intron->[4];
	
	# only draw this exon if is inside the slice
	my $box_start = $intron->[0];
	$box_start = 1 if $box_start < 1 ;
	my $box_end   = $intron->[1];
	$box_end    = $length if $box_end > $length;
		
	#Draw an I-bar covering the intron
	my $G = $self->Line({
	    'x'         => $box_start ,
	    'y'         => 1,
	    'width'     => $box_end-$box_start,
	    'height'    => 0,
	    'colour'    => $colour,
	    'absolutey' => 1,
	    'title'     => "$exon_names",
	    'href'      => '',
	});
	$self->push( $G );
	$G = $self->Line({
	    'x'         => $box_start,
	    'y'         => -2,
	    'width'     => 0,
	    'height'    => 6,
	    'colour'    => $colour,
	    'absolutey' => 1,
	    'title'     => "$exon_names",
	    'href'      => '',
	});
	$self->push( $G );
	$G = $self->Line({
	    'x'         => $box_end ,
	    'y'         => -2,
	    'width'     => 0,
	    'height'    => 6,
	    'colour'    => $colour,
	    'absolutey' => 1,
	    'title'     => "$exon_names",
	    'href'      => '',
	});	
	$self->push( $G )
    }
}

1;
